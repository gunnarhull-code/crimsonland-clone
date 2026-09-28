extends Node
## Spawns enemies over time per docs/crimsonland-clone/issues/17 (spawn
## pacing) and issues/21 (Nests). Self-contained Autoload: owns its own
## timers and spawn logic, only instances new Enemy/Nest nodes into the
## Arena's Enemies container it was given - it does not reach into or
## mutate Player/Enemy internal state.

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const NEST_SCENE := preload("res://scenes/Nest.tscn")

const CONCURRENT_CAP := 250
const ALIEN_INTRODUCED_AT_MIN := 2.0
const BOSS_INTRODUCED_AT_MIN := 5.0
const NEST_INTRODUCED_AT_MIN := 8.0
const NEST_SPAWN_INTERVAL_SEC := 90.0
const NEST_CAP := 2

var _enemies_container: Node2D
var _player: Node2D
var _arena_size := Vector2(1280, 720)

var _spawn_timer: float = 0.0
var _nest_timer: float = 0.0
var _active_nest_count: int = 0


func register_arena(enemies_container: Node2D, player: Node2D, arena_size: Vector2) -> void:
	_enemies_container = enemies_container
	_player = player
	_arena_size = arena_size
	_spawn_timer = 0.0
	_nest_timer = NEST_SPAWN_INTERVAL_SEC
	_active_nest_count = 0


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


func _spawn_interval(minutes: float) -> float:
	return max(0.3, 2.0 - minutes * 0.15)


func _concurrent_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


func _try_spawn_enemy(minutes: float) -> void:
	if _concurrent_enemy_count() >= CONCURRENT_CAP:
		return
	spawn_enemy_at(_pick_species(minutes), _pick_variant(minutes), _random_edge_position())


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
