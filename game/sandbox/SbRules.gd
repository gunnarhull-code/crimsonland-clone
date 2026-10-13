extends Node2D
## All the trigger / state / payoff behaviour of the upgrades: what happens when
## a bullet is fired, when it hits, when an enemy dies, plus the lasting world
## objects (gravity and stasis zones, bond links, cracks, portals). Numbers come
## from upgrades.csv via SbUpgrades. The shape upgrades (Pierce, Zigzag,
## Ricochet...) live in SbBullet.gd; the stat upgrades in SbPlayer.gd.

const Up := preload("res://sandbox/SbUpgrades.gd")
const DroneS := preload("res://sandbox/SbDrone.gd")

const MAX_ZONES := 40
const MAX_CRACKS := 60
const MAX_DRONES := 60
const MAX_ORBITS := 30
const EXPLOSIONS_PER_FRAME := 60   # spec 4.3 placeholder

var sb
var zones: Array = []      # {kind, pos, r, t}
var links: Array = []      # {members: Array, t: float}
var cracks: Array = []     # {pts, t, dmg, flash}
var portals: Array = []    # {pos, normal}
var _pending_blasts: Array = []


# ------------------------------------------------------------------ helpers --

func every_n(id: String, k: int = -1) -> int:
	var s: int = sb.stack(id) if k < 0 else k
	if s <= 0:
		return 0
	var e := ceilf(Up.p(id, "every") / pow(Up.p(id, "stack_div"), s - 1))
	return maxi(int(e), int(Up.p(id, "min")))


func _scaled(id: String, key: String, stack_key: String, k: int) -> float:
	return Up.p(id, key) * pow(Up.p(id, stack_key), k - 1)


func _alive(e) -> bool:
	return is_instance_valid(e) and not e.dead


# --------------------------------------------------------------- firing hook --

## Called for every bullet created (pull, Split, Echo). Returns true if this
## bullet should become an orbiting shield instead of flying.
func on_fired(props: Dictionary) -> bool:
	sb.fired += 1
	var f: int = sb.fired
	var player = sb.player

	var n := every_n("reclaimer")
	if n > 0 and f % n == 0 and player.ammo < player.MAGAZINE:
		player.ammo += 1
		sb.fx_text(player.global_position + Vector2(0, -22), "+1 ammo", Color(0.5, 1.0, 0.6))
		sb.audio.play("refund")

	n = every_n("blast_ring")
	if n > 0 and f % n == 0:
		var k: int = sb.stack("blast_ring")
		sb.explode(player.global_position, Up.p("blast_ring", "radius"),
			props["damage"] * _scaled("blast_ring", "damage_frac", "damage_stack", k), Color(1.0, 0.45, 0.2))
		player.take_damage(Up.p("blast_ring", "self_damage"))

	n = every_n("shockwave")
	if n > 0 and f % n == 0:
		var k: int = sb.stack("shockwave")
		var r := _scaled("shockwave", "radius", "radius_stack", k)
		sb.fx_ring(player.global_position, r, Color(0.7, 0.85, 1.0))
		sb.audio.play("whoosh")
		for e in sb.enemies.get_children():
			var off: Vector2 = e.global_position - player.global_position
			if not e.dead and off.length() <= r + e.radius:
				e.knock(off.normalized() * Up.p("shockwave", "impulse"))

	n = every_n("orbit_shard")
	return n > 0 and f % n == 0 and sb.orbit_count < MAX_ORBITS


# ----------------------------------------------------------------- hit logic --

## A flying bullet touched an enemy. `first` is false for a Zigzag re-crossing.
func bullet_hit(b, e, first: bool) -> void:
	deal_hit(e, b.damage, {"st": b.st, "gen": b.gen, "base": b.damage, "pos": b.global_position, "victims": b.victims})
	if first:
		b.hits_left -= 1
		if b.hits_left <= 0:
			if not b.try_ricochet_off(e):
				b.queue_free()
		else:
			b.damage *= 1.0 - b.falloff


## The single place damage + on-hit effects are applied to an enemy.
## ctx: st (this source's stacks), gen, base (damage before target modifiers),
## pos (impact point).
func deal_hit(e, dmg: float, ctx: Dictionary) -> void:
	if not _alive(e):
		return
	var st: Dictionary = ctx["st"]
	var gen: int = ctx["gen"]
	var base: float = ctx["base"]
	sb.hits += 1

	var final := dmg
	var xk: int = st.get("exploit", 0)
	if xk > 0:
		var bonus := Up.p("exploit", "debuff_bonus") if e.is_debuffed() else Up.p("exploit", "all_bonus")
		final *= 1.0 + bonus * pow(Up.p("exploit", "stack"), xk - 1)
	var ak: int = st.get("adaptive_round", 0)
	if ak > 0 and sb.leading_species() == e.species:
		var before := final
		final *= 1.0 + sb.species_hits.get(e.species, 0) * Up.p("adaptive_round", "per_hit") \
			* pow(Up.p("adaptive_round", "stack"), ak - 1)
		sb.adaptive_extra += final - before
	sb.species_hits[e.species] = sb.species_hits.get(e.species, 0) + 1
	if e.armor > 0.0:
		final = maxf(1.0, final - e.armor)

	e.take_damage(final)
	_share_damage(e, final)

	var at: Vector2 = e.global_position
	if not e.dead:
		var pk: int = st.get("poison", 0)
		if pk > 0:
			var dps := _scaled("poison", "dps", "dps_stack", pk)
			e.apply_poison(dps, Up.p("poison", "duration"))
			_share_state(e, "poison", dps, Up.p("poison", "duration"))
		var ck: int = st.get("chill", 0)
		if ck > 0:
			var dur := _scaled("chill", "duration", "duration_stack", ck)
			e.apply_chill(Up.p("chill", "speed"), dur)
			_share_state(e, "chill", Up.p("chill", "speed"), dur)
		if st.get("bond_arc", 0) > 0:
			_bond(e, st["bond_arc"])
		if st.get("shard_bloom", 0) > 0:
			_shard(e, st["shard_bloom"], base)
		if st.get("third_strike", 0) > 0:
			_third_strike(e, st["third_strike"])

	var sk: int = st.get("shrapnel", 0)
	if sk > 0:
		sb.explode(at, _scaled("shrapnel", "radius", "radius_stack", sk), final * _scaled("shrapnel", "damage_frac", "damage_stack", sk))
	var gk: int = st.get("gravity_seed", 0)
	if gk > 0:
		_add_zone("gravity", at, Up.p("gravity_seed", "radius"), _scaled("gravity_seed", "duration", "stack", gk))
	var fk: int = st.get("still_field", 0)
	if fk > 0:
		_add_zone("still", at, Up.p("still_field", "radius"), _scaled("still_field", "duration", "stack", fk))

	# Spawners: Split (every hit) and Echo (every Nth hit) fire a stray bullet.
	var split_n: int = sb.stack("split") * int(Up.p("split", "per_stack"))
	if split_n > 0 and gen < int(Up.p("split", "gen_limit")):
		for i in split_n:
			_stray(at, gen + 1, ctx.get("victims", {}), e)
	var en := every_n("echo")
	if en > 0 and gen < int(Up.p("echo", "gen_limit")) and sb.hits % en == 0:
		_stray(at, gen + 1, ctx.get("victims", {}), e)


func _stray(at: Vector2, gen: int, parent_victims: Dictionary, hit_enemy) -> void:
	var v := parent_victims.duplicate()
	v[hit_enemy.get_instance_id()] = true
	sb.player.fire_pipeline(at, Vector2.RIGHT.rotated(randf() * TAU), gen, 0, v)


# ------------------------------------------------------- bond arc / strikes --

func _bond(e, k: int) -> void:
	if e.link != null and e.link["t"] > 0.0:
		e.link["t"] = Up.p("bond_arc", "duration")
		return
	var want := int(_scaled("bond_arc", "count", "stack", k))
	var members: Array = [e]
	var cur = e
	for i in want - 1:
		var best = null
		var best_d: float = Up.p("bond_arc", "range")
		for o in sb.enemies.get_children():
			if o.dead or members.has(o) or (o.link != null and o.link["t"] > 0.0):
				continue
			var d: float = cur.global_position.distance_to(o.global_position)
			if d < best_d:
				best_d = d
				best = o
		if best == null:
			break
		members.append(best)
		cur = best
	if members.size() < 2:
		return
	var group := {"members": members, "t": Up.p("bond_arc", "duration")}
	links.append(group)
	for m in members:
		m.link = group


func _share_damage(e, amount: float) -> void:
	if e.link == null or e.link["t"] <= 0.0:
		return
	for m in e.link["members"]:
		if m != e and _alive(m):
			m.take_damage(amount, Color(0.6, 0.9, 1.0))


func _share_state(e, kind: String, a: float, b: float) -> void:
	if e.link == null or e.link["t"] <= 0.0:
		return
	for m in e.link["members"]:
		if m != e and _alive(m):
			if kind == "poison":
				m.apply_poison(a, b)
			else:
				m.apply_chill(a, b)


func _shard(e, k: int, base: float) -> void:
	e.shards += 1
	var need := maxi(int(ceilf(Up.p("shard_bloom", "need") / pow(Up.p("shard_bloom", "stack_div"), k - 1))), int(Up.p("shard_bloom", "min")))
	if e.shards >= need:
		var dmg: float = e.shards * Up.p("shard_bloom", "shard_frac") * base
		e.shards = 0
		sb.explode(e.global_position, Up.p("shard_bloom", "radius"), dmg, Color(0.8, 0.95, 1.0))


func _third_strike(e, k: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var window := _scaled("third_strike", "window", "stack", k)
	var times: Array = []
	for t in e.strike_times:
		if now - t <= window:
			times.append(t)
	times.append(now)
	e.strike_times = times
	if times.size() == 2:
		e.stun_t = Up.p("third_strike", "stun")
		sb.fx_text(e.global_position + Vector2(0, -e.radius - 14), "STUN", Color(1, 1, 0.4))
	elif times.size() >= 3:
		e.strike_times = []
		sb.fx_text(e.global_position + Vector2(0, -e.radius - 14), "DISINTEGRATE", Color(0.9, 0.5, 1.0))
		sb.audio.play("zap")
		if e.variant == "boss":
			e.take_damage(e.max_hp * Up.p("third_strike", "boss_frac"), Color(0.9, 0.5, 1.0))
		else:
			e.take_damage(e.hp + 1.0, Color(0.9, 0.5, 1.0))


# ---------------------------------------------------------------- kill hook --

func enemy_died(e) -> void:
	var vk: int = sb.stack("volatile_core")
	if vk > 0:
		_pending_blasts.append({"pos": e.global_position, "r": Up.p("volatile_core", "radius"),
			"dmg": Up.p("volatile_core", "hp_frac") * e.max_hp * pow(Up.p("volatile_core", "stack"), vk - 1)})
	var bk: int = sb.stack("brood_seed")
	if bk > 0 and randf() < Up.p("brood_seed", "chance"):
		var count := int(Up.p("brood_seed", "drones") * pow(Up.p("brood_seed", "stack"), bk - 1))
		for i in count:
			if sb.drones.get_child_count() >= MAX_DRONES:
				break
			var d := DroneS.new()
			d.setup(sb, e.global_position)
			sb.drones.add_child(d)
			sb.audio.play("hatch")


# ------------------------------------------------------------ world objects --

func _add_zone(kind: String, pos: Vector2, r: float, dur: float) -> void:
	for z in zones:
		if z["kind"] == kind and z["pos"].distance_to(pos) < r * 0.6:
			z["t"] = maxf(z["t"], dur)
			return
	if zones.size() >= MAX_ZONES:
		return
	zones.append({"kind": kind, "pos": pos, "r": r, "t": dur, "max": dur})


func add_crack(pts: PackedVector2Array, bullet_damage: float, k: int) -> void:
	if cracks.size() >= MAX_CRACKS:
		return
	cracks.append({"pts": pts.duplicate(), "t": Up.p("fault_line", "delay"), "flash": 0.0,
		"dmg": bullet_damage * _scaled("fault_line", "damage_frac", "stack", k)})


func _near_portal(p: Vector2) -> int:
	var r := Up.p("twin_gate", "radius")
	for i in portals.size():
		if portals[i]["pos"].distance_to(p) <= r:
			return i
	return -1


## A bullet reached a wall: if it is inside a portal that has a partner, send it through.
func wall_portal(b, p: Vector2, _normal: Vector2) -> bool:
	var i := _near_portal(p)
	if i < 0 or (i ^ 1) >= portals.size():
		return false
	var out: Dictionary = portals[i ^ 1]
	b.global_position = out["pos"] + out["normal"] * (Up.p("twin_gate", "radius") + 8.0)
	# Keep the angle to the wall: rotate the heading from "into the entry wall" to "out of the exit wall".
	var turn: float = out["normal"].angle() - (-_normal).angle()
	b.velocity = b.velocity.rotated(turn)
	b.rotation = b.velocity.angle()
	b._contact.clear()
	b._base = b.global_position
	return true


## A bullet died on a wall: with Twin Gate, the first walls hit become portals.
func wall_make_portal(_b, p: Vector2, normal: Vector2) -> bool:
	var k: int = sb.stack("twin_gate")
	if k <= 0 or _near_portal(p) >= 0:
		return false
	var max_portals := 2 * int(Up.p("twin_gate", "pairs") * pow(Up.p("twin_gate", "stack"), k - 1))
	if portals.size() >= max_portals:
		return false
	portals.append({"pos": p, "normal": normal})
	return true


func clear_world() -> void:
	zones.clear()
	links.clear()
	cracks.clear()
	portals.clear()
	_pending_blasts.clear()


# --------------------------------------------------------------------- tick --

func _physics_process(delta: float) -> void:
	sb.explosions_this_frame = 0
	_tick_zones(delta)
	_tick_links(delta)
	_tick_cracks(delta)
	_tick_portals(delta)
	var n := 0
	while not _pending_blasts.is_empty() and n < EXPLOSIONS_PER_FRAME:
		var bl: Dictionary = _pending_blasts.pop_back()
		sb.explode(bl["pos"], bl["r"], bl["dmg"], Color(0.8, 0.4, 1.0))
		n += 1
	queue_redraw()


func _tick_zones(delta: float) -> void:
	for z in zones:
		z["t"] -= delta
		for e in sb.enemies.get_children():
			if e.dead:
				continue
			var off: Vector2 = z["pos"] - e.global_position
			if off.length() > z["r"] + e.radius:
				continue
			if z["kind"] == "gravity":
				e.global_position += off.normalized() * minf(Up.p("gravity_seed", "pull") * delta, off.length())
			else:
				e.held_t = 0.1
	zones = zones.filter(func(z): return z["t"] > 0.0)


func _tick_links(delta: float) -> void:
	for g in links:
		g["t"] -= delta
		g["members"] = g["members"].filter(func(m): return _alive(m))
	links = links.filter(func(g): return g["t"] > 0.0 and g["members"].size() > 1)


func _tick_cracks(delta: float) -> void:
	for c in cracks:
		if c["flash"] > 0.0:
			c["flash"] -= delta
			continue
		c["t"] -= delta
		if c["t"] <= 0.0:
			c["flash"] = 0.3
			_erupt(c)
	cracks = cracks.filter(func(c): return c["flash"] > 0.0 or c["t"] > 0.0)


func _erupt(c: Dictionary) -> void:
	var pts: PackedVector2Array = c["pts"]
	var width := Up.p("fault_line", "width")
	for e in sb.enemies.get_children():
		if e.dead:
			continue
		var hit := false
		for i in range(pts.size() - 1):
			var q := Geometry2D.get_closest_point_to_segment(e.global_position, pts[i], pts[i + 1])
			if q.distance_to(e.global_position) <= width + e.radius:
				hit = true
				break
		if hit:
			e.take_damage(c["dmg"], Color(1.0, 0.6, 0.3))


func _tick_portals(delta: float) -> void:
	if sb.stack("twin_gate") == 0:
		portals.clear()
		return
	var r := Up.p("twin_gate", "radius")
	for e in sb.enemies.get_children():
		if e.portal_cd > 0.0:
			e.portal_cd -= delta
			continue
		var i := _near_portal(e.global_position)
		if i >= 0 and (i ^ 1) < portals.size():
			var out: Dictionary = portals[i ^ 1]
			e.global_position = out["pos"] + out["normal"] * (r + e.radius + 10.0)
			e.portal_cd = 1.5


# ---------------------------------------------------------------------- draw --

func _draw() -> void:
	for z in zones:
		var a := clampf(z["t"] / z["max"], 0.0, 1.0)
		var col := Color(0.7, 0.4, 1.0) if z["kind"] == "gravity" else Color(0.5, 0.8, 1.0)
		draw_circle(z["pos"], z["r"], Color(col, 0.10 + 0.08 * a))
		draw_arc(z["pos"], z["r"], 0.0, TAU, 40, Color(col, 0.6), 2.0)
	for g in links:
		var m: Array = g["members"]
		for i in range(m.size() - 1):
			if is_instance_valid(m[i]) and is_instance_valid(m[i + 1]):
				draw_line(m[i].global_position, m[i + 1].global_position, Color(0.5, 0.95, 1.0, 0.8), 2.0)
	for c in cracks:
		var pts: PackedVector2Array = c["pts"]
		if c["flash"] > 0.0:
			draw_polyline(pts, Color(1.0, 0.6, 0.2, c["flash"] / 0.3), 10.0)
		else:
			var prog: float = 1.0 - c["t"] / Up.p("fault_line", "delay")
			draw_polyline(pts, Color(1.0, 0.5, 0.2, 0.25 + 0.6 * prog), 2.0 + 2.0 * prog)
	for i in portals.size():
		var col := Color(0.4, 0.8, 1.0) if (i / 2) % 2 == 0 else Color(1.0, 0.6, 0.9)
		var p: Dictionary = portals[i]
		draw_circle(p["pos"], Up.p("twin_gate", "radius"), Color(col, 0.35))
		draw_arc(p["pos"], Up.p("twin_gate", "radius"), 0.0, TAU, 32, col, 3.0)


# ----------------------------------------------------------------- tooltips --

## Plain-English numbers for an upgrade at k stacks (used by the UI tooltip).
func describe(id: String, k: int) -> String:
	var P := func(key: String) -> float: return Up.p(id, key)
	if k <= 0:
		return "-"
	var p2 := func(base: float, stack: float) -> float: return base * pow(stack, k - 1)
	match id:
		"spread":
			return "x%d bullets per pull" % int(pow(P.call("bullet_mult"), k))
		"grow":
			return "bullets x%.1f size, x%.2f damage, charge %.2fs" % [pow(P.call("size_mult"), k), pow(P.call("damage_mult"), k), sb.grow_charge_base * pow(P.call("charge_mult"), k)]
		"poison":
			return "%d damage/s for %ds, direct damage x0.8" % [int(p2.call(P.call("dps"), P.call("dps_stack"))), int(P.call("duration"))]
		"pierce":
			var passes := int(P.call("pass") + P.call("pass_add") * (k - 1))
			return "passes %d enemies (hits up to %d), -20%% damage each" % [passes, passes + 1]
		"quickdraw":
			return "%.2f shots/s" % (3.5 * pow(P.call("rate_mult"), k))
		"exploit":
			var s := pow(P.call("stack"), k - 1)
			return "+%d%% damage to all, +%d%% to poisoned/chilled" % [roundi(P.call("all_bonus") * s * 100), roundi(P.call("debuff_bonus") * s * 100)]
		"shrapnel":
			return "blast radius %d, %d%% of damage dealt" % [int(p2.call(P.call("radius"), P.call("radius_stack"))), roundi(p2.call(P.call("damage_frac"), P.call("damage_stack")) * 100)]
		"chill":
			return "slow to %d%% speed for %ds" % [roundi(P.call("speed") * 100), int(p2.call(P.call("duration"), P.call("duration_stack")))]
		"bloodshot":
			var hp_per: float = P.call("hp_per") / pow(P.call("stack_div"), k - 1)
			return "1 extra bullet per %.1f HP (now +%d)" % [hp_per, int(floorf(sb.player.hp / hp_per))]
		"reclaimer":
			return "every %d bullets refunds a round" % every_n(id, k)
		"blast_ring":
			return "every %d bullets: radius %d, %d%% damage, costs you %d HP" % [every_n(id, k), int(P.call("radius")), roundi(p2.call(P.call("damage_frac"), P.call("damage_stack")) * 100), int(P.call("self_damage"))]
		"shockwave":
			return "every %d bullets shoves enemies within %d" % [every_n(id, k), int(p2.call(P.call("radius"), P.call("radius_stack")))]
		"echo":
			return "every %d hits a stray bullet (up to generation %d)" % [every_n(id, k), int(P.call("gen_limit"))]
		"zigzag":
			return "can cross each enemy %d times" % int(p2.call(P.call("crossings"), P.call("stack")))
		"ricochet":
			return "%d bounces, -%d%% damage each" % [int(p2.call(P.call("bounces"), P.call("stack"))), roundi(P.call("loss") * 100)]
		"volatile_core":
			return "dead enemies explode: radius %d, %d%% of their max HP" % [int(P.call("radius")), roundi(p2.call(P.call("hp_frac"), P.call("stack")) * 100)]
		"soul_snatcher":
			var rate: float = P.call("per_kill") * pow(P.call("stack"), k - 1)
			return "+%d%% at pick, +%.1f%% per kill (now +%.1f%% total)" % [roundi(P.call("pick_bonus") * k * 100), rate * 100, (P.call("pick_bonus") * k + sb.kills * rate) * 100]
		"reaper":
			var rate2: float = P.call("per_kill") * pow(P.call("stack"), k - 1)
			return "+%d max HP at pick, +%.1f%% max HP per kill (cap +%d%%)" % [int(P.call("pick_hp") * k), rate2 * 100, roundi(P.call("cap") * 100)]
		"gravity_seed":
			return "pulls enemies within %d for %ds" % [int(P.call("radius")), int(p2.call(P.call("duration"), P.call("stack")))]
		"shard_bloom":
			var need := maxi(int(ceilf(P.call("need") / pow(P.call("stack_div"), k - 1))), int(P.call("min")))
			return "detonates at %d shards (%d%% damage each, radius %d)" % [need, roundi(P.call("shard_frac") * 100), int(P.call("radius"))]
		"third_strike":
			return "2 hits within %ds stun %ds, 3rd hit disintegrates" % [int(p2.call(P.call("window"), P.call("stack"))), int(P.call("stun"))]
		"bond_arc":
			return "links %d enemies for %ds, shares damage and states" % [int(p2.call(P.call("count"), P.call("stack"))), int(P.call("duration"))]
		"twin_gate":
			return "%d portal pair(s) from the first walls hit" % int(p2.call(P.call("pairs"), P.call("stack")))
		"still_field":
			return "zone radius %d holds enemies still for %ds" % [int(P.call("radius")), int(p2.call(P.call("duration"), P.call("stack")))]
		"brood_seed":
			return "%d%% chance per kill, %d drone(s), %s" % [roundi(P.call("chance") * 100), int(p2.call(P.call("drones"), P.call("stack"))), ("%ds" % int(P.call("life"))) if P.call("life") > 0.0 else "permanent (max 60)"]
		"orbit_shard":
			return "every %d bullets orbits you for %ds" % [every_n(id, k), int(P.call("life"))]
		"fault_line":
			return "crack erupts after %.1fs for %d%% bullet damage" % [P.call("delay"), roundi(p2.call(P.call("damage_frac"), P.call("stack")) * 100)]
		"heat_coil":
			var pulls := maxi(int(ceilf(P.call("pulls") / pow(P.call("stack_div"), k - 1))), int(P.call("min")))
			return "beam after %d pulls: x%d damage, pierces all" % [pulls, int(P.call("beam_mult"))]
		"adaptive_round":
			return "+%.2f%% damage per hit on your most-hit species" % (P.call("per_hit") * pow(P.call("stack"), k - 1) * 100)
		"split":
			return "%d guaranteed split(s) per hit, children keep each other upgrade 50%% (halving per generation)" % (k * int(P.call("per_stack")))
	return ""
