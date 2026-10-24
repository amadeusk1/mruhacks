package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type Title struct {
	ID       string  `json:"id"`
	Title    string  `json:"title"`
	Year     int     `json:"year"`
	Duration float64 `json:"duration"`
}
type Playback struct {
	URL       *url.URL
	SessionID string
	Title     Title
}
type Provider interface {
	Catalog(context.Context, string) ([]Title, error)
	Open(context.Context, string) (Playback, error)
	Stop(context.Context, string) error
	Fetch(context.Context, *url.URL, string) (*http.Response, error)
}
type Emby struct {
	Base      *url.URL
	Key, User string
	Client    *http.Client
	Bitrate   int
}

func newEmby(raw, key, user string) (*Emby, error) {
	u, e := url.Parse(raw)
	if e != nil || u.Host == "" || (u.Scheme != "https" && u.Scheme != "http") || u.User != nil || u.RawQuery != "" {
		return nil, errors.New("invalid EMBY_URL")
	}
	u.Path = strings.TrimRight(u.Path, "/")
	if !strings.HasSuffix(strings.ToLower(u.Path), "/emby") {
		u.Path += "/emby"
	}
	p := &Emby{Base: u, Key: key, User: user, Bitrate: 6000000}
	p.Client = &http.Client{Timeout: 45 * time.Second, CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }}
	return p, nil
}
func (p *Emby) endpoint(path string, q url.Values) *url.URL {
	u := *p.Base
	u.Path += path
	u.RawQuery = q.Encode()
	return &u
}
func (p *Emby) request(ctx context.Context, method string, u *url.URL, body any) (*http.Response, error) {
	if !p.safe(u) {
		return nil, errors.New("media origin rejected")
	}
	var data io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		data = bytes.NewReader(b)
	}
	req, e := http.NewRequestWithContext(ctx, method, u.String(), data)
	if e != nil {
		return nil, errors.New("invalid upstream request")
	}
	req.Header.Set("User-Agent", "PenglooCinema/0.1")
	req.Header.Set("X-Emby-Token", p.Key)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Emby-Authorization", `MediaBrowser Client="Pengloo Cinema", Device="Cinema gateway", DeviceId="pengloo-cinema", Version="0.1.0"`)
	resp, e := p.Client.Do(req)
	if e != nil {
		return nil, errors.New("Emby request failed")
	}
	return resp, nil
}
func (p *Emby) safe(u *url.URL) bool {
	return u != nil && u.Scheme == p.Base.Scheme && u.Host == p.Base.Host && u.User == nil
}
func (p *Emby) json(ctx context.Context, method, path string, q url.Values, body, out any) error {
	resp, e := p.request(ctx, method, p.endpoint(path, q), body)
	if e != nil {
		return e
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("Emby returned HTTP %d", resp.StatusCode)
	}
	return json.NewDecoder(io.LimitReader(resp.Body, 8<<20)).Decode(out)
}

type embyItem struct {
	ID    string `json:"Id"`
	Name  string `json:"Name"`
	Year  int    `json:"ProductionYear"`
	Ticks int64  `json:"RunTimeTicks"`
}

func (i embyItem) title() Title { return Title{i.ID, i.Name, i.Year, float64(i.Ticks) / 1e7} }
func (p *Emby) Catalog(ctx context.Context, search string) ([]Title, error) {
	q := url.Values{"Recursive": {"true"}, "IncludeItemTypes": {"Movie,Episode"}, "Fields": {"RunTimeTicks"}, "Limit": {"80"}, "SortBy": {"SortName"}, "SortOrder": {"Ascending"}}
	if search != "" {
		q.Set("SearchTerm", search)
	}
	var d struct{ Items []embyItem }
	e := p.json(ctx, "GET", "/Users/"+url.PathEscape(p.User)+"/Items", q, nil, &d)
	out := []Title{}
	for _, i := range d.Items {
		out = append(out, i.title())
	}
	return out, e
}
func (p *Emby) Open(ctx context.Context, id string) (Playback, error) {
	// Fetch through the selected user's library: rejects IDs the cinema user cannot access.
	var item embyItem
	if e := p.json(ctx, "GET", "/Users/"+url.PathEscape(p.User)+"/Items/"+url.PathEscape(id), nil, nil, &item); e != nil {
		return Playback{}, e
	}
	profile := map[string]any{"Name": "Pengloo browser", "MaxStreamingBitrate": p.Bitrate, "DirectPlayProfiles": []any{}, "TranscodingProfiles": []any{map[string]any{"Type": "Video", "Container": "ts", "Protocol": "hls", "VideoCodec": "h264", "AudioCodec": "aac", "Context": "Streaming", "MaxAudioChannels": "2", "MinSegments": 2, "BreakOnNonKeyFrames": true}}}
	body := map[string]any{"UserId": p.User, "DeviceProfile": profile, "MaxStreamingBitrate": p.Bitrate, "EnableDirectPlay": false, "EnableDirectStream": false, "EnableTranscoding": true, "AllowVideoStreamCopy": false, "AllowAudioStreamCopy": false, "AutoOpenLiveStream": true, "StartTimeTicks": 0}
	var info struct {
		PlaySessionID string `json:"PlaySessionId"`
		ErrorCode     string
		MediaSources  []struct {
			TranscodingURL string `json:"TranscodingUrl"`
		}
	}
	if e := p.json(ctx, "POST", "/Items/"+url.PathEscape(id)+"/PlaybackInfo", nil, body, &info); e != nil {
		return Playback{}, e
	}
	for _, m := range info.MediaSources {
		if m.TranscodingURL != "" {
			ref, e := url.Parse(m.TranscodingURL)
			if e != nil {
				continue
			}
			base := *p.Base
			base.Path += "/"
			u := base.ResolveReference(ref)
			if !p.safe(u) {
				return Playback{}, errors.New("Emby returned a different media origin")
			}
			return Playback{u, info.PlaySessionID, item.title()}, nil
		}
	}
	return Playback{}, errors.New("Emby did not offer a compatible HLS transcode; check user transcoding permissions")
}
func (p *Emby) Stop(ctx context.Context, id string) error {
	if id == "" {
		return nil
	}
	resp, e := p.request(ctx, "DELETE", p.endpoint("/Videos/ActiveEncodings", url.Values{"DeviceId": {"pengloo-cinema"}, "PlaySessionId": {id}}), nil)
	if e != nil {
		return e
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return errors.New("Emby transcode stop failed")
	}
	return nil
}
func (p *Emby) Fetch(ctx context.Context, u *url.URL, rangeHeader string) (*http.Response, error) {
	if !p.safe(u) {
		return nil, errors.New("media origin rejected")
	}
	req, e := http.NewRequestWithContext(ctx, "GET", u.String(), nil)
	if e != nil {
		return nil, errors.New("invalid media URL")
	}
	req.Header.Set("User-Agent", "PenglooCinema/0.1")
	req.Header.Set("X-Emby-Token", p.Key)
	if rangeHeader != "" {
		req.Header.Set("Range", rangeHeader)
	}
	resp, e := p.Client.Do(req)
	if e != nil {
		return nil, errors.New("Emby stream unavailable")
	}
	return resp, nil
}
