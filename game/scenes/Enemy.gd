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

# Spider jerk randomness (both wander's skitter_pause and chase's burst-dart
# use these) - per direct playtest request, the old fixed 0.4s/0.3s burst
# timing read as a metronome, not a jerky, unpredictable spider. Randomizing
# both how long each dart lasts (timing) and how fast it covers ground
# (distance) breaks that regularity.
const SPIDER_BURST_MIN := 0.15
const SPIDER_BURST_MAX := 0.55
const SPIDER_FREEZE_MIN := 0.12
const SPIDER_FREEZE_MAX := 0.5
const SPIDER_DART_SPEED_MIN := 0.6
const SPIDER_DART_SPEED_MAX := 1.5

# Chase variety - per direct playtest request: enemies were all beelining to
# the player's exact position with instant direction snaps, which reads as
# one tight, perfectly-tracking clump rather than a spread-out crowd. Each
# enemy instead aims at a personal offset point near the player (so they
# fan out instead of converging on one spot) and turns toward it at a
# capped rate (so sharp corners get overshot into a wide arc instead of a
# snap-turn) - both rerolled periodically so it's not a fixed formation and
# not every enemy is equally sluggish ("some of them can, sometimes").
const CHASE_AIM_OFFSET_MIN := 30.0
const CHASE_AIM_OFFSET_MAX := 110.0
const CHASE_VARIETY_REROLL_MIN := 2.0
const CHASE_VARIETY_REROLL_MAX := 4.0
const CHASE_TURN_RATE_MIN_DEG := 70.0
const CHASE_TURN_RATE_MAX_DEG := 1000.0

# How stale a player position this enemy reacts to, at range - per direct
# playtest request ("they all just target me... kite them around, they end
# up grouping up into a big, tight group... don't just seem like robots").
# Every enemy previously aimed at the player's exact live position, so a
# kited crowd converged onto the same point in perfect lockstep. Each
# enemy instead samples Player.get_position_delayed() at its own rolled
# lag, so they're chasing slightly different moments of the player's
# recent path - naturally spreads a kited group instead of merging it, and
# reads as personality (some react almost instantly, some visibly lag)
# instead of uniform robotic tracking.
const CHASE_REACTION_LAG_MIN := 0.1
const CHASE_REACTION_LAG_MAX := 0.8

# Once an enemy is genuinely close, it stops aiming at its personal offset
# point and aims straight at the player instead - per direct playtest
# request ("nobody's really dangerous... I want them to consistently do
# damage"). The offset was making enemies orbit near the player without
# ever actually closing to contact distance, so damage landed far less
# often than the attack cooldown alone would suggest. The offset still
# does its job at range (fanning a crowd out while approaching); it just
# doesn't get to override the final approach anymore.
const CHASE_CLOSE_RANGE := 100.0
const CONTACT_TOUCH_BUFFER := 6.0

# Auto-aggro: an enemy that never crosses the player's aggro radius would
# otherwise wander forever, which reads as "just standing there" once the
# Arena got much bigger than the screen. Per direct playtest request, every
# enemy forces its own aggro after a randomized timeout even if the player
# never gets close.
const AUTO_AGGRO_TIMEOUT_MIN := 8.0
const AUTO_AGGRO_TIMEOUT_MAX := 16.0

# "More natural" movement, per direct playtest request: real acceleration
# instead of velocity snapping instantly to whatever the current behavior
# wants (a wander target, a chase direction, a burst/freeze toggle), a mild
# steering nudge away from nearby enemies so a crowd doesn't read as bodies
# sliding through each other, and a fixed per-enemy speed multiplier so a
# same-species swarm doesn't move in perfect lockstep.
const ACCEL_PX_S2 := 900.0
const SEPARATION_RADIUS := 46.0
const SEPARATION_STRENGTH := 60.0
const SPEED_VARIANCE_MIN := 0.85
const SPEED_VARIANCE_MAX := 1.15

# Orbit radius per loop-style variant, in px. Large enough to read as a
# proper loop rather than a tight spin at typical wander speeds (~40-150px/s
# - a small radius at that speed produces a very high angular rate, which is
# what "tiny circles, way too fast" actually was: not a speed problem, a
# missing-radius-control problem).
const WANDER_RADIUS := {
	"tight_loop": 70.0,
	"loop": 130.0,
	"wide_loop": 200.0,
	"figure_eight": 110.0,
}

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
var _wander_angle: float = 0.0
var _wander_sub_timer: float = 0.0
var _wander_darting: bool = true
var _wander_dart_dir: Vector2 = Vector2.RIGHT

var _spider_bursting: bool = true
var _spider_phase_timer: float = 0.4
var _spider_dart_speed_mult: float = 1.0
var _wander_dart_speed_mult: float = 1.0

var _chase_dir: Vector2 = Vector2.ZERO
var _chase_aim_offset: Vector2 = Vector2.ZERO
var _chase_turn_rate_deg: float = 400.0
var _chase_variety_timer: float = 0.0
var _chase_reaction_lag: float = 0.0

var _wander_elapsed: float = 0.0
var _auto_aggro_timeout: float = 12.0
var _speed_variance: float = 1.0

var _off_arena_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0

var _player: Node2D
var _weapon_drop_guaranteed: bool = false

# Shotgun's Buckshot Knockback permanent upgrade (issue 22) - a punchy,
# un-eased shove that overrides normal wander/chase for a brief moment,
# rather than being blended through the accel/separation smoothing below
# (which would flatten it into barely noticeable).
const KNOCKBACK_DURATION_SEC := 0.25
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_timer: float = 0.0

@onready var _hitbox: CollisionShape2D = $CollisionShape2D
@onready var _body: Node2D = $Body


func setup(p_species: String, p_variant: String, spawn_pos: Vector2) -> void:
	species = p_species
	variant = p_variant
	global_position = spawn_pos
	stats = DataTables.get_enemy_stats(species, variant)
	hp = stats.get("hp", 10.0) * EnemySpawner.get_toughness_multiplier()
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
	_auto_aggro_timeout = randf_range(AUTO_AGGRO_TIMEOUT_MIN, AUTO_AGGRO_TIMEOUT_MAX)
	_speed_variance = randf_range(SPEED_VARIANCE_MIN, SPEED_VARIANCE_MAX)
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity = _knockback_velocity * (_knockback_timer / KNOCKBACK_DURATION_SEC)
		move_and_slide()
		_process_contact_damage(delta)
		if velocity.length() > 1.0:
			_body.rotation = velocity.angle()
		return

	if not aggroed:
		_check_aggro(delta)

	var desired_velocity: Vector2 = _process_chase(delta) if aggroed else _process_wander(delta)
	desired_velocity += _compute_separation()
	velocity = velocity.move_toward(desired_velocity, ACCEL_PX_S2 * delta)

	move_and_slide()
	_process_contact_damage(delta)
	if velocity.length() > 1.0:
		_body.rotation = velocity.angle()


func apply_knockback(impulse: Vector2) -> void:
	_knockback_velocity = impulse
	_knockback_timer = KNOCKBACK_DURATION_SEC


func _check_aggro(delta: float) -> void:
	var radius: float = stats.get("aggro_radius_px", 450.0) * _player.get_aggro_radius_multiplier()
	if global_position.distance_to(_player.global_position) <= radius:
		aggroed = true
		return
	_wander_elapsed += delta
	if _wander_elapsed >= _auto_aggro_timeout:
		aggroed = true


## A mild push away from nearby enemies, blended into the desired velocity
## rather than a hard shove - the bodies still freely overlap (no physics
## collision, per issues/02's addendum), this just discourages them from
## visibly sliding through each other while moving as a crowd.
func _compute_separation() -> Vector2:
	var push := Vector2.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self:
			continue
		var offset: Vector2 = global_position - e.global_position
		var dist := offset.length()
		if dist > 0.01 and dist < SEPARATION_RADIUS:
			push += offset.normalized() * (SEPARATION_RADIUS - dist) / SEPARATION_RADIUS
	return push * SEPARATION_STRENGTH


# ---------------------------------------------------------------- wander --

func _process_wander(delta: float) -> Vector2:
	_wander_reroll_timer -= delta
	if _wander_reroll_timer <= 0.0:
		_pick_new_wander_variant()

	var speed: float = stats.get("wander_speed_px_s", 40.0) * (BOSS_SPEED_MULT if variant == "boss" else 1.0) * _speed_variance

	# BUGFIX: the anchor drifts toward the player regardless of which local
	# pattern is active, so wandering always eventually closes the distance
	# into aggro range even from a spawn point the local pattern alone could
	# never carry it away from (e.g. the side edges, >450px from a centered
	# player). Drifting the ANCHOR rather than adding to velocity directly
	# keeps the orbit's own shape/radius clean instead of distorting it.
	if _player and is_instance_valid(_player):
		var to_player: Vector2 = _player.global_position - _wander_anchor
		if to_player.length() > 1.0:
			_wander_anchor += to_player.normalized() * speed * 0.25 * delta

	var desired := _compute_local_wander_velocity(speed, delta)
	return _process_soft_boundary(delta, desired)


func _compute_local_wander_velocity(speed: float, delta: float) -> Vector2:
	match _wander_kind:
		"tight_loop", "loop", "wide_loop", "figure_eight":
			if _wander_kind == "figure_eight":
				_wander_sub_timer -= delta
				if _wander_sub_timer <= 0.0:
					_wander_sub_timer = 0.9
					_wander_orbit_dir *= -1.0
			var radius: float = WANDER_RADIUS.get(_wander_kind, 100.0)
			# Angular rate = speed / radius, so a larger radius reads as a
			# slower, lazier loop rather than a fast spin at the same speed.
			_wander_angle += (speed / radius) * _wander_orbit_dir * delta
			# A touch of "imperfect" wobble - not a mathematically clean circle.
			var wobble := 1.0 + 0.18 * sin(_wander_angle * 2.3)
			var target: Vector2 = _wander_anchor + Vector2.RIGHT.rotated(_wander_angle) * radius * wobble
			var to_target: Vector2 = target - global_position
			return to_target.normalized() * speed if to_target.length() > 1.0 else Vector2.ZERO
		"skitter_pause", "zigzag_dart", "freeze_scurry":
			_wander_sub_timer -= delta
			if _wander_sub_timer <= 0.0:
				_wander_darting = not _wander_darting
				if _wander_darting:
					_wander_dart_dir = Vector2.RIGHT.rotated(randf() * TAU)
					_wander_sub_timer = randf_range(0.3, 0.6)
					if _wander_kind == "skitter_pause":
						_wander_dart_speed_mult = randf_range(SPIDER_DART_SPEED_MIN, SPIDER_DART_SPEED_MAX)
				else:
					var freeze_len := randf_range(SPIDER_FREEZE_MIN, SPIDER_FREEZE_MAX) if _wander_kind == "skitter_pause" else 0.25
					_wander_sub_timer = freeze_len
			var speed_mult: float = _wander_dart_speed_mult if _wander_kind == "skitter_pause" else 1.0
			return _wander_dart_dir * speed * speed_mult if _wander_darting else Vector2.ZERO
		"long_drift":
			_wander_sub_timer -= delta
			if _wander_sub_timer <= 0.0:
				_wander_dart_dir = Vector2.RIGHT.rotated(randf() * TAU)
				_wander_sub_timer = randf_range(3.0, 5.0)
			return _wander_dart_dir * speed
		"idle_sway":
			_wander_sub_timer += delta
			return Vector2.RIGHT.rotated(_wander_orbit_dir) * sin(_wander_sub_timer * 1.5) * speed * 0.5
		_:
			return Vector2.ZERO


func _pick_new_wander_variant() -> void:
	_wander_reroll_timer = randf_range(WANDER_REROLL_MIN, WANDER_REROLL_MAX)
	var options: Array = SPECIES_WANDER_VARIANTS.get(species, ["tight_loop"])
	_wander_kind = options[randi() % options.size()]
	_wander_orbit_dir = 1.0 if randf() < 0.5 else -1.0
	_wander_sub_timer = 0.0
	_wander_darting = true
	if WANDER_RADIUS.has(_wander_kind):
		# Start the orbit exactly where the enemy already is, rather than
		# anchored at the current position (which would force a slow
		# spiral-in from radius 0 - with only a 1-2s re-roll window, it would
		# switch variants again before ever tracing a visible loop).
		_wander_angle = randf() * TAU
		var radius: float = WANDER_RADIUS[_wander_kind]
		_wander_anchor = global_position - Vector2.RIGHT.rotated(_wander_angle) * radius
	else:
		_wander_anchor = global_position


func _process_soft_boundary(delta: float, desired: Vector2) -> Vector2:
	var size: Vector2 = ArenaConfig.size
	var out_of_bounds: bool = global_position.x < 0.0 or global_position.x > size.x \
		or global_position.y < 0.0 or global_position.y > size.y
	if out_of_bounds:
		_off_arena_timer += delta
		if _off_arena_timer > OFF_ARENA_STEER_THRESHOLD:
			var center := size / 2.0
			var steer := (center - global_position).normalized()
			return desired.lerp(steer * desired.length(), 0.15)
	else:
		_off_arena_timer = 0.0
	return desired


# ----------------------------------------------------------------- chase --

func _process_chase(delta: float) -> Vector2:
	var chase_speed: float = stats.get("chase_speed_px_s", 100.0) * (BOSS_SPEED_MULT if variant == "boss" else 1.0) * _speed_variance

	_chase_variety_timer -= delta
	if _chase_variety_timer <= 0.0:
		_chase_variety_timer = randf_range(CHASE_VARIETY_REROLL_MIN, CHASE_VARIETY_REROLL_MAX)
		_chase_aim_offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(CHASE_AIM_OFFSET_MIN, CHASE_AIM_OFFSET_MAX)
		_chase_turn_rate_deg = randf_range(CHASE_TURN_RATE_MIN_DEG, CHASE_TURN_RATE_MAX_DEG)
		_chase_reaction_lag = randf_range(CHASE_REACTION_LAG_MIN, CHASE_REACTION_LAG_MAX)

	var dist_to_player: float = global_position.distance_to(_player.global_position)
	var aim_point: Vector2 = _player.global_position if dist_to_player < CHASE_CLOSE_RANGE \
		else _player.get_position_delayed(_chase_reaction_lag) + _chase_aim_offset
	var to_target: Vector2 = aim_point - global_position
	var desired_dir: Vector2 = to_target.normalized() if to_target.length() > 1.0 else Vector2.ZERO
	_chase_dir = _turn_toward(_chase_dir, desired_dir, _chase_turn_rate_deg, delta)

	if species == "spider":
		_spider_phase_timer -= delta
		if _spider_phase_timer <= 0.0:
			_spider_bursting = not _spider_bursting
			if _spider_bursting:
				_spider_phase_timer = randf_range(SPIDER_BURST_MIN, SPIDER_BURST_MAX)
				_spider_dart_speed_mult = randf_range(SPIDER_DART_SPEED_MIN, SPIDER_DART_SPEED_MAX)
			else:
				_spider_phase_timer = randf_range(SPIDER_FREEZE_MIN, SPIDER_FREEZE_MAX)
		return _chase_dir * chase_speed * _spider_dart_speed_mult if _spider_bursting else Vector2.ZERO
	else:
		return _chase_dir * chase_speed


## Rotates `current` toward `desired` by at most `max_deg_per_sec`, rather
## than snapping instantly - the cap on how sharp a turn can be.
func _turn_toward(current: Vector2, desired: Vector2, max_deg_per_sec: float, delta: float) -> Vector2:
	if desired == Vector2.ZERO:
		return current
	if current == Vector2.ZERO:
		return desired
	var diff := wrapf(desired.angle() - current.angle(), -PI, PI)
	var max_step := deg_to_rad(max_deg_per_sec) * delta
	var step: float = clamp(diff, -max_step, max_step)
	return current.rotated(step)


# --------------------------------------------------------- contact damage --

func _process_contact_damage(delta: float) -> void:
	# BUGFIX: this used to only decrement while touching, so an enemy that
	# bounced in and out of contact range (turn-rate overshoot, separation
	# jitter) had its cooldown clock effectively pause every time it lost
	# contact - "barely did damage... took forever to die," reported
	# directly. The cooldown now always ticks down in real time; touching
	# only gates whether a *ready* attack can land, exactly like it should.
	_attack_cooldown_timer -= delta
	var my_radius: float = stats.get("hitbox_radius_px", 14.0)
	var player_radius: float = _player.hitbox_radius if "hitbox_radius" in _player else 14.0
	var touching: bool = global_position.distance_to(_player.global_position) <= (my_radius + player_radius + CONTACT_TOUCH_BUFFER)
	if not touching:
		return
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
	var drop_chance: float
	if not _player.has_had_first_weapon_drop:
		# BUGFIX: this used to be 1.0 for every kill while still on the
		# Pistol, so an early kill could silently swap the player into
		# whatever weapon rolled (a 1-in-5 chance of the Heavy Cannon's
		# giant, slow, ~0.5/s projectile) with no confirmation. Per issues/04
		# only the player's very *first* kill is guaranteed to drop - after
		# that, still-on-Pistol kills get an elevated but not guaranteed rate.
		drop_chance = 1.0
		_player.has_had_first_weapon_drop = true
	elif _player.weapon_id == "pistol":
		drop_chance = clamp(0.35 + luck, 0.0, 1.0)
	else:
		drop_chance = clamp(0.08 + luck, 0.0, 1.0)
	if randf() < drop_chance:
		var weapon_ids: Array = DataTables.get_all_weapons().map(func(w): return w["id"])
		weapon_ids.erase("pistol")
		if weapon_ids.is_empty():
			return
		var pickup := WEAPON_PICKUP_SCENE.instantiate()
		get_tree().current_scene.get_node("Enemies").add_child(pickup)
		pickup.global_position = global_position
		pickup.setup(weapon_ids[randi() % weapon_ids.size()])
