class_name CinemaSource
extends RefCounted
## Provider-neutral seam between the cinema UI and the MediaProvider boundary
## ("Cinema - Plex Watchparty Integration Plan": Plex first via adapted plex-watchparty, Emby later).
## The UI only talks to this interface; Plex/Emby adapters implement it. DemoSource below is the
## clearly-labelled stand-in. Item ids are opaque screening-scoped ids: provider item ids,
## tokens and stream URLs never reach the UI.
##
## status: "demo" | "signed_out" | "connecting" | "connected" | "empty" | "offline" | "error"
## item:   {id, title, year:int, thumb: Texture2D|null, thumb_url: String, duration_s: float, summary}
## snapshot (one server timeline, per the plan):
##   {screening_id, media_id, stream_generation, revision, playing, position_s, server_time_ms,
##    duration_s, controller_player_id, phase: "idle"|"preparing"|"buffering"|"playing"|"paused"|"ended",
##    audio_tracks: [{id, label}], subtitle_tracks: [{id, label}], audio_track, subtitle_track}  (tracks optional)

signal status_changed(status: String, detail: String)
signal catalog_changed(items: Array)
signal snapshot_changed(snapshot: Dictionary)

var provider_type := "demo"     ## "plex" | "emby" | "demo" (display only)
var source_name := ""           ## e.g. the media server's friendly name
var status := "offline"
var detail := ""
var items: Array = []
var snapshot := {}


func label() -> String:
	var kind: String = {"plex": "Plex", "emby": "Emby", "demo": "Demo"}.get(provider_type, "Media")
	return "%s (%s)" % [source_name, kind] if source_name != "" else kind


## Start connecting (join ticket exchange happens inside the adapter).
func connect_source() -> void:
	pass


## Library browse/search; results arrive via catalog_changed.
func search(_query: String) -> void:
	pass


## Controller-only intents. Each carries a request id and the revision it was based on;
## the service rejects stale or unauthorized commands and answers with a new snapshot.
func request_load(_media_id: String) -> void:
	pass


func request_play() -> void:
	pass


func request_pause() -> void:
	pass


func request_seek(_seconds: float) -> void:
	pass


## Track change for the shared stream (may restart the transcode for everyone; controller only).
func request_tracks(_audio_id: String, _subtitle_id: String) -> void:
	pass


func is_controller(player_id: String) -> bool:
	return str(snapshot.get("controller_player_id", "")) == player_id


## Position now, extrapolated from the last snapshot (clients interpolate; server is authority).
func position_now() -> float:
	var p := float(snapshot.get("position_s", 0.0))
	if bool(snapshot.get("playing", false)):
		p += (Time.get_ticks_msec() - float(snapshot.get("_local_ms", Time.get_ticks_msec()))) / 1000.0
	return minf(p, float(snapshot.get("duration_s", p)))


func _set_snapshot(s: Dictionary) -> void:
	s["_local_ms"] = Time.get_ticks_msec()
	s["revision"] = int(snapshot.get("revision", 0)) + 1
	snapshot = s
	snapshot_changed.emit(snapshot)


## Local demo library: no Plex, no streaming. Always labelled "Demo" in the UI.
class DemoSource:
	extends CinemaSource
	const TITLES := [
		{"id": "demo:moonbound", "title": "Moonbound", "year": 2026, "duration_s": 5708.0, "summary": "A little penguin. A big sky.", "top": "#1B2D5C", "bot": "#3A5AA0"},
		{"id": "demo:underwater", "title": "Underwater Day", "year": 2025, "duration_s": 5220.0, "summary": "Small friends. Big wonders.", "top": "#0F6A78", "bot": "#1F9FA8"},
		{"id": "demo:lantern", "title": "Lantern Coast", "year": 2024, "duration_s": 6010.0, "summary": "Brighter together.", "top": "#5B4A7C", "bot": "#E08A64"},
	]

	func connect_source() -> void:
		provider_type = "demo"
		source_name = "Demo library"
		status = "demo"
		detail = "No media server connected"
		status_changed.emit(status, detail)
		search("")

	func search(query: String) -> void:
		items = []
		for t in TITLES:
			if query == "" or str(t["title"]).to_lower().contains(query.to_lower()):
				items.append(t)
		catalog_changed.emit(items)

	func request_load(media_id: String) -> void:
		for t in TITLES:
			if t["id"] == media_id:
				_set_snapshot({"screening_id": "demo", "media_id": media_id, "stream_generation": 1, "playing": true,
					"position_s": 0.0, "duration_s": t["duration_s"], "controller_player_id": str(Net.local_id()), "phase": "playing"})

	func request_play() -> void:
		var s := snapshot.duplicate(); s["position_s"] = position_now(); s["playing"] = true; s["phase"] = "playing"
		_set_snapshot(s)

	func request_pause() -> void:
		var s := snapshot.duplicate(); s["position_s"] = position_now(); s["playing"] = false; s["phase"] = "paused"
		_set_snapshot(s)

	func request_seek(seconds: float) -> void:
		var s := snapshot.duplicate(); s["position_s"] = clampf(seconds, 0.0, float(s.get("duration_s", seconds)))
		_set_snapshot(s)
