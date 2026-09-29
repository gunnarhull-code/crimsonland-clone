extends Node
## Tracks elapsed session time. Used only as a raw stopwatch now - the
## Toughness Multiplier and spawn pacing it used to feed (issues/15, /17)
## are wave-based per issue 23's addendum (see EnemySpawner.gd's
## get_toughness_multiplier()), since a jumpable "difficulty marker" has
## to mean something fixed, which a real-time clock can't give you if a
## run starts at wave 8 with zero elapsed minutes. Self-contained
## Autoload: tracks only its own data. Pauses automatically with the rest
## of gameplay (default process mode) during the level-up choice screen,
## per issues/14.

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
