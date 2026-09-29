extends Camera2D
## Follows the Player through the Arena (now bigger than the screen, see
## issues/02's addendum) by simply being one of its children - no manual
## follow logic needed. Clamped to the Arena's true bounds via ArenaConfig.
## Zoomed out per direct playtest request. BUGFIX: every earlier round of
## this (1.0 -> 1.15 -> 1.5 -> 2.6) actually zoomed further IN each time -
## Camera2D.zoom is a magnification factor (higher = more zoomed in, less
## of the world visible), the exact opposite of what was assumed when this
## was first written. Caught directly ("you're zooming in, getting closer
## towards the character. i want a bigger view"). 0.4 (near-full-map view)
## was "a little too far" the other way; settled at 0.55 ("I like the
## distance"), then nudged in "just a tad" to 0.62 (~2064x1161 area).

const ZOOM := Vector2(0.62, 0.62)
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
