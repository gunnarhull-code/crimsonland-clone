extends Control
## Shown on death per issues/14 - the only end condition in this endless
## survival MVP. Displays score/level/survival time per issues/02 and
## issues/20; no retry-run stats or leaderboard for the MVP.

var _player: Node

@onready var _score_label: Label = $Panel/Layout/ScoreLabel
@onready var _level_label: Label = $Panel/Layout/LevelLabel
@onready var _time_label: Label = $Panel/Layout/TimeLabel


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
	visible = true
	get_tree().paused = true
	SessionClock.stop()
