extends Camera2D
## Follows the Player through the Arena (now bigger than the screen, see
## issues/02's addendum) by simply being one of its children - no manual
## follow logic needed. Clamped to the Arena's true bounds via ArenaConfig.
## Zoomed out per direct playtest request: first a little (1.15x), then
## further ("I'd like to zoom out the screen so I can see more of it... I
## like the size of the map, I just want to zoom out the screen").

const ZOOM := Vector2(1.5, 1.5)
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
