extends Node2D
## Root scene per docs/crimsonland-clone/issues/18: registers the Player and
## the Enemies container with the EnemySpawner Autoload, then starts the
## SessionClock. The Arena is now much bigger than the visible screen, with
## a camera following the Player, per issues/02's addendum reversing its
## original static-screen/no-scrolling call.

@onready var _player: CharacterBody2D = $Player
@onready var _background: Node2D = $Background


func _ready() -> void:
	_background.setup(ArenaConfig.size)
	var enemies: Node2D = $Enemies
	EnemySpawner.register_arena(enemies, _player, ArenaConfig.size)
	SaveManager.begin_run()
	SessionClock.start()
	$UI/ResultsScreen.continue_pressed.connect($UI/UpgradeShop.open)
	EnemySpawner.wave_cleared.connect(_on_wave_cleared)
	$UI/UpgradeShop.run_resumed.connect(EnemySpawner.resume_after_shop)


## Per-wave shop stop: bank the score earned so far, then open the shop in
## its mid-run mode (Continue Run instead of Start Run).
func _on_wave_cleared(_wave: int) -> void:
	if not _player.alive:
		return
	SaveManager.bank_run_score(_player.score)
	$UI/UpgradeShop.open_mid_run()
