extends CanvasLayer
## Prototype UI: HUD, the start / upgrade-pick / end screens, and the F1 cheat
## menu. Runs while the game is paused (draft and end screens pause the tree).

const Up := preload("res://sandbox/SbUpgrades.gd")
const DraftS := preload("res://proto/Draft.gd")

const CHEAT_W := 290.0
const DAMAGE_STEPS := [1.0, 2.0, 5.0, 10.0, 50.0, 100.0, 1000.0]

var run
var sb

var _hud: Label
var _owned: Label
var _overlay: Control
var _box: VBoxContainer
var _cheat_panel: PanelContainer
var _jump_slider: HSlider
var _jump_label: Label
var _up_pick: OptionButton
var _odds_label: Label
var _refresh_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_overlay()
	_build_cheats()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F1:
		_cheat_panel.visible = not _cheat_panel.visible
	elif run.run_state == "draft":
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < run.offer.size():
			run.pick(run.offer[idx])


func _process(delta: float) -> void:
	_refresh_t -= delta
	if _refresh_t > 0.0:
		return
	_refresh_t = 0.1
	var p = sb.player
	var lines: Array[String] = []
	if run.run_state == "level" or run.run_state == "draft":
		lines.append("LEVEL %d / %d      Kills %d" % [run.run_level, run.RUN_LEVELS, sb.kills])
		lines.append(sb.waves.status)
		lines.append("HP %d/%d     Ammo %d/%d%s" % [int(p.hp), int(p.max_hp), p.ammo, p.MAGAZINE, "  (reloading)" if p.reloading else ""])
		lines.append("Dodge: %s" % ("READY (Space)" if p.dodge_cd <= 0.0 else "%.1fs" % p.dodge_cd))
		if sb.stack("adaptive_round") > 0:
			lines.append("Adaptive Round +%.1f%% vs %s   extra damage %d" % [sb.adaptive_bonus() * 100.0, sb.leading_species(), int(sb.adaptive_extra)])
	_hud.text = "\n".join(lines)
	var owned: Array[String] = []
	for row in Up.all():
		var k: int = sb.raw_stack(row["id"])
		if k > 0:
			var tag := "" if sb.stack(row["id"]) > 0 else "  (inactive)"
			owned.append("%s x%d%s" % [row["name"], k, tag])
	_owned.text = ("YOUR UPGRADES\n" + "\n".join(owned)) if not owned.is_empty() else ""


# -------------------------------------------------------------- building --

func _label(text: String, size: int = 14, color: Color = Color.WHITE, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(cb)
	return b


func _build_hud() -> void:
	_hud = _label("", 15)
	_hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hud.position = Vector2(14, 8)
	add_child(_hud)
	_owned = _label("", 13, Color(1.0, 0.9, 0.55))
	_owned.add_theme_color_override("font_shadow_color", Color.BLACK)
	_owned.position = Vector2(14, 120)
	add_child(_owned)
	var hint := _label("F1 cheats   Space dodge   R reload   WASD move   click fire", 12, Color(1, 1, 1, 0.45))
	hint.position = Vector2(14, 700)
	add_child(hint)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	center.add_child(_box)


func _reset_box() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_overlay.visible = true


func hide_overlay() -> void:
	_overlay.visible = false


func show_menu() -> void:
	_reset_box()
	var t := _label("JUNKYARD RUN", 40, Color(1.0, 0.85, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	var body := _label("Prototype.  Clear 10 levels.  Before each level you pick 1 of 3 upgrades,\nso you hold exactly N upgrades entering level N.  Die and the run ends.\n\nF1 opens the cheat menu at any time.", 16, Color.WHITE, true)
	body.custom_minimum_size.x = 620
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(body)
	var b := _button("START RUN", func(): run.new_run())
	b.custom_minimum_size = Vector2(220, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(b)


func show_end(won: bool) -> void:
	_reset_box()
	var t := _label("VICTORY - RUN CLEARED" if won else "RUN OVER", 38, Color(0.5, 1.0, 0.6) if won else Color(1.0, 0.45, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	var text := "Levels cleared: %d / %d\nKills: %d\n\nBuild: %s" % [run.best_level if not won else run.RUN_LEVELS, run.RUN_LEVELS, sb.kills, run.last_build]
	if not won:
		text = "You died on level %d.\n\n%s" % [run.run_level, text]
	var body := _label(text, 16, Color.WHITE, true)
	body.custom_minimum_size.x = 640
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(body)
	var b := _button("NEW RUN", func(): run.new_run())
	b.custom_minimum_size = Vector2(220, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(b)


func show_draft() -> void:
	_reset_box()
	var t := _label("CHOOSE AN UPGRADE", 30, Color(1.0, 0.85, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	var sub := _label("Pick %d of %d   -   before level %d      (keys 1 / 2 / 3)" % [run.run_level, run.RUN_LEVELS, run.run_level], 15, Color(1, 1, 1, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(row)
	for i in run.offer.size():
		row.add_child(_card(run.offer[i], i))
	if run.offer.is_empty():
		_box.add_child(_label("Nothing left to offer.", 16))
		_box.add_child(_button("Continue", func(): run.start_level(run.run_level)))


func _rarity_color(w: float) -> Color:
	if w < 0.2:
		return Color(0.75, 0.78, 0.85)
	if w < 0.5:
		return Color(0.4, 0.7, 1.0)
	if w < 0.8:
		return Color(0.75, 0.5, 1.0)
	return Color(1.0, 0.65, 0.25)


func _card(id: String, idx: int) -> Control:
	var row: Dictionary = Up.get_row(id)
	var w := Up.weight(id)
	var col := _rarity_color(w)
	var owned: int = sb.raw_stack(id)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(310, 340)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.98)
	style.border_color = col
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", style)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_label(row["name"], 24, col))
	var status := "NEW" if owned == 0 else "You own x%d  ->  x%d" % [owned, owned + 1]
	v.add_child(_label(status, 14, Color(0.6, 1.0, 0.7) if owned == 0 else Color(1.0, 0.85, 0.4)))
	var need: String = row.get("requires", "")
	if need != "":
		v.add_child(_label("Chained: needs %s" % Up.get_row(need).get("name", need), 12, Color(1, 1, 1, 0.55)))
	var summary := _label(row["summary"], 13, Color(0.9, 0.9, 0.95), true)
	summary.custom_minimum_size.x = 280
	v.add_child(summary)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var nums := "Now: %s\nWith this pick: %s" % [
		sb.rules.describe(id, owned) if owned > 0 else "not held",
		sb.rules.describe(id, owned + 1)]
	var nl := _label(nums, 12, Color(0.7, 0.9, 1.0), true)
	nl.custom_minimum_size.x = 280
	v.add_child(nl)
	v.add_child(_label("weight %.2f   unlocks at pick %d   ~%d%% to be offered" % [
		w, DraftS.unlock_pick(id), roundi(DraftS.offer_chance(id, sb.stacks, run.run_level) * 100.0)], 11, Color(1, 1, 1, 0.4)))
	var take := _button("TAKE  (%d)" % (idx + 1), func(): run.pick(id))
	take.custom_minimum_size.y = 40
	v.add_child(take)
	return p


# ---------------------------------------------------------------- cheats --

func _build_cheats() -> void:
	_cheat_panel = PanelContainer.new()
	_cheat_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.05, 0.92)
	style.set_content_margin_all(8)
	_cheat_panel.add_theme_stylebox_override("panel", style)
	_cheat_panel.anchor_left = 1.0
	_cheat_panel.anchor_right = 1.0
	_cheat_panel.anchor_top = 0.0
	_cheat_panel.anchor_bottom = 1.0
	_cheat_panel.offset_left = -CHEAT_W
	_cheat_panel.offset_right = 0.0
	add_child(_cheat_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cheat_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)

	box.add_child(_label("CHEATS  (F1 to close)", 15, Color(1.0, 0.5, 0.45)))

	box.add_child(_label("PLAYER", 13, Color(1.0, 0.85, 0.4)))
	_check(box, "God mode", sb.god_mode, func(v): sb.god_mode = v)
	_check(box, "Infinite ammo", sb.infinite_ammo, func(v): sb.infinite_ammo = v)
	_check(box, "Full heal at each level start", sb.heal_on_level_start, func(v): sb.heal_on_level_start = v)
	_check(box, "Damage numbers", sb.show_numbers, func(v): sb.show_numbers = v)
	_check(box, "Particles and splatter", sb.juice_on, func(v): sb.set_juice(v))
	_check(box, "Screen shake", sb.shake_on, func(v): sb.shake_on = v)
	_check(box, "Sound effects", sb.audio.enabled, func(v): sb.audio.enabled = v)
	var dmg_label := _label("Damage dealt x1", 12)
	box.add_child(dmg_label)
	var dmg := HSlider.new()
	dmg.min_value = 0
	dmg.max_value = DAMAGE_STEPS.size() - 1
	dmg.step = 1
	dmg.focus_mode = Control.FOCUS_NONE
	dmg.value_changed.connect(func(v):
		sb.cheat_damage_mult = DAMAGE_STEPS[int(v)]
		dmg_label.text = "Damage dealt x%d" % int(sb.cheat_damage_mult))
	box.add_child(dmg)
	var spd_label := _label("Move speed x1.0", 12)
	box.add_child(spd_label)
	var spd := HSlider.new()
	spd.min_value = 0.5
	spd.max_value = 3.0
	spd.step = 0.25
	spd.value = 1.0
	spd.focus_mode = Control.FOCUS_NONE
	spd.value_changed.connect(func(v):
		sb.move_speed_mult = v
		spd_label.text = "Move speed x%.2f" % v)
	box.add_child(spd)
	var ts_label := _label("Game speed x1.0", 12)
	box.add_child(ts_label)
	var ts := HSlider.new()
	ts.min_value = 0.25
	ts.max_value = 4.0
	ts.step = 0.25
	ts.value = 1.0
	ts.focus_mode = Control.FOCUS_NONE
	ts.value_changed.connect(func(v):
		Engine.time_scale = v
		ts_label.text = "Game speed x%.2f" % v)
	box.add_child(ts)
	var h := HBoxContainer.new()
	h.add_child(_button("Heal", func(): sb.heal()))
	h.add_child(_button("Hurt 25", func(): sb.hurt_player(25.0)))
	h.add_child(_button("Reload", func(): sb.player.start_reload()))
	box.add_child(h)

	box.add_child(HSeparator.new())
	box.add_child(_label("LEVEL", 13, Color(1.0, 0.85, 0.4)))
	_jump_label = _label("Level 1", 12)
	box.add_child(_jump_label)
	_jump_slider = HSlider.new()
	_jump_slider.min_value = 1
	_jump_slider.max_value = 10
	_jump_slider.step = 1
	_jump_slider.value = 1
	_jump_slider.focus_mode = Control.FOCUS_NONE
	_jump_slider.value_changed.connect(func(v): _jump_label.text = "Level %d   (enemy HP x%.1f)" % [int(v), pow(sb.HP_AT_LEVEL_10, (int(v) - 1) / 9.0)])
	box.add_child(_jump_slider)
	box.add_child(_button("Jump to level (keep my upgrades)", func(): run.cheat_jump(int(_jump_slider.value))))
	box.add_child(_button("Roll a build for this level + start", func(): run.cheat_roll_build(int(_jump_slider.value))))
	var h2 := HBoxContainer.new()
	h2.add_child(_button("Skip level", func(): run.cheat_skip_level()))
	h2.add_child(_button("Kill all", func(): sb.clear_enemies()))
	box.add_child(h2)
	box.add_child(_button("Restart run", func(): run.new_run()))

	box.add_child(HSeparator.new())
	box.add_child(_label("UPGRADES", 13, Color(1.0, 0.85, 0.4)))
	_up_pick = OptionButton.new()
	_up_pick.focus_mode = Control.FOCUS_NONE
	for row in Up.all():
		_up_pick.add_item(row["name"])
		_up_pick.set_item_metadata(_up_pick.item_count - 1, row["id"])
	box.add_child(_up_pick)
	var h3 := HBoxContainer.new()
	h3.add_child(_button("+1", func(): _give(1), 50))
	h3.add_child(_button("-1", func(): _give(-1), 50))
	h3.add_child(_button("+1 each", func(): for row in Up.all(): sb.set_stack(row["id"], sb.raw_stack(row["id"]) + 1)))
	h3.add_child(_button("Clear", func(): sb.stacks.clear()))
	box.add_child(h3)
	var h4 := HBoxContainer.new()
	h4.add_child(_button("Extra draft pick", func(): run.open_draft()))
	h4.add_child(_button("Reroll", func(): run.reroll_draft()))
	box.add_child(h4)
	box.add_child(_button("Show draft odds for this level", func(): _show_odds()))
	_odds_label = _label("", 11, Color(0.8, 0.9, 1.0), true)
	box.add_child(_odds_label)

	box.add_child(HSeparator.new())
	box.add_child(_label("SPAWN  (ring around you)", 13, Color(1.0, 0.85, 0.4)))
	for sp in ["rat", "spider", "alien", "tick", "scrapper"]:
		for variant in ["base", "boss"]:
			if variant == "boss" and (sp == "tick" or sp == "scrapper"):
				continue
			var r := HBoxContainer.new()
			var l := _label("%s%s" % [sp.capitalize(), " boss" if variant == "boss" else ""], 12)
			l.custom_minimum_size.x = 84
			r.add_child(l)
			var counts := [1, 5, 20] if variant == "base" else [1, 2]
			for c in counts:
				r.add_child(_button("x%d" % c, func(): sb.spawn_enemies(sp, variant, c), 40))
			box.add_child(r)
	_check(box, "Enemies chase and attack", sb.enemies_chase, func(v): sb.enemies_chase = v)


func _check(box: Control, text: String, value: bool, cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 12)
	c.toggled.connect(cb)
	box.add_child(c)


func _give(delta: int) -> void:
	var id: String = _up_pick.get_item_metadata(_up_pick.selected)
	sb.set_stack(id, sb.raw_stack(id) + delta)


## Offer chances (per card slot x3) for the pick number on the level slider.
func _show_odds() -> void:
	var n := int(_jump_slider.value)
	var rows: Array = []
	for id in DraftS.pool(sb.stacks, n):
		rows.append([DraftS.offer_chance(id, sb.stacks, n), id])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var lines: Array[String] = ["Pick %d: %d upgrades in the pool" % [n, rows.size()]]
	for r in rows:
		lines.append("%s  ~%d%%" % [Up.get_row(r[1]).get("name", r[1]), roundi(r[0] * 100.0)])
	_odds_label.text = "\n".join(lines)
