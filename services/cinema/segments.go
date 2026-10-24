package main

// Segments: server-side decode for in-world screens. An ffmpeg child process turns the current
// film into short MJPEG (video) or MP3 (audio) chunks, so game clients never run a video decoder
// or a webview: they only decode JPEG frames and MP3, which Godot does natively and on the web.
// ffmpeg reads the film through a loopback-only, single-use token URL, so the Emby key never
// appears in its arguments.

import (
	"context"
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
)

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
	id, dur := s.state.Title.ID, s.state.Title.Duration
	s.mu.Unlock()
	if id == "" {
		fail(w, 409, "Choose a film first")
		return
	}
	if dur > 0 && start >= dur {
		fail(w, 416, "Past the end of the film")
		return
	}
	select {
	case s.ffmpegSlots <- struct{}{}:
		defer func() { <-s.ffmpegSlots }()
	default:
		fail(w, 503, "Cinema is busy; retry")
		return
	}
	token := randomID()
	s.mu.Lock()
	s.sources[token] = id
	s.mu.Unlock()
	defer func() { s.mu.Lock(); delete(s.sources, token); s.mu.Unlock() }()
	ctx, cancel := context.WithTimeout(r.Context(), 90*time.Second)
	defer cancel()
	args := []string{"-nostdin", "-loglevel", "error", "-ss", strconv.FormatFloat(start, 'f', 3, 64),
		"-i", s.selfURL + "/cinema/internal/source/" + token, "-t", strconv.FormatFloat(length, 'f', 3, 64)}
	if kind == "video" {
		args = append(args, "-an", "-vf", "fps="+strconv.Itoa(segmentFPS)+",scale=640:-2", "-q:v", "6", "-f", "image2pipe", "-c:v", "mjpeg", "pipe:1")
		w.Header().Set("Content-Type", "application/x-pengloo-frames")
		w.Header().Set("X-Segment-Fps", strconv.Itoa(segmentFPS))
	} else {
		args = append(args, "-vn", "-ac", "2", "-ar", "44100", "-c:a", "libmp3lame", "-b:a", "128k", "-f", "mp3", "pipe:1")
		w.Header().Set("Content-Type", "audio/mpeg")
	}
	cmd := exec.CommandContext(ctx, s.ffmpeg, args...)
	out, e := cmd.StdoutPipe()
	if e != nil || cmd.Start() != nil {
		fail(w, 502, "Transcoder failed to start")
		return
	}
	w.Header().Set("Cache-Control", "private, no-store")
	if kind == "audio" {
		_, _ = io.Copy(w, out)
	} else {
		raw, _ := io.ReadAll(io.LimitReader(out, 64<<20))
		_, _ = w.Write(frameJPEGs(raw))
	}
	_ = cmd.Wait()
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
