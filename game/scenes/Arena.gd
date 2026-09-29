extends Node2D
## Root scene per docs/crimsonland-clone/issues/18: registers the Player and
## the Enemies container with the EnemySpawner Autoload, then starts the
## SessionClock. The Arena is now much bigger than the visible screen, with
## a camera following the Player, per issues/02's addendum reversing its
## original static-screen/no-scrolling call.

@onready var _player: CharacterBody2D = $Player
@onready var _background: ColorRect = $Background


func _ready() -> void:
	_background.size = ArenaConfig.size
	var enemies: Node2D = $Enemies
	EnemySpawner.register_arena(enemies, _player, ArenaConfig.size)
	SessionClock.start()
