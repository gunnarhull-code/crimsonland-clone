extends RefCounted
## Loads sandbox/upgrades.csv. Numbers live in the CSV `params` column
## ("key=value;key=value"); the behaviour for each id is in SbPlayer.gd and
## Sandbox.gd. Use as: const Up := preload("res://sandbox/SbUpgrades.gd")

const PATH := "res://sandbox/upgrades.csv"

static var _rows: Array = []
static var _by_id: Dictionary = {}


static func all() -> Array:
	if _rows.is_empty():
		_load()
	return _rows


static func get_row(id: String) -> Dictionary:
	all()
	return _by_id.get(id, {})


## One numeric parameter of an upgrade, 0.0 if missing.
static func p(id: String, key: String) -> float:
	all()
	return _by_id.get(id, {}).get("p", {}).get(key, 0.0)


static func _load() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("SbUpgrades: could not open %s" % PATH)
		return
	var header := f.get_csv_line()
	while f.get_position() < f.get_length():
		var line := f.get_csv_line()
		if line.size() < 2 or line[0] == "":
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i] if i < line.size() else ""
		row["p"] = _parse_params(row.get("params", ""))
		_rows.append(row)
		_by_id[row["id"]] = row
	f.close()


static func _parse_params(s: String) -> Dictionary:
	var d := {}
	for part in s.split(";", false):
		var kv := part.split("=")
		if kv.size() == 2:
			d[kv[0].strip_edges()] = float(kv[1])
	return d
