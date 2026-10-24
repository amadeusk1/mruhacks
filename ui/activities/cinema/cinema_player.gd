extends Control
## Real media overlay. Native: system WebView. Web: same-origin HTML player bridge.
## The game remains connected; the webview owns its only movie decoder/audio output.
signal finished
var url := ""          ## close-up page (embed mode + single-use ticket); default: the service page
var _view: Control
var _volume := -1.0
var _bridge: JavaScriptObject
var _callback: JavaScriptObject
var _closing := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.has_feature("web"):
		_bridge = JavaScriptBridge.get_interface("PenglooCinema")
		if _bridge == null:
			_show_error("Cinema web bridge is missing. Add /cinema/bridge.js to the web export shell.")
			return
		_callback = JavaScriptBridge.create_callback(func(_args: Array) -> void: close())
		_bridge.open(_callback)
	elif native_webview() and ClassDB.class_exists("WebView") and DisplayServer.get_name() != "headless":
		_view = ClassDB.instantiate("WebView") as Control
		if _view == null:
			_show_error("The native cinema player failed to start.")
			return
		_view.set("full_window_size", true)
		_view.set("autoplay", true)
		_view.set("forward_input_events", false)
		_view.set("incognito", true)
		_view.set("url", url if url != "" else service_url())
		_view.connect("ipc_message", _on_message)
		_view.connect("page_load_finished", func(_u: String) -> void: _volume = -1.0)
		add_child(_view)
	elif url != "":
		OS.shell_open(url)  # no native webview: watch close-up in the system browser instead
		_show_error("Close-up opened in your browser. The film keeps playing on the big screen here.")
	else:
		_show_error("Close-up isn't available here. The film keeps playing on the big screen.")

## Project setting pengloo/cinema/native_webview (default on): off skips the WRY WebView entirely.
static func native_webview() -> bool:
	return bool(ProjectSettings.get_setting("pengloo/cinema/native_webview", true))


static func service_url() -> String:
	var configured := OS.get_environment("PENGLOO_CINEMA_URL")
	if configured.is_empty():
		configured = str(ProjectSettings.get_setting("cinema/service_url", "https://pengloo.party/cinema/"))
	return configured

## Movie volume follows Settings (UIRouter "movie"), applied inside the page.
func _process(_d: float) -> void:
	var v := float(UIRouter.settings.get("movie", 50.0)) / 100.0
	if is_instance_valid(_view) and v != _volume:
		_volume = v
		_view.call("eval", "window.penglooSetVolume && penglooSetVolume(%.2f)" % v)


func _on_message(message: String) -> void:
	var data: Variant = JSON.parse_string(message)
	if data is Dictionary and data.get("type") == "pengloo-cinema-close":
		close.call_deferred()

func _show_error(message: String) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var button := Button.new()
	button.text = "Return to cinema"
	button.pressed.connect(close)
	box.add_child(button)

func close() -> void:
	if _closing:
		return
	_closing = true
	if _bridge != null:
		_bridge.close()
	if is_instance_valid(_view):
		_view.call("focus_parent")
		_view.queue_free()
	UIRouter.remove(self)
	finished.emit()
	queue_free()

func _exit_tree() -> void:
	if _bridge != null and not _closing:
		_bridge.close()
