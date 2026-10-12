extends Node2D
## Sandbox player: the V2 pistol (fixed stats) plus whichever of the first ten
## upgrades the sandbox has stacked. WASD move, mouse aim, hold left click to
## fire. All the "effective stat" maths lives here so the UI can show it.

const Up := preload("res://sandbox/SbUpgrades.gd")
const Visual := preload("res://scenes/EntityVisual.gd")

const MOVE_SPEED := 210.0
const MAX_HP := 100.0
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
var hp := MAX_HP
var ammo := MAGAZINE
var reloading := false
var charging := false
var cooldown := 0.0
var _reload_t := 0.0
var _charge_t := 0.0
var _charge_total := 0.0
var _dead_t := 0.0
var _body: Node2D
var aim_override = null


func _ready() -> void:
	_body = Visual.new()
	add_child(_body)
	_body.configure(RADIUS, Color(0.45, 0.72, 1.0), Color(0.1, 0.1, 0.08), "triangle")


# ----------------------------------------------------------- effective stats --

func n(id: String) -> int:
	return sb.stack(id)


func fire_rate() -> float:
	return FIRE_RATE * pow(Up.p("quickdraw", "rate_mult"), n("quickdraw"))


## 0 with no Grow. Grow supplies the base charge time, then multiplies by 1.25 per stack.
func charge_time() -> float:
	var g := n("grow")
	if g == 0:
		return 0.0
	return sb.grow_charge_base * pow(Up.p("grow", "charge_mult"), g)


func size_mult() -> float:
	return pow(Up.p("grow", "size_mult"), n("grow"))


## Damage before Exploit (which depends on the target).
func bullet_damage() -> float:
	var d := BASE_DAMAGE * pow(Up.p("grow", "damage_mult"), n("grow"))
	if n("poison") > 0:
		d *= Up.p("poison", "direct_mult")
	return d


func max_enemy_hits() -> int:
	var k := n("pierce")
	if k == 0:
		return 1
	return 1 + int(Up.p("pierce", "pass") + Up.p("pierce", "pass_add") * (k - 1))


func extra_bullets() -> int:
	var b := n("bloodshot")
	if b == 0:
		return 0
	var hp_per := Up.p("bloodshot", "hp_per") / pow(Up.p("bloodshot", "stack_div"), b - 1)
	return int(floorf(hp / hp_per))


func bullets_per_pull() -> int:
	var mult := pow(Up.p("spread", "bullet_mult"), n("spread"))
	return mini(int((1 + extra_bullets()) * mult), MAX_BULLETS_PER_PULL)


## Every Nth bullet fired refunds a round; 0 means Reclaimer is not held.
func reclaim_every() -> int:
	var r := n("reclaimer")
	if r == 0:
		return 0
	var e := ceilf(Up.p("reclaimer", "every") / pow(Up.p("reclaimer", "stack_div"), r - 1))
	return maxi(int(e), int(Up.p("reclaimer", "min")))


# -------------------------------------------------------------------- update --

func _physics_process(delta: float) -> void:
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


func _pull() -> void:
	cooldown = 1.0 / fire_rate()
	var ct := charge_time()
	if ct > 0.0:
		charging = true
		_charge_t = ct
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
	var count := bullets_per_pull()
	var aim := aim_pos() - global_position
	var base_dir := (aim.normalized() if aim.length() > 1.0 else Vector2.RIGHT)
	base_dir = base_dir.rotated(deg_to_rad(randf_range(-AIM_SPREAD_DEG, AIM_SPREAD_DEG)))
	var spacing := 0.0
	if count > 1:
		spacing = minf(Up.p("spread", "fan_deg"), MAX_FAN_DEG / (count - 1))
	var props := {
		"damage": bullet_damage(), "size": size_mult(), "speed": BULLET_SPEED,
		"hits": max_enemy_hits(), "falloff": Up.p("pierce", "falloff"),
	}
	var every := reclaim_every()
	for i in count:
		var ang := (i - (count - 1) * 0.5) * deg_to_rad(spacing)
		sb.spawn_bullet(global_position + base_dir * 18.0, base_dir.rotated(ang), props)
		sb.fired += 1
		if every > 0 and sb.fired % every == 0 and ammo < MAGAZINE:
			ammo += 1
			sb.fx_text(global_position + Vector2(0, -22), "+1 ammo", Color(0.5, 1.0, 0.6))
	if ammo <= 0:
		start_reload()


func take_damage(amount: float) -> void:
	if sb.god_mode or hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	sb.fx_text(global_position + Vector2(0, -26), "-%d" % int(amount), Color(1.0, 0.4, 0.4))
	if hp <= 0.0:
		_dead_t = 1.5


func revive() -> void:
	hp = MAX_HP
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
	draw_rect(Rect2(-w / 2.0, RADIUS + 8.0, w * hp / MAX_HP, 5.0), Color(0.4, 0.9, 0.4))


## Where the player is aiming (the mouse; tests can set aim_override).
func aim_pos() -> Vector2:
	return aim_override if aim_override != null else get_global_mouse_position()
