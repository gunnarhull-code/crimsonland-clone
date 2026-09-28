extends Node2D
## Root scene per docs/crimsonland-clone/issues/18: registers the Player and
## the Enemies container with the EnemySpawner Autoload, then starts the
## SessionClock. Single static 1280x720 arena, no scrolling, per issues/02.

@onready var _player: CharacterBody2D = $Player
@onready var _enemies: Node2D = $Enemies


func _ready() -> void:
	var arena_size: Vector2 = get_viewport_rect().size
	EnemySpawner.register_arena(_enemies, _player, arena_size)
	SessionClock.start()
