extends RefCounted
## Spawn formations and per-level timelines (formations.csv, timeline.csv).
## A formation is a species-themed sequence: what spawns, in what pattern
## (burst / drip / scatter / wall), from which kind of entrance (rift / burrow /
## pit / edge) and with how much warning. A level's timeline places formations
## at times; sequences overlap.

const FORMATIONS_PATH := "res://sandbox/formations.csv"
const TIMELINE_PATH := "res://sandbox/timeline.csv"

static var _formations := {}
static var _timeline := {}


static func get_formation(id: String) -> Dictionary:
	_ensure()
	return _formations.get(id, {})


static func all_ids() -> Array:
	_ensure()
	return _formations.keys()


## Events for a level: [{t, formation, count}], sorted by time. Empty if none authored.
static func timeline(level: int) -> Array:
	_ensure()
	return _timeline.get(level, [])


static func _ensure() -> void:
	if not _formations.is_empty():
		return
	for row in _rows(FORMATIONS_PATH):
		_formations[row["id"]] = {
			"id": row["id"], "name": row["name"], "species": row["species"], "variant": row["variant"],
			"count": int(row["count"]), "pattern": row["pattern"], "interval": float(row["interval_sec"]),
			"group": maxi(1, int(row["group"])), "gate": row["gate"], "entrance": row["entrance"],
			"warning": float(row["warning_sec"]), "spread": float(row["spread"]), "gates": maxi(1, int(row["gates"])),
		}
	for row in _rows(TIMELINE_PATH):
		var lvl := int(row["level"])
		if not _timeline.has(lvl):
			_timeline[lvl] = []
		_timeline[lvl].append({"t": float(row["t"]), "formation": row["formation"],
			"count": int(row["count"]) if row["count"] != "" else 0})
	for lvl in _timeline:
		_timeline[lvl].sort_custom(func(a, b): return a["t"] < b["t"])


static func _rows(path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("SbFormations: could not open %s" % path)
		return out
	var header := f.get_csv_line()
	while f.get_position() < f.get_length():
		var line := f.get_csv_line()
		if line.size() < 2 or line[0] == "":
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i] if i < line.size() else ""
		out.append(row)
	f.close()
	return out
