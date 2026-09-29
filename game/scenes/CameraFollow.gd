extends Camera2D
## Follows the Player through the Arena (now bigger than the screen, see
## issues/02's addendum) by simply being one of its children - no manual
## follow logic needed. Clamped to the Arena's true bounds via ArenaConfig.
## Zoomed out per direct playtest request, three rounds now: 1.15x, then
## 1.5x ("I'd like to zoom out the screen so I can see more of it"), then
## this - 1.5x still wasn't enough ("STILL ZOOM WAY OUT"), so this jump is
## deliberately large rather than another small nudge.

const ZOOM := Vector2(2.6, 2.6)
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
