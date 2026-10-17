extends Node2D
## Splatter and scorch marks painted on the ground. Oldest are removed past the
## cap; everything fades slowly. Redrawn only when something changes.

const MAX := 260
const LIFE := 40.0

var enabled := true
var _d: Array = []     # {pts, dots, color, age}
var _tick := 0.0


func splat(pos: Vector2, color: Color, radius: float) -> void:
	if not enabled:
		return
	var pts := PackedVector2Array()
	var n := 9
	for i in n:
		var a := TAU * i / n
		pts.append(pos + Vector2.from_angle(a) * radius * randf_range(0.55, 1.15))
	var dots: Array = []
	for i in randi_range(2, 5):
		dots.append([pos + Vector2.from_angle(randf() * TAU) * radius * randf_range(1.1, 1.9), radius * randf_range(0.12, 0.28)])
	_add({"pts": pts, "dots": dots, "color": Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, 0.55), "age": 0.0})


func scorch(pos: Vector2, radius: float) -> void:
	if not enabled:
		return
	var pts := PackedVector2Array()
	var n := 14
	for i in n:
		pts.append(pos + Vector2.from_angle(TAU * i / n) * radius * randf_range(0.6, 1.0))
	_add({"pts": pts, "dots": [], "color": Color(0.03, 0.03, 0.03, 0.5), "age": 0.0})


func clear_all() -> void:
	_d.clear()
	queue_redraw()


func _add(d: Dictionary) -> void:
	if _d.size() >= MAX:
		_d.pop_front()
	_d.append(d)
	queue_redraw()


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.5 or _d.is_empty():
		return
	for d in _d:
		d["age"] += _tick
	_tick = 0.0
	_d = _d.filter(func(d): return d["age"] < LIFE)
	queue_redraw()


func _draw() -> void:
	for d in _d:
		var c: Color = d["color"]
		c.a *= clampf(1.0 - d["age"] / LIFE, 0.0, 1.0)
		draw_colored_polygon(d["pts"], c)
		for dot in d["dots"]:
			draw_circle(dot[0], dot[1], c)
