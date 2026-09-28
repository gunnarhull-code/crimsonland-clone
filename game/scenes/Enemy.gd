extends CharacterBody2D
## One enemy instance, generic across all 3 Species and their Boss Variants
## (docs/crimsonland-clone/issues/18: one base scene, per-species data from
## enemies.csv, not per-species inherited scenes). Implements the two-phase
## state machine from issues/06/issues/10: dynamic re-rolling wander, then
## permanent aggro with a species-specific chase style.

const SPECIES_WANDER_VARIANTS := {
	"rat": ["tight_loop", "zigzag_dart", "freeze_scurry"],
	"spider": ["loop", "figure_eight", "skitter_pause"],
	"alien": ["wide_loop", "long_drift", "idle_sway"],
}
const SPECIES_INNER_SHAPE := {"rat": "dots", "spider": "diamond", "alien": "hexagon"}
const SPECIES_COLOR := {
	"rat": Color(0.435, 0.812, 0.435),
	"spider": Color(0.949, 0.573, 0.290),
	"alien": Color(0.910, 0.365, 0.365),
}
const INNER_COLOR := Color(0.1, 0.1, 0.08)

const WANDER_REROLL_MIN := 1.0
const WANDER_REROLL_MAX := 2.0
const BOSS_SPEED_MULT := 0.6
const OFF_ARENA_STEER_THRESHOLD := 1.5

const PARTICLE_BURST := preload("res://scenes/effects/ParticleBurst.tscn")
const WEAPON_PICKUP_SCENE := preload("res://scenes/WeaponPickup.tscn")

var species: String = "rat"
var variant: String = "base"
var stats: Dictionary = {}
var hp: float = 0.0

var aggroed: bool = false
var _wander_kind: String = "tight_loop"
var _wander_reroll_timer: float = 0.0
var _wander_anchor: Vector2 = Vector2.ZERO
var _wander_orbit_dir: float = 1.0
var _wander_sub_timer: float = 0.0
var _wander_darting: bool = true
var _wander_dart_dir: Vector2 = Vector2.RIGHT

var _spider_bursting: bool = true
var _spider_phase_timer: float = 0.4

var _off_arena_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0

var _player: Node2D
var _weapon_drop_guaranteed: bool = false

@onready var _hitbox: CollisionShape2D = $CollisionShape2D
@onready var _body: Node2D = $Body


func setup(p_species: String, p_variant: String, spawn_pos: Vector2) -> void:
	species = p_species
	variant = p_variant
	global_position = spawn_pos
	stats = DataTables.get_enemy_stats(species, variant)
	hp = stats.get("hp", 10.0) * SessionClock.get_toughness_multiplier()
	add_to_group("enemies")
	if _hitbox.shape is CircleShape2D:
		_hitbox.shape.radius = stats.get("hitbox_radius_px", 14.0)
	if _body:
		_body.configure(
			stats.get("hitbox_radius_px", 14.0),
			SPECIES_COLOR.get(species, Color.WHITE),
			INNER_COLOR,
			SPECIES_INNER_SHAPE.get(species, "diamond"),
			variant == "boss"
		)
	_wander_anchor = spawn_pos
	_pick_new_wander_variant()
	_attack_cooldown_timer = stats.get("attack_cooldown_sec", 1.0)
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	if not aggroed:
		_check_aggro()

	if aggroed:
		_process_chase(delta)
	else:
		_process_wander(delta)

	move_and_slide()
	_process_contact_damage(delta)
	if velocity.length() > 1.0:
		_body.rotation = velocity.angle()


func _check_aggro() -> void:
	var radius: float = stats.get("aggro_radius_px", 450.0) * _player.get_aggro_radius_multiplier()
	if global_position.distance_to(_player.global_position) <= radius:
		aggroed = true


# ---------------------------------------------------------------- wander --

func _process_wander(delta: float) -> void:
	_wander_reroll_timer -= delta
	if _wander_reroll_timer <= 0.0:
		_pick_new_wander_variant()

	var speed: float = stats.get("wander_speed_px_s", 40.0) * (BOSS_SPEED_MULT if variant == "boss" else 1.0)

	match _wander_kind:
		"tight_loop", "loop", "wide_loop":
			var offset := global_position - _wander_anchor
			if offset.length() < 1.0:
				offset = Vector2.RIGHT
			velocity = offset.normalized().rotated(_wander_orbit_dir * PI / 2.0) * speed
		"figure_eight":
			_wander_sub_timer -= delta
			if _wander_sub_timer <= 0.0:
				_wander_sub_timer = 0.9
				_wander_orbit_dir *= -1.0
			var offset := global_position - _wander_anchor
			if offset.length() < 1.0:
				offset = Vector2.RIGHT
			velocity = offset.normalized().rotated(_wander_orbit_dir * PI / 2.0) * speed
		"skitter_pause", "zigzag_dart", "freeze_scurry":
			_wander_sub_timer -= delta
			if _wander_sub_timer <= 0.0:
				_wander_darting = not _wander_darting
				if _wander_darting:
					_wander_dart_dir = Vector2.RIGHT.rotated(randf() * TAU)
					_wander_sub_timer = randf_range(0.3, 0.6)
				else:
					var freeze_len := 0.5 if _wander_kind == "skitter_pause" else 0.25
					_wander_sub_timer = freeze_len
			velocity = _wander_dart_dir * speed if _wander_darting else Vector2.ZERO
		"long_drift":
			_wander_sub_timer -= delta
			if _wander_sub_timer <= 0.0:
				_wander_dart_dir = Vector2.RIGHT.rotated(randf() * TAU)
				_wander_sub_timer = randf_range(3.0, 5.0)
			velocity = _wander_dart_dir * speed
		"idle_sway":
			_wander_sub_timer += delta
			velocity = Vector2.RIGHT.rotated(_wander_orbit_dir) * sin(_wander_sub_timer * 1.5) * speed * 0.5
		_:
			velocity = Vector2.ZERO

	_process_soft_boundary(delta)


func _pick_new_wander_variant() -> void:
	_wander_reroll_timer = randf_range(WANDER_REROLL_MIN, WANDER_REROLL_MAX)
	var options: Array = SPECIES_WANDER_VARIANTS.get(species, ["tight_loop"])
	_wander_kind = options[randi() % options.size()]
	_wander_anchor = global_position
	_wander_orbit_dir = 1.0 if randf() < 0.5 else -1.0
	_wander_sub_timer = 0.0
	_wander_darting = true


func _process_soft_boundary(delta: float) -> void:
	var size: Vector2 = get_viewport_rect().size
	var out_of_bounds: bool = global_position.x < 0.0 or global_position.x > size.x \
		or global_position.y < 0.0 or global_position.y > size.y
	if out_of_bounds:
		_off_arena_timer += delta
		if _off_arena_timer > OFF_ARENA_STEER_THRESHOLD:
			var center := size / 2.0
			var steer := (center - global_position).normalized()
			velocity = velocity.lerp(steer * velocity.length(), 0.15)
	else:
		_off_arena_timer = 0.0


# ----------------------------------------------------------------- chase --

func _process_chase(delta: float) -> void:
	var chase_speed: float = stats.get("chase_speed_px_s", 100.0) * (BOSS_SPEED_MULT if variant == "boss" else 1.0)
	var to_player: Vector2 = (_player.global_position - global_position)
	var dir: Vector2 = to_player.normalized() if to_player.length() > 1.0 else Vector2.ZERO

	if species == "spider":
		_spider_phase_timer -= delta
		if _spider_phase_timer <= 0.0:
			_spider_bursting = not _spider_bursting
			_spider_phase_timer = 0.4 if _spider_bursting else 0.3
		velocity = dir * chase_speed if _spider_bursting else Vector2.ZERO
	else:
		velocity = dir * chase_speed


# --------------------------------------------------------- contact damage --

func _process_contact_damage(delta: float) -> void:
	var my_radius: float = stats.get("hitbox_radius_px", 14.0)
	var player_radius: float = _player.hitbox_radius if "hitbox_radius" in _player else 14.0
	var touching: bool = global_position.distance_to(_player.global_position) <= (my_radius + player_radius)
	if not touching:
		return
	_attack_cooldown_timer -= delta
	if _attack_cooldown_timer <= 0.0:
		_player.take_damage(stats.get("damage", 5.0))
		_attack_cooldown_timer = stats.get("attack_cooldown_sec", 1.0)


# ------------------------------------------------------------------ death --

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		_die()


func _die() -> void:
	if _player and is_instance_valid(_player):
		_player.on_enemy_killed(species, variant, stats.get("xp", 5.0), global_position)
	var burst := PARTICLE_BURST.instantiate()
	get_tree().current_scene.get_node("Effects").add_child(burst)
	burst.global_position = global_position
	burst.fire(5, SPECIES_COLOR.get(species, Color.WHITE))
	AudioManager.play_death()
	_maybe_drop_weapon()
	queue_free()


func _maybe_drop_weapon() -> void:
	if _player == null:
		return
	# "Pickup luck" (Lucky Find perk) boosts the base non-Pistol drop chance -
	# the only "item" this MVP has to be lucky about, per issues/13.
	var luck: float = _player.get_effective_stat("player.pickup_luck", 0.0)
	var drop_chance: float = 1.0 if _player.weapon_id == "pistol" else clamp(0.08 + luck, 0.0, 1.0)
	if randf() < drop_chance:
		var weapon_ids: Array = DataTables.get_all_weapons().map(func(w): return w["id"])
		weapon_ids.erase("pistol")
		if weapon_ids.is_empty():
			return
		var pickup := WEAPON_PICKUP_SCENE.instantiate()
		get_tree().current_scene.get_node("Enemies").add_child(pickup)
		pickup.global_position = global_position
		pickup.setup(weapon_ids[randi() % weapon_ids.size()])
