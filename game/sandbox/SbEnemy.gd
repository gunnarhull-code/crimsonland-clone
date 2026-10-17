extends Node2D
## Sandbox enemy: stats from enemies.csv (via DataTables), simple chase AI,
## contact damage, and the states the upgrades use. Drawn by SbArt.gd.

const Art := preload("res://sandbox/SbArt.gd")

const ACCEL := 900.0
const CLOSE_RANGE := 100.0
const TOUCH_BUFFER := 6.0

var sb
var species := "rat"
var variant := "base"
var stats := {}
var hp := 1.0
var max_hp := 1.0
var radius := 12.0
var dead := false

var poison_t := 0.0
var poison_dps := 0.0
var chill_t := 0.0
var chill_speed := 1.0
var armor := 0.0
var shards := 0
var strike_times: Array = []
var stun_t := 0.0
var held_t := 0.0
var portal_cd := 0.0
var link = null
var _knock := Vector2.ZERO

var _vel := Vector2.ZERO
var _face := 0.0
var _walk := 0.0
var _life_t := 0.0
var _kick := Vector2.ZERO        # visual-only shove from the last hit
var _attack_t := 0.0
var _aim_offset := Vector2.ZERO
var _speed_var := 1.0
var _bursting := true
var _phase_t := 0.3
var _dart_mult := 1.0
var _poison_acc := 0.0
var _poison_fx_t := 0.5
var _poison_drip_t := 0.0
var _flash := 0.0


func setup(p_sb, sp: String, p_variant: String, pos: Vector2) -> void:
	sb = p_sb
	species = sp
	variant = p_variant
	global_position = pos
	stats = DataTables.get_enemy_stats(sp, p_variant)
	max_hp = stats.get("hp", 10.0) * sb.hp_mult()
	hp = max_hp
	radius = stats.get("hitbox_radius_px", 12.0)
	_attack_t = stats.get("attack_cooldown_sec", 1.0)
	_aim_offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, 90.0)
	_speed_var = randf_range(0.85, 1.15)
	_face = randf() * TAU
	_walk = randf() * TAU


func is_debuffed() -> bool:
	return poison_t > 0.0 or chill_t > 0.0


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps if poison_t > 0.0 else 0.0, dps)
	poison_t = maxf(poison_t, duration)


func knock(impulse: Vector2) -> void:
	_knock += impulse


func apply_chill(speed_mult: float, duration: float) -> void:
	chill_speed = speed_mult
	chill_t = maxf(chill_t, duration)


## `from_dir` is the direction the hit travelled (zero if unknown), used for sparks.
func take_damage(amount: float, color: Color = Color.WHITE, from_dir: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.09
	_kick = from_dir * minf(7.0, 3.0 + amount * 0.08)
	sb.record_damage(amount)
	sb.fx_text(global_position + Vector2(randf_range(-8, 8), -radius), _fmt(amount), color, clampi(13 + int(amount * 0.12), 13, 26))
	sb.vfx_hit(global_position, from_dir, Art.ichor(species), amount, radius)
	if hp > 0.0:
		sb.audio.play("hit")
	if hp <= 0.0:
		_die()


func _fmt(a: float) -> String:
	return str(roundi(a)) if a >= 10.0 else "%.1f" % a


func _die() -> void:
	dead = true
	sb.kills += 1
	sb.audio.play("kill")
	sb.vfx_kill(global_position, species, radius, variant == "boss", _kick)
	sb.rules.enemy_died(self)
	queue_free()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_life_t += delta
	_flash = maxf(0.0, _flash - delta)
	_kick = _kick.move_toward(Vector2.ZERO, 60.0 * delta)
	if poison_t > 0.0:
		poison_t -= delta
		var d := poison_dps * delta
		hp -= d
		sb.record_damage(d)
		_poison_acc += d
		_poison_fx_t -= delta
		if _poison_fx_t <= 0.0:
			sb.fx_text(global_position + Vector2(0, -radius), _fmt(_poison_acc), Color(0.55, 1.0, 0.4))
			_poison_acc = 0.0
			_poison_fx_t = 0.5
		_poison_drip_t -= delta
		if _poison_drip_t <= 0.0:
			_poison_drip_t = 0.18
			sb.particles.add(global_position + Vector2.from_angle(randf() * TAU) * radius * 0.6,
				Vector2(randf_range(-12, 12), randf_range(-30, -12)), 0.5, 2.5, Color(0.5, 1.0, 0.35, 0.9), "dot", 2.0)
		if hp <= 0.0:
			_die()
			return
	else:
		poison_dps = 0.0
	if chill_t > 0.0:
		chill_t -= delta

	var player = sb.player
	stun_t = maxf(0.0, stun_t - delta)
	held_t = maxf(0.0, held_t - delta)
	var immobile := stun_t > 0.0 or held_t > 0.0
	var desired := Vector2.ZERO
	if sb.enemies_chase and player.hp > 0.0 and not immobile:
		desired = _chase_velocity(player, delta)
	if immobile:
		_vel = Vector2.ZERO
	_vel = _vel.move_toward(desired, ACCEL * delta)
	global_position += (_vel + _knock) * delta
	_knock = _knock.move_toward(Vector2.ZERO, 1500.0 * delta)
	global_position = global_position.clamp(Vector2.ZERO, sb.ARENA)
	if _vel.length() > 1.0:
		_face = lerp_angle(_face, _vel.angle(), minf(1.0, 14.0 * delta))
		_walk += _vel.length() * delta * (0.5 / maxf(radius, 6.0)) * 6.0

	if sb.enemies_chase and not immobile:
		_attack_t -= delta
		var touch: float = radius + player.RADIUS + TOUCH_BUFFER
		if player.hp > 0.0 and _attack_t <= 0.0 and global_position.distance_to(player.global_position) <= touch:
			player.take_damage(stats.get("damage", 5.0))
			_attack_t = stats.get("attack_cooldown_sec", 1.0)
			_kick = (player.global_position - global_position).normalized() * 6.0   # lunge forward visually
	queue_redraw()


func _chase_velocity(player, delta: float) -> Vector2:
	var speed: float = stats.get("chase_speed_px_s", 100.0) * _speed_var
	if chill_t > 0.0:
		speed *= chill_speed
	var target: Vector2 = player.global_position
	if global_position.distance_to(target) >= CLOSE_RANGE:
		target += _aim_offset
	var dir := (target - global_position).normalized()
	if species == "spider":
		_phase_t -= delta
		if _phase_t <= 0.0:
			_bursting = not _bursting
			_phase_t = randf_range(0.15, 0.55) if _bursting else randf_range(0.12, 0.5)
			_dart_mult = randf_range(0.6, 1.5)
		return dir * speed * _dart_mult if _bursting else Vector2.ZERO
	return dir * speed


func _draw() -> void:
	# soft ground shadow
	var sh := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		sh.append(Vector2(cos(a) * radius * 1.3 + 3.0, sin(a) * radius * 0.95 + 5.0))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.28))

	var tint := Color(1, 1, 1)
	if poison_t > 0.0:
		tint *= Color(0.75, 1.0, 0.65)
	if chill_t > 0.0:
		tint *= Color(0.7, 0.85, 1.2)
	if _flash > 0.0:
		tint = Color(2.2, 2.2, 2.2)
	var bob := sin(_life_t * 9.0 + _walk) * 0.015 if _vel.length() > 5.0 else 0.0
	Art.draw_enemy(self, species, variant == "boss", radius, _face, _walk, tint, _flash * 1.2 + bob, armor > 0.0, _kick)
	Art.draw_status(self, radius, _life_t, poison_t > 0.0, chill_t > 0.0, stun_t > 0.0, shards)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if hp < max_hp:
		var w := radius * 2.0 + 10.0
		draw_rect(Rect2(-w / 2.0, -radius - 12.0, w, 4.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2.0, -radius - 12.0, w * clampf(hp / max_hp, 0.0, 1.0), 4.0), Color(0.9, 0.3, 0.3))
