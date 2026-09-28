extends CharacterBody2D
## The player. An instanced scene, not a singleton, per
## docs/crimsonland-clone/issues/16 - owns its own HP/speed/weapon/perks so a
## second instance could exist later without any rewrite. Input is captured
## once per frame into a small state (move_vector, aim_position, fire_held)
## which the rest of this script reads - nothing below _capture_input() calls
## Input.* directly, per the same ticket.

signal leveled_up(level: int, choices: Array)
signal died
signal hp_changed(current: float, max_hp: float)
signal score_changed(score: int)
signal xp_changed(xp: float, xp_required: float, level: int)
signal weapon_changed(weapon_id: String)

const BASE_MAX_HP := 100.0
const BASE_MOVE_SPEED := 260.0
const BASE_HP_REGEN := 0.0
const BASE_PICKUP_LUCK := 0.0
const BASE_PICKUP_RADIUS := 20.0
const BASE_AGGRO_RADIUS_MULT := 1.0
const BASE_PERK_CHOICES := 3.0
const POST_LEVELUP_INVULN_SEC := 0.5

const WEAPON_STAT_MAP := {
	"reload_time": "reload_time_sec",
	"fire_rate": "fire_rate_per_sec",
	"magazine_size": "magazine_size",
	"projectile_speed": "projectile_speed_px_s",
	"spread": "spread_deg",
	"damage": "damage",
}

const SPECIES_SCORE_WEIGHT := {"rat": 1, "spider": 2, "alien": 4}
const BOSS_SCORE_MULT := 6

const PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const PARTICLE_BURST := preload("res://scenes/effects/ParticleBurst.tscn")

@export var hitbox_radius: float = 14.0

var stat_modifiers: Dictionary = {}
var active_perks: Array = []
var recurring_levelup_perks: Array = []
var special_triggers: Dictionary = {}

var hp: float = BASE_MAX_HP
var level: int = 1
var xp: float = 0.0
var score: int = 0
var survival_time: float = 0.0
var invulnerable: bool = false
var alive: bool = true

var weapon_id: String = "pistol"
var has_had_first_weapon_drop: bool = false
var ammo_in_magazine: int = 0
var is_reloading: bool = false
var _reload_timer: float = 0.0
var _fire_cooldown_timer: float = 0.0

var _move_vector: Vector2 = Vector2.ZERO
var _aim_position: Vector2 = Vector2.ZERO
var _fire_held: bool = false

@onready var _hitbox: CollisionShape2D = $CollisionShape2D
@onready var _body: Node2D = $Body


func _ready() -> void:
	add_to_group("player")
	hp = get_effective_stat("player.max_hp", BASE_MAX_HP)
	ammo_in_magazine = DataTables.get_weapon(weapon_id).get("magazine_size", 0)
	if _hitbox.shape is CircleShape2D:
		_hitbox.shape.radius = hitbox_radius
	hp_changed.emit(hp, get_max_hp())
	xp_changed.emit(xp, _xp_required_for_level(level + 1), level)
	weapon_changed.emit(weapon_id)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_capture_input()
	_apply_movement(delta)
	_update_regen(delta)
	_update_weapon(delta)
	survival_time += delta
	_update_score()


## The one place this scene reads Input.* directly - everything downstream
## reads _move_vector / _aim_position / _fire_held instead.
func _capture_input() -> void:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1.0
	_move_vector = v.normalized()
	_aim_position = get_global_mouse_position()
	_fire_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _apply_movement(_delta: float) -> void:
	velocity = _move_vector * get_effective_stat("player.move_speed", BASE_MOVE_SPEED)
	move_and_slide()
	# Hard-capped at the Arena edge per issues/02 - the enemy soft-boundary
	# drift from issues/10 does not apply to the player.
	var arena_size: Vector2 = get_viewport_rect().size
	global_position.x = clamp(global_position.x, hitbox_radius, arena_size.x - hitbox_radius)
	global_position.y = clamp(global_position.y, hitbox_radius, arena_size.y - hitbox_radius)
	if _aim_position != global_position:
		_body.rotation = (_aim_position - global_position).angle()


func _update_regen(delta: float) -> void:
	var regen := get_effective_stat("player.hp_regen", BASE_HP_REGEN)
	if regen > 0.0 and hp < get_max_hp():
		set_hp(min(get_max_hp(), hp + regen * delta))


func _update_score() -> void:
	var new_score := int(survival_time) + _kill_score
	if new_score != score:
		score = new_score
		score_changed.emit(score)


var _kill_score: int = 0


func _update_weapon(delta: float) -> void:
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			is_reloading = false
			ammo_in_magazine = int(get_effective_weapon_stats(weapon_id)["magazine_size"])
		return

	_fire_cooldown_timer -= delta
	if _fire_held and _fire_cooldown_timer <= 0.0:
		if ammo_in_magazine <= 0:
			_start_reload()
		else:
			_fire()


func _start_reload() -> void:
	is_reloading = true
	_reload_timer = get_effective_weapon_stats(weapon_id)["reload_time_sec"]


func _fire() -> void:
	var stats := get_effective_weapon_stats(weapon_id)
	_fire_cooldown_timer = 1.0 / max(0.01, stats["fire_rate_per_sec"])
	ammo_in_magazine -= 1

	var base_dir: Vector2 = (_aim_position - global_position)
	if base_dir.length() < 0.01:
		base_dir = Vector2.RIGHT
	base_dir = base_dir.normalized()

	if weapon_id == "shotgun":
		for i in 6:
			_spawn_projectile(base_dir.rotated(deg_to_rad(randf_range(-stats["spread_deg"], stats["spread_deg"]))), stats)
	else:
		var spread: float = stats["spread_deg"]
		var dir := base_dir.rotated(deg_to_rad(randf_range(-spread, spread)))
		_spawn_projectile(dir, stats)

	AudioManager.play_fire()
	if ammo_in_magazine <= 0:
		_start_reload()


func _spawn_projectile(direction: Vector2, stats: Dictionary) -> void:
	var proj := PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.get_node("Projectiles").add_child(proj)
	proj.global_position = global_position
	proj.setup(direction, stats, weapon_id)


func pick_up_weapon(new_weapon_id: String) -> void:
	weapon_id = new_weapon_id
	ammo_in_magazine = int(get_effective_weapon_stats(weapon_id)["magazine_size"])
	is_reloading = false
	AudioManager.play_pickup()
	weapon_changed.emit(weapon_id)


func get_pickup_radius() -> float:
	return get_effective_stat("player.pickup_radius", BASE_PICKUP_RADIUS)


func get_aggro_radius_multiplier() -> float:
	return get_effective_stat("player.aggro_radius_multiplier", BASE_AGGRO_RADIUS_MULT)


func get_max_hp() -> float:
	return get_effective_stat("player.max_hp", BASE_MAX_HP)


func take_damage(amount: float) -> void:
	if not alive or invulnerable:
		return
	set_hp(hp - amount)
	AudioManager.play_player_hit()
	if hp <= 0.0:
		_die()


func set_hp(new_hp: float) -> void:
	hp = clamp(new_hp, 0.0, get_max_hp())
	hp_changed.emit(hp, get_max_hp())


func _die() -> void:
	alive = false
	died.emit()


func on_enemy_killed(species: String, variant: String, xp_reward: float, position: Vector2) -> void:
	gain_xp(xp_reward)
	var weight: int = SPECIES_SCORE_WEIGHT.get(species, 1)
	if variant == "boss":
		weight *= BOSS_SCORE_MULT
	_kill_score += weight
	trigger_event("on_kill", {"position": position})


func on_nest_destroyed(xp_reward: float) -> void:
	gain_xp(xp_reward)


func gain_xp(amount: float) -> void:
	xp += amount
	var required := _xp_required_for_level(level + 1)
	if xp >= required:
		_level_up()
	else:
		xp_changed.emit(xp, required, level)


func _xp_required_for_level(target_level: int) -> float:
	# docs/crimsonland-clone/issues/14: 100 * level^1.5
	return 100.0 * pow(float(target_level), 1.5)


func _level_up() -> void:
	level += 1
	for perk in recurring_levelup_perks:
		_apply_math_effect(perk)
	xp_changed.emit(xp, _xp_required_for_level(level + 1), level)
	var choices := _roll_perk_choices()
	leveled_up.emit(level, choices)


func _roll_perk_choices() -> Array:
	var all_perks: Array = DataTables.get_all_perks()
	var pool: Array = all_perks.filter(func(p): return not active_perks.has(p))
	pool.shuffle()
	var count := int(get_effective_stat("game.perk_choices_offered", BASE_PERK_CHOICES))
	return pool.slice(0, min(count, pool.size()))


## Called by the level-up UI once the player picks. Grants the post-choice
## invulnerability window per issues/14 (not at the moment of leveling up).
func choose_perk(perk: Dictionary) -> void:
	apply_perk(perk)
	invulnerable = true
	AudioManager.play_levelup()
	var burst := PARTICLE_BURST.instantiate()
	get_tree().current_scene.get_node("Effects").add_child(burst)
	burst.global_position = global_position
	burst.fire(6, Color(0.9, 0.75, 0.2))
	await get_tree().create_timer(POST_LEVELUP_INVULN_SEC).timeout
	invulnerable = false


func apply_perk(perk: Dictionary) -> void:
	active_perks.append(perk)
	_apply_math_effect(perk)
	if perk["trigger"] == "on_levelup" and perk["special_handler_id"] == "":
		recurring_levelup_perks.append(perk)
	elif perk["trigger"] != "passive" and perk["special_handler_id"] != "":
		_register_special_trigger(perk)


func _apply_math_effect(perk: Dictionary) -> void:
	if perk["effect_type"] != "special":
		_apply_single_effect(perk["effect_type"], perk["target"], perk["value"])
	if perk.get("has_secondary_effect", false):
		_apply_single_effect(perk["effect_type_2"], perk["target_2"], perk["value_2"])


func _apply_single_effect(effect_type: String, target: String, value: float) -> void:
	if target == "":
		return
	var mod: Dictionary = stat_modifiers.get(target, {"additive": 0.0, "multiplicative": 1.0})
	if effect_type == "additive":
		mod["additive"] += value
	elif effect_type == "multiplicative":
		mod["multiplicative"] *= value
	stat_modifiers[target] = mod


func get_effective_stat(key: String, base: float) -> float:
	var mod: Dictionary = stat_modifiers.get(key, {"additive": 0.0, "multiplicative": 1.0})
	return (base * mod["multiplicative"]) + mod["additive"]


func get_effective_weapon_stats(id: String) -> Dictionary:
	var base := DataTables.get_weapon(id).duplicate()
	for perk_key in WEAPON_STAT_MAP:
		var data_key: String = WEAPON_STAT_MAP[perk_key]
		base[data_key] = get_effective_stat("weapon.%s" % perk_key, base[data_key])
	return base


func _register_special_trigger(perk: Dictionary) -> void:
	var trig: String = perk["trigger"]
	if not special_triggers.has(trig):
		special_triggers[trig] = []
	special_triggers[trig].append({"id": perk["special_handler_id"], "chance": perk["value"]})


func trigger_event(event_name: String, context: Dictionary = {}) -> void:
	for entry in special_triggers.get(event_name, []):
		if randf() < entry["chance"]:
			_run_special_handler(entry["id"], context)


func _run_special_handler(handler_id: String, context: Dictionary) -> void:
	match handler_id:
		"bonus_pickup_on_kill":
			# Simplest MVP expression: an instant small XP bonus "drop".
			gain_xp(5.0)
			var burst := PARTICLE_BURST.instantiate()
			get_tree().current_scene.get_node("Effects").add_child(burst)
			burst.global_position = context.get("position", global_position)
			burst.fire(4, Color(1.0, 0.85, 0.3))
