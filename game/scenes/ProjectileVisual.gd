extends Node2D
## Per-weapon bullet shapes per issues/19's weapon icon palette. Circles are
## reserved for entity hitboxes (issue 19's "circle = hitbox" rule) - bullets
## aren't hitboxes, so each weapon gets its own silhouette instead of a
## generic dot, per direct playtest request ("bullets are different from
## guns").

var _mode: String = "dot"
var _size: float = 3.0
var _width: float = 4.0
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


func configure_capsule(length: float, width: float, color: Color) -> void:
	_mode = "capsule"
	_size = length
	_width = width
	_color = color
	queue_redraw()


func configure_bolt(size: float, color: Color) -> void:
	_mode = "bolt"
	_size = size
	_color = color
	queue_redraw()


func configure_pellet(size: float, color: Color) -> void:
	_mode = "pellet"
	_size = size
	_color = color
	queue_redraw()


func configure_rocket(length: float, width: float, color: Color) -> void:
	_mode = "rocket"
	_size = length
	_width = width
	_color = color
	queue_redraw()


func _draw() -> void:
	match _mode:
		"dot":
			draw_circle(Vector2.ZERO, _size, _color)
		"line":
			draw_line(Vector2(-_size / 2.0, 0.0), Vector2(_size / 2.0, 0.0), _color, 4.0)
		"capsule":
			_draw_capsule()
		"bolt":
			_draw_bolt()
		"pellet":
			_draw_pellet()
		"rocket":
			_draw_rocket()


## Elongated bullet along the travel axis - Pistol/SMG.
func _draw_capsule() -> void:
	var half := _size / 2.0
	draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), _color, _width)
	draw_circle(Vector2(half, 0.0), _width / 2.0, _color)
	draw_circle(Vector2(-half, 0.0), _width / 2.0, _color)


## A small jagged lightning glyph - Electric Gun.
func _draw_bolt() -> void:
	var s := _size
	var pts := PackedVector2Array([
		Vector2(-s * 0.6, -s * 0.5), Vector2(s * 0.05, -s * 0.1),
		Vector2(-s * 0.15, s * 0.1), Vector2(s * 0.6, s * 0.5),
		Vector2(s * 0.05, s * 0.05), Vector2(s * 0.2, -s * 0.15),
	])
	draw_polyline(pts, _color, 2.5)


## A small forward-pointing pellet - Shotgun.
func _draw_pellet() -> void:
	var s := _size
	var pts := PackedVector2Array([Vector2(s, 0.0), Vector2(-s * 0.6, s * 0.5), Vector2(-s * 0.6, -s * 0.5)])
	draw_colored_polygon(pts, _color)


## A tapered nose-cone shape - Heavy Cannon's rocket.
func _draw_rocket() -> void:
	var half := _size / 2.0
	var w := _width
	var body := PackedVector2Array([
		Vector2(half, 0.0), Vector2(half * 0.3, -w), Vector2(-half, -w),
		Vector2(-half, w), Vector2(half * 0.3, w),
	])
	draw_colored_polygon(body, _color)
