package main

// Segments: server-side decode for in-world screens. An ffmpeg child process turns the current
// film into short MJPEG (video) or MP3 (audio) chunks, so game clients never run a video decoder
// or a webview: they only decode JPEG frames and MP3, which Godot does natively and on the web.
// ffmpeg reads the film through a loopback-only, single-use token URL, so the Emby key never
// appears in its arguments.

import (
	"context"
	"fmt"
	"io"
	"math"
	"net"
	"net/http"
	"os/exec"
	"strconv"
	"time"
)

const (
	segmentFPS    = 15
	segmentMaxLen = 20.0
	segmentCache  = 16 // recent segments kept for other viewers (~40 MB worst case)
)

// cachedSegment is one transcoded chunk shared by every viewer of the same screening;
// done closes when bytes are ready, so concurrent requests wait instead of re-transcoding.
type cachedSegment struct {
	done  chan struct{}
	bytes []byte
	used  time.Time
}

func (s *Server) segment(w http.ResponseWriter, r *http.Request, u session) {
	q := r.URL.Query()
	kind := q.Get("kind")
	start, e1 := strconv.ParseFloat(q.Get("start"), 64)
	length, e2 := strconv.ParseFloat(q.Get("len"), 64)
	if (kind != "video" && kind != "audio") || e1 != nil || e2 != nil || math.IsNaN(start) || math.IsInf(start, 0) ||
		start < 0 || math.IsNaN(length) || length < 1 || length > segmentMaxLen {
		fail(w, 400, "Invalid segment")
		return
	}
	if s.ffmpeg == "" {
		fail(w, 501, "ffmpeg is not installed on the cinema server")
		return
	}
	s.touch(u.ID)
	s.mu.Lock()
	id, dur, gen := s.state.Title.ID, s.state.Title.Duration, s.state.Generation
	s.mu.Unlock()
	if id == "" {
		fail(w, 409, "Choose a film first")
		return
	}
	if dur > 0 && start >= dur {
		fail(w, 416, "Past the end of the film")
		return
	}
	s.mu.Lock()
	if s.state.Generation != gen || s.state.Title.ID != id {
		s.mu.Unlock()
		fail(w, 409, "Screening changed")
		return
	}
	key := fmt.Sprintf("%d|%s|%s|%.3f|%.3f", gen, id, kind, start, length)
	c, hit := s.segments[key]
	if !hit {
		c = &cachedSegment{done: make(chan struct{})}
		s.segments[key] = c
		s.evictSegmentsLocked()
	}
	c.used = time.Now()
	s.mu.Unlock()
	if !hit {
		raw := s.transcode(id, kind, start, length, gen)
		s.mu.Lock()
		if s.state.Generation != gen || s.state.Title.ID != id {
			raw = nil
		}
		c.bytes = raw
		if raw == nil {
			delete(s.segments, key)
		}
		s.mu.Unlock()
		close(c.done)
	}
	select {
	case <-c.done:
	case <-r.Context().Done():
		return
	}
	if c.bytes == nil {
		fail(w, 503, "Transcode failed or cinema busy; retry")
		return
	}
	if kind == "video" {
		w.Header().Set("Content-Type", "application/x-pengloo-frames")
		w.Header().Set("X-Segment-Fps", strconv.Itoa(segmentFPS))
	} else {
		w.Header().Set("Content-Type", "audio/mpeg")
	}
	w.Header().Set("Cache-Control", "private, no-store")
	_, _ = w.Write(c.bytes)
}

func (s *Server) evictSegmentsLocked() {
	for len(s.segments) > segmentCache {
		oldest, at := "", time.Now()
		for k, v := range s.segments {
			if v.used.Before(at) {
				oldest, at = k, v.used
			}
		}
		delete(s.segments, oldest)
	}
}

// transcode runs one ffmpeg child for a chunk, queueing up to 30 s for a free slot; nil on failure.
// gen is the screening this chunk belongs to. A switch cancels it, and finished bytes are dropped
// if that screening is no longer current.
func (s *Server) transcode(id, kind string, start, length float64, gen int64) []byte {
	s.mu.Lock()
	screen := s.segCtx
	s.mu.Unlock()
	wait := time.NewTimer(30 * time.Second)
	defer wait.Stop()
	select {
	case s.ffmpegSlots <- struct{}{}:
		defer func() { <-s.ffmpegSlots }()
	case <-wait.C:
		return nil
	case <-screen.Done():
		return nil
	}
	if screen.Err() != nil {
		return nil
	}
	token := randomID()
	s.mu.Lock()
	s.sources[token] = id
	s.mu.Unlock()
	defer func() { s.mu.Lock(); delete(s.sources, token); s.mu.Unlock() }()
	// A viewer disconnecting must not cancel a chunk others are waiting on. Switching films does.
	ctx, cancel := context.WithTimeout(screen, 90*time.Second)
	defer cancel()
	args := []string{"-nostdin", "-loglevel", "error", "-ss", strconv.FormatFloat(start, 'f', 3, 64),
		"-i", s.selfURL + "/cinema/internal/source/" + token, "-t", strconv.FormatFloat(length, 'f', 3, 64)}
	if kind == "video" {
		args = append(args, "-an", "-vf", "fps="+strconv.Itoa(segmentFPS)+",scale=640:-2", "-q:v", "6", "-f", "image2pipe", "-c:v", "mjpeg", "pipe:1")
	} else {
		args = append(args, "-vn", "-ac", "2", "-ar", "44100", "-c:a", "libmp3lame", "-b:a", "128k", "-f", "mp3", "pipe:1")
	}
	raw, e := exec.CommandContext(ctx, s.ffmpeg, args...).Output()
	if e != nil || len(raw) == 0 || screen.Err() != nil {
		return nil
	}
	s.mu.Lock()
	current := s.state.Generation == gen && s.state.Title.ID == id
	s.mu.Unlock()
	if !current {
		return nil
	}
	if kind == "video" {
		return frameJPEGs(raw)
	}
	return raw
}

// frameJPEGs turns ffmpeg's concatenated JPEGs into [u32 little-endian length][jpeg]... so clients
// split frames in O(frames) instead of scanning bytes. ffmpeg's MJPEG frames carry no embedded
// thumbnails, so an SOI marker (FF D8 FF) only starts a frame.
func frameJPEGs(raw []byte) []byte {
	out := make([]byte, 0, len(raw)+4096)
	start := -1
	emit := func(end int) {
		n := end - start
		out = append(out, byte(n), byte(n>>8), byte(n>>16), byte(n>>24))
		out = append(out, raw[start:end]...)
	}
	for i := 0; i+2 < len(raw); i++ {
		if raw[i] == 0xFF && raw[i+1] == 0xD8 && raw[i+2] == 0xFF {
			if start >= 0 {
				emit(i)
			}
			start = i
			i += 2
		}
	}
	if start >= 0 {
		emit(len(raw))
	}
	return out
}

// internalSource feeds ffmpeg: loopback callers with a live segment token only.
func (s *Server) internalSource(w http.ResponseWriter, r *http.Request) {
	host, _, _ := net.SplitHostPort(r.RemoteAddr)
	if ip := net.ParseIP(host); ip == nil || !ip.IsLoopback() {
		http.NotFound(w, r)
		return
	}
	s.mu.Lock()
	id, ok := s.sources[r.PathValue("token")]
	s.mu.Unlock()
	if !ok {
		http.NotFound(w, r)
		return
	}
	u, e := s.provider.Source(r.Context(), id)
	if e != nil {
		fail(w, 502, e.Error())
		return
	}
	resp, e := s.provider.Fetch(r.Context(), u, r.Header.Get("Range"))
	if e != nil {
		fail(w, 502, e.Error())
		return
	}
	defer resp.Body.Close()
	for _, h := range []string{"Content-Type", "Content-Length", "Content-Range", "Accept-Ranges"} {
		if v := resp.Header.Get(h); v != "" {
			w.Header().Set(h, v)
		}
	}
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
}
