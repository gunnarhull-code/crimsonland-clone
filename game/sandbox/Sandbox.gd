extends Node2D
## Upgrade sandbox: a flat arena where you stack the first ten V2 upgrades
## with +/- buttons and spawn the current monsters (enemies.csv) to test them.
## Run with run-sandbox.bat, or open sandbox/Sandbox.tscn and press F6.
##
## Hotkeys: 1/2/3 = 5 rats/spiders/aliens at the cursor, 4/5/6 = a boss at the
## cursor, C = clear enemies, R = reload, H = heal, Tab = hide panels.

const Up := preload("res://sandbox/SbUpgrades.gd")
const PlayerS := preload("res://sandbox/SbPlayer.gd")
const BulletS := preload("res://sandbox/SbBullet.gd")
const EnemyS := preload("res://sandbox/SbEnemy.gd")
const FxS := preload("res://sandbox/SbFx.gd")
const UiS := preload("res://sandbox/SbUI.gd")

const ARENA := Vector2(1600, 900)
# Performance safety valves (spec 4.3 placeholders).
const MAX_ENEMIES := 400
const MAX_BULLETS := 1500
const MAX_FX := 300
# Spec 13.10: enemy HP scales geometrically to 20x by level 10.
const HP_AT_LEVEL_10 := 20.0
const DPS_WINDOW_SEC := 5.0

var stacks := {}
var fired := 0
var hits := 0
var kills := 0
var total_damage := 0.0

# Tuning / toggles driven by the right-hand panel.
var level := 1
var enemies_chase := true
var god_mode := false
var show_numbers := true
var grow_charge_base := 0.3     # open question 1 in the handoff
var charge_overlaps := true     # ditto: charge overlaps the fire-rate lockout

var player
var enemies: Node2D
var bullets: Node2D
var fx: Node2D
var ui
var _damage_log: Array = []     # [time_sec, amount]


func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = ARENA / 2.0
	var vp := get_viewport_rect().size
	var z := minf(vp.x / ARENA.x, vp.y / ARENA.y)
	cam.zoom = Vector2(z, z)
	add_child(cam)

	enemies = Node2D.new()
	bullets = Node2D.new()
	fx = Node2D.new()
	add_child(enemies)
	add_child(bullets)
	player = PlayerS.new()
	player.sb = self
	player.position = ARENA / 2.0
	add_child(player)
	add_child(fx)

	ui = UiS.new()
	ui.sb = self
	add_child(ui)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0.11, 0.14, 0.11))
	var grid := Color(1, 1, 1, 0.05)
	for x in range(0, int(ARENA.x) + 1, 100):
		draw_line(Vector2(x, 0), Vector2(x, ARENA.y), grid, 1.0)
	for y in range(0, int(ARENA.y) + 1, 100):
		draw_line(Vector2(0, y), Vector2(ARENA.x, y), grid, 1.0)
	draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0.6, 0.6, 0.6), false, 3.0)


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
		KEY_C: clear_enemies()
		KEY_R: player.start_reload()
		KEY_H: heal()
		KEY_TAB: ui.toggle_panels()


# ------------------------------------------------------------------ helpers --

func stack(id: String) -> int:
	return stacks.get(id, 0)


func set_stack(id: String, n: int) -> void:
	stacks[id] = maxi(0, n)


## True while the left button is held and the cursor is not over a panel.
func fire_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		and get_viewport().gui_get_hovered_control() == null


## Enemy HP multiplier for the chosen level (1x at level 1, 20x at level 10).
func hp_mult() -> float:
	return pow(HP_AT_LEVEL_10, (level - 1) / 9.0)


func heal() -> void:
	player.hp = player.MAX_HP
	player.ammo = player.MAGAZINE
	player.reloading = false


func hurt_player(amount: float) -> void:
	player.hp = maxf(1.0, player.hp - amount)


func clear_enemies() -> void:
	for e in enemies.get_children():
		e.queue_free()
	for b in bullets.get_children():
		b.queue_free()


func reset_counters() -> void:
	fired = 0
	hits = 0
	kills = 0
	total_damage = 0.0
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


func fx_text(pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	if not show_numbers or fx.get_child_count() >= MAX_FX:
		return
	var f := FxS.new()
	f.kind = "text"
	f.text = text
	f.color = color
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


# ----------------------------------------------------------------- spawning --

## Spawn `count` enemies. `at` = Vector2 scatters them around that point;
## null places them in a ring around the player.
func spawn_enemies(species: String, variant: String, count: int, at = null) -> void:
	for i in count:
		if enemies.get_child_count() >= MAX_ENEMIES:
			return
		var pos: Vector2
		if at == null:
			pos = player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(350.0, 450.0)
		else:
			pos = at + Vector2.RIGHT.rotated(randf() * TAU) * (randf_range(0.0, 60.0) if count > 1 else 0.0)
		pos = pos.clamp(Vector2(20, 20), ARENA - Vector2(20, 20))
		var e := EnemyS.new()
		e.setup(self, species, variant, pos)
		enemies.add_child(e)


func spawn_bullet(pos: Vector2, dir: Vector2, props: Dictionary) -> void:
	if bullets.get_child_count() >= MAX_BULLETS:
		return
	var b := BulletS.new()
	b.setup(self, pos, dir, props)
	bullets.add_child(b)


# --------------------------------------------------------------- hit logic --

## Damage multiplier Exploit gives against this particular enemy.
func exploit_mult(e) -> float:
	var n := stack("exploit")
	if n == 0:
		return 1.0
	var bonus := Up.p("exploit", "debuff_bonus") if e.is_debuffed() else Up.p("exploit", "all_bonus")
	return 1.0 + bonus * pow(Up.p("exploit", "stack"), n - 1)


## A bullet touched an enemy: damage, on-hit effects, then pierce bookkeeping.
func bullet_hit(b, e) -> void:
	b.hit_set[e.get_instance_id()] = true
	hits += 1
	var dmg: float = b.damage * exploit_mult(e)   # checked before this hit adds a state
	e.take_damage(dmg)
	if not e.dead:
		var n_poison := stack("poison")
		if n_poison > 0:
			e.apply_poison(Up.p("poison", "dps") * pow(Up.p("poison", "dps_stack"), n_poison - 1),
				Up.p("poison", "duration"))
		var n_chill := stack("chill")
		if n_chill > 0:
			e.apply_chill(Up.p("chill", "speed"),
				Up.p("chill", "duration") * pow(Up.p("chill", "duration_stack"), n_chill - 1))
	var n_shrap := stack("shrapnel")
	if n_shrap > 0:
		var radius := Up.p("shrapnel", "radius") * pow(Up.p("shrapnel", "radius_stack"), n_shrap - 1)
		var frac := Up.p("shrapnel", "damage_frac") * pow(Up.p("shrapnel", "damage_stack"), n_shrap - 1)
		explode(e.global_position, radius, dmg * frac)
	b.hits_left -= 1
	if b.hits_left <= 0:
		b.queue_free()
	else:
		b.damage *= 1.0 - b.falloff


## A plain blast: damages every enemy in range, applies no states, counts no hits.
func explode(pos: Vector2, radius: float, damage: float) -> void:
	fx_ring(pos, radius, Color(1.0, 0.6, 0.2))
	for e in enemies.get_children():
		if not e.dead and e.global_position.distance_to(pos) <= radius + e.radius:
			e.take_damage(damage, Color(1.0, 0.7, 0.3))
