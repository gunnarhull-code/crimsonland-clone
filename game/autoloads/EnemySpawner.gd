extends Node
## Spawns enemies over time per docs/crimsonland-clone/issues/17 (spawn
## pacing) and issues/21 (Nests). Self-contained Autoload: owns its own
## timers and spawn logic, only instances new Enemy/Nest nodes into the
## Arena's Enemies container it was given - it does not reach into or
## mutate Player/Enemy internal state.
##
## Two additions per direct playtest request ("sometimes they need to spawn
## in groups... give some personal touches to the way they spawn and the
## waves, not just a bunch of random enemies"):
## - Pack spawns: the normal trickle spawn occasionally spawns a same-species
##   cluster instead of a lone enemy.
## - Themed waves: periodically, a named, staggered burst of enemies in a
##   formation (cluster/ring/line/pincer) rather than uniform randomness -
##   announced to the HUD via `wave_announced`.

signal wave_announced(text: String)

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const NEST_SCENE := preload("res://scenes/Nest.tscn")

const CONCURRENT_CAP := 250
const ALIEN_INTRODUCED_AT_MIN := 2.0
const BOSS_INTRODUCED_AT_MIN := 5.0
const NEST_INTRODUCED_AT_MIN := 8.0
const NEST_SPAWN_INTERVAL_SEC := 90.0
const NEST_CAP := 2

const PACK_CHANCE_BASE := 0.12
const PACK_CHANCE_PER_MIN := 0.01
const PACK_CHANCE_MAX := 0.35
const PACK_SIZE_MIN := 3
const PACK_SIZE_MAX := 6
const PACK_SCATTER_PX := 40.0

const WAVE_FIRST_DELAY_SEC := 35.0
const WAVE_INTERVAL_SEC := 55.0
const WAVE_STAGGER_SEC := 0.12
const WAVE_RING_RADIUS := 320.0
const WAVE_LINE_SPACING := 55.0

# Each flavor is only eligible once `minutes` reaches its threshold, so the
# roster of possible waves opens up over a run the same way the regular
# spawn roster does.
const WAVE_FLAVORS := [
	{"name": "Rat Swarm", "species": "rat", "min_minutes": 0.0, "count_min": 10, "count_max": 16, "formation": "cluster"},
	{"name": "Spider Ambush", "species": "spider", "min_minutes": 0.5, "count_min": 6, "count_max": 10, "formation": "ring"},
	{"name": "Alien Vanguard", "species": "alien", "min_minutes": 2.5, "count_min": 4, "count_max": 7, "formation": "line"},
	{"name": "Pincer Assault", "species": "", "min_minutes": 4.0, "count_min": 5, "count_max": 9, "formation": "pincer"},
]

var _enemies_container: Node2D
var _player: Node2D
var _arena_size := Vector2(1280, 720)

var _spawn_timer: float = 0.0
var _nest_timer: float = 0.0
var _active_nest_count: int = 0

var _wave_timer: float = 0.0
var _pending_wave_spawns: Array = []


func register_arena(enemies_container: Node2D, player: Node2D, arena_size: Vector2) -> void:
	_enemies_container = enemies_container
	_player = player
	_arena_size = arena_size
	_spawn_timer = 0.0
	_nest_timer = NEST_SPAWN_INTERVAL_SEC
	_active_nest_count = 0
	_wave_timer = WAVE_FIRST_DELAY_SEC
	_pending_wave_spawns = []


func _process(delta: float) -> void:
	if _enemies_container == null:
		return
	var minutes := SessionClock.get_elapsed_minutes()

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _spawn_interval(minutes)
		_try_spawn_enemy(minutes)

	if minutes >= NEST_INTRODUCED_AT_MIN and _active_nest_count < NEST_CAP:
		_nest_timer -= delta
		if _nest_timer <= 0.0:
			_nest_timer = NEST_SPAWN_INTERVAL_SEC
			_spawn_nest()

	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = WAVE_INTERVAL_SEC
		_start_wave(minutes)

	_process_pending_wave_spawns(delta)


func _spawn_interval(minutes: float) -> float:
	return max(0.3, 2.0 - minutes * 0.15)


func _concurrent_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


func _try_spawn_enemy(minutes: float) -> void:
	if _concurrent_enemy_count() >= CONCURRENT_CAP:
		return
	var species := _pick_species(minutes)
	var variant := _pick_variant(minutes)
	var pack_chance: float = clamp(PACK_CHANCE_BASE + minutes * PACK_CHANCE_PER_MIN, PACK_CHANCE_BASE, PACK_CHANCE_MAX)
	if randf() < pack_chance:
		_spawn_pack(species, variant, _random_edge_position())
	else:
		spawn_enemy_at(species, variant, _random_edge_position())


## A cluster of the same species spawning together at one edge point, instead
## of the usual lone trickle spawn.
func _spawn_pack(species: String, variant: String, origin: Vector2) -> void:
	var count := randi_range(PACK_SIZE_MIN, PACK_SIZE_MAX)
	for i in count:
		var offset := Vector2(randf_range(-PACK_SCATTER_PX, PACK_SCATTER_PX), randf_range(-PACK_SCATTER_PX, PACK_SCATTER_PX))
		spawn_enemy_at(species, variant, origin + offset)


# ------------------------------------------------------------------ waves --

func _start_wave(minutes: float) -> void:
	var eligible: Array = WAVE_FLAVORS.filter(func(f): return minutes >= f["min_minutes"])
	if eligible.is_empty():
		return
	var flavor: Dictionary = eligible[randi() % eligible.size()]
	var count := randi_range(flavor["count_min"], flavor["count_max"])
	wave_announced.emit(flavor["name"])
	match flavor["formation"]:
		"cluster":
			_queue_wave_cluster(flavor["species"], minutes, count, _random_edge_position())
		"ring":
			_queue_wave_ring(flavor["species"], minutes, count)
		"line":
			_queue_wave_line(flavor["species"], minutes, count, _random_edge_position())
		"pincer":
			var half := count / 2
			var edges := _pincer_edge_positions()
			_queue_wave_cluster(_pick_species(minutes), minutes, half, edges[0])
			_queue_wave_cluster(_pick_species(minutes), minutes, count - half, edges[1])


func _queue_wave_cluster(species: String, minutes: float, count: int, origin: Vector2) -> void:
	for i in count:
		var offset := Vector2(randf_range(-PACK_SCATTER_PX, PACK_SCATTER_PX), randf_range(-PACK_SCATTER_PX, PACK_SCATTER_PX))
		_pending_wave_spawns.append({
			"delay": i * WAVE_STAGGER_SEC,
			"species": species,
			"variant": _pick_variant(minutes),
			"pos": origin + offset,
		})


## Enemies "dropping in" evenly spaced around the player, at a radius they'll
## have to close - an ambush rather than an edge trickle.
func _queue_wave_ring(species: String, minutes: float, count: int) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var start_angle := randf() * TAU
	for i in count:
		var angle := start_angle + TAU * float(i) / count + randf_range(-0.15, 0.15)
		var pos: Vector2 = _player.global_position + Vector2.RIGHT.rotated(angle) * WAVE_RING_RADIUS
		pos.x = clamp(pos.x, 10.0, _arena_size.x - 10.0)
		pos.y = clamp(pos.y, 10.0, _arena_size.y - 10.0)
		_pending_wave_spawns.append({
			"delay": i * WAVE_STAGGER_SEC,
			"species": species,
			"variant": _pick_variant(minutes),
			"pos": pos,
		})


## A marching line of enemies along one edge - a "vanguard" rather than a
## scattered handful.
func _queue_wave_line(species: String, minutes: float, count: int, origin: Vector2) -> void:
	var along_x: bool = origin.y < 0.0 or origin.y > _arena_size.y
	for i in count:
		var offset := (i - (count - 1) / 2.0) * WAVE_LINE_SPACING
		var pos: Vector2 = origin + (Vector2(offset, 0.0) if along_x else Vector2(0.0, offset))
		_pending_wave_spawns.append({
			"delay": i * WAVE_STAGGER_SEC,
			"species": species,
			"variant": _pick_variant(minutes),
			"pos": pos,
		})


func _pincer_edge_positions() -> Array:
	if randi() % 2 == 0:
		return [Vector2(-20.0, randf() * _arena_size.y), Vector2(_arena_size.x + 20.0, randf() * _arena_size.y)]
	return [Vector2(randf() * _arena_size.x, -20.0), Vector2(randf() * _arena_size.x, _arena_size.y + 20.0)]


func _process_pending_wave_spawns(delta: float) -> void:
	if _pending_wave_spawns.is_empty():
		return
	var remaining: Array = []
	for entry in _pending_wave_spawns:
		entry["delay"] -= delta
		if entry["delay"] <= 0.0:
			spawn_enemy_at(entry["species"], entry["variant"], entry["pos"])
		else:
			remaining.append(entry)
	_pending_wave_spawns = remaining


func _pick_species(minutes: float) -> String:
	var roll := randf()
	if minutes < ALIEN_INTRODUCED_AT_MIN:
		return "rat" if roll < 0.5 else "spider"
	if roll < 0.4:
		return "rat"
	elif roll < 0.75:
		return "spider"
	return "alien"


func _pick_variant(minutes: float) -> String:
	if minutes < BOSS_INTRODUCED_AT_MIN:
		return "base"
	var boss_chance: float = clamp(0.05 + (minutes - BOSS_INTRODUCED_AT_MIN) * 0.01, 0.05, 0.25)
	return "boss" if randf() < boss_chance else "base"


## Public: also used by Nest.gd to spawn its own enemies through the same cap check.
func spawn_enemy_at(species: String, variant: String, pos: Vector2) -> Node:
	if _concurrent_enemy_count() >= CONCURRENT_CAP:
		return null
	var enemy := ENEMY_SCENE.instantiate()
	_enemies_container.add_child(enemy)
	enemy.setup(species, variant, pos)
	return enemy


func _spawn_nest() -> void:
	var nest := NEST_SCENE.instantiate()
	_enemies_container.add_child(nest)
	_active_nest_count += 1
	nest.tree_exited.connect(_on_nest_removed)
	nest.setup(_random_interior_position())


func _on_nest_removed() -> void:
	_active_nest_count = max(0, _active_nest_count - 1)


func _random_edge_position() -> Vector2:
	var side := randi() % 4
	match side:
		0:
			return Vector2(randf() * _arena_size.x, -20.0)
		1:
			return Vector2(randf() * _arena_size.x, _arena_size.y + 20.0)
		2:
			return Vector2(-20.0, randf() * _arena_size.y)
		_:
			return Vector2(_arena_size.x + 20.0, randf() * _arena_size.y)


func _random_interior_position() -> Vector2:
	var pos := Vector2(randf_range(120.0, _arena_size.x - 120.0), randf_range(120.0, _arena_size.y - 120.0))
	if _player and pos.distance_to(_player.global_position) < 200.0:
		pos += (pos - _player.global_position).normalized() * 250.0
	return pos


func reset() -> void:
	_enemies_container = null
	_player = null
	_spawn_timer = 0.0
	_nest_timer = 0.0
	_active_nest_count = 0
	_wave_timer = 0.0
	_pending_wave_spawns = []
