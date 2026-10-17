extends Node2D
## All the short-lived on-screen effects (floating damage numbers, expanding
## rings, beams) in ONE node: updated in one loop and drawn in one pass, instead
## of a separate node per effect. Capped so a huge fight cannot flood it.

const MAX := 140
const TEXT_MAX := 90

var _items: Array = []   # {kind, pos, t, life, text, color, size, radius, to, width}
var _texts := 0


func count() -> int:
	return _items.size()


func text(pos: Vector2, s: String, color: Color, size: int) -> void:
	if _texts >= TEXT_MAX or _items.size() >= MAX:
		return
	_texts += 1
	_items.append({"kind": "text", "pos": pos, "t": 0.0, "life": 0.7, "text": s, "color": color, "size": size})


func ring(pos: Vector2, radius: float, color: Color) -> void:
	if _items.size() >= MAX:
		return
	_items.append({"kind": "ring", "pos": pos, "t": 0.0, "life": 0.35, "radius": radius, "color": color})


func beam(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	_items.append({"kind": "beam", "pos": from, "t": 0.0, "life": 0.25, "to": to - from, "width": width, "color": color})


func _process(delta: float) -> void:
	if _items.is_empty():
		return
	var i := 0
	while i < _items.size():
		var it: Dictionary = _items[i]
		it["t"] += delta
		if it["t"] >= it["life"]:
			if it["kind"] == "text":
				_texts -= 1
			_items[i] = _items[_items.size() - 1]
			_items.pop_back()
			continue
		i += 1
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for it in _items:
		var k: float = it["t"] / it["life"]
		var c: Color = it["color"]
		match it["kind"]:
			"text":
				draw_string(font, it["pos"] + Vector2(-14, -40.0 * k), it["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, it["size"], Color(c, 1.0 - k * k))
			"ring":
				var r: float = it["radius"] * lerpf(0.5, 1.0, minf(k * 4.0, 1.0))
				draw_circle(it["pos"], r, Color(c, 0.30 * (1.0 - k)))
				draw_arc(it["pos"], r, 0.0, TAU, 48, Color(c, 1.0 - k), 2.0)
			"beam":
				var to: Vector2 = it["pos"] + it["to"]
				draw_line(it["pos"], to, Color(c, 0.35 * (1.0 - k)), it["width"] * 2.0)
				draw_line(it["pos"], to, Color(1, 1, 1, 1.0 - k), it["width"] * 0.5)
