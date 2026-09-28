extends Control
## Level-up choice screen. Per issues/14: the game PAUSES while this is
## shown (corrected from an earlier real-time draft); invulnerability is
## granted only once the player picks (see Player.choose_perk), not at the
## moment of leveling up.

var _player: Node

@onready var _title: Label = $Panel/Layout/Title
@onready var _button_container: VBoxContainer = $Panel/Layout/Buttons


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	call_deferred("_connect_to_player")


func _connect_to_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.leveled_up.connect(_on_leveled_up)


func _on_leveled_up(level: int, choices: Array) -> void:
	_title.text = "Level %d - choose a perk" % level
	for child in _button_container.get_children():
		child.queue_free()
	for perk in choices:
		var btn := Button.new()
		btn.text = "%s\n%s" % [perk["name"], perk["description"]]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.custom_minimum_size = Vector2(400, 72)
		btn.pressed.connect(_on_perk_pressed.bind(perk))
		_button_container.add_child(btn)
	visible = true
	get_tree().paused = true


func _on_perk_pressed(perk: Dictionary) -> void:
	visible = false
	get_tree().paused = false
	_player.choose_perk(perk)
