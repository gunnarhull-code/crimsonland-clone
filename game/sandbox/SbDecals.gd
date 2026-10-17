extends Node2D
## Splatter and scorch marks painted on the ground. Each mark is a few soft-edged
## sprites (one shared radial-gradient texture, so the GPU batches them into a
## single draw). Oldest are removed past the cap; everything fades slowly.

const MAX := 220
const LIFE := 40.0

var enabled := true
var _tex: GradientTexture2D
var _items: Array = []     # {spr, age, alpha}
var _tick := 0.0


func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.set_offset(0, 0.35)
	g.set_offset(1, 1.0)
	_tex = GradientTexture2D.new()
	_tex.gradient = g
	_tex.fill = GradientTexture2D.FILL_RADIAL
	_tex.fill_from = Vector2(0.5, 0.5)
	_tex.fill_to = Vector2(1.0, 0.5)
	_tex.width = 64
	_tex.height = 64


func splat(pos: Vector2, color: Color, radius: float) -> void:
	if not enabled:
		return
	var c := Color(color.r * 0.55, color.g * 0.55, color.b * 0.55)
	_blob(pos, radius * 1.15, c, 0.6)
	for i in randi_range(1, 3):
		_blob(pos + Vector2.from_angle(randf() * TAU) * radius * randf_range(1.0, 1.8), radius * randf_range(0.25, 0.5), c, 0.55)


func scorch(pos: Vector2, radius: float) -> void:
	if enabled:
		_blob(pos, radius, Color(0.02, 0.02, 0.02), 0.55)


func clear_all() -> void:
	for it in _items:
		it["spr"].queue_free()
	_items.clear()


func _blob(pos: Vector2, radius: float, color: Color, alpha: float) -> void:
	if _items.size() >= MAX:
		_items.pop_front()["spr"].queue_free()
	var s := Sprite2D.new()
	s.texture = _tex
	s.position = pos
	s.scale = Vector2.ONE * (radius * 2.0 / 64.0)
	s.rotation = randf() * TAU
	s.modulate = Color(color, alpha)
	add_child(s)
	_items.append({"spr": s, "age": 0.0, "alpha": alpha, "color": color})


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.5 or _items.is_empty():
		return
	for it in _items:
		it["age"] += _tick
		it["spr"].modulate = Color(it["color"], it["alpha"] * clampf(1.0 - it["age"] / LIFE, 0.0, 1.0))
	_tick = 0.0
	while not _items.is_empty() and _items[0]["age"] >= LIFE:
		_items.pop_front()["spr"].queue_free()
