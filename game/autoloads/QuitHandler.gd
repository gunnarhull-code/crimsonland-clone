extends Node
## Escape quits the game, per direct playtest request. A dedicated
## always-on Autoload (per issues/16's "Autoloads only for genuinely global
## systems") rather than a check inside Player/Arena, so it keeps working
## regardless of pause state - the level-up choice screen and the results
## screen both pause the tree, and Escape should still work there too.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()
