extends Node2D
## Sandbox player: the V2 pistol (fixed stats) plus whichever upgrades the
## sandbox has stacked. WASD move, mouse aim, hold left click to fire.
## Holds the firing pipeline (spec 4.1) and the "effective stat" maths so the
## UI can show it. Trigger/hit effects live in SbRules.gd.

const Up := preload("res://sandbox/SbUpgrades.gd")
const Visual := preload("res://scenes/EntityVisual.gd")

const MOVE_SPEED := 210.0
const BASE_MAX_HP := 100.0
const RADIUS := 14.0
# Pistol baseline (same numbers as weapons.csv).
const FIRE_RATE := 3.5
const MAGAZINE := 12
const RELOAD_SEC := 1.0
const BULLET_SPEED := 950.0
const AIM_SPREAD_DEG := 2.0
const BASE_DAMAGE := 10.0
# Safety valve from spec 4.3.
const MAX_BULLETS_PER_PULL := 256
const MAX_FAN_DEG := 150.0

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
var _reload_t := 0.0
var _charge_t := 0.0
var _charge_total := 0.0
var _dead_t := 0.0
var _body: Node2D


func _ready() -> void:
	_body = Visual.new()
	add_child(_body)
	_body.configure(RADIUS, Color(0.45, 0.72, 1.0), Color(0.1, 0.1, 0.08), "triangle")


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
	return {
		"damage": d, "size": pow(Up.p("grow", "size_mult"), g), "speed": BULLET_SPEED,
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
	_update_max_hp()
	if hp <= 0.0:
		_dead_t -= delta
		if _dead_t <= 0.0:
			revive()
		queue_redraw()
		return

	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): v.x += 1.0
	global_position += v.normalized() * MOVE_SPEED * delta
	global_position = global_position.clamp(Vector2(RADIUS, RADIUS), sb.ARENA - Vector2(RADIUS, RADIUS))

	var aim := aim_pos()
	if aim.distance_to(global_position) > 1.0:
		_body.rotation = (aim - global_position).angle()

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
	if sb.god_mode or hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	damage_taken += amount
	sb.audio.play("hurt")
	sb.fx_text(global_position + Vector2(0, -26), "-%d" % int(amount), Color(1.0, 0.4, 0.4))
	if hp <= 0.0:
		_dead_t = 1.5
		sb.waves.player_down()


func revive() -> void:
	hp = max_hp
	ammo = MAGAZINE
	reloading = false
	charging = false


func _draw() -> void:
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
	var w := 44.0
	draw_rect(Rect2(-w / 2.0, RADIUS + 8.0, w, 5.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2.0, RADIUS + 8.0, w * hp / max_hp, 5.0), Color(0.4, 0.9, 0.4))
