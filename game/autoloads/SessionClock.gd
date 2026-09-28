extends Node
## Tracks elapsed session time. Feeds the Toughness Multiplier
## (docs/crimsonland-clone/issues/15) and the spawn pacing curve
## (issues/17). Self-contained Autoload: tracks only its own data.
## Pauses automatically with the rest of gameplay (default process mode)
## during the level-up choice screen, per issues/14.

var elapsed_sec: float = 0.0
var running: bool = false


func _process(delta: float) -> void:
	if running:
		elapsed_sec += delta


func start() -> void:
	elapsed_sec = 0.0
	running = true


func stop() -> void:
	running = false


func get_elapsed_minutes() -> float:
	return elapsed_sec / 60.0


## docs/crimsonland-clone/issues/15: 1 + elapsed_minutes * 0.15
func get_toughness_multiplier() -> float:
	return 1.0 + get_elapsed_minutes() * 0.15
