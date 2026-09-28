extends Node2D
## A brief jagged line between two points, showing what the Electric Gun's
## chain arc actually jumped to - per direct playtest request ("vfx lines
## showing what the electricity is jumping to"). Companion to ParticleBurst,
## but geometry instead of particles.

const LIFETIME := 0.15
const SEGMENTS := 5
const JAG_PX := 9.0

var _life: float = 0.0
var _color: Color = Color(0.6, 0.85, 1.0)
var _points: PackedVector2Array = PackedVector2Array()


func fire(from: Vector2, to: Vector2, color: Color) -> void:
	global_position = from
	_color = color
	var local_to := to - from
	var perp := Vector2(-local_to.y, local_to.x).normalized()
	_points = PackedVector2Array()
	for i in range(SEGMENTS + 1):
		var t := float(i) / SEGMENTS
		var jag := 0.0 if (i == 0 or i == SEGMENTS) else randf_range(-JAG_PX, JAG_PX)
		_points.append(local_to * t + perp * jag)
	queue_redraw()


func _process(delta: float) -> void:
	_life += delta
	if _life >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var c: Color = _color
	c.a = 1.0 - (_life / LIFETIME)
	for i in range(_points.size() - 1):
		draw_line(_points[i], _points[i + 1], c, 2.5)
