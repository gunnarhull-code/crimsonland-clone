extends Node2D
## Minimal projectile shapes per issues/19's weapon icon palette.

var _mode: String = "dot"
var _size: float = 3.0
var _color: Color = Color.WHITE


func configure_dot(radius: float, color: Color) -> void:
	_mode = "dot"
	_size = radius
	_color = color
	queue_redraw()


func configure_line(length: float, color: Color) -> void:
	_mode = "line"
	_size = length
	_color = color
	queue_redraw()


func _draw() -> void:
	if _mode == "dot":
		draw_circle(Vector2.ZERO, _size, _color)
	else:
		draw_line(Vector2(-_size / 2.0, 0.0), Vector2(_size / 2.0, 0.0), _color, 4.0)
