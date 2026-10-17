extends RefCounted
## Monster stats and behaviour parameters, from sandbox/monsters.csv.
## `move` picks the movement brain in SbEnemy.gd; `params` are its numbers
## ("key=value;key=value"), e.g. a spider's windup time or an alien's stomp radius.

const PATH := "res://sandbox/monsters.csv"

static var _rows := {}


static func get_stats(species: String, variant: String) -> Dictionary:
	if _rows.is_empty():
		_load()
	return _rows.get("%s_%s" % [species, variant], {})


static func _load() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("SbMonsters: could not open %s" % PATH)
		return
	var header := f.get_csv_line()
	while f.get_position() < f.get_length():
		var line := f.get_csv_line()
		if line.size() < 2 or line[0] == "":
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i] if i < line.size() else ""
		var entry := {
			"species": row["species"], "variant": row["variant"], "name": row["name"],
			"hp": float(row["hp"]), "damage": float(row["damage"]),
			"attack_cooldown_sec": float(row["attack_cooldown_sec"]),
			"chase_speed_px_s": float(row["chase_speed_px_s"]),
			"hitbox_radius_px": float(row["hitbox_radius_px"]),
			"move": row["move"], "p": _parse(row.get("params", "")),
		}
		_rows["%s_%s" % [row["species"], row["variant"]]] = entry
	f.close()


static func _parse(s: String) -> Dictionary:
	var d := {}
	for part in s.split(";", false):
		var kv := part.split("=")
		if kv.size() == 2:
			d[kv[0].strip_edges()] = float(kv[1])
	return d


## Every monster row, for things that need the whole roster (the sprite baker).
static func all() -> Array:
	if _rows.is_empty():
		_load()
	return _rows.values()
