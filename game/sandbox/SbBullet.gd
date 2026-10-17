extends Node2D
## One bullet. Collision is a manual segment-vs-circle test against the
## Sandbox's enemies (no Area2D), so fast bullets can't tunnel. Handles the
## bullet-shape upgrades itself: Pierce, Zigzag, Ricochet, Orbit Shard,
## Still Field holds, Fault Line crack recording and Twin Gate walls.

const Up := preload("res://sandbox/SbUpgrades.gd")
const CRACK_STEP := 25.0

var sb
var velocity := Vector2.ZERO
var damage := 10.0
var radius := 3.0
var hits_left := 1
var falloff := 0.2
var st := {}                 # this bullet's (possibly chance-tested) upgrade stacks
var gen := 0                 # 0 = fired by the gun, +1 per Split/Echo generation
var orbit := false

var max_cross := 1
var bounces_left := 0
var zig := false

var _len := 14.0
var victims := {}             # enemy ids this bullet or its ancestors already hit
var _age := 0.0
var _contact := {}
var _cross := {}
var _base := Vector2.ZERO    # zigzag: the un-weaved path
var _dist := 0.0
var _orbit_t := 0.0
var _orbit_angle := 0.0
var _orbit_cd := {}
var _crack: PackedVector2Array = PackedVector2Array()
var _crack_acc := 0.0
var _home_target = null
var _home_scan := 0.0
var _homing := 0


func setup(p_sb, pos: Vector2, dir: Vector2, props: Dictionary, p_orbit: bool) -> void:
	sb = p_sb
	global_position = pos
	_base = pos
	velocity = dir * props["speed"]
	damage = props["damage"]
	radius = 3.0 * props["size"]
	_len = 14.0 * props["size"]
	hits_left = props["hits"]
	falloff = props["falloff"]
	st = props["st"]
	victims = props.get("victims", {}).duplicate()
	gen = props["gen"]
	zig = st.get("zigzag", 0) > 0
	_homing = st.get("homing", 0)
	if zig:
		max_cross = int(Up.p("zigzag", "crossings") * pow(Up.p("zigzag", "stack"), st["zigzag"] - 1))
	var rk: int = st.get("ricochet", 0)
	if rk > 0:
		bounces_left = int(Up.p("ricochet", "bounces") * pow(Up.p("ricochet", "stack"), rk - 1))
	orbit = p_orbit
	if orbit:
		_orbit_t = Up.p("orbit_shard", "life")
		_orbit_angle = (pos - sb.player.global_position).angle()
	rotation = dir.angle()
	_crack.append(pos)


func _exit_tree() -> void:
	if orbit and is_instance_valid(sb):
		sb.orbit_count -= 1
	if _crack.size() >= 2 and is_instance_valid(sb) and st.get("fault_line", 0) > 0 and sb.is_inside_tree():
		sb.rules.add_crack(_crack, damage, st["fault_line"])


func _physics_process(delta: float) -> void:
	if orbit:
		_orbit_step(delta)
		return
	_age += delta
	if _age >= sb.BULLET_LIFETIME:
		queue_free()
		return
	modulate.a = clampf(sb.BULLET_LIFETIME - _age, 0.0, 1.0)

	if _homing > 0:
		_steer_home(delta)
	var from := global_position
	var to: Vector2
	if zig:
		var dir := velocity.normalized()
		_base += velocity * delta
		_dist += velocity.length() * delta
		var wave := sin(_dist / Up.p("zigzag", "wavelength") * TAU) * Up.p("zigzag", "amp")
		to = _base + dir.orthogonal() * wave
	else:
		to = from + velocity * delta
	global_position = to
	rotation = (to - from).angle() if to != from else rotation

	_crack_acc += from.distance_to(to)
	if _crack_acc >= CRACK_STEP and _crack.size() < 90:
		_crack_acc = 0.0
		_crack.append(to)

	var now := {}
	for e in sb.enemies_near(from, to, radius + 45.0):
		if e.dead:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(e.global_position, from, to)
		if closest.distance_to(e.global_position) > e.radius + radius:
			continue
		var id: int = e.get_instance_id()
		now[id] = true
		if _contact.has(id):
			continue
		var c: int = _cross.get(id, 0)
		if c == 0 and victims.has(id):
			continue   # already hit by this bullet or an ancestor: no ping-pong
		if c >= max_cross:
			continue
		_cross[id] = c + 1
		victims[id] = true
		sb.rules.bullet_hit(self, e, c == 0)
		if is_queued_for_deletion():
			return
	_contact = now

	if not Rect2(Vector2.ZERO, sb.ARENA).has_point(to):
		_hit_wall(to)


func _hit_wall(p: Vector2) -> void:
	var normal := Vector2.ZERO
	if p.x < 0.0: normal = Vector2.RIGHT
	elif p.x > sb.ARENA.x: normal = Vector2.LEFT
	elif p.y < 0.0: normal = Vector2.DOWN
	else: normal = Vector2.UP
	var clamped := p.clamp(Vector2.ZERO, sb.ARENA)
	if sb.rules.wall_portal(self, clamped, normal):
		return
	if bounces_left > 0:
		_bounce(normal)
		global_position = clamped
		_base = clamped
		return
	if sb.rules.wall_make_portal(self, clamped, normal):
		queue_free()
		return
	queue_free()


## Reflect off a surface normal: costs a bounce and 15% damage.
func _bounce(normal: Vector2) -> void:
	velocity = velocity.bounce(normal)
	bounces_left -= 1
	damage *= 1.0 - Up.p("ricochet", "loss")
	rotation = velocity.angle()
	_base = global_position
	_contact.clear()


## Called by the rules once a hit used up the last enemy this bullet may pass.
## Returns true if a Ricochet bounce kept the bullet alive.
func try_ricochet_off(e) -> bool:
	if bounces_left <= 0:
		return false
	var n: Vector2 = (global_position - e.global_position).normalized()
	if n == Vector2.ZERO:
		n = -velocity.normalized()
	_bounce(n)
	hits_left = 1
	_cross[e.get_instance_id()] = max_cross
	return true


func _orbit_step(delta: float) -> void:
	_orbit_t -= delta
	if _orbit_t <= 0.0:
		queue_free()
		return
	_orbit_angle += Up.p("orbit_shard", "spin") * delta
	global_position = sb.player.global_position + Vector2.RIGHT.rotated(_orbit_angle) * Up.p("orbit_shard", "radius")
	rotation = _orbit_angle + PI / 2.0
	var now := Time.get_ticks_msec() / 1000.0
	for e in sb.enemies.get_children():
		if e.dead:
			continue
		if global_position.distance_to(e.global_position) > e.radius + radius + 4.0:
			continue
		var id: int = e.get_instance_id()
		if _orbit_cd.get(id, 0.0) > now:
			continue
		_orbit_cd[id] = now + 0.4
		sb.rules.deal_hit(e, damage, {"st": st, "gen": sb.GEN_HARD_LIMIT, "base": damage, "pos": global_position, "orbit": true})


func _draw() -> void:
	var half := _len / 2.0
	var tail_c := Color(1.0, 0.85, 0.4, 0.28)
	if gen > 0:
		tail_c = Color(0.5, 0.85, 1.0, 0.28)
	if not orbit:
		draw_line(Vector2(-half, 0), Vector2(-half - 34.0, 0), tail_c, radius * 1.4)
		draw_line(Vector2(-half, 0), Vector2(-half - 16.0, 0), Color(tail_c.r, tail_c.g, tail_c.b, 0.5), radius * 1.8)
	var c := Color(1.0, 0.92, 0.45)
	if gen > 0:
		c = Color(0.55, 0.9, 1.0)
	if orbit:
		c = Color(1.0, 0.6, 0.25)
	draw_line(Vector2(-half, 0), Vector2(half, 0), c, radius * 2.0)
	draw_circle(Vector2(half, 0), radius, c)
	draw_circle(Vector2(-half, 0), radius, c)


## Homing: gently curve toward the closest enemy ahead. Soft on purpose: the turn
## rate is limited (so no hard corners) and the target must be inside a forward
## cone, which widens with each stack. Skips enemies this bullet already hit.
func _steer_home(delta: float) -> void:
	var turn := deg_to_rad(Up.p("homing", "turn") * pow(Up.p("homing", "turn_stack"), _homing - 1))
	_home_scan -= delta
	if _home_scan <= 0.0 or _home_target == null or not is_instance_valid(_home_target) or _home_target.dead:
		_home_scan = 0.08
		_home_target = _find_home_target()
	if _home_target == null or not is_instance_valid(_home_target):
		return
	var want: float = (_home_target.global_position - global_position).angle()
	var cur := velocity.angle()
	var step := clampf(wrapf(want - cur, -PI, PI), -turn * delta, turn * delta)
	velocity = velocity.rotated(step)
	rotation = velocity.angle()


func _find_home_target():
	var rng: float = Up.p("homing", "range")
	var cone := minf(180.0, Up.p("homing", "cone") * pow(Up.p("homing", "cone_stack"), _homing - 1))
	var fwd := velocity.angle()
	var best = null
	var best_d := rng
	for e in sb.enemies_near(global_position, global_position, rng):
		if e.dead or victims.has(e.get_instance_id()):
			continue
		var off: Vector2 = e.global_position - global_position
		var d := off.length()
		if d >= best_d or d < 1.0:
			continue
		if absf(wrapf(off.angle() - fwd, -PI, PI)) > deg_to_rad(cone):
			continue
		best_d = d
		best = e
	return best
