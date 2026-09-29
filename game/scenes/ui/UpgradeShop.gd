extends Control
## Post-death Upgrade Shop, per issue 22 (permanent weapon upgrades/perks)
## and issue 23 (difficulty markers). Reached via ResultsScreen's Continue
## button. Spends SaveManager.banked_score on one-time weapon-mechanic
## upgrades and permanent perks, and picks which wave to start the next
## run from - any wave up to the highest ever reached, "instead of having
## to reset to 1" every time, per direct playtest request.

const WEAPON_UPGRADES := [
	{"weapon_id": "pistol", "name": "Akimbo", "desc": "Fires two bullets per pull instead of one.", "cost": 150},
	{"weapon_id": "gauss_gun", "name": "Railgun Overcharge", "desc": "Pierces every enemy in its line - no cap.", "cost": 300},
	{"weapon_id": "electric_gun", "name": "Chain Reaction", "desc": "Keeps cascading to new targets, losing some damage each jump.", "cost": 300},
	{"weapon_id": "shotgun", "name": "Buckshot Knockback", "desc": "Pellets physically shove enemies back.", "cost": 250},
	{"weapon_id": "smg", "name": "Spin-Up Barrel", "desc": "Fire rate ramps up the longer you hold the trigger.", "cost": 250},
	{"weapon_id": "heavy_cannon", "name": "Cluster Warhead", "desc": "Explosion flings out smaller secondary blasts.", "cost": 350},
]

const PERK_UNLOCKS := ["iron_skin", "sprinter", "second_wind", "late_bloomer"]
const PERK_COST := 200

var _selected_wave: int = 1

@onready var _score_label: Label = $Panel/Layout/ScoreLabel
@onready var _upgrades_box: VBoxContainer = $Panel/Layout/Scroll/ContentBox/UpgradesBox
@onready var _perks_box: VBoxContainer = $Panel/Layout/Scroll/ContentBox/PerksBox
@onready var _wave_label: Label = $Panel/Layout/WaveRow/WaveLabel
@onready var _start_button: Button = $Panel/Layout/StartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	$Panel/Layout/WaveRow/PrevButton.pressed.connect(_on_wave_prev)
	$Panel/Layout/WaveRow/NextButton.pressed.connect(_on_wave_next)
	_start_button.pressed.connect(_on_start_pressed)


func open() -> void:
	_selected_wave = max(1, SaveManager.highest_wave_reached)
	_refresh()
	visible = true
	get_tree().paused = true


func _refresh() -> void:
	_score_label.text = "Banked Score: %d" % SaveManager.banked_score

	for child in _upgrades_box.get_children():
		child.queue_free()
	for u in WEAPON_UPGRADES:
		_upgrades_box.add_child(_build_purchase_button(
			SaveManager.has_upgrade(u["weapon_id"]), u["name"], u["desc"], u["cost"],
			_on_buy_upgrade.bind(u)
		))

	for child in _perks_box.get_children():
		child.queue_free()
	for perk_id in PERK_UNLOCKS:
		var perk: Dictionary = DataTables.get_perk(perk_id)
		_perks_box.add_child(_build_purchase_button(
			SaveManager.has_perk(perk_id), perk["name"], perk["description"], PERK_COST,
			_on_buy_perk.bind(perk_id)
		))

	_selected_wave = clamp(_selected_wave, 1, max(1, SaveManager.highest_wave_reached))
	_wave_label.text = "Start at wave %d / %d" % [_selected_wave, SaveManager.highest_wave_reached]


func _build_purchase_button(owned: bool, item_name: String, desc: String, cost: int, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(720, 44)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD
	btn.add_theme_font_size_override("font_size", 13)
	if owned:
		btn.text = "%s (owned) - %s" % [item_name, desc]
		btn.disabled = true
	else:
		btn.text = "%s - %d - %s" % [item_name, cost, desc]
		btn.disabled = SaveManager.banked_score < cost
		btn.pressed.connect(on_press)
	return btn


func _on_buy_upgrade(u: Dictionary) -> void:
	if SaveManager.purchase_upgrade(u["weapon_id"], u["cost"]):
		_refresh()


func _on_buy_perk(perk_id: String) -> void:
	if SaveManager.purchase_perk(perk_id, PERK_COST):
		_refresh()


func _on_wave_prev() -> void:
	_selected_wave = max(1, _selected_wave - 1)
	_refresh()


func _on_wave_next() -> void:
	_selected_wave = min(max(1, SaveManager.highest_wave_reached), _selected_wave + 1)
	_refresh()


func _on_start_pressed() -> void:
	SaveManager.next_run_start_wave = _selected_wave
	visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()
