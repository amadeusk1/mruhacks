extends Node
## One-shot overlap check for the town HUD at the project viewport size. Not part of the game.


func _ready() -> void:
	var hud: Node = load("res://scenes/play_hud.tscn").instantiate()
	get_tree().root.add_child.call_deferred(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var root := hud.get_node("Root") as Control
	var town: TownHud = null
	for child in root.get_children():
		if child is TownHud:
			town = child
	print("VIEW ", get_viewport().get_visible_rect().size)
	if town == null:
		print("NO TOWN HUD")
		get_tree().quit()
		return
	town._action.set_caption("Enter café")
	town._action.visible = true
	town._action._restyle()
	town._place_action()
	await get_tree().process_frame
	town._place_action()
	await get_tree().process_frame
	print("LABEL ", town._action._label.text, " ", town._action._label.get_combined_minimum_size(), " btn ", town._action.get_combined_minimum_size())
	var chat := root.get_node("Chat") as Control
	var coin := root.get_node("CoinBadge") as Control
	var chip := town._chip
	var mic := town._mic
	var dock := town._dock
	var action := town._action
	var map := dock.get_child(0) as Control
	_report("chat", chat)
	_report("coin", coin)
	_report("chip", chip)
	_report("mic", mic)
	_report("dock", dock)
	_report("map", map)
	_report("action", action)
	_gap("chat", chat, "dock", dock)
	_gap("chat", chat, "map", map)
	_gap("coin", coin, "mic", mic)
	_gap("action", action, "dock", dock)
	_gap("chip", chip, "coin", coin)
	get_tree().quit()


func _report(name: String, c: Control) -> void:
	var r := c.get_global_rect()
	print("RECT %s %.1f,%.1f %.1fx%.1f" % [name, r.position.x, r.position.y, r.size.x, r.size.y])


func _gap(a_name: String, a: Control, b_name: String, b: Control) -> void:
	var ra := a.get_global_rect()
	var rb := b.get_global_rect()
	var hit := ra.intersects(rb)
	var dx := 0.0
	if ra.position.x + ra.size.x <= rb.position.x:
		dx = rb.position.x - (ra.position.x + ra.size.x)
	elif rb.position.x + rb.size.x <= ra.position.x:
		dx = ra.position.x - (rb.position.x + rb.size.x)
	var dy := 0.0
	if ra.position.y + ra.size.y <= rb.position.y:
		dy = rb.position.y - (ra.position.y + ra.size.y)
	elif rb.position.y + rb.size.y <= ra.position.y:
		dy = ra.position.y - (rb.position.y + rb.size.y)
	print("GAP %s %s hit=%s dx=%.1f dy=%.1f" % [a_name, b_name, hit, dx, dy])
