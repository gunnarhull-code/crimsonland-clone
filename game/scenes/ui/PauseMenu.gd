extends Control
## A basic pause menu, per direct playtest request: "I want a super basic
## menu that lets you press escape to open it instead of the quit. And
## then I want you to have a quit button and resume button. And a reset
## progress button." Escape used to quit the game immediately (QuitHandler,
## now removed) - it opens this instead. process_mode ALWAYS so it keeps
## responding to Escape regardless of whatever else has paused the tree.

const RESET_CONFIRM_TEXT := "Click again to confirm"
const RESET_DEFAULT_TEXT := "Reset Progress"

@onready var _resume_button: Button = $Panel/Layout/ResumeButton
@onready var _reset_button: Button = $Panel/Layout/ResetButton
@onready var _quit_button: Button = $Panel/Layout/QuitButton

var _was_paused_before: bool = false
var _reset_confirm_armed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume_button.pressed.connect(_resume)
	_reset_button.pressed.connect(_on_reset_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		return
	if visible:
		_resume()
	elif not _other_screen_active():
		_open()


## Don't open on top of the level-up/results/shop screens - those already
## pause the game and have their own modal flow.
func _other_screen_active() -> bool:
	var arena := get_tree().current_scene
	if arena == null:
		return false
	for path in ["UI/ResultsScreen", "UI/UpgradeShop", "UI/LevelUpChoice"]:
		var screen: Control = arena.get_node_or_null(path)
		if screen and screen.visible:
			return true
	return false


func _open() -> void:
	_reset_confirm_armed = false
	_reset_button.text = RESET_DEFAULT_TEXT
	_was_paused_before = get_tree().paused
	visible = true
	get_tree().paused = true


func _resume() -> void:
	visible = false
	get_tree().paused = _was_paused_before


func _on_reset_pressed() -> void:
	if _reset_confirm_armed:
		SaveManager.reset_progress()
		_reset_confirm_armed = false
		_reset_button.text = RESET_DEFAULT_TEXT
	else:
		_reset_confirm_armed = true
		_reset_button.text = RESET_CONFIRM_TEXT


func _on_quit_pressed() -> void:
	get_tree().quit()
