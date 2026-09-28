extends Node2D
## Draws a circle sized exactly to the entity's hitbox (issues/19: what's
## visible is what can hit you) with a bold flat inner shape for species
## identity. Shared by Player and Enemy so the "circle = hitbox" rule can't
## drift between them.

@export var radius: float = 14.0
@export var fill_color: Color = Color.WHITE
@export var inner_color: Color = Color.BLACK
@export var inner_shape: String = "triangle" # triangle | dots | diamond | hexagon
@export var boss_ring: bool = false


func configure(p_radius: float, p_fill: Color, p_inner: Color, p_shape: String, p_boss: bool = false) -> void:
	radius = p_radius
	fill_color = p_fill
	inner_color = p_inner
	inner_shape = p_shape
	boss_ring = p_boss
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color)
	if boss_ring:
		draw_arc(Vector2.ZERO, radius - 1.5, 0.0, TAU, 48, Color.WHITE, 3.0)
	match inner_shape:
		"triangle":
			_draw_triangle()
		"dots":
			_draw_dots()
		"diamond":
			_draw_diamond()
		"hexagon":
			_draw_hexagon()


func _draw_triangle() -> void:
	var s := radius * 0.7
	var tri := PackedVector2Array([Vector2(s * 0.6, 0.0), Vector2(-s * 0.4, s * 0.45), Vector2(-s * 0.4, -s * 0.45)])
	draw_colored_polygon(tri, inner_color)


func _draw_dots() -> void:
	var r := radius * 0.16
	for dx in [-radius * 0.45, 0.0, radius * 0.45]:
		draw_circle(Vector2(dx, 0.0), r, inner_color)


func _draw_diamond() -> void:
	var s := radius * 0.42
	var pts := PackedVector2Array([Vector2(0.0, -s), Vector2(s, 0.0), Vector2(0.0, s), Vector2(-s, 0.0)])
	draw_colored_polygon(pts, inner_color)


func _draw_hexagon() -> void:
	var s := radius * 0.4
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 - PI / 6.0
		pts.append(Vector2(cos(a), sin(a)) * s)
	draw_colored_polygon(pts, inner_color)
