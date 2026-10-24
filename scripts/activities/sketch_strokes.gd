class_name SketchStrokes
extends RefCounted
## Wire format for SketchCanvas strokes ({c: "rrggbb", w: width at 1000 px, p: PackedVector2Array 0..1}).
## Per stroke: rgb (3 bytes), width (u8), point count (u16), then points as u16 x/y quantized
## to 1/65535 of the canvas. Caps match SketchCanvas so a hostile client cannot inflate payloads.

const MAX_STROKES := 400
const MAX_POINTS := 6000
const MAX_BYTES := 8 + MAX_STROKES * 6 + MAX_POINTS * 4


static func encode(strokes: Array) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	var n := mini(strokes.size(), MAX_STROKES)
	b.put_u16(n)
	var budget := MAX_POINTS
	for i in n:
		var s: Dictionary = strokes[i]
		var c := Color(str(s.get("c", "#000000")))
		b.put_u8(c.r8)
		b.put_u8(c.g8)
		b.put_u8(c.b8)
		b.put_u8(clampi(int(round(float(s.get("w", 8.0)))), 1, 255))
		var p: PackedVector2Array = s.get("p", PackedVector2Array())
		var count := mini(p.size(), budget)
		budget -= count
		b.put_u16(count)
		for k in count:
			b.put_u16(int(clampf(p[k].x, 0.0, 1.0) * 65535.0))
			b.put_u16(int(clampf(p[k].y, 0.0, 1.0) * 65535.0))
	return b.data_array


## Returns [] for anything malformed instead of trusting the sender.
static func decode(data: PackedByteArray) -> Array:
	if data.size() < 2 or data.size() > MAX_BYTES:
		return []
	var b := StreamPeerBuffer.new()
	b.data_array = data
	var out := []
	var n := b.get_u16()
	if n > MAX_STROKES:
		return []
	for _i in n:
		if b.get_available_bytes() < 6:
			return []
		var c := Color8(b.get_u8(), b.get_u8(), b.get_u8())
		var w := float(b.get_u8())
		var count := b.get_u16()
		if b.get_available_bytes() < count * 4:
			return []
		var p := PackedVector2Array()
		p.resize(count)
		for k in count:
			p[k] = Vector2(b.get_u16() / 65535.0, b.get_u16() / 65535.0)
		out.append({"c": c.to_html(false), "w": w, "p": p})
	return out
