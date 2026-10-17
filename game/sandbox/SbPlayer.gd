extends Node2D
## Sandbox player: the V2 pistol (fixed stats) plus whichever upgrades the
## sandbox has stacked. WASD move, mouse aim, hold left click to fire.
## Holds the firing pipeline (spec 4.1) and the "effective stat" maths so the
## UI can show it. Trigger/hit effects live in SbRules.gd.

const Up := preload("res://sandbox/SbUpgrades.gd")
const Art := preload("res://sandbox/SbArt.gd")

const MOVE_SPEED := 210.0
const BASE_MAX_HP := 100.0
const RADIUS := 14.0
# Pistol baseline (same numbers as weapons.csv).
const FIRE_RATE := 3.5
const MAGAZINE := 12
const RELOAD_SEC := 1.0
const BULLET_SPEED := 475.0
const AIM_SPREAD_DEG := 2.0
const BASE_DAMAGE := 10.0
# Safety valve from spec 4.3.
const MAX_BULLETS_PER_PULL := 256
const MAX_FAN_DEG := 150.0
# Dodge: a short dash with a brief invulnerable window (shakes off latched ticks).
const DODGE_COOLDOWN := 1.5
const DASH_TIME := 0.18
const DASH_SPEED := 900.0
const INVULN_TIME := 0.25

var sb
var max_hp := BASE_MAX_HP
var hp := BASE_MAX_HP
var ammo := MAGAZINE
var reloading := false
var charging := false
var cooldown := 0.0
var heat := 0
var aim_override = null      # tests can force the aim point
var damage_taken := 0.0
var latch_count := 0          # ticks currently attached to you
var move_velocity := Vector2.ZERO   # how fast and which way you are moving (monsters lead their shots with it)
var _prev_pos := Vector2.ZERO
var dodge_cd := 0.0
var _dash_t := 0.0
var _dash_dir := Vector2.RIGHT
var _invuln_t := 0.0
var _space_prev := false
var _dot_acc := 0.0
var _dot_fx_t := 0.5
var _reload_t := 0.0
var _charge_t := 0.0
var _charge_total := 0.0
var _dead_t := 0.0
var _aim_angle := 0.0
var _flash_t := 0.0
var _recoil := 0.0
var _t := 0.0


# ----------------------------------------------------------- effective stats --

func n(id: String) -> int:
	return sb.stack(id)


func aim_pos() -> Vector2:
	return aim_override if aim_override != null else get_global_mouse_position()


func fire_rate() -> float:
	return FIRE_RATE * pow(Up.p("quickdraw", "rate_mult"), n("quickdraw"))


## 0 with no Grow. Grow supplies the base charge time, then multiplies by 1.25 per stack.
func charge_time() -> float:
	var g := n("grow")
	if g == 0:
		return 0.0
	return sb.grow_charge_base * pow(Up.p("grow", "charge_mult"), g)


func extra_bullets() -> int:
	var b := n("bloodshot")
	if b == 0:
		return 0
	var hp_per := Up.p("bloodshot", "hp_per") / pow(Up.p("bloodshot", "stack_div"), b - 1)
	return int(floorf(hp / hp_per))


func heat_needed() -> int:
	var k := n("heat_coil")
	if k == 0:
		return 0
	return maxi(int(ceilf(Up.p("heat_coil", "pulls") / pow(Up.p("heat_coil", "stack_div"), k - 1))), int(Up.p("heat_coil", "min")))


## Everything about one bullet that depends on the stacks `st` it carries.
func make_props(st: Dictionary, gen: int) -> Dictionary:
	var g: int = st.get("grow", 0)
	var d := BASE_DAMAGE * pow(Up.p("grow", "damage_mult"), g)
	var s: int = st.get("soul_snatcher", 0)
	if s > 0:
		d *= 1.0 + Up.p("soul_snatcher", "pick_bonus") * s \
			+ sb.kills * Up.p("soul_snatcher", "per_kill") * pow(Up.p("soul_snatcher", "stack"), s - 1)
	if st.get("poison", 0) > 0:
		d *= Up.p("poison", "direct_mult")
	var hits := 1
	var pk: int = st.get("pierce", 0)
	if pk > 0:
		hits = 1 + int(Up.p("pierce", "pass") + Up.p("pierce", "pass_add") * (pk - 1))
	var speed := BULLET_SPEED * pow(Up.p("velocity", "speed_mult"), st.get("velocity", 0))
	for id in st:   # any upgrade can slow bullets with a bullet_speed param (e.g. 0.85 = 15% slower per stack)
		var slow := Up.p(id, "bullet_speed")
		if slow > 0.0:
			speed *= pow(slow, st[id])
	return {
		"damage": d, "size": pow(sb.grow_size_mult, g), "speed": speed,
		"hits": hits, "falloff": Up.p("pierce", "falloff"), "st": st, "gen": gen,
	}


func pull_props() -> Dictionary:
	return make_props(sb.bullet_stacks(0), 0)


func bullets_per_pull() -> int:
	return _count(sb.bullet_stacks(0), extra_bullets())


func _count(st: Dictionary, extra: int) -> int:
	var mult := pow(Up.p("spread", "bullet_mult"), st.get("spread", 0))
	return mini(int((1 + extra) * mult), MAX_BULLETS_PER_PULL)


# -------------------------------------------------------------------- update --

func _physics_process(delta: float) -> void:
	move_velocity = (global_position - _prev_pos) / maxf(delta, 0.0001)
	_prev_pos = global_position
	_t += delta
	_flash_t = maxf(0.0, _flash_t - delta)
	_recoil = move_toward(_recoil, 0.0, 60.0 * delta)
	_invuln_t = maxf(0.0, _invuln_t - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	_update_max_hp()
	if hp <= 0.0:
		_dead_t -= delta
		if sb.revive_on_death and _dead_t <= 0.0:
			revive()

		queue_redraw()
		return

	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): v.x += 1.0
	var space := Input.is_physical_key_pressed(KEY_SPACE)
	if space and not _space_prev and dodge_cd <= 0.0:
		_start_dodge(v)
	_space_prev = space
	if _dash_t > 0.0:
		_dash_t -= delta
		global_position += _dash_dir * DASH_SPEED * delta
		sb.particles.add(global_position, Vector2.ZERO, 0.3, RADIUS * 0.9, Color(0.4, 0.6, 1.0, 0.35), "dot", 0.0)
	else:
		global_position += v.normalized() * MOVE_SPEED * sb.move_speed_mult * delta
	global_position = global_position.clamp(Vector2(RADIUS, RADIUS), sb.ARENA - Vector2(RADIUS, RADIUS))

	var aim := aim_pos()
	if aim.distance_to(global_position) > 1.0:
		_aim_angle = (aim - global_position).angle()

	cooldown = maxf(0.0, cooldown - delta)
	if reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			reloading = false
			ammo = MAGAZINE
			sb.audio.play("click")
	elif charging:
		_charge_t -= delta
		if _charge_t <= 0.0:
			charging = false
			_fire()
			if not sb.charge_overlaps:
				cooldown = 1.0 / fire_rate()
	elif cooldown <= 0.0 and sb.fire_held():
		if ammo <= 0:
			start_reload()
		else:
			_pull()
	queue_redraw()


## Reaper: max HP grows with kills; current HP rises by the same amount.
func _update_max_hp() -> void:
	var r := n("reaper")
	var target := BASE_MAX_HP
	if r > 0:
		var per_kill := Up.p("reaper", "per_kill") * pow(Up.p("reaper", "stack"), r - 1)
		target = (BASE_MAX_HP + Up.p("reaper", "pick_hp") * r) * (1.0 + minf(Up.p("reaper", "cap"), sb.kills * per_kill))
	if target > max_hp:
		hp += target - max_hp
	max_hp = target
	hp = minf(hp, max_hp)


func _pull() -> void:
	cooldown = 1.0 / fire_rate()
	var ct := charge_time()
	if ct > 0.0:
		charging = true
		_charge_t = ct
		sb.audio.play("charge")
		_charge_total = ct
	else:
		_fire()


func start_reload() -> void:
	if reloading or ammo >= MAGAZINE:
		return
	reloading = true
	charging = false
	_reload_t = RELOAD_SEC


func _fire() -> void:
	ammo -= 1  # one round per pull, however many bullets
	if sb.infinite_ammo:
		ammo = MAGAZINE
	var aim := aim_pos() - global_position
	var dir := (aim.normalized() if aim.length() > 1.0 else Vector2.RIGHT)
	dir = dir.rotated(deg_to_rad(randf_range(-AIM_SPREAD_DEG, AIM_SPREAD_DEG)))
	var need := heat_needed()
	if need > 0:
		heat += 1
		if heat >= need:
			heat = 0
			_fire_beam(dir)
			if ammo <= 0:
				start_reload()
			return
	sb.audio.play("shot")
	fire_pipeline(global_position + dir * 18.0, dir, 0, extra_bullets())
	_muzzle(dir)
	if ammo <= 0:
		start_reload()


## The firing pipeline: bullet count, fan, per-bullet stats. gen 0 is a normal
## pull; gen > 0 is a Split/Echo bullet, whose upgrades are chance-tested.
func fire_pipeline(origin: Vector2, dir: Vector2, gen: int, extra: int = 0, victims: Dictionary = {}) -> void:
	var st: Dictionary = sb.bullet_stacks(gen)
	var count := _count(st, extra)
	var spacing := 0.0
	if count > 1:
		spacing = minf(Up.p("spread", "fan_deg"), MAX_FAN_DEG / (count - 1))
	var props := make_props(st, gen)
	props["victims"] = victims
	for i in count:
		var ang := (i - (count - 1) * 0.5) * deg_to_rad(spacing)
		var orbit: bool = sb.rules.on_fired(props)
		sb.spawn_bullet(origin, dir.rotated(ang), props, orbit)


## Heat Coil: one huge piercing beam instead of bullets.
func _fire_beam(dir: Vector2) -> void:
	var st: Dictionary = sb.bullet_stacks(0)
	var props := make_props(st, 0)
	sb.audio.play("beam")
	sb.shake(0.12)
	sb.rules.on_fired(props)
	var dmg: float = props["damage"] * Up.p("heat_coil", "beam_mult")
	var from := global_position
	var to := from + dir * 3000.0
	sb.fx_beam(from, to, Up.p("heat_coil", "beam_width"))
	for e in sb.enemies.get_children():
		if e.dead:
			continue
		var q := Geometry2D.get_closest_point_to_segment(e.global_position, from, to)
		if q.distance_to(e.global_position) <= e.radius + Up.p("heat_coil", "beam_width"):
			sb.rules.deal_hit(e, dmg, {"st": st, "gen": sb.GEN_HARD_LIMIT, "base": dmg, "pos": e.global_position})


func take_damage(amount: float) -> void:
	if _invuln_t > 0.0:
		return
	if sb.god_mode or hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	damage_taken += amount
	sb.audio.play("hurt")
	sb.shake(clampf(amount / 60.0, 0.03, 0.2))
	sb.screen_flash(Color(1.0, 0.1, 0.1), clampf(amount / 50.0 * 0.3, 0.06, 0.3))
	sb.fx_text(global_position + Vector2(0, -26), "-%d" % int(amount), Color(1.0, 0.4, 0.4))
	if hp <= 0.0:
		_dead_t = 1.5
		sb.waves.player_down()


func revive() -> void:
	for e in sb.enemies.get_children():
		if e.latched:
			e.unlatch(0.0)
	latch_count = 0
	hp = max_hp
	ammo = MAGAZINE
	reloading = false
	charging = false


func _draw() -> void:
	var sh := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		sh.append(Vector2(cos(a) * RADIUS * 1.4 + 3.0, sin(a) * RADIUS * 1.1 + 5.0))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.3))
	if hp > 0.0:
		Art.draw_player(self, RADIUS, _aim_angle, _flash_t, _recoil, _t)
	if hp <= 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -24), "DOWN - reviving",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.5, 0.5))
		return
	if charging:
		var k := 1.0 - _charge_t / _charge_total
		draw_arc(Vector2.ZERO, RADIUS + 8.0, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(1.0, 0.85, 0.3), 3.0)
	elif reloading:
		var k := 1.0 - _reload_t / RELOAD_SEC
		draw_arc(Vector2.ZERO, RADIUS + 8.0, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(0.7, 0.7, 0.7), 3.0)
	if latch_count > 0:
		for i in 4:
			var k := fmod(_t * 0.9 + i * 0.25, 1.0)
			draw_circle(Vector2(sin(i * 2.3 + _t * 2.0) * RADIUS * 0.8, RADIUS * 0.6 - k * RADIUS * 1.8), 3.0 * (1.0 - k) + 1.0, Color(0.7, 0.35, 1.0, 0.85 * (1.0 - k)))
		draw_string(ThemeDB.fallback_font, Vector2(-34, -RADIUS - 18), "POISONED x%d" % latch_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.5, 1.0))
	if dodge_cd > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 12.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - dodge_cd / DODGE_COOLDOWN), 24, Color(0.5, 0.7, 1.0, 0.35), 2.0)
	var w := 44.0
	draw_rect(Rect2(-w / 2.0, RADIUS + 8.0, w, 5.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2.0, RADIUS + 8.0, w * hp / max_hp, 5.0), Color(0.4, 0.9, 0.4))


## Visual-only kick when a pull fires: muzzle flash, recoil, a spent casing.
func _muzzle(dir: Vector2) -> void:
	_flash_t = 0.06
	_recoil = 4.0
	if sb.juice_on:
		sb.particles.add(global_position + dir.rotated(1.4) * 10.0, dir.rotated(1.5 + randf_range(-0.4, 0.4)) * randf_range(90.0, 160.0),
			0.5, 2.2, Color(0.95, 0.78, 0.3), "dot", 3.0)


func facing_angle() -> float:
	return _aim_angle


func is_invulnerable() -> bool:
	return _invuln_t > 0.0


## Dash toward the way you are moving (or where you aim if standing still).
## Grants a short invulnerable window and shakes every tick off you.
func _start_dodge(move_dir: Vector2) -> void:
	_dash_dir = move_dir.normalized() if move_dir != Vector2.ZERO else Vector2.from_angle(_aim_angle)
	_dash_t = DASH_TIME
	_invuln_t = INVULN_TIME
	dodge_cd = DODGE_COOLDOWN
	charging = false
	sb.audio.play("whoosh")
	for e in sb.enemies.get_children():
		if e.latched:
			e.unlatch(e.mp.get("shake_stun", 1.0))
			sb.fx_text(e.global_position + Vector2(0, -16), "SHAKEN OFF", Color(1.0, 1.0, 0.5))


## Damage over time (latched ticks). Quiet: floating numbers every half second.
func apply_dot(amount: float) -> void:
	if sb.god_mode or hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	damage_taken += amount
	_dot_acc += amount
	_dot_fx_t -= get_physics_process_delta_time()
	if _dot_fx_t <= 0.0:
		sb.fx_text(global_position + Vector2(randf_range(-8, 8), -26), "-%.1f" % _dot_acc, Color(0.75, 0.4, 1.0))
		_dot_acc = 0.0
		_dot_fx_t = 0.5
	if hp <= 0.0:
		_dead_t = 1.5
		sb.waves.player_down()
