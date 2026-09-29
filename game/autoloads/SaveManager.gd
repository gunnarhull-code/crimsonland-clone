extends Node
## Persists progress across game restarts and relaunches, per issue 22
## (permanent weapon upgrades/perks) and issue 23 (difficulty markers). A
## single JSON file at user://save.json, loaded once at startup, written
## after every change. This is the first persistence anything in this
## codebase has ever needed - every other Autoload is pure in-memory
## session state (per issue 16's architecture).

const SAVE_PATH := "user://save.json"

var banked_score: int = 0
var unlocked_upgrades: Dictionary = {}
var unlocked_perks: Dictionary = {}
var highest_wave_reached: int = 1

## Set by UpgradeShop right before starting a new run, read once by
## Arena._ready()/EnemySpawner.register_arena(). Not persisted - a
## same-session handoff between scenes, not save data.
var next_run_start_wave: int = 1


func _ready() -> void:
	_load()


func has_upgrade(weapon_id: String) -> bool:
	return unlocked_upgrades.get(weapon_id, false)


func has_perk(perk_id: String) -> bool:
	return unlocked_perks.get(perk_id, false)


func add_banked_score(amount: int) -> void:
	banked_score += amount
	_save()


func purchase_upgrade(weapon_id: String, cost: int) -> bool:
	if unlocked_upgrades.get(weapon_id, false) or banked_score < cost:
		return false
	banked_score -= cost
	unlocked_upgrades[weapon_id] = true
	_save()
	return true


func purchase_perk(perk_id: String, cost: int) -> bool:
	if unlocked_perks.get(perk_id, false) or banked_score < cost:
		return false
	banked_score -= cost
	unlocked_perks[perk_id] = true
	_save()
	return true


func report_wave_reached(wave: int) -> void:
	if wave > highest_wave_reached:
		highest_wave_reached = wave
		_save()


func _save() -> void:
	var data := {
		"banked_score": banked_score,
		"unlocked_upgrades": unlocked_upgrades.keys(),
		"unlocked_perks": unlocked_perks.keys(),
		"highest_wave_reached": highest_wave_reached,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	banked_score = int(parsed.get("banked_score", 0))
	unlocked_upgrades = {}
	for id in parsed.get("unlocked_upgrades", []):
		unlocked_upgrades[id] = true
	unlocked_perks = {}
	for id in parsed.get("unlocked_perks", []):
		unlocked_perks[id] = true
	highest_wave_reached = int(parsed.get("highest_wave_reached", 1))
