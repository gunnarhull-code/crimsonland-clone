extends "res://sandbox/Sandbox.gd"
## The prototype run: 10 levels, an upgrade pick before each (pick N before
## level N, so you hold exactly N upgrades entering level N), die and the run
## ends, clear level 10 and you win. Built on the sandbox world (same player,
## bullets, enemies, upgrade rules and wave runner); only the UI and the flow
## are new. Cheats live in the F1 menu (ProtoUI.gd).
##
## Step 1 of the build plan: run loop + draft + cheats.

const DraftS := preload("res://proto/Draft.gd")
const ProtoUiS := preload("res://proto/ProtoUI.gd")

const RUN_LEVELS := 10
const OFFER_SIZE := 3

var run_state := "menu"       # menu | draft | level | over | won
var run_level := 0            # the level being played, or about to be
var offer: Array = []
var run_kills := 0
var best_level := 0
var last_build := ""


func _build_ui() -> void:
	revive_on_death = false
	ui = ProtoUiS.new()
	ui.run = self
	ui.sb = self
	add_child(ui)


func _after_ready() -> void:
	waves.finished.connect(_on_level_finished)
	ui.show_menu()


## Sandbox hotkeys are off in the run (number keys pick cards). Only reload stays.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		player.start_reload()


# -------------------------------------------------------------- run flow --

func new_run() -> void:
	clear_enemies()
	stacks.clear()
	reset_counters()
	player.max_hp = player.BASE_MAX_HP
	heal()
	run_level = 0
	_advance()


## Move to the next level: first its upgrade pick, or the win screen.
func _advance() -> void:
	run_level += 1
	if run_level > RUN_LEVELS:
		_win()
		return
	open_draft()


func open_draft() -> void:
	offer = DraftS.offer(stacks, run_level, OFFER_SIZE)
	run_state = "draft"
	get_tree().paused = true
	ui.show_draft()


func reroll_draft() -> void:
	if run_state == "draft":
		offer = DraftS.offer(stacks, run_level, OFFER_SIZE)
		ui.show_draft()


func pick(id: String) -> void:
	set_stack(id, raw_stack(id) + 1)
	start_level(run_level)


func start_level(lvl: int) -> void:
	run_level = lvl
	run_state = "level"
	get_tree().paused = false
	ui.hide_overlay()
	waves.start(lvl)


func _on_level_finished(cleared: bool) -> void:
	if run_state != "level":
		return
	if cleared:
		best_level = maxi(best_level, run_level)
		_advance()
	else:
		_lose()


func _lose() -> void:
	run_state = "over"
	last_build = build_text()
	get_tree().paused = true
	ui.show_end(false)


func _win() -> void:
	run_state = "won"
	last_build = build_text()
	get_tree().paused = true
	ui.show_end(true)


func build_text() -> String:
	var lines: Array[String] = []
	for row in Up.all():
		var k := raw_stack(row["id"])
		if k > 0:
			lines.append("%s x%d" % [row["name"], k])
	return ", ".join(lines) if not lines.is_empty() else "(nothing)"


# ---------------------------------------------------------------- cheats --

## Jump straight into a level with whatever you currently own.
func cheat_jump(lvl: int) -> void:
	clear_enemies()
	start_level(clampi(lvl, 1, RUN_LEVELS))


## Throw away your build and roll one the way a real run would reach `lvl`:
## one draft pick per level before it, choosing a random card each time.
func cheat_roll_build(lvl: int) -> void:
	stacks.clear()
	reset_counters()
	for n in range(1, lvl + 1):
		var o := DraftS.offer(stacks, n, OFFER_SIZE)
		if o.is_empty():
			break
		var id: String = o[randi() % o.size()]
		set_stack(id, raw_stack(id) + 1)
	start_level(lvl)


func cheat_skip_level() -> void:
	if run_state == "level":
		waves.force_clear()
