extends Node
## Loads perks.csv / weapons.csv / enemies.csv once at startup into in-memory
## tables. Self-contained Autoload per docs/crimsonland-clone/issues/18 and
## the "Autoloads versus regular nodes" guidance it cites: this node only
## tracks its own data and exposes it, it never reaches into other systems.

var perks: Dictionary = {}
var weapons: Dictionary = {}
var enemies: Dictionary = {}


func _ready() -> void:
	perks = _load_perks("res://data/perks.csv")
	weapons = _load_weapons("res://data/weapons.csv")
	enemies = _load_enemies("res://data/enemies.csv")


func get_perk(id: String) -> Dictionary:
	return perks.get(id, {})


func get_all_perks() -> Array:
	return perks.values()


func get_weapon(id: String) -> Dictionary:
	return weapons.get(id, {})


func get_all_weapons() -> Array:
	return weapons.values()


func get_enemy_stats(species: String, variant: String) -> Dictionary:
	return enemies.get("%s_%s" % [species, variant], {})


## Reads a CSV file into a list of {column_name: raw_string_value} dicts.
func _read_csv_rows(path: String) -> Array:
	var rows: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataTables: could not open %s" % path)
		return rows
	var header := file.get_csv_line()
	while file.get_position() < file.get_length():
		var line := file.get_csv_line()
		if line.size() == 0 or line[0] == "":
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i] if i < line.size() else ""
		rows.append(row)
	file.close()
	return rows


func _num(row: Dictionary, key: String, default: float = 0.0) -> float:
	var raw: String = row.get(key, "")
	return float(raw) if raw != "" else default


func _load_perks(path: String) -> Dictionary:
	var table := {}
	for row in _read_csv_rows(path):
		var entry := {
			"id": row.get("id", ""),
			"name": row.get("name", ""),
			"description": row.get("description", ""),
			"category": row.get("category", ""),
			"effect_type": row.get("effect_type", ""),
			"target": row.get("target", ""),
			"value": _num(row, "value"),
			"effect_type_2": row.get("effect_type_2", ""),
			"target_2": row.get("target_2", ""),
			"value_2": _num(row, "value_2"),
			"has_secondary_effect": row.get("target_2", "") != "",
			"trigger": row.get("trigger", "passive"),
			"special_handler_id": row.get("special_handler_id", ""),
			"prerequisite_id": row.get("prerequisite_id", ""),
		}
		table[entry["id"]] = entry
	return table


func _load_weapons(path: String) -> Dictionary:
	var table := {}
	for row in _read_csv_rows(path):
		var entry := {
			"id": row.get("id", ""),
			"name": row.get("name", ""),
			"fire_rate_per_sec": _num(row, "fire_rate_per_sec"),
			"magazine_size": int(_num(row, "magazine_size")),
			"reload_time_sec": _num(row, "reload_time_sec"),
			"projectile_speed_px_s": _num(row, "projectile_speed_px_s"),
			"spread_deg": _num(row, "spread_deg"),
			"damage": _num(row, "damage"),
			"special": row.get("special", ""),
		}
		table[entry["id"]] = entry
	return table


func _load_enemies(path: String) -> Dictionary:
	var table := {}
	for row in _read_csv_rows(path):
		var entry := {
			"species": row.get("species", ""),
			"variant": row.get("variant", ""),
			"name": row.get("name", ""),
			"hp": _num(row, "hp"),
			"damage": _num(row, "damage"),
			"attack_cooldown_sec": _num(row, "attack_cooldown_sec"),
			"xp": _num(row, "xp"),
			"chase_speed_px_s": _num(row, "chase_speed_px_s"),
			"wander_speed_px_s": _num(row, "wander_speed_px_s"),
			"aggro_radius_px": _num(row, "aggro_radius_px"),
			"hitbox_radius_px": _num(row, "hitbox_radius_px"),
		}
		table["%s_%s" % [entry["species"], entry["variant"]]] = entry
	return table
