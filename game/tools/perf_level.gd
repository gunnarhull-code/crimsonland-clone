extends Node
## Real-renderer probe of a real level: the strafing bot plays level N with some upgrades.
const RUN := preload("res://proto/Run.gd")
var run
var f := 0
var samples: Array = []
var peak_enemies := 0
var lvl := 8
var prof_p := 0.0
var prof_ph := 0.0
var prof_dc := 0.0
var prof_o := 0.0
var prof_n := 0.0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		lvl = int(args[0])
	run = RUN.new()
	add_child(run)
func _physics_process(delta: float) -> void:
	f += 1
	if f == 3:
		run.god_mode = true
		run.set_stack("spread", 2)
		run.set_stack("pierce", 2)
		run.set_stack("quickdraw", 2)
		run.set_stack("shrapnel", 2)
		run.set_stack("poison", 1)
		run.cheat_jump(lvl)
		var mode := int(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else 0
		if mode == 1 or mode == 3:
			run.set_juice(false)
		if mode == 2 or mode == 3:
			run.show_numbers = false
		if mode == 4:
			run.enemies.visible = false
		if mode == 5:
			run.bullets.visible = false
		for pn in run.ui._cheat_panel.get_children():
			pass
	if run.run_state == "level" and f > 3:
		var p = run.player
		p.global_position += Vector2.from_angle(f * 0.03) * 150.0 * delta
		p.global_position = p.global_position.clamp(Vector2(100, 100), Vector2(1500, 800))
		var best = null
		var bd := INF
		for e in run.enemies.get_children():
			var d: float = p.global_position.distance_to(e.global_position)
			if d < bd:
				bd = d
				best = e
		if best:
			p.aim_override = best.global_position
		if p.cooldown <= 0.0 and p.ammo > 0 and not p.charging and not p.reloading:
			p._pull()
		elif p.ammo <= 0:
			p.start_reload()
	if f > 700 and f <= 1500:
		samples.append(Engine.get_frames_per_second())
		prof_p += Performance.get_monitor(Performance.TIME_PROCESS)
		prof_ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		prof_dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prof_o += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		prof_n += 1.0
		peak_enemies = maxi(peak_enemies, run.enemies.get_child_count())
	if f == 1501:
		var s := 0.0
		var mn := 9999.0
		for v in samples:
			s += v
			mn = minf(mn, v)
		print("RESULT level ", lvl, ": avg ", snappedf(s / samples.size(), 0.1), " fps, min ", snappedf(mn, 0.1), ", peak enemies ", peak_enemies, ", bullets now ", run.bullets.get_child_count(), ", fx ", run.fx.count())
		print("  process ", snappedf(prof_p / prof_n * 1000.0, 0.1), " ms, physics ", snappedf(prof_ph / prof_n * 1000.0, 0.1), " ms, draw calls ", int(prof_dc / prof_n), ", canvas objects ", int(prof_o / prof_n))
		get_tree().quit()
