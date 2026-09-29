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

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const NEST_SCENE := preload("res://scenes/Nest.tscn")

const CONCURRENT_CAP := 250
const NEST_CAP := 2

const INTER_WAVE_DELAY_SEC := 2.5
const SPAWN_STAGGER_SEC := 0.12
const CLUSTER_SCATTER_PX := 40.0
const RING_RADIUS := 320.0
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
const PROCEDURAL_FORMATIONS := ["cluster", "ring", "line", "pincer"]

var _enemies_container: Node2D
var _player: Node2D
var _arena_size := Vector2(1280, 720)

var current_wave: int = 1
var _wave_active: bool = false
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
		return

	_inter_wave_delay_timer -= delta
	if _inter_wave_delay_timer <= 0.0:
		current_wave += 1
		_start_current_wave()


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
	wave_announced.emit(wave["name"])
	var roster := _build_wave_roster(wave)
	var origin := _random_point_near_player(rng)
	match wave.get("formation", "cluster"):
		"ring":
			_queue_ring(roster, rng)
		"line":
			_queue_line(roster, origin, rng)
		"pincer":
			_queue_pincer(roster, rng)
		_:
			_queue_cluster(roster, origin, rng)
	if wave.get("spawns_nest", false) and _active_nest_count < NEST_CAP:
		_spawn_nest(rng)
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
func _queue_ring(roster: Array, rng: RandomNumberGenerator) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var count := roster.size()
	if count == 0:
		return
	var start_angle := rng.randf() * TAU
	for i in count:
		var angle := start_angle + TAU * float(i) / count + rng.randf_range(-0.15, 0.15)
		var pos: Vector2 = _player.global_position + Vector2.RIGHT.rotated(angle) * RING_RADIUS
		pos.x = clamp(pos.x, 10.0, _arena_size.x - 10.0)
		pos.y = clamp(pos.y, 10.0, _arena_size.y - 10.0)
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


func _spawn_nest(rng: RandomNumberGenerator) -> void:
	var nest := NEST_SCENE.instantiate()
	_enemies_container.add_child(nest)
	_active_nest_count += 1
	nest.tree_exited.connect(_on_nest_removed)
	nest.setup(_random_interior_position(rng))


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
