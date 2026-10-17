extends Node2D
## Runs themed spawn sequences (formations). Each sequence has a warning phase
## (the entrance telegraphs itself), then spawns its monsters over time, then
## closes. Entrances:
##   rift    a glowing wormhole gate at an arena edge
##   burrow  dirt mounds heave, then monsters burst up out of the ground
##   pit     a hole opens in the earth and monsters pour out of it
##   edge    monsters simply walk in over the fence (a small chevron warning)
## Patterns: burst (all at once), drip (groups every interval), scatter (spread
## over several points), wall (side by side along an edge).

const Formations := preload("res://sandbox/SbFormations.gd")

const SAFE_DISTANCE := 280.0     # entrances stay this far from the player
const EDGE_INSET := 34.0
const CLOSE_TIME := 0.9
const EMERGE := {"rift": 0.3, "burrow": 0.6, "pit": 0.5, "edge": 0.0}

var sb
var _seqs: Array = []


## Start a formation. count_override > 0 replaces its default count.
func begin(fid: String, count_override: int = 0) -> bool:
	var f: Dictionary = Formations.get_formation(fid)
	if f.is_empty():
		return false
	var s := {"f": f, "count": count_override if count_override > 0 else f["count"], "state": "warn",
		"t": 0.0, "entries": [], "next": 0, "points": [], "close_t": 0.0}
	_plan(s)
	_seqs.append(s)
	match f["entrance"]:
		"rift":
			sb.audio.play("rift")
		"burrow", "pit":
			sb.audio.play("rumble")
		_:
			sb.audio.play("alert", -4.0)
	return true


func is_idle() -> bool:
	return _seqs.is_empty()


func cancel() -> void:
	_seqs.clear()


func active_count() -> int:
	return _seqs.size()


# ------------------------------------------------------------------ planning --

func _plan(s: Dictionary) -> void:
	var f: Dictionary = s["f"]
	var count: int = s["count"]
	var entries: Array = []      # {at, pos, done}
	var points: Array = []       # entrance anchor points to draw
	var spread: float = f["spread"]
	var entrance: String = f["entrance"]
	match f["pattern"]:
		"burst":
			spread = maxf(spread, sqrt(float(count)) * 14.0)
			var gate := _anchor(f, entrance)
			points = [gate]
			for i in count:
				entries.append({"at": i * 0.05, "pos": _near(gate, spread, entrance), "done": false})
		"drip":
			var gate2 := _anchor(f, entrance)
			points = [gate2]
			for i in count:
				entries.append({"at": float(i / int(f["group"])) * f["interval"], "pos": _near(gate2, maxf(spread, 14.0), entrance), "done": false})
		"wall":
			var gate3 := _anchor(f, entrance)
			points = [gate3]
			var along := _edge_tangent(gate3)
			for i in count:
				var off := (i - (count - 1) * 0.5) * 62.0
				entries.append({"at": i * 0.12, "pos": (gate3 + along * off).clamp(Vector2(20, 20), sb.ARENA - Vector2(20, 20)), "done": false})
		"around":
			var center: Vector2 = sb.player.global_position
			points = []
			for i in count:
				var ang := TAU * i / count + randf_range(-0.2, 0.2)
				var pos := (center + Vector2.from_angle(ang) * spread * randf_range(0.85, 1.15)).clamp(Vector2(30, 30), sb.ARENA - Vector2(30, 30))
				entries.append({"at": i * 0.02, "pos": pos, "done": false})
		"scatter":
			for g in int(f["gates"]):
				points.append(_anchor(f, entrance))
			for i in count:
				entries.append({"at": i * f["interval"], "pos": _near(points[i % points.size()], maxf(spread, 20.0), entrance), "done": false})
	if entrance == "burrow" and f["pattern"] != "around":
		# every monster gets its own mound, so the warning shows exactly where they will rise
		points = []
		for e in entries:
			var p := _burrow_point()
			e["pos"] = p
			points.append(p)
	s["entries"] = entries
	s["points"] = points


func _near(center: Vector2, spread: float, entrance: String) -> Vector2:
	if entrance == "burrow":
		return center
	return (center + Vector2.from_angle(randf() * TAU) * randf_range(0.0, spread)).clamp(Vector2(20, 20), sb.ARENA - Vector2(20, 20))


## Where a formation's entrance sits: a pit in the open, or a point on an arena edge.
func _anchor(f: Dictionary, entrance: String) -> Vector2:
	if entrance == "pit" or entrance == "burrow":
		for i in 14:
			var p := Vector2(randf_range(140.0, sb.ARENA.x - 140.0), randf_range(140.0, sb.ARENA.y - 140.0))
			if p.distance_to(sb.player.global_position) >= SAFE_DISTANCE + 40.0:
				return p
		return Vector2(sb.ARENA.x * 0.5, 160.0)
	return _edge_point(f["gate"])


func _edge_point(side: String) -> Vector2:
	var sides := ["left", "right", "top", "bottom"]
	if side != "random" and sides.has(side):
		return _point_on(side)
	var far: Array = []
	for sd in sides:
		var p := _point_on(sd)
		if p.distance_to(sb.player.global_position) >= SAFE_DISTANCE:
			far.append(p)
	if far.is_empty():
		return _point_on(sides[randi() % 4])
	return far[randi() % far.size()]


func _point_on(side: String) -> Vector2:
	match side:
		"left":
			return Vector2(EDGE_INSET, randf_range(140.0, sb.ARENA.y - 140.0))
		"right":
			return Vector2(sb.ARENA.x - EDGE_INSET, randf_range(140.0, sb.ARENA.y - 140.0))
		"top":
			return Vector2(randf_range(140.0, sb.ARENA.x - 140.0), EDGE_INSET)
	return Vector2(randf_range(140.0, sb.ARENA.x - 140.0), sb.ARENA.y - EDGE_INSET)


func _edge_tangent(p: Vector2) -> Vector2:
	return Vector2.DOWN if (p.x < 100.0 or p.x > sb.ARENA.x - 100.0) else Vector2.RIGHT


func _burrow_point() -> Vector2:
	for i in 16:
		var p := Vector2(randf_range(60.0, sb.ARENA.x - 60.0), randf_range(60.0, sb.ARENA.y - 60.0))
		if p.distance_to(sb.player.global_position) >= SAFE_DISTANCE:
			return p
	return Vector2(sb.ARENA.x * 0.5, 120.0)


# ----------------------------------------------------------------------- run --

func _physics_process(delta: float) -> void:
	for s in _seqs:
		s["t"] += delta
		var f: Dictionary = s["f"]
		match s["state"]:
			"warn":
				if s["t"] >= f["warning"]:
					s["state"] = "run"
					s["t"] = 0.0
					if f["entrance"] == "pit":
						_open_nest(s)
			"run":
				if f["entrance"] == "pit":
					s["state"] = "close"
					s["close_t"] = 0.05
					continue
				var entries: Array = s["entries"]
				while s["next"] < entries.size() and entries[s["next"]]["at"] <= s["t"]:
					_spawn_entry(s, entries[s["next"]])
					s["next"] += 1
				if s["next"] >= entries.size():
					s["state"] = "close"
					s["close_t"] = CLOSE_TIME
			"close":
				s["close_t"] -= delta
	_seqs = _seqs.filter(func(s): return not (s["state"] == "close" and s["close_t"] <= 0.0))
	queue_redraw()


func _spawn_entry(s: Dictionary, entry: Dictionary) -> void:
	var f: Dictionary = s["f"]
	var entrance: String = f["entrance"]
	entry["done"] = true
	var e = sb.spawn_one(f["species"], f["variant"], entry["pos"], EMERGE.get(entrance, 0.0))
	if e == null:
		return
	match entrance:
		"burrow", "pit":
			sb.particles.burst(entry["pos"], Vector2.UP, 8, 150.0, PI, 0.5, 4.0, Color(0.32, 0.24, 0.17, 0.9), "dot", 4.0)
		"rift":
			sb.particles.burst(entry["pos"], Vector2.RIGHT, 6, 160.0, PI, 0.4, 3.0, Color(0.75, 0.55, 1.0, 0.9), "line", 3.0)


# ---------------------------------------------------------------------- draw --

func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for s in _seqs:
		var f: Dictionary = s["f"]
		var prog := 1.0
		if s["state"] == "warn":
			prog = clampf(s["t"] / maxf(f["warning"], 0.01), 0.0, 1.0)
		var closing := 1.0
		if s["state"] == "close":
			closing = clampf(s["close_t"] / CLOSE_TIME, 0.0, 1.0)
		match f["entrance"]:
			"rift":
				for p in s["points"]:
					_draw_rift(p, prog * closing, now)
			"pit":
				if s["state"] == "warn":
					for p in s["points"]:
						_draw_pit(p, prog, now, true)
			"burrow":
				var entries: Array = s["entries"]
				for i in entries.size():
					if not entries[i]["done"]:
						_draw_mound(entries[i]["pos"], prog, now + i)
			_:
				for p in s["points"]:
					_draw_chevron(p, prog, now)


func _draw_rift(p: Vector2, k: float, now: float) -> void:
	var r := 18.0 + 34.0 * k
	draw_circle(p, r * 1.5, Color(0.5, 0.25, 0.9, 0.10 * k))
	draw_circle(p, r, Color(0.06, 0.02, 0.12, 0.85 * k))
	for i in 3:
		var a0 := now * (2.5 + i) + i * 2.1
		draw_arc(p, r * (1.0 - i * 0.22), a0, a0 + 3.4, 20, Color(0.7 + i * 0.1, 0.5, 1.0, 0.9 * k), 2.5)
	draw_arc(p, r * 1.18, 0.0, TAU, 32, Color(0.4, 0.9, 1.0, 0.45 * k), 1.5)


func _draw_pit(p: Vector2, k: float, now: float, warning: bool) -> void:
	var r := 46.0 * k
	draw_circle(p, r * 1.25, Color(0.2, 0.15, 0.1, 0.8 * k))
	draw_circle(p, r, Color(0.01, 0.01, 0.01, 0.95))
	draw_arc(p, r * 1.1, 0.0, TAU, 28, Color(0.35, 0.26, 0.18, 0.9), 4.0)
	if warning:
		for i in 6:
			var a := TAU * i / 6.0 + sin(now * 9.0 + i) * 0.2
			draw_line(p + Vector2.from_angle(a) * r * 1.1, p + Vector2.from_angle(a) * r * 1.6, Color(0.28, 0.2, 0.14, 0.8), 2.0)


func _draw_mound(p: Vector2, k: float, now: float) -> void:
	var shake := Vector2(sin(now * 31.0), cos(now * 27.0)) * 2.5 * k
	var r := 8.0 + 14.0 * k
	draw_circle(p + shake, r * 1.3, Color(0.1, 0.07, 0.05, 0.55))
	draw_circle(p + shake, r, Color(0.3, 0.22, 0.15, 0.95))
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		draw_line(p + shake + Vector2.from_angle(a) * r * 0.3, p + shake + Vector2.from_angle(a) * r * 1.5, Color(0.05, 0.04, 0.03, 0.9), 1.5)


func _draw_chevron(p: Vector2, k: float, now: float) -> void:
	var pulse := 0.5 + 0.5 * sin(now * 14.0)
	for i in 3:
		var o := Vector2(0, -float(i) * 10.0)
		draw_colored_polygon(PackedVector2Array([p + o + Vector2(-9, 0), p + o + Vector2(0, -9), p + o + Vector2(9, 0)]), Color(1.0, 0.45, 0.2, (0.3 + 0.5 * pulse) * k))


## A pit entrance becomes a nest: a monster you can shoot or blast. The nest
## breeds the formation's monsters out of the hole (count, interval and group
## from formations.csv) and collapses when it runs dry; destroy it first and
## the rest never come out.
func _open_nest(s: Dictionary) -> void:
	var f: Dictionary = s["f"]
	if s["points"].is_empty():
		return
	var nest = sb.spawn_one("nest", "base", s["points"][0], 0.5)
	if nest == null:
		return
	nest.nest_setup(f["species"], f["variant"], s["count"], f["interval"], f["group"])
	sb.audio.play("rumble")
