extends Node
## Spawns enemies in discrete, authored waves - a full redesign per issue 23,
## replacing the continuous timer-based trickle spawn from issues/17's
## original design. Per direct playtest request ("make the enemies
## difficulty and spawning go more wave like... wait until they're all dead
## before the next wave... more thematic and tailored... enemy spawners
## after the first few waves... the waves should be the same every time"):
##
## - Waves are defined in waves.csv (composition + formation + optional
##   Nest) for the first `DataTables.get_max_authored_wave()` waves, then
##   generated procedurally beyond that - but every wave, authored or
##   procedural, is spawned using a RandomNumberGenerator seeded by its own
##   wave number, so replaying (or jumping straight to) any wave produces
##   byte-for-byte the same positions/composition every time.
## - The next wave only starts once the current one (its full roster AND
##   any Nest it spawned) is entirely dead - a real "wait for clear" gate,
##   not a timer.
## - `current_wave` is the "difficulty marker" the player can jump back
##   into via SaveManager.next_run_start_wave, instead of always resetting
##   to wave 1.

signal wave_announced(text: String)
## Emitted when a wave is fully cleared; the spawner then holds (no next
## wave) until resume_after_shop() is called - the per-wave shop stop.
signal wave_cleared(wave: int)

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const NEST_SCENE := preload("res://scenes/Nest.tscn")

const CONCURRENT_CAP := 250
const NEST_CAP := 2

const INTER_WAVE_DELAY_SEC := 2.5
const SPAWN_STAGGER_SEC := 0.12
const CLUSTER_SCATTER_PX := 40.0
# 320 -> 600 per direct playtest request: a ring wave that drops in close
# enough to "barely escape" isn't a fun ambush, it's just unfair. 600px
# gives real room to react before the ring can close in.
const RING_RADIUS := 600.0
const RING_RADIUS_SMALL := 380.0
const RING_RADIUS_LARGE := 900.0
const LINE_SPACING := 55.0

## Toughness now scales with the wave marker instead of elapsed session
## time, per issue 23 - a "difficulty marker" has to mean something fixed
## and jumpable, which a real-time clock can't give you if you start at
## wave 8 with zero elapsed minutes.
const TOUGHNESS_PER_WAVE := 0.12

## Past the authored waves.csv rows, wave composition scales smoothly with
## wave number, using a per-wave-seeded RNG so it's still fully
## deterministic (see file header).
const PROCEDURAL_BASE_RAT := 10
const PROCEDURAL_BASE_SPIDER := 8
const PROCEDURAL_BASE_ALIEN := 6
const PROCEDURAL_SCALE_PER_WAVE := 0.12
const PROCEDURAL_FORMATIONS := ["cluster", "cluster_near", "cluster_far", "scatter", "ring", "ring_small", "ring_large", "double_ring", "wall", "pincer", "arc", "spiral", "cross", "corners"]

var _enemies_container: Node2D
var _player: Node2D
var _arena_size := Vector2(1280, 720)

var current_wave: int = 1
var _wave_active: bool = false
var _awaiting_shop: bool = false
var _inter_wave_delay_timer: float = 0.0
var _active_nest_count: int = 0
var _pending_spawns: Array = []


func register_arena(enemies_container: Node2D, player: Node2D, arena_size: Vector2) -> void:
	_enemies_container = enemies_container
	_player = player
	_arena_size = arena_size
	# -1 here because the _process() advance path always increments before
	# starting a wave (so the "wait, then clear, then advance" loop is a
	# single code path) - this cancels that out so the very first wave
	# spawned is actually SaveManager.next_run_start_wave, not one past it.
	current_wave = max(1, SaveManager.next_run_start_wave) - 1
	_wave_active = false
	_awaiting_shop = false
	_active_nest_count = 0
	_pending_spawns = []
	_inter_wave_delay_timer = 0.5


func _process(delta: float) -> void:
	if _enemies_container == null:
		return
	_process_pending_spawns(delta)

	if _wave_active:
		if _pending_spawns.is_empty() and _concurrent_enemy_count() == 0 and _active_nest_count == 0:
			_wave_active = false
			SaveManager.report_wave_reached(current_wave)
			_inter_wave_delay_timer = INTER_WAVE_DELAY_SEC
			_awaiting_shop = true
			wave_cleared.emit(current_wave)
		return

	if _awaiting_shop:
		return

	_inter_wave_delay_timer -= delta
	if _inter_wave_delay_timer <= 0.0:
		current_wave += 1
		_start_current_wave()


## Called by the Arena when the player leaves the per-wave shop.
func resume_after_shop() -> void:
	_awaiting_shop = false
	_inter_wave_delay_timer = 1.0


func get_current_wave() -> int:
	return current_wave


func get_toughness_multiplier() -> float:
	return 1.0 + float(current_wave - 1) * TOUGHNESS_PER_WAVE


func _concurrent_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


# ------------------------------------------------------------------ waves --

func _start_current_wave() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = current_wave
	var wave := _get_wave_data(current_wave, rng)
	wave_announced.emit("Wave %d: %s" % [current_wave, wave["name"]])
	var roster := _build_wave_roster(wave)
	var origin := _random_point_near_player(rng)
	match wave.get("formation", "cluster"):
		"ring":
			_queue_ring(roster, rng, RING_RADIUS)
		"ring_small":
			_queue_ring(roster, rng, RING_RADIUS_SMALL)
		"ring_large":
			_queue_ring(roster, rng, RING_RADIUS_LARGE)
		"double_ring":
			_queue_double_ring(roster, rng)
		"line":
			_queue_line(roster, origin, rng)
		"wall":
			_queue_wall(roster, rng)
		"pincer":
			_queue_pincer(roster, rng)
		"arc":
			_queue_arc(roster, rng)
		"spiral":
			_queue_spiral(roster, rng)
		"cross":
			_queue_cross(roster, rng)
		"corners":
			_queue_corners(roster, rng)
		"scatter":
			_queue_scatter(roster, rng)
		"cluster_near":
			_queue_cluster(roster, _point_near_player(rng, 400.0, 550.0), rng)
		"cluster_far":
			_queue_cluster(roster, _point_near_player(rng, 1000.0, 1300.0), rng)
		_:
			_queue_cluster(roster, origin, rng)
	if wave.get("spawns_nest", false) and _active_nest_count < NEST_CAP:
		_spawn_nest(rng, wave.get("nest_species", ""))
	_wave_active = true


func _get_wave_data(n: int, rng: RandomNumberGenerator) -> Dictionary:
	var authored: Dictionary = DataTables.get_wave(n)
	if not authored.is_empty():
		return authored
	return _generate_procedural_wave(n, rng)


func _generate_procedural_wave(n: int, rng: RandomNumberGenerator) -> Dictionary:
	var scale: float = 1.0 + float(n - DataTables.get_max_authored_wave()) * PROCEDURAL_SCALE_PER_WAVE
	var species_roll := ["rat", "spider", "alien"]
	return {
		"name": "Wave %d" % n,
		"rat_count": int(PROCEDURAL_BASE_RAT * scale),
		"spider_count": int(PROCEDURAL_BASE_SPIDER * scale),
		"alien_count": int(PROCEDURAL_BASE_ALIEN * scale),
		"boss_species": species_roll[rng.randi() % species_roll.size()],
		"boss_count": 1 + int(float(n - DataTables.get_max_authored_wave()) / 6.0),
		"spawns_nest": n % 4 == 0,
		"formation": PROCEDURAL_FORMATIONS[rng.randi() % PROCEDURAL_FORMATIONS.size()],
	}


func _build_wave_roster(wave: Dictionary) -> Array:
	var roster: Array = []
	for i in wave.get("rat_count", 0):
		roster.append({"species": "rat", "variant": "base"})
	for i in wave.get("spider_count", 0):
		roster.append({"species": "spider", "variant": "base"})
	for i in wave.get("alien_count", 0):
		roster.append({"species": "alien", "variant": "base"})
	var boss_species: String = wave.get("boss_species", "")
	if boss_species != "":
		for i in wave.get("boss_count", 0):
			roster.append({"species": boss_species, "variant": "boss"})
	return roster


func _queue_cluster(roster: Array, origin: Vector2, rng: RandomNumberGenerator) -> void:
	for i in roster.size():
		var offset := Vector2(rng.randf_range(-CLUSTER_SCATTER_PX, CLUSTER_SCATTER_PX), rng.randf_range(-CLUSTER_SCATTER_PX, CLUSTER_SCATTER_PX))
		_pending_spawns.append({
			"delay": i * SPAWN_STAGGER_SEC,
			"species": roster[i]["species"],
			"variant": roster[i]["variant"],
			"pos": origin + offset,
		})


## Enemies "dropping in" evenly spaced around the player - an ambush rather
## than an edge trickle.
func _queue_ring(roster: Array, rng: RandomNumberGenerator, radius: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var count := roster.size()
	if count == 0:
		return
	var start_angle := rng.randf() * TAU
	for i in count:
		var angle := start_angle + TAU * float(i) / count + rng.randf_range(-0.15, 0.15)
		var pos: Vector2 = _player.global_position + Vector2.RIGHT.rotated(angle) * radius
		pos = _clamp_to_arena(pos)
		_pending_spawns.append({"delay": i * SPAWN_STAGGER_SEC, "species": roster[i]["species"], "variant": roster[i]["variant"], "pos": pos})


## A marching line along one edge - a "vanguard" rather than a scatter.
func _queue_line(roster: Array, origin: Vector2, rng: RandomNumberGenerator) -> void:
	var along_x: bool = origin.y < 0.0 or origin.y > _arena_size.y
	var count := roster.size()
	for i in count:
		var offset := (i - (count - 1) / 2.0) * LINE_SPACING
		var pos: Vector2 = origin + (Vector2(offset, 0.0) if along_x else Vector2(0.0, offset))
		_pending_spawns.append({"delay": i * SPAWN_STAGGER_SEC, "species": roster[i]["species"], "variant": roster[i]["variant"], "pos": pos})
	# rng unused for line jitter by design - a clean marching line reads better without it.
	rng.randf()


func _clamp_to_arena(pos: Vector2) -> Vector2:
	return Vector2(clamp(pos.x, 10.0, _arena_size.x - 10.0), clamp(pos.y, 10.0, _arena_size.y - 10.0))


func _player_pos() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return _arena_size / 2.0
	return _player.global_position


func _queue_at(i: int, entry: Dictionary, pos: Vector2) -> void:
	_pending_spawns.append({"delay": i * SPAWN_STAGGER_SEC, "species": entry["species"], "variant": entry["variant"], "pos": _clamp_to_arena(pos)})


## Two concentric rings (alternating inner/outer) - pressure from two depths.
func _queue_double_ring(roster: Array, rng: RandomNumberGenerator) -> void:
	var start_angle := rng.randf() * TAU
	var center := _player_pos()
	for i in roster.size():
		var ring_radius := RING_RADIUS_SMALL + 60.0 if i % 2 == 0 else RING_RADIUS_LARGE - 50.0
		var angle := start_angle + TAU * float(i) / roster.size() + rng.randf_range(-0.1, 0.1)
		_queue_at(i, roster[i], center + Vector2.RIGHT.rotated(angle) * ring_radius)


## A two-deep wall 800px away, facing the player - a proper advancing front
## (unlike "line", which hugs an arena edge).
func _queue_wall(roster: Array, rng: RandomNumberGenerator) -> void:
	var center := _player_pos()
	var angle := rng.randf() * TAU
	var forward := Vector2.RIGHT.rotated(angle)
	var side := forward.orthogonal()
	var per_row := int(ceil(roster.size() / 2.0))
	for i in roster.size():
		var row := i / per_row
		var col := i % per_row
		var lateral := (col - (per_row - 1) / 2.0) * LINE_SPACING
		_queue_at(i, roster[i], center + forward * (800.0 + row * 60.0) + side * lateral)


## A half-ring on one side of the player - they can only run the other way.
func _queue_arc(roster: Array, rng: RandomNumberGenerator) -> void:
	var center := _player_pos()
	var mid := rng.randf() * TAU
	var count := roster.size()
	for i in count:
		var t: float = float(i) / float(max(1, count - 1)) - 0.5
		_queue_at(i, roster[i], center + Vector2.RIGHT.rotated(mid + t * PI) * 700.0)


## A spiral fanning outward from 450px to 950px away.
func _queue_spiral(roster: Array, rng: RandomNumberGenerator) -> void:
	var center := _player_pos()
	var start_angle := rng.randf() * TAU
	var count := roster.size()
	for i in count:
		var radius: float = 450.0 + 500.0 * float(i) / float(max(1, count - 1))
		_queue_at(i, roster[i], center + Vector2.RIGHT.rotated(start_angle + i * 0.55) * radius)


## Four columns marching in from north/east/south/west.
func _queue_cross(roster: Array, rng: RandomNumberGenerator) -> void:
	var center := _player_pos()
	var start_angle := rng.randf() * TAU
	for i in roster.size():
		var arm := i % 4
		var depth := i / 4
		_queue_at(i, roster[i], center + Vector2.RIGHT.rotated(start_angle + arm * PI / 2.0) * (550.0 + depth * 55.0))


## Four small clusters at the diagonals, 750px out.
func _queue_corners(roster: Array, rng: RandomNumberGenerator) -> void:
	var center := _player_pos()
	var start_angle := rng.randf() * TAU + PI / 4.0
	var origins: Array = []
	for k in 4:
		origins.append(_clamp_to_arena(center + Vector2.RIGHT.rotated(start_angle + k * PI / 2.0) * 750.0))
	for i in roster.size():
		var off := Vector2(rng.randf_range(-CLUSTER_SCATTER_PX, CLUSTER_SCATTER_PX), rng.randf_range(-CLUSTER_SCATTER_PX, CLUSTER_SCATTER_PX))
		_queue_at(i, roster[i], origins[i % 4] + off)


## Everyone at an independent random spot 450-1000px out.
func _queue_scatter(roster: Array, rng: RandomNumberGenerator) -> void:
	for i in roster.size():
		_queue_at(i, roster[i], _point_near_player(rng, 450.0, 1000.0))


func _point_near_player(rng: RandomNumberGenerator, min_r: float, max_r: float) -> Vector2:
	var angle := rng.randf() * TAU
	return _clamp_to_arena(_player_pos() + Vector2.RIGHT.rotated(angle) * rng.randf_range(min_r, max_r))


## Seeded species roll for Nests the CSV doesn't pin (alien only from wave 5).
func _pick_nest_species(rng: RandomNumberGenerator) -> String:
	var options := ["rat", "spider"]
	if current_wave >= 5:
		options.append("alien")
	return options[rng.randi() % options.size()]


func _queue_pincer(roster: Array, rng: RandomNumberGenerator) -> void:
	var edges := _pincer_edge_positions(rng)
	var half := roster.size() / 2
	_queue_cluster(roster.slice(0, half), edges[0], rng)
	_queue_cluster(roster.slice(half), edges[1], rng)


func _pincer_edge_positions(rng: RandomNumberGenerator) -> Array:
	if _player == null or not is_instance_valid(_player):
		return [_random_point_near_player(rng), _random_point_near_player(rng)]
	var radius := rng.randf_range(780.0, 950.0)
	var base_angle := rng.randf() * TAU
	var p1: Vector2 = _player.global_position + Vector2.RIGHT.rotated(base_angle) * radius
	var p2: Vector2 = _player.global_position + Vector2.RIGHT.rotated(base_angle + PI) * radius
	p1.x = clamp(p1.x, 0.0, _arena_size.x)
	p1.y = clamp(p1.y, 0.0, _arena_size.y)
	p2.x = clamp(p2.x, 0.0, _arena_size.x)
	p2.y = clamp(p2.y, 0.0, _arena_size.y)
	return [p1, p2]


## A point 780-950px from the player - just outside the camera's visible
## area at its 1.15x zoom (see issue 17's addendum for the derivation).
func _random_point_near_player(rng: RandomNumberGenerator) -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return _arena_size / 2.0
	var angle := rng.randf() * TAU
	var radius := rng.randf_range(780.0, 950.0)
	var pos: Vector2 = _player.global_position + Vector2.RIGHT.rotated(angle) * radius
	pos.x = clamp(pos.x, 0.0, _arena_size.x)
	pos.y = clamp(pos.y, 0.0, _arena_size.y)
	return pos


func _process_pending_spawns(delta: float) -> void:
	if _pending_spawns.is_empty():
		return
	var remaining: Array = []
	for entry in _pending_spawns:
		entry["delay"] -= delta
		if entry["delay"] <= 0.0:
			spawn_enemy_at(entry["species"], entry["variant"], entry["pos"])
		else:
			remaining.append(entry)
	_pending_spawns = remaining


## Public: also used by Nest.gd to spawn its own enemies through the same cap check.
func spawn_enemy_at(species: String, variant: String, pos: Vector2) -> Node:
	if _concurrent_enemy_count() >= CONCURRENT_CAP:
		return null
	var enemy := ENEMY_SCENE.instantiate()
	_enemies_container.add_child(enemy)
	enemy.setup(species, variant, pos)
	return enemy


func _spawn_nest(rng: RandomNumberGenerator, species_override: String = "") -> void:
	var nest := NEST_SCENE.instantiate()
	_enemies_container.add_child(nest)
	_active_nest_count += 1
	nest.tree_exited.connect(_on_nest_removed)
	nest.setup(_random_interior_position(rng), species_override if species_override != "" else _pick_nest_species(rng))


func _on_nest_removed() -> void:
	_active_nest_count = max(0, _active_nest_count - 1)


func _random_interior_position(rng: RandomNumberGenerator) -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return _arena_size / 2.0
	var angle := rng.randf() * TAU
	var radius := rng.randf_range(300.0, 900.0)
	var pos: Vector2 = _player.global_position + Vector2.RIGHT.rotated(angle) * radius
	pos.x = clamp(pos.x, 120.0, _arena_size.x - 120.0)
	pos.y = clamp(pos.y, 120.0, _arena_size.y - 120.0)
	return pos


func reset() -> void:
	_enemies_container = null
	_player = null
	current_wave = 1
	_wave_active = false
	_inter_wave_delay_timer = 0.0
	_active_nest_count = 0
	_pending_spawns = []
