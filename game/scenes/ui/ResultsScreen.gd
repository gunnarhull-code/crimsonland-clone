extends Control
## Shown on death per issues/14 - the only end condition in this endless
## survival MVP. Displays score/level/survival time per issues/02 and
## issues/20. Per direct playtest request, any key or click restarts the
## run by reloading the Arena scene - Autoloads persist across the reload,
## but Arena.gd's _ready() re-registers EnemySpawner (which fully resets
## its own timers/state) and calls SessionClock.start() (which resets
## elapsed_sec to 0), so nothing needs an explicit reset call here.

var _player: Node

@onready var _score_label: Label = $Panel/Layout/ScoreLabel
@onready var _level_label: Label = $Panel/Layout/LevelLabel
@onready var _time_label: Label = $Panel/Layout/TimeLabel
@onready var _restart_label: Label = $Panel/Layout/RestartLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	call_deferred("_connect_to_player")


func _connect_to_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.died.connect(_on_died)


func _on_died() -> void:
	_score_label.text = "Score: %d" % _player.score
	_level_label.text = "Level reached: %d" % _player.level
	_time_label.text = "Survived: %ds" % int(_player.survival_time)
	_restart_label.text = "Press any key to restart"
	visible = true
	get_tree().paused = true
	SessionClock.stop()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed):
		_restart()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
