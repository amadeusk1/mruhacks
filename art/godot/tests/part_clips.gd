extends SceneTree
# Prop part clips: every GLB with a part_ node should have its generated clips, loops looping.
func find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r := find_ap(c)
		if r: return r
	return null
func _init() -> void:
	var files := 0
	var clips := 0
	var loops := 0
	var bad := []
	for kit in DirAccess.get_directories_at("res://models"):
		if kit.begins_with("anim_"): continue
		for f in DirAccess.get_files_at("res://models/" + kit):
			if not f.ends_with(".glb"): continue
			var _ps = load("res://models/%s/%s" % [kit, f])
			if _ps == null:
				print("LOAD_FAILED ", kit, "/", f)
				continue
			var r: Node = _ps.instantiate()
			var ap := find_ap(r)
			if ap:
				files += 1
				for nm in ap.get_animation_list():
					clips += 1
					var a := ap.get_animation(nm)
					var should_loop: bool = nm.ends_with("_sway") or nm.ends_with("_flutter") or nm.ends_with("_spin")
					if should_loop and a.loop_mode == Animation.LOOP_NONE: bad.append("%s/%s:%s" % [kit, f, nm])
					if a.loop_mode != Animation.LOOP_NONE: loops += 1
					for t in a.get_track_count():
						if r.get_node_or_null(ap.root_node).get_node_or_null(NodePath(String(a.track_get_path(t)).get_slice(":", 0))) == null:
							bad.append("%s/%s:%s unresolved %s" % [kit, f, nm, a.track_get_path(t)])
			r.free()
	print("PART_CLIPS files=%d clips=%d looping=%d problems=%s" % [files, clips, loops, str(bad.slice(0, 8))])
	quit()
