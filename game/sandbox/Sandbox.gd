extends Node2D
## Upgrade sandbox: a flat arena where you stack the 30 rubric upgrades with
## +/- buttons, spawn the current monsters (enemies.csv), and run a level 1-10
## wave test to see how a build scales. Run with run-sandbox.bat, or open
## sandbox/Sandbox.tscn and press F6.
##
## Hotkeys: 1/2/3 = 5 rats/spiders/aliens at the cursor, 4/5/6 = a boss at the
## cursor, C = clear enemies, R = reload, H = heal, Tab = hide panels.

const Up := preload("res://sandbox/SbUpgrades.gd")
const PlayerS := preload("res://sandbox/SbPlayer.gd")
const BulletS := preload("res://sandbox/SbBullet.gd")
const EnemyS := preload("res://sandbox/SbEnemy.gd")
const FxS := preload("res://sandbox/SbFx.gd")
const RulesS := preload("res://sandbox/SbRules.gd")
const WavesS := preload("res://sandbox/SbWaves.gd")
const SpawnerS := preload("res://sandbox/SbSpawner.gd")
const WebsS := preload("res://sandbox/SbWebs.gd")
const ParticlesS := preload("res://sandbox/SbParticles.gd")
const DecalsS := preload("res://sandbox/SbDecals.gd")
const Art := preload("res://sandbox/SbArt.gd")
const AudioS := preload("res://sandbox/SbAudio.gd")
const UiS := preload("res://sandbox/SbUI.gd")

const ARENA := Vector2(1600, 900)
# Performance safety valves (spec 4.3 placeholders).
const MAX_ENEMIES := 400
const MAX_BULLETS := 1500
const MAX_FX := 300
const EXPLOSIONS_PER_FRAME := 60
# Spawned (Split/Echo) bullets: generation 0 is the gun. Anything at this
# generation can never spawn more (used for beams, drones, orbiting shards).
const GEN_HARD_LIMIT := 99
# Upgrades that belong to a bullet. A Split/Echo bullet tests each of these
# at 0.5^generation (spec 13.14); gun-level upgrades never inherit.
const BULLET_LEVEL := ["spread", "grow", "velocity", "homing", "poison", "pierce", "exploit", "shrapnel", "chill", "shrink",
	"zigzag", "ricochet", "soul_snatcher", "gravity_seed", "shard_bloom", "third_strike",
	"bond_arc", "still_field", "fault_line", "adaptive_round"]
# Spec 13.10: enemy HP scales geometrically to 20x by level 10.
const HP_AT_LEVEL_10 := 20.0
const DPS_WINDOW_SEC := 5.0
# Every flying bullet is removed after this long (stops Twin Gate loops); fades over the last second.
const BULLET_LIFETIME := 20.0

var stacks := {}
var fired := 0
var hits := 0
var kills := 0
var total_damage := 0.0
var species_hits := {}
var adaptive_extra := 0.0     # total extra damage Adaptive Round has added since the last reset
var orbit_count := 0
var explosions_this_frame := 0

# Tuning / toggles driven by the right-hand panel.
var level := 1
var enemies_chase := true
var god_mode := false
var show_numbers := true
var grow_charge_base := 0.3     # open question 1 in the handoff
var charge_overlaps := true     # ditto: charge overlaps the fire-rate lockout
var grow_size_mult := 2.5         # Grow: bullet size multiplier per stack (cheat slider; the CSV value is only a default)

var player
var enemies: Node2D
var bullets: Node2D
var drones: Node2D
var fx: Node2D
var rules
var audio
var particles
var decals
var cam: Camera2D
var flash_rect: ColorRect
var waves
var spawner
var webs
var ui

# Switches the prototype run flips (the sandbox keeps the defaults).
var revive_on_death := true       # false: dying ends the run
var heal_on_level_start := true   # full heal when a wave-test level starts
var cheat_damage_mult := 1.0      # cheat: multiplies all damage you deal
var infinite_ammo := false        # cheat
var move_speed_mult := 1.0        # cheat
var juice_on := true             # particles, splatter, hit sparks
var shake_on := true             # screen shake
var _trauma := 0.0
var shake_scale := 1.0             # 0..2, the cheat slider
var species_count := {}            # live monsters per species, refreshed 5x a second
var _count_t := 0.0
var _rat_pack := 0.0
var _grid := {}                      # spatial hash of enemies (cell -> list), rebuilt each physics frame
const GRID := 96.0
var crowd_size := 0                  # total live monsters, refreshed 5x a second
var _shake_t := 0.0
var _damage_log: Array = []     # [time_sec, amount]


func _ready() -> void:
	_build_world()
	_build_ui()
	_after_ready()


func _build_world() -> void:
	cam = Camera2D.new()
	cam.position = ARENA / 2.0
	var vp := get_viewport_rect().size
	var z := minf(vp.x / ARENA.x, vp.y / ARENA.y)
	cam.zoom = Vector2(z, z)
	add_child(cam)

	audio = AudioS.new()
	add_child(audio)
	rules = RulesS.new()
	rules.sb = self
	add_child(rules)
	decals = DecalsS.new()
	add_child(decals)
	spawner = SpawnerS.new()
	spawner.sb = self
	add_child(spawner)
	webs = WebsS.new()
	webs.sb = self
	add_child(webs)
	enemies = Node2D.new()
	drones = Node2D.new()
	bullets = Node2D.new()
	add_child(enemies)
	add_child(drones)
	add_child(bullets)
	player = PlayerS.new()
	player.sb = self
	player.position = ARENA / 2.0
	add_child(player)
	particles = ParticlesS.new()
	add_child(particles)
	fx = Node2D.new()
	add_child(fx)
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 1
	add_child(flash_layer)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0.1, 0.1, 0.0)
	flash_layer.add_child(flash_rect)
	waves = WavesS.new()
	waves.sb = self
	add_child(waves)


## The sandbox panels. The prototype (proto/Run.gd) overrides this with its own UI.
func _build_ui() -> void:
	ui = UiS.new()
	ui.sb = self
	add_child(ui)


func _after_ready() -> void:
	pass


## The junkyard floor: dirt, oil, scrap and tyres scattered from a fixed seed,
## drawn once, with a rusty fence around the edge. Dark and low-contrast so
## monsters, bullets and effects stand out against it.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0.17, 0.145, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 40:   # lighter and darker dirt patches
		var c := Vector2(rng.randf() * ARENA.x, rng.randf() * ARENA.y)
		var shade := rng.randf_range(-0.018, 0.018)
		draw_circle(c, rng.randf_range(40, 150), Color(0.17 + shade, 0.145 + shade, 0.12 + shade, 0.55))
	for i in 14:   # oil stains
		var c := Vector2(rng.randf() * ARENA.x, rng.randf() * ARENA.y)
		draw_set_transform(c, rng.randf() * PI, Vector2(1.0, rng.randf_range(0.5, 0.9)))
		draw_circle(Vector2.ZERO, rng.randf_range(18, 55), Color(0.06, 0.06, 0.065, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 12:   # old tyres and rims
		var c := Vector2(rng.randf() * ARENA.x, rng.randf() * ARENA.y)
		var r := rng.randf_range(14, 26)
		draw_arc(c, r, 0.0, TAU, 24, Color(0.11, 0.1, 0.1), r * 0.5)
		draw_arc(c, r * 0.4, 0.0, TAU, 16, Color(0.3, 0.28, 0.27, 0.6), 2.0)
	for i in 90:  # scrap plates, bottles and bolts
		var c := Vector2(rng.randf() * ARENA.x, rng.randf() * ARENA.y)
		var ang := rng.randf() * TAU
		draw_set_transform(c, ang, Vector2.ONE)
		var kind := rng.randi() % 4
		if kind == 0:
			draw_rect(Rect2(-14, -5, rng.randf_range(16, 34), rng.randf_range(7, 14)), Color(0.3, 0.19, 0.13, 0.7))
		elif kind == 1:
			draw_rect(Rect2(-10, -3, 20, 6), Color(0.22, 0.28, 0.25, 0.7))
			draw_circle(Vector2(11, 0), 3.5, Color(0.22, 0.28, 0.25, 0.7))
		elif kind == 2:
			draw_circle(Vector2.ZERO, rng.randf_range(2.5, 5), Color(0.34, 0.33, 0.32, 0.7))
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(-9, -4), Vector2(10, -2), Vector2(4, 8)]), Color(0.33, 0.25, 0.18, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# rusty fence
	var post := Color(0.28, 0.22, 0.18)
	var rail := Color(0.4, 0.27, 0.18)
	draw_rect(Rect2(Vector2.ZERO, ARENA), rail, false, 6.0)
	for x in range(0, int(ARENA.x) + 1, 80):
		draw_circle(Vector2(x, 0), 7, post)
		draw_circle(Vector2(x, ARENA.y), 7, post)
	for y in range(0, int(ARENA.y) + 1, 80):
		draw_circle(Vector2(0, y), 7, post)
		draw_circle(Vector2(ARENA.x, y), 7, post)



func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var cursor := get_global_mouse_position()
	match event.keycode:
		KEY_1: spawn_enemies("rat", "base", 5, cursor)
		KEY_2: spawn_enemies("spider", "base", 5, cursor)
		KEY_3: spawn_enemies("alien", "base", 5, cursor)
		KEY_4: spawn_enemies("rat", "boss", 1, cursor)
		KEY_5: spawn_enemies("spider", "boss", 1, cursor)
		KEY_6: spawn_enemies("alien", "boss", 1, cursor)
		KEY_7: spawn_enemies("tick", "base", 4, cursor)
		KEY_8: spawn_enemies("scrapper", "base", 2, cursor)
		KEY_C: clear_enemies()
		KEY_R: player.start_reload()
		KEY_H: heal()
		KEY_TAB: ui.toggle_panels()


# ------------------------------------------------------------------ helpers --

## Stacks of an upgrade that count right now (0 if its prerequisite is missing).
func stack(id: String) -> int:
	var k: int = stacks.get(id, 0)
	if k > 0:
		var req: String = Up.get_row(id).get("requires", "")
		if req != "" and stacks.get(req, 0) <= 0:
			return 0
	return k


func raw_stack(id: String) -> int:
	return stacks.get(id, 0)


func set_stack(id: String, n: int) -> void:
	stacks[id] = maxi(0, n)


## The stacks a bullet carries. Gun-fired bullets (gen 0) keep everything;
## each bullet-level upgrade on a Split/Echo bullet only applies with a
## 0.5^gen chance, tested per upgrade per bullet.
func bullet_stacks(gen: int) -> Dictionary:
	var st := {}
	var keep := pow(0.5, gen)
	for id in BULLET_LEVEL:
		var k := stack(id)
		if k > 0 and gen > 0 and randf() > keep:
			k = 0
		if k > 0:
			st[id] = k
	return st


## Current Adaptive Round bonus (as a fraction, 0.12 = +12%) against the leading species.
func adaptive_bonus() -> float:
	var k := stack("adaptive_round")
	if k == 0:
		return 0.0
	return species_hits.get(leading_species(), 0) * Up.p("adaptive_round", "per_hit") * pow(Up.p("adaptive_round", "stack"), k - 1)


func leading_species() -> String:
	var best := ""
	var best_n := 0
	for s in species_hits:
		if species_hits[s] > best_n:
			best_n = species_hits[s]
			best = s
	return best


## True while the left button is held and the cursor is not over a panel.
func fire_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		and get_viewport().gui_get_hovered_control() == null


## Enemy HP multiplier for the chosen level (1x at level 1, 20x at level 10).
func hp_mult() -> float:
	return pow(HP_AT_LEVEL_10, (level - 1) / 9.0)


func heal() -> void:
	player.hp = player.max_hp
	player.ammo = player.MAGAZINE
	player.reloading = false


func hurt_player(amount: float) -> void:
	player.hp = maxf(1.0, player.hp - amount)


func clear_enemies() -> void:
	player.latch_count = 0
	webs.clear()
	player.held_t = 0.0
	for e in enemies.get_children():
		e.queue_free()
	for b in bullets.get_children():
		b.queue_free()
	for d in drones.get_children():
		d.queue_free()
	rules.clear_world()
	waves.stop()


func reset_counters() -> void:
	fired = 0
	hits = 0
	kills = 0
	total_damage = 0.0
	species_hits.clear()
	adaptive_extra = 0.0
	player.heat = 0
	player.damage_taken = 0.0
	_damage_log.clear()


func record_damage(amount: float) -> void:
	total_damage += amount
	_damage_log.append([Time.get_ticks_msec() / 1000.0, amount])


func recent_dps() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	while not _damage_log.is_empty() and now - _damage_log[0][0] > DPS_WINDOW_SEC:
		_damage_log.pop_front()
	var sum := 0.0
	for entry in _damage_log:
		sum += entry[1]
	return sum / DPS_WINDOW_SEC


func fx_text(pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 14) -> void:
	if not show_numbers or fx.get_child_count() >= MAX_FX:
		return
	var f := FxS.new()
	f.kind = "text"
	f.text = text
	f.color = color
	f.font_size = size
	f.position = pos
	fx.add_child(f)


func fx_ring(pos: Vector2, radius: float, color: Color) -> void:
	if fx.get_child_count() >= MAX_FX:
		return
	var f := FxS.new()
	f.kind = "ring"
	f.radius = radius
	f.color = color
	f.life = 0.35
	f.position = pos
	fx.add_child(f)


func fx_beam(from: Vector2, to: Vector2, width: float) -> void:
	var f := FxS.new()
	f.kind = "beam"
	f.life = 0.25
	f.position = from
	f.beam_to = to - from
	f.beam_width = width
	f.color = Color(1.0, 0.55, 0.25)
	fx.add_child(f)


# ----------------------------------------------------------------- spawning --

## Spawn `count` enemies. `at` = Vector2 scatters them around that point;
## null places them in a ring around the player. Returns the enemies made.
func spawn_enemies(species: String, variant: String, count: int, at = null) -> Array:
	var made: Array = []
	for i in count:
		if enemies.get_child_count() >= MAX_ENEMIES:
			break
		var pos: Vector2
		if at == null:
			pos = player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(350.0, 450.0)
		else:
			pos = at + Vector2.RIGHT.rotated(randf() * TAU) * (randf_range(0.0, 60.0) if count > 1 else 0.0)
		pos = pos.clamp(Vector2(20, 20), ARENA - Vector2(20, 20))
		var e := EnemyS.new()
		e.setup(self, species, variant, pos)
		enemies.add_child(e)
		made.append(e)
	return made


## Spawn one monster at an exact spot. `emerge` seconds of rising out of the ground first (it cannot act yet).
func spawn_one(species: String, variant: String, pos: Vector2, emerge: float = 0.0):
	if enemies.get_child_count() >= MAX_ENEMIES:
		return null
	var e := EnemyS.new()
	e.setup(self, species, variant, pos.clamp(Vector2(16, 16), ARENA - Vector2(16, 16)))
	e.emerge_t = emerge
	e.emerge_total = maxf(emerge, 0.001)
	enemies.add_child(e)
	return e


func spawn_bullet(pos: Vector2, dir: Vector2, props: Dictionary, orbit: bool = false) -> void:
	if bullets.get_child_count() >= MAX_BULLETS:
		return
	var b := BulletS.new()
	b.setup(self, pos, dir, props, orbit)
	if orbit:
		orbit_count += 1
	bullets.add_child(b)


## A plain blast: damages every enemy in range, applies no states, counts no hits.
func explode(pos: Vector2, radius: float, damage: float, color: Color = Color(1.0, 0.6, 0.2)) -> void:
	if explosions_this_frame >= EXPLOSIONS_PER_FRAME:
		return
	explosions_this_frame += 1
	audio.play("explosion", clampf(radius / 90.0 - 1.0, -6.0, 0.0) * 4.0)
	fx_ring(pos, radius, color)
	vfx_explosion(pos, radius, color, damage)
	webs.burn(pos, radius)
	for e in enemies.get_children():
		if not e.dead and e.global_position.distance_to(pos) <= radius + e.radius:
			e.take_damage(damage, color.lightened(0.3), (e.global_position - pos).normalized())


# ---------------------------------------------------------------------- juice --
# Screen shake, hit sparks, gore and scorch marks. All optional (juice_on, shake_on).

## Smooth, low-frequency camera sway (not per-frame random jitter, which is what gives headaches).
## Strength is trauma squared, so small events are barely felt and big ones are wild.
func _process(delta: float) -> void:
	_count_t -= delta
	if _count_t <= 0.0:
		_count_t = 0.2
		species_count.clear()
		crowd_size = enemies.get_child_count()
		for e in enemies.get_children():
			species_count[e.species] = species_count.get(e.species, 0) + 1
		_refresh_rat_pack()
	_trauma = maxf(0.0, _trauma - delta * 2.2)
	_shake_t += delta
	var s := _trauma * _trauma * 16.0 * shake_scale
	if s > 0.05:
		cam.offset = Vector2(sin(_shake_t * 23.0) + 0.5 * sin(_shake_t * 37.0 + 1.3), cos(_shake_t * 19.0) + 0.5 * sin(_shake_t * 31.0 + 0.7)) * s * 0.7
	else:
		cam.offset = Vector2.ZERO
	if flash_rect.color.a > 0.0:
		flash_rect.color.a = maxf(0.0, flash_rect.color.a - delta * 1.6)


func shake(amount: float) -> void:
	if shake_on:
		_trauma = minf(1.0, _trauma + amount)


func screen_flash(color: Color, alpha: float) -> void:
	if juice_on:
		flash_rect.color = Color(color.r, color.g, color.b, alpha)


func set_juice(on: bool) -> void:
	juice_on = on
	particles.enabled = on
	decals.enabled = on
	if not on:
		decals.clear_all()


func vfx_hit(pos: Vector2, dir: Vector2, ichor: Color, amount: float, _radius: float) -> void:
	if not juice_on:
		return
	var fwd := dir if dir != Vector2.ZERO else Vector2.RIGHT.rotated(randf() * TAU)
	var n := 3 + mini(int(amount / 12.0), 5)
	particles.burst(pos, -fwd, n, 300.0, 1.1, 0.22, 4.0, Color(1.0, 0.92, 0.55), "line", 4.0)
	particles.burst(pos, fwd, 2 + n / 2, 210.0, 0.7, 0.5, 3.0, ichor, "dot", 5.0)


func vfx_kill(pos: Vector2, species: String, radius: float, boss: bool, dir: Vector2) -> void:
	var ichor := Art.ichor(species)
	if boss:
		shake(0.35)
		screen_flash(ichor, 0.08)

	if not juice_on:
		return
	var n := 14 + (16 if boss else 0)
	particles.burst(pos, Vector2.RIGHT, n, 240.0 + radius * 6.0, PI, 0.75, 4.0 + radius * 0.1, ichor, "dot", 4.0)
	particles.burst(pos, dir if dir != Vector2.ZERO else Vector2.RIGHT, 6, 340.0, PI, 0.4, 4.0, Color(ichor.r, ichor.g, ichor.b, 0.9), "line", 3.0)
	decals.splat(pos, ichor, radius * (1.9 if boss else 1.25))
	fx_ring(pos, radius * (3.2 if boss else 1.9), ichor)


func vfx_explosion(pos: Vector2, radius: float, color: Color, damage: float = 20.0) -> void:
	# power 1.0 is a mid-size blast (radius 90, 20 damage). Below ~0.5 there is no shake at all;
	# a stack-4 Shrapnel or a big Volatile Core chain is well past 1.5 and shakes hard.
	var power := (radius / 90.0) * sqrt(maxf(damage, 1.0) / 20.0)
	shake(clampf((power - 0.5) * 0.35, 0.0, 0.6))
	if not juice_on:
		return
	particles.burst(pos, Vector2.RIGHT, 16, clampf(radius * 4.0, 160.0, 520.0), PI, 0.5, 4.0, color.lightened(0.35), "line", 3.0)
	particles.burst(pos, Vector2.RIGHT, 8, radius * 2.0, PI, 0.7, 5.0, Color(0.15, 0.13, 0.12, 0.8), "dot", 4.0)
	decals.scorch(pos, radius * 0.6)


## Cheat: shrink every enemy on screen for a few seconds.
func cheat_shrink_all() -> void:
	for e in enemies.get_children():
		e.apply_shrink(Up.p("shrink", "scale"), 6.0, Up.p("shrink", "damage_taken"))


## 0..1: how big the rat pack is between `pack_start` and `pack_full` rats
## (monsters.csv). The bigger the pack, the faster and fiercer each rat.
func rat_pack() -> float:
	return _rat_pack


func _refresh_rat_pack() -> void:
	var p: Dictionary = EnemyS.Monsters.get_stats("rat", "base").get("p", {})
	var start: float = p.get("pack_start", 10.0)
	var full: float = p.get("pack_full", 120.0)
	_rat_pack = clampf((species_count.get("rat", 0) - start) / maxf(full - start, 1.0), 0.0, 1.0)


# ------------------------------------------------------------ spatial grid --
# Bullets used to test every enemy; with hundreds of bullets and monsters that is
# tens of thousands of checks a frame. The grid (rebuilt first thing each frame)
# lets a bullet look only at monsters in the cells its path crosses.

func _physics_process(_delta: float) -> void:
	_grid.clear()
	for e in enemies.get_children():
		var p: Vector2 = e.global_position
		var key := Vector2i(int(floorf(p.x / GRID)), int(floorf(p.y / GRID)))
		if _grid.has(key):
			_grid[key].append(e)
		else:
			_grid[key] = [e]


## Monsters whose cell touches the box around the segment a-b grown by `margin`.
func enemies_near(a: Vector2, b: Vector2, margin: float) -> Array:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(margin, margin)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(margin, margin)
	var out: Array = []
	for cx in range(int(floorf(lo.x / GRID)), int(floorf(hi.x / GRID)) + 1):
		for cy in range(int(floorf(lo.y / GRID)), int(floorf(hi.y / GRID)) + 1):
			var cell = _grid.get(Vector2i(cx, cy))
			if cell != null:
				out.append_array(cell)
	return out
