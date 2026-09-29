extends Node2D
## A simple two-rect health bar (dark backing + colored fill), redrawn
## whenever the fraction changes. First used by Nest.gd, per direct
## playtest request ("the nests need to have a health bar so I can
## destroy them") - Nest is the one entity in this game with no other
## progress readout (an Enemy just dies in a few hits; a Nest takes many).

const WIDTH := 50.0
const HEIGHT := 6.0
const OFFSET_Y := -34.0
const BG_COLOR := Color(0.1, 0.1, 0.1, 0.85)
const FILL_COLOR := Color(0.75, 0.65, 0.2)
const LOW_FILL_COLOR := Color(0.85, 0.35, 0.15)
const LOW_FRACTION_THRESHOLD := 0.35

var _fraction: float = 1.0


func set_fraction(f: float) -> void:
	_fraction = clamp(f, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var top_left := Vector2(-WIDTH / 2.0, OFFSET_Y)
	draw_rect(Rect2(top_left, Vector2(WIDTH, HEIGHT)), BG_COLOR)
	var fill_color: Color = LOW_FILL_COLOR if _fraction < LOW_FRACTION_THRESHOLD else FILL_COLOR
	draw_rect(Rect2(top_left, Vector2(WIDTH * _fraction, HEIGHT)), fill_color)
