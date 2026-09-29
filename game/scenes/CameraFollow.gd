extends Camera2D
## Follows the Player through the Arena (now bigger than the screen, see
## issues/02's addendum) by simply being one of its children - no manual
## follow logic needed. Clamped to the Arena's true bounds via ArenaConfig.
## Zoomed out per direct playtest request. BUGFIX: every earlier round of
## this (1.0 -> 1.15 -> 1.5 -> 2.6) actually zoomed further IN each time -
## Camera2D.zoom is a magnification factor (higher = more zoomed in, less
## of the world visible), the exact opposite of what was assumed when this
## was first written. Caught directly ("you're zooming in, getting closer
## towards the character. i want a bigger view") after three rounds of
## "zoom out" requests each made it worse. A value below 1.0 is the one
## that actually shows more of the Arena - 0.4 shows a ~3200x1800 area,
## close to the full 3840x2160 Arena.

const ZOOM := Vector2(0.4, 0.4)
const SMOOTHING_SPEED := 6.0


func _ready() -> void:
	zoom = ZOOM
	limit_left = 0
	limit_top = 0
	limit_right = int(ArenaConfig.size.x)
	limit_bottom = int(ArenaConfig.size.y)
	position_smoothing_enabled = true
	position_smoothing_speed = SMOOTHING_SPEED
	make_current()
