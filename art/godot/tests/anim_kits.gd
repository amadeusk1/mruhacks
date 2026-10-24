extends SceneTree
# Lists every anim_* GLB's clips, then retargets an emote onto a separately loaded avatar_base:
# every track path must resolve (node + bone or blend shape), and playing the clip must move bones and morphs.

func find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := find(c, cls)
		if r:
			return r
	return null

func _init() -> void:
	var libs := {}
	for kit in DirAccess.get_directories_at("res://models"):
		if not kit.begins_with("anim_"):
			continue
		for f in DirAccess.get_files_at("res://models/" + kit):
			if not f.ends_with(".glb"):
				continue
			var root: Node = load("res://models/%s/%s" % [kit, f]).instantiate()
			var ap := find(root, "AnimationPlayer") as AnimationPlayer
			var sk := find(root, "Skeleton3D") as Skeleton3D
			var mi := find(root, "MeshInstance3D") as MeshInstance3D
			var clips := []
			if ap:
				for a in ap.get_animation_list():
					var an := ap.get_animation(a)
					clips.append("%s=%.3fs/loop%d" % [a, an.length, an.loop_mode])
				libs[kit] = ap.get_animation_library(ap.get_animation_library_list()[0])
			print("ANIM ", kit, "/", f, " bones=", sk.get_bone_count() if sk else 0,
				" blend_shapes=", mi.mesh.get_blend_shape_count() if mi else 0, " clips=", clips.size(), " ", clips)
			root.free()
	# retarget: anim_emotes clip on the avatar/avatar_base scene
	var av: Node3D = load("res://models/avatar/avatar_base.glb").instantiate()
	root.add_child(av)
	var sk := find(av, "Skeleton3D") as Skeleton3D
	var mi := find(av, "MeshInstance3D") as MeshInstance3D
	var bad := []
	var tracks := 0
	for kit in libs:
		for an_name in libs[kit].get_animation_list():
			var an: Animation = libs[kit].get_animation(an_name)
			for i in an.get_track_count():
				tracks += 1
				var p := an.track_get_path(i)
				var node := av.get_node_or_null(NodePath(String(p.get_concatenated_names())))
				var sub := String(p.get_concatenated_subnames())
				var ok := node != null
				if ok and node is Skeleton3D and sub != "":
					ok = node.find_bone(sub) >= 0
				elif ok and node is MeshInstance3D and an.track_get_type(i) == Animation.TYPE_BLEND_SHAPE:
					ok = node.find_blend_shape_by_name(sub) >= 0
				if not ok:
					bad.append("%s:%s" % [an_name, p])
	print("RETARGET tracks=", tracks, " unresolved=", bad.size(), " ", bad.slice(0, 5))
	# play an emote on avatar_base through a fresh AnimationPlayer and confirm the pose and face change
	var ap := AnimationPlayer.new()
	av.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("emotes", libs["anim_emotes"])
	var bi := sk.find_bone("flipper.R")
	var rest := sk.get_bone_pose_rotation(bi)
	ap.play("emotes/emote_wave")
	ap.seek(0.45, true)
	var moved := rest.angle_to(sk.get_bone_pose_rotation(bi))
	var bs := mi.get_blend_shape_value(mi.find_blend_shape_by_name("eyes_happy"))
	print("RETARGET play emote_wave@0.45s flipper.R_rotated_deg=", snappedf(rad_to_deg(moved), 0.1), " eyes_happy=", snappedf(bs, 0.01),
		" RESULT ", "PASS" if bad.is_empty() and moved > 0.5 and bs > 0.5 else "FAIL")
	quit()
