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
	"sort"
	"strings"
	"time"
)

type Title struct {
	ID       string  `json:"id"`
	Title    string  `json:"title"`
	Year     int     `json:"year"`
	Duration float64 `json:"duration"`
	Kind     string  `json:"kind"`             // movie, series, or episode
	Poster   bool    `json:"poster"`           // a Primary image exists; bytes come from /api/image
	Season   int     `json:"season,omitempty"`
	Episode  int     `json:"episode,omitempty"`
}
type Season struct {
	Number   int     `json:"number"`
	Name     string  `json:"name"`
	Episodes []Title `json:"episodes"`
}
type Playback struct {
	URL       *url.URL
	SessionID string
	Title     Title
}
type Provider interface {
	Catalog(context.Context, string) ([]Title, error)
	Show(context.Context, string) ([]Season, error)
	Poster(context.Context, string) (*http.Response, error)
	Open(context.Context, string) (Playback, error)
	Stop(context.Context, string) error
	Fetch(context.Context, *url.URL, string) (*http.Response, error)
	Source(context.Context, string) (*url.URL, error) // original file, for the segment transcoder
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
	ID        string            `json:"Id"`
	Name      string            `json:"Name"`
	Type      string            `json:"Type"`
	Year      int               `json:"ProductionYear"`
	Ticks     int64             `json:"RunTimeTicks"`
	Season    int               `json:"ParentIndexNumber"`
	Episode   int               `json:"IndexNumber"`
	ImageTags map[string]string `json:"ImageTags"`
}

func validMediaID(id string) bool {
	if id == "" || len(id) > 100 || strings.Contains(id, "/") || strings.Contains(id, "..") {
		return false
	}
	return true
}
func (i embyItem) title() Title {
	kind := strings.ToLower(i.Type)
	if kind == "" {
		kind = "movie"
	}
	return Title{ID: i.ID, Title: i.Name, Year: i.Year, Duration: float64(i.Ticks) / 1e7, Kind: kind, Poster: i.ImageTags["Primary"] != "", Season: i.Season, Episode: i.Episode}
}
func (p *Emby) Catalog(ctx context.Context, search string) ([]Title, error) {
	// Series, not Episode: episodes belong under their show, not loose in the movie row.
	q := url.Values{"Recursive": {"true"}, "IncludeItemTypes": {"Movie,Series"}, "Fields": {"RunTimeTicks,ImageTags,Type"}, "Limit": {"80"}, "SortBy": {"SortName"}, "SortOrder": {"Ascending"}}
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

// Show is one series, grouped into seasons. Episodes stay in order inside each season.
func (p *Emby) Show(ctx context.Context, id string) ([]Season, error) {
	if !validMediaID(id) {
		return nil, errors.New("Invalid show")
	}
	var item embyItem
	if e := p.json(ctx, "GET", "/Users/"+url.PathEscape(p.User)+"/Items/"+url.PathEscape(id), nil, nil, &item); e != nil {
		return nil, e
	}
	if !strings.EqualFold(item.Type, "Series") {
		return nil, errors.New("That title is not a show")
	}
	q := url.Values{"UserId": {p.User}, "Fields": {"RunTimeTicks,ImageTags,Type,ParentIndexNumber,IndexNumber"}}
	var d struct{ Items []embyItem }
	if e := p.json(ctx, "GET", "/Shows/"+url.PathEscape(id)+"/Episodes", q, nil, &d); e != nil {
		return nil, e
	}
	order := []int{}
	by := map[int][]Title{}
	for _, ep := range d.Items {
		if _, ok := by[ep.Season]; !ok {
			order = append(order, ep.Season)
		}
		by[ep.Season] = append(by[ep.Season], ep.title())
	}
	sort.Ints(order)
	out := []Season{}
	for _, n := range order {
		name := "Specials"
		if n > 0 {
			name = fmt.Sprintf("Season %d", n)
		}
		eps := by[n]
		sort.Slice(eps, func(i, j int) bool { return eps[i].Episode < eps[j].Episode })
		out = append(out, Season{Number: n, Name: name, Episodes: eps})
	}
	return out, nil
}

// Poster is the Emby Primary image. The token stays on this request; callers only see image bytes.
func (p *Emby) Poster(ctx context.Context, id string) (*http.Response, error) {
	if !validMediaID(id) {
		return nil, errors.New("Invalid title")
	}
	return p.request(ctx, "GET", p.endpoint("/Items/"+url.PathEscape(id)+"/Images/Primary", url.Values{"maxWidth": {"480"}, "quality": {"80"}}), nil)
}
func (p *Emby) Open(ctx context.Context, id string) (Playback, error) {
	// Fetch through the selected user's library: rejects IDs the cinema user cannot access.
	var item embyItem
	if e := p.json(ctx, "GET", "/Users/"+url.PathEscape(p.User)+"/Items/"+url.PathEscape(id), nil, nil, &item); e != nil {
		return Playback{}, e
	}
	if strings.EqualFold(item.Type, "Series") || strings.EqualFold(item.Type, "Season") {
		return Playback{}, errors.New("Pick an episode from that show")
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

// Source is the original media file (Range-capable); Fetch adds the token header.
func (p *Emby) Source(_ context.Context, id string) (*url.URL, error) {
	return p.endpoint("/Videos/"+url.PathEscape(id)+"/stream", url.Values{"static": {"true"}}), nil
}
