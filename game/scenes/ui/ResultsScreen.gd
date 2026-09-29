extends Control
## Shown on death per issues/14 - the only end condition in this endless
## survival MVP. Displays score/level/survival time per issues/02 and
## issues/20, banks the run's score into SaveManager, and waits for a
## click on the Continue button - per direct playtest request ("let's
## make it click a button to continue"), replacing the previous "any key
## or click" restart, which was too easy to trigger by accident.

signal continue_pressed

var _player: Node

@onready var _score_label: Label = $Panel/Layout/ScoreLabel
@onready var _level_label: Label = $Panel/Layout/LevelLabel
@onready var _time_label: Label = $Panel/Layout/TimeLabel
@onready var _continue_button: Button = $Panel/Layout/ContinueButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	call_deferred("_connect_to_player")


func _connect_to_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.died.connect(_on_died)


func _on_died() -> void:
	_score_label.text = "Score: %d" % _player.score
	_level_label.text = "Level reached: %d" % _player.level
	_time_label.text = "Survived: %ds" % int(_player.survival_time)
	SaveManager.bank_run_score(_player.score)
	visible = true
	get_tree().paused = true
	SessionClock.stop()


func _on_continue_pressed() -> void:
	visible = false
	continue_pressed.emit()
