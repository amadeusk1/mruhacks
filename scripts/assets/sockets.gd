class_name Sockets
## Finds the socket_* nodes baked into the asset pack (see vault note "Sockets and Attachments").

## All sockets under an asset: {"seat_0": Node3D, "door": Node3D, ...} (prefix stripped).
static func all(root: Node) -> Dictionary:
	var out := {}
	_collect(root, out)
	return out

## One socket by short name ("seat_0") or null.
static func find(root: Node, name: String) -> Node3D:
	return all(root).get(name)

static func _collect(n: Node, out: Dictionary) -> void:
	if n is Node3D and String(n.name).begins_with("socket_"):
		out[String(n.name).substr(7)] = n
	for c in n.get_children():
		_collect(c, out)
