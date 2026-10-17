extends Node2D
## Sandbox monster. Stats and behaviour numbers come from monsters.csv; the
## `move` column picks a brain:
##   swarm        rats: pack chase, some circle round to bite from behind, scatter when a packmate dies
##   stalk_lunge  spiders: circle at range, glow, then dash in a straight line; sidestep aimed shots
##   plod         aliens and scrappers: steady advance; aliens armor/regen/stomp, scrappers carry a bullet plate
##   crawl_latch  ticks: fast, latch onto you and poison you until you dodge or knock them off
## Drawn by SbArt.gd.

const Art := preload("res://sandbox/SbArt.gd")
const Monsters := preload("res://sandbox/SbMonsters.gd")

const ACCEL := 900.0
const TOUCH_BUFFER := 6.0
const KNOCK_DECEL := 1500.0

var sb
var species := "rat"
var variant := "base"
var stats := {}
var mp := {}                     # behaviour params from monsters.csv
var move_kind := "swarm"
var hp := 1.0
var max_hp := 1.0
var radius := 12.0
var dead := false

var poison_t := 0.0
var poison_dps := 0.0
var chill_t := 0.0
var chill_speed := 1.0
var shrink_t := 0.0
var shrink_scale := 1.0           # target size while shrunk
var shrink_dmg_mult := 1.0        # damage multiplier while shrunk
var base_radius := 12.0
var _size := 1.0
var armor := 0.0
var plate_arc_deg := 0.0         # frontal bullet plate width, 0 = none
var shards := 0
var strike_times: Array = []
var stun_t := 0.0
var held_t := 0.0
var portal_cd := 0.0
var link = null
var latched := false
var emerge_t := 0.0                # rising out of the ground: cannot act yet
var emerge_total := 0.001
var telegraph := 0.0             # 0..1 wind-up progress, drawn as a warning

var _knock := Vector2.ZERO
var _regen := 0.0                    # cached from mp (dictionary lookups every frame are slow with hundreds of monsters)
var _sidestep := 0.0
var _dmg := 0.0
var _atk_cd := 1.0
var _pack_speed := 0.0
var _pack_bite := 0.0
var _base_speed := 100.0
var _desired := Vector2.ZERO       # last brain result, reused between brain updates in a crowd
var _brain_dt := 0.0
var _skip_dt := 0.0
var _heading := 0.0                # slow-turning monsters (Scrapper) move along this
var _lift := 0.0                   # visual height of a tick mid-hop
var _hop_total := 0.2
var _grow_t := 0.0               # maggots: time alive, they pupate into a fly if you leave them
var _flit_t := 0.0
var _flit_dir := Vector2.RIGHT
var _flit_mult := 1.0
var _web_acc := 0.0
var _vel := Vector2.ZERO
var _face := 0.0
var _walk := 0.0
var _life_t := 0.0
var _kick := Vector2.ZERO        # visual-only shove from the last hit
var _attack_t := 0.0
var _aim_offset := Vector2.ZERO
var _speed_var := 1.0
var _poison_acc := 0.0
var _poison_fx_t := 0.5
var _poison_drip_t := 0.0
var _flash := 0.0
var _state := "move"
var _state_t := 0.0
var _side := 1.0
var _dash_dir := Vector2.RIGHT
var _dash_hit := false
var _lunge_cd := 1.0
var _stomp_cd := 2.0
var _flanker := false
var _dive := false               # a flanker that has reached its ring commits to the bite
var _flank_t := 0.0
var _scatter_t := 0.0
var _scatter_from := Vector2.ZERO
var _sidestep_cd := 0.0
var _scan_t := 0.0
var _regen_idle := 0.0
var _regen_fx_t := 0.0
var _latch_angle := 0.0
var _latch_time := 0.0


func setup(p_sb, sp: String, p_variant: String, pos: Vector2) -> void:
	sb = p_sb
	species = sp
	variant = p_variant
	global_position = pos
	stats = Monsters.get_stats(sp, p_variant)
	mp = stats.get("p", {})
	move_kind = stats.get("move", "swarm")
	max_hp = stats.get("hp", 10.0) * sb.hp_mult()
	hp = max_hp
	radius = stats.get("hitbox_radius_px", 12.0)
	base_radius = radius
	armor = mp.get("armor", 0.0)
	plate_arc_deg = mp.get("plate_arc", 0.0)
	_attack_t = stats.get("attack_cooldown_sec", 1.0)
	_aim_offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, 90.0)
	_speed_var = randf_range(0.85, 1.15)
	_face = randf() * TAU
	_heading = _face
	_regen = mp.get("regen", 0.0)
	_sidestep = mp.get("sidestep_chance", 0.0)
	_dmg = stats.get("damage", 0.0)
	_atk_cd = stats.get("attack_cooldown_sec", 1.0)
	_pack_speed = mp.get("pack_speed", 0.0)
	_pack_bite = mp.get("pack_bite", 0.0)
	_base_speed = stats.get("chase_speed_px_s", 100.0)
	_walk = randf() * TAU
	_side = 1.0 if randf() < 0.5 else -1.0
	_flanker = randf() < mp.get("flank_chance", 0.0)
	_flank_t = randf_range(3.0, 4.5)   # then it gives up and just charges
	_lunge_cd = randf_range(0.8, 2.0)
	_stomp_cd = randf_range(1.5, 3.0)


func is_debuffed() -> bool:
	return poison_t > 0.0 or chill_t > 0.0 or shrink_t > 0.0


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps if poison_t > 0.0 else 0.0, dps)
	poison_t = maxf(poison_t, duration)


## Shrunk: smaller (so harder to hit) but takes extra damage. Bosses shrink only partway.
func apply_shrink(scale: float, duration: float, dmg_mult: float) -> void:
	shrink_scale = lerpf(scale, 1.0, 0.5) if variant == "boss" else scale
	shrink_dmg_mult = dmg_mult
	shrink_t = maxf(shrink_t, duration)


func apply_chill(speed_mult: float, duration: float) -> void:
	chill_speed = speed_mult
	chill_t = maxf(chill_t, duration)


func knock(impulse: Vector2) -> void:
	if latched:
		unlatch(0.6)
	_knock += impulse


## True if a bullet travelling along `dir` strikes this monster's front plate.
func blocks(dir: Vector2) -> bool:
	if plate_arc_deg <= 0.0 or dir == Vector2.ZERO:
		return false
	return Vector2.from_angle(_face).dot(-dir.normalized()) > cos(deg_to_rad(plate_arc_deg) * 0.5)


## Packmate died nearby: panic away from the spot for a moment.
func scare(from: Vector2, seconds: float) -> void:
	_scatter_t = seconds * randf_range(0.6, 1.2)
	_scatter_from = from


## `from_dir` is the direction the hit travelled (zero if unknown), used for sparks.
func take_damage(amount: float, color: Color = Color.WHITE, from_dir: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	if shrink_t > 0.0:
		amount *= shrink_dmg_mult
	hp -= amount
	_flash = 0.09
	_regen_idle = 0.0
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
	if latched:
		unlatch(0.0)
	sb.kills += 1
	sb.audio.play("kill")
	sb.vfx_kill(global_position, species, radius, variant == "boss", _kick)
	sb.rules.enemy_died(self)
	var scare_s: float = mp.get("scatter_time", 0.0)
	if scare_s > 0.0:
		for o in sb.enemies.get_children():
			if o != self and not o.dead and o.species == species and o.global_position.distance_to(global_position) <= mp.get("scatter_radius", 150.0):
				o.scare(global_position, scare_s)
	queue_free()


# ---------------------------------------------------------------- latching --

func latch(player) -> void:
	latched = true
	_latch_time = 0.0
	_latch_angle = (global_position - player.global_position).angle()
	player.latch_count += 1
	sb.audio.play("click")
	sb.fx_text(global_position + Vector2(0, -radius - 6), "LATCHED", Color(0.8, 0.4, 1.0))


## Drop off the player and stand dazed for `stun` seconds.
func unlatch(stun: float) -> void:
	if not latched:
		return
	latched = false
	sb.player.latch_count = maxi(0, sb.player.latch_count - 1)
	stun_t = maxf(stun_t, stun)
	_knock += Vector2.from_angle(_latch_angle) * 420.0
	_vel = Vector2.ZERO


# ------------------------------------------------------------------- update --

func _physics_process(delta: float) -> void:
	if dead:
		return
	# Huge rat crowds update every 2nd or 3rd frame (staggered), using the accumulated time.
	var crowd: int = sb.crowd_size
	if crowd > 150 and move_kind == "swarm" and not latched and emerge_t <= 0.0:
		var step := 2 if crowd < 280 else 3
		_skip_dt += delta
		if (Engine.get_physics_frames() + get_instance_id()) % step != 0:
			return
		delta = _skip_dt
		_skip_dt = 0.0
	else:
		_skip_dt = 0.0
	_life_t += delta
	_flash = maxf(0.0, _flash - delta)
	_kick = _kick.move_toward(Vector2.ZERO, 60.0 * delta)
	if poison_t > 0.0:
		poison_t -= delta
		var d := poison_dps * delta
		if shrink_t > 0.0:
			d *= shrink_dmg_mult
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
	if _regen > 0.0:
		_update_regen(delta)
	shrink_t = maxf(0.0, shrink_t - delta)
	_size = move_toward(_size, shrink_scale if shrink_t > 0.0 else 1.0, 2.5 * delta)
	radius = base_radius * _size * (1.0 - 0.6 * clampf(emerge_t / emerge_total, 0.0, 1.0))

	if emerge_t > 0.0:
		emerge_t -= delta
		_vel = Vector2.ZERO
		queue_redraw()
		return
	var player = sb.player
	stun_t = maxf(0.0, stun_t - delta)
	held_t = maxf(0.0, held_t - delta)

	if latched:
		if player.hp <= 0.0 or not sb.enemies_chase:
			unlatch(0.0)
		else:
			_latched_step(player, delta)
			queue_redraw()
			return

	if species == "maggot":
		_grow(delta)
		if dead:
			return
	var immobile := stun_t > 0.0 or held_t > 0.0 or _state == "pupate"
	var desired := Vector2.ZERO
	if sb.enemies_chase and player.hp > 0.0 and not immobile:
		if _sidestep > 0.0:
			_check_sidestep(player, delta)
		desired = _think(player, delta)
	if immobile:
		_vel = Vector2.ZERO
		telegraph = 0.0
	_vel = _vel.move_toward(desired, ACCEL * delta)
	global_position += (_vel + _knock) * delta
	_knock = _knock.move_toward(Vector2.ZERO, KNOCK_DECEL * delta)
	global_position = global_position.clamp(Vector2.ZERO, sb.ARENA)
	_keep_out_of_player(player)
	var slow_turner: bool = mp.get("turn_rate", 0.0) > 0.0
	if slow_turner:
		_face = _heading
		if _vel.length() > 1.0:
			_walk += _vel.length() * delta * (0.5 / maxf(radius, 6.0)) * 6.0
	elif _vel.length() > 1.0:
		_face = lerp_angle(_face, _vel.angle(), minf(1.0, 14.0 * delta))
		_walk += _vel.length() * delta * (0.5 / maxf(radius, 6.0)) * 6.0
	elif sb.enemies_chase and player.hp > 0.0 and move_kind != "swarm":
		_face = lerp_angle(_face, (player.global_position - global_position).angle(), minf(1.0, 6.0 * delta))

	if sb.enemies_chase and not immobile and player.hp > 0.0:
		_contact(player, delta)
	_redraw_lod()


func _update_regen(delta: float) -> void:
	var regen: float = mp.get("regen", 0.0)
	if regen <= 0.0 or hp >= max_hp:
		return
	_regen_idle += delta
	if _regen_idle >= mp.get("regen_delay", 2.0):
		hp = minf(max_hp, hp + regen * sb.hp_mult() * delta)
		_regen_fx_t -= delta
		if _regen_fx_t <= 0.0:
			_regen_fx_t = 0.35
			sb.particles.add(global_position + Vector2.from_angle(randf() * TAU) * radius * 0.7,
				Vector2(0, -26), 0.6, 2.8, Color(0.4, 1.0, 0.5, 0.9), "dot", 1.0)


func _speed() -> float:
	var s: float = _base_speed * _speed_var
	if _pack_speed > 0.0:
		s *= 1.0 + _pack_speed * sb.rat_pack()
	return s * chill_speed if chill_t > 0.0 else s


func _latched_step(player, delta: float) -> void:
	_latch_time += delta
	global_position = player.global_position + Vector2.from_angle(_latch_angle) * (player.RADIUS + radius * 0.35)
	_face = _latch_angle + PI
	_walk += delta * 6.0
	player.apply_dot(mp.get("latch_dps", 3.0) * delta)


## Ordinary biting: when touching the player and the attack is ready.
func _contact(player, delta: float) -> void:
	if _state == "windup" or _state == "dash" or _state == "stomp_windup":
		return
	var dmg := _dmg
	if dmg <= 0.0:
		return
	_attack_t -= delta
	var touch: float = radius + player.RADIUS + TOUCH_BUFFER
	if _attack_t <= 0.0 and global_position.distance_to(player.global_position) <= touch:
		player.take_damage(dmg)
		_attack_t = _atk_cd * (1.0 - _pack_bite * sb.rat_pack())
		_kick = (player.global_position - global_position).normalized() * 6.0


# -------------------------------------------------------------------- brains --

func _brain(player, delta: float) -> Vector2:
	match move_kind:
		"swarm":
			return _brain_swarm(player, delta)
		"stalk_lunge":
			return _brain_stalk(player, delta)
		"crawl_latch":
			return _brain_tick(player, delta)
		"wriggle":
			return _brain_wriggle(player, delta)
		"flit":
			return _brain_flit(player, delta)
	return _brain_plod(player, delta)


func _brain_swarm(player, delta: float) -> Vector2:
	var spd := _speed()
	if _scatter_t > 0.0:
		_scatter_t -= delta
		return (global_position - _scatter_from).normalized() * spd * 1.15
	var to_p: Vector2 = player.global_position - global_position
	var dist := to_p.length()
	var target: Vector2 = player.global_position
	if _flanker:
		# Orbit the player at a ring until round the back, then commit to the bite.
		_flank_t -= delta
		if _flank_t <= 0.0:
			_flanker = false
		elif not _dive:
			var ring: float = mp.get("flank_ring", 230.0)
			var behind: float = player.facing_angle() + PI
			var here: float = (global_position - player.global_position).angle()
			var off := wrapf(behind - here, -PI, PI)
			if dist < ring * 0.6 or absf(off) < 0.55:
				_dive = true
			else:
				var step := clampf(off, -0.9, 0.9)
				target = player.global_position + Vector2.from_angle(here + step) * ring
		# diving: head straight for the player
	elif dist >= 100.0:
		target += _aim_offset
	return (target - global_position).normalized() * spd


func _brain_stalk(player, delta: float) -> Vector2:
	var spd := _speed()
	var to_p: Vector2 = player.global_position - global_position
	var d := maxf(to_p.length(), 0.01)
	match _state:
		"move":
			_lunge_cd -= delta
			var tangent := to_p.orthogonal().normalized() * _side
			var err: float = d - mp.get("orbit", 250.0)
			var v := tangent * spd * 0.75 + to_p.normalized() * clampf(err / 90.0, -1.0, 1.0) * spd * 0.8
			if _lunge_cd <= 0.0 and d < mp.get("orbit", 250.0) * 1.8:
				_state = "windup"
				_state_t = mp.get("windup", 0.55)
				_dash_dir = (_lead_point(player) - global_position).normalized()
				sb.audio.play("alert")
			return v
		"windup":
			_state_t -= delta
			var total: float = mp.get("windup", 0.55)
			telegraph = 1.0 - clampf(_state_t / total, 0.0, 1.0)
			if _state_t > 0.12:
				_dash_dir = (_lead_point(player) - global_position).normalized()
			if _state_t <= 0.0:
				_state = "dash"
				_state_t = mp.get("dash_time", 0.32)
				_dash_hit = false
				sb.audio.play("whoosh", 2.0)
				_web_acc = 0.0
				_lay_web()
			return Vector2.ZERO
		"dash":
			_state_t -= delta
			var dv: Vector2 = _dash_dir * mp.get("dash_speed", 700.0) * (chill_speed if chill_t > 0.0 else 1.0)
			_vel = dv
			if mp.get("web", 0.0) > 0.0:
				_web_acc += dv.length() * delta
				if _web_acc >= mp.get("web_step", 70.0):
					_web_acc = 0.0
					_lay_web()
			if not _dash_hit and d <= radius + player.RADIUS + 6.0 and not player.is_invulnerable():
				_dash_hit = true
				player.take_damage(stats.get("damage", 8.0) * mp.get("dash_damage_mult", 1.5))
				_state_t = 0.0
			if _state_t <= 0.0:
				_state = "recover"
				_state_t = mp.get("recover", 0.7)
				telegraph = 0.0
			return dv
		"recover":
			_state_t -= delta
			if _state_t <= 0.0:
				_state = "move"
				_lunge_cd = randf_range(mp.get("cd_min", 1.4), mp.get("cd_max", 2.6))
				_side = 1.0 if randf() < 0.5 else -1.0
			return Vector2.ZERO
	return Vector2.ZERO


func _brain_tick(player, delta: float) -> Vector2:
	var spd := _speed()
	var to_p: Vector2 = player.global_position - global_position
	var d := to_p.length()
	if d <= radius + player.RADIUS + 4.0 and not player.is_invulnerable() and player.latch_count < int(mp.get("stack_max", 6.0)):
		_lift = 0.0
		latch(player)
		return Vector2.ZERO
	# Far away: a quick wiggling crawl. Inside lunge range: a short crouch, then a
	# fast pounce at the player (it leaps, it does not slow down), and a quick recover.
	if d > mp.get("lunge_range", 130.0) and _state == "move":
		_lift = 0.0
		var dir := to_p.normalized().rotated(sin(_life_t * 7.0 + _aim_offset.x) * mp.get("wiggle", 0.45))
		return dir * spd
	match _state:
		"move":
			_state = "crouch"
			_state_t = mp.get("crouch", 0.08)
		"crouch":
			_state_t -= delta
			if _state_t <= 0.0:
				_state = "hop"
				_dash_dir = (_lead_point(player) - global_position).normalized()
				_hop_total = clampf((d + 8.0) / mp.get("lunge_speed", 540.0), 0.12, 0.3)
				_state_t = _hop_total
		"hop":
			_state_t -= delta
			_lift = sin(PI * clampf(1.0 - _state_t / _hop_total, 0.0, 1.0)) * radius * 1.9
			if _state_t <= 0.0:
				_lift = 0.0
				_state = "land"
				_state_t = mp.get("recover", 0.16)
			return _lunge_velocity()
		"land":
			_state_t -= delta
			if _state_t <= 0.0:
				_state = "move"
	return Vector2.ZERO


## Maggots: a slow, sinuous crawl straight at the player. Weak alone, many together.
func _brain_wriggle(player, _delta: float) -> Vector2:
	var to_p: Vector2 = player.global_position - global_position
	var dir := to_p.normalized().rotated(sin(_life_t * 9.0 + _aim_offset.x) * mp.get("wiggle", 0.7))
	return dir * _speed()


func _brain_plod(player, delta: float) -> Vector2:
	var spd := _speed()
	var to_p: Vector2 = player.global_position - global_position
	var d := to_p.length()
	_stomp_cd -= delta
	if _state == "stomp_windup":
		_state_t -= delta
		telegraph = 1.0 - clampf(_state_t / mp.get("stomp_windup", 0.85), 0.0, 1.0)
		if _state_t <= 0.0:
			_slam(player)
			_state = "move"
			telegraph = 0.0
			_stomp_cd = mp.get("stomp_cooldown", 4.5)
		return Vector2.ZERO
	if mp.get("stomp_range", 0.0) > 0.0 and _stomp_cd <= 0.0 and d <= mp.get("stomp_range", 0.0):
		_state = "stomp_windup"
		_state_t = mp.get("stomp_windup", 0.85)
		sb.audio.play("alert")
		return Vector2.ZERO
	var target: Vector2 = player.global_position
	if d >= 100.0:
		target += _aim_offset
	var turn: float = mp.get("turn_rate", 0.0)
	if turn > 0.0:
		# Slow turners keep moving along their heading, so you can get round behind them.
		_heading = rotate_toward(_heading, (target - global_position).angle(), deg_to_rad(turn) * delta)
		return Vector2.from_angle(_heading) * spd
	return (target - global_position).normalized() * spd


func _slam(player) -> void:
	var r: float = mp.get("stomp_radius", 130.0)
	sb.fx_ring(global_position, r, Color(1.0, 0.4, 0.2))
	sb.audio.play("explosion", -2.0)
	sb.shake(0.16)
	sb.particles.burst(global_position, Vector2.RIGHT, 18, r * 2.2, PI, 0.45, 4.0, Color(0.55, 0.5, 0.45, 0.8), "dot", 4.0)
	if global_position.distance_to(player.global_position) <= r + player.RADIUS and not player.is_invulnerable():
		player.take_damage(mp.get("stomp_damage", 18.0))


## Spiders (and anything with sidestep_chance): hop out of the line of an aimed shot.
func _check_sidestep(player, delta: float) -> void:
	var chance: float = mp.get("sidestep_chance", 0.0)
	if chance <= 0.0:
		return
	_sidestep_cd -= delta
	_scan_t -= delta
	if _sidestep_cd > 0.0 or _scan_t > 0.0 or _state == "windup" or _state == "dash":
		return
	if global_position.distance_to(player.global_position) > 700.0:
		return
	_scan_t = 0.07
	for b in sb.bullets.get_children():
		if b.orbit or b.velocity == Vector2.ZERO:
			continue
		var rel: Vector2 = global_position - b.global_position
		if rel.length() > 190.0 or rel.length() < 20.0:
			continue
		var vdir: Vector2 = b.velocity.normalized()
		var along := rel.dot(vdir)
		if along <= 0.0:
			continue
		var lateral: Vector2 = rel - vdir * along
		if lateral.length() > radius + 12.0:
			continue
		if randf() < chance:
			var away := lateral.normalized() if lateral.length() > 1.0 else vdir.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
			var dist: float = mp.get("sidestep_dist", 70.0)
			_knock += away * sqrt(2.0 * KNOCK_DECEL * dist)
			_sidestep_cd = mp.get("sidestep_cd", 1.6)
			sb.audio.play("whoosh", -10.0)
			sb.particles.burst(global_position, away, 4, 140.0, 0.5, 0.25, 3.0, Color(1, 1, 1, 0.5), "line", 4.0)
		else:
			_sidestep_cd = 0.3
		return


# --------------------------------------------------------------------- draw --

func _draw() -> void:
	var low: bool = species == "rat" and sb.crowd_size > 90
	if low:
		draw_circle(Vector2(3.0, 5.0), radius * 1.1, Color(0, 0, 0, 0.26))
	else:
		draw_colored_polygon(Art.shadow(radius), Color(0, 0, 0, 0.28))

	# telegraphs: warn before the dangerous thing happens
	if telegraph > 0.0:
		if _state == "stomp_windup":
			var r: float = mp.get("stomp_radius", 130.0)
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.25, 0.1, 0.07 + 0.16 * telegraph))
			draw_circle(Vector2.ZERO, r * telegraph, Color(1.0, 0.3, 0.1, 0.22))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.4, 0.2, 0.85), 2.0)
		elif _state == "windup":
			draw_line(Vector2.ZERO, _dash_dir * (mp.get("dash_speed", 700.0) * mp.get("dash_time", 0.3)), Color(1.0, 0.25, 0.15, 0.25 + 0.4 * telegraph), 2.0)
			draw_arc(Vector2.ZERO, radius * (1.9 - 0.5 * telegraph), 0.0, TAU, 24, Color(1.0, 0.3, 0.15, 0.4 + 0.5 * telegraph), 2.5)

	var tint := Color(1, 1, 1)
	if poison_t > 0.0:
		tint *= Color(0.75, 1.0, 0.65)
	if chill_t > 0.0:
		tint *= Color(0.7, 0.85, 1.2)
	if telegraph > 0.0:
		tint *= Color(1.0 + 0.5 * telegraph, 1.0 - 0.2 * telegraph, 1.0 - 0.3 * telegraph)
	if _flash > 0.0:
		tint = Color(2.2, 2.2, 2.2)
	var squat := -0.12 * telegraph if _state == "windup" else 0.0
	var extra := 0.0
	if species == "tick":
		extra = clampf(_latch_time / 6.0, 0.0, 1.0)
	elif species == "scrapper":
		extra = deg_to_rad(plate_arc_deg)
	elif species == "rat":
		extra = sb.rat_pack()
	var bob := sin(_life_t * 9.0 + _walk) * 0.015 if _vel.length() > 5.0 else 0.0
	Art.draw_enemy(self, species, variant == "boss", radius, _face, _walk, tint, _flash * 1.2 + bob + squat, armor > 0.0, _kick + Vector2(0, -_lift), extra, low)
	if poison_t > 0.0 or chill_t > 0.0 or stun_t > 0.0 or shards > 0:
		draw_set_transform(Vector2(0, -_lift), 0.0, Vector2.ONE)
		Art.draw_status(self, radius, _life_t, poison_t > 0.0, chill_t > 0.0, stun_t > 0.0, shards)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _state == "pupate":
		var sh2 := Vector2(sin(_life_t * 40.0), cos(_life_t * 37.0)) * 1.2
		Art.draw_cocoon(self, radius, sh2)
	if hp < max_hp:
		var w := radius * 2.0 + 10.0
		draw_rect(Rect2(-w / 2.0, -radius - 12.0, w, 4.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2.0, -radius - 12.0, w * clampf(hp / max_hp, 0.0, 1.0), 4.0), Color(0.9, 0.3, 0.3))


## Monsters bite from the edge of the player, never from inside the centre.
func _keep_out_of_player(player) -> void:
	if latched or emerge_t > 0.0 or player.hp <= 0.0:
		return
	var off: Vector2 = global_position - player.global_position
	var min_d: float = radius + player.RADIUS
	if off.length() < min_d:
		var dir := off.normalized() if off.length() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
		global_position = player.global_position + dir * min_d


## Where the player will be when a dash started now would arrive: aim there, not
## at where they stand. A running player gets cut off; only a dodge (or turning
## after the aim locks) avoids it. `lead` in monsters.csv scales the prediction.
func _lead_point(player) -> Vector2:
	var lead: float = mp.get("lead", 0.0)
	if lead <= 0.0:
		return player.global_position
	var dash_speed: float = mp.get("dash_speed", 700.0)
	var t := global_position.distance_to(player.global_position) / dash_speed
	var future: Vector2 = player.global_position
	for i in 2:
		future = player.global_position + player.move_velocity * t * lead
		t = global_position.distance_to(future) / dash_speed
	return future.clamp(Vector2.ZERO, sb.ARENA)


## Level of detail: with a big crowd, redraw each monster every 2nd or 3rd frame
## (they are small and the animation still reads), staggered so it is not visible.
func _redraw_lod() -> void:
	var n: int = sb.crowd_size
	var every := 1 if n < 80 else (2 if n < 200 else 3)
	if every == 1 or (Engine.get_physics_frames() + get_instance_id()) % every == 0:
		queue_redraw()


## The brain, but in a big rat crowd it only thinks every 2nd or 3rd physics frame
## (staggered per monster) and the movement reuses its last answer. Other species
## always think every frame: their wind-ups need exact timing.
func _think(player, delta: float) -> Vector2:
	if move_kind != "swarm":
		return _brain(player, delta)
	_brain_dt += delta
	var n: int = sb.crowd_size
	var every := 1 if n < 100 else (2 if n < 250 else 3)
	if every == 1 or (Engine.get_physics_frames() + get_instance_id()) % every == 0:
		_desired = _brain(player, _brain_dt)
		_brain_dt = 0.0
	return _desired


## Matriarch: leave a web where it is (at launch and along the dash).
func _lay_web() -> void:
	if mp.get("web", 0.0) > 0.0:
		sb.webs.add(global_position, mp.get("web_radius", 26.0), mp.get("web_hold", 1.0), mp.get("web_life", 12.0))


## A tick's pounce is instant (it bypasses the usual acceleration limit), so it
## really does leap rather than speed up gradually.
func _lunge_velocity() -> Vector2:
	_vel = _dash_dir * mp.get("lunge_speed", 540.0) * (chill_speed if chill_t > 0.0 else 1.0)
	return _vel


## Flies: fast and erratic. Every fraction of a second they pick a new dart
## (aimed roughly at you, with a wild angle and speed), so they are hard to hit.
func _brain_flit(player, delta: float) -> Vector2:
	_flit_t -= delta
	if _flit_t <= 0.0:
		_flit_t = randf_range(mp.get("dart_min", 0.18), mp.get("dart_max", 0.45))
		var to_p: Vector2 = player.global_position - global_position
		_flit_dir = to_p.normalized().rotated(randf_range(-1.3, 1.3))
		_flit_mult = randf_range(0.45, 1.7)
	_vel = _flit_dir * _speed() * _flit_mult      # darts change direction instantly
	return _vel


## Maggots left alive too long stop, wrap in a cocoon for a moment, then hatch
## into a Fly. The maggot does not count as a kill.
func _grow(delta: float) -> void:
	var total: float = mp.get("grow_time", 0.0)
	if total <= 0.0 or not sb.enemies_chase:
		return
	_grow_t += delta
	var pupate: float = mp.get("pupate", 1.4)
	if _grow_t >= total:
		var at := global_position
		dead = true
		sb.particles.burst(at, Vector2.RIGHT, 14, 220.0, PI, 0.5, 3.0, Color(0.9, 0.9, 0.55, 0.9), "dot", 4.0)
		sb.fx_ring(at, 26.0, Color(0.7, 0.9, 0.4))
		sb.audio.play("hatch")
		sb.spawn_one("fly", "base", at, 0.25)
		queue_free()
	elif _grow_t >= total - pupate and _state != "pupate":
		_state = "pupate"
		_vel = Vector2.ZERO
