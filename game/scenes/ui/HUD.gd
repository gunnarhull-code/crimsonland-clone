extends Control
## Live HUD per issues/20 - score shown during play, not just on death.

const WAVE_DISPLAY_SEC := 2.5

@onready var _hp_label: Label = $HPLabel
@onready var _score_label: Label = $ScoreLabel
@onready var _level_label: Label = $LevelLabel
@onready var _weapon_label: Label = $WeaponLabel
@onready var _ammo_label: Label = $AmmoLabel
@onready var _wave_label: Label = $WaveLabel

var _player: Node
var _wave_display_id: int = 0


func _ready() -> void:
	call_deferred("_connect_to_player")
	EnemySpawner.wave_announced.connect(_on_wave_announced)


func _connect_to_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	_player.hp_changed.connect(_on_hp_changed)
	_player.score_changed.connect(_on_score_changed)
	_player.xp_changed.connect(_on_xp_changed)
	_player.weapon_changed.connect(_on_weapon_changed)
	_on_hp_changed(_player.hp, _player.get_max_hp())
	_on_score_changed(_player.score)
	_on_xp_changed(_player.xp, 100.0, _player.level)
	_on_weapon_changed(_player.weapon_id)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.is_reloading:
		_ammo_label.text = "Reloading..."
	else:
		_ammo_label.text = "Ammo %d" % _player.ammo_in_magazine


func _on_hp_changed(current: float, max_hp: float) -> void:
	_hp_label.text = "HP %d/%d" % [int(current), int(max_hp)]


func _on_score_changed(score: int) -> void:
	_score_label.text = "Score %d" % score


func _on_xp_changed(xp: float, xp_required: float, level: int) -> void:
	_level_label.text = "Lv %d  (%d/%d XP)" % [level, int(xp), int(xp_required)]


func _on_weapon_changed(weapon_id: String) -> void:
	_weapon_label.text = "Weapon: %s" % weapon_id


## A named wave (e.g. "Rat Swarm") shown briefly per EnemySpawner's themed
## wave events, so a group spawn reads as a deliberate beat, not silent RNG.
func _on_wave_announced(text: String) -> void:
	_wave_label.text = text
	_wave_display_id += 1
	var id := _wave_display_id
	await get_tree().create_timer(WAVE_DISPLAY_SEC).timeout
	if id == _wave_display_id:
		_wave_label.text = ""
