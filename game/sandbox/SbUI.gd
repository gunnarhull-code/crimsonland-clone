extends CanvasLayer
## Sandbox panels, built in code: upgrades on the left, spawn + wave test +
## tuning on the right, live stats along the bottom.

const Up := preload("res://sandbox/SbUpgrades.gd")

const PANEL_W := 270.0

var sb
var _panels: Array = []
var _rows := {}              # id -> {box, name, count}
var _stats: Label
var _level_label: Label
var _level_slider: HSlider
var _charge_label: Label
var _wave_status: Label
var _wave_history: Label
var _start_btn: Button
var _refresh_t := 0.0
var _tip_t := 0.0
var _tip_panel: PanelContainer
var _tip_label: Label
var _row_by_box := {}       # row HBox instance id -> upgrade id


func _ready() -> void:
	_build_left()
	_build_right()
	_stats = Label.new()
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_theme_font_size_override("font_size", 13)
	_stats.add_theme_color_override("font_shadow_color", Color.BLACK)
	_stats.position = Vector2(PANEL_W + 20.0, 720.0 - 150.0)
	add_child(_stats)
	var help := Label.new()
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.text = "WASD move   Space dodge   Mouse aim/fire   R reload   H heal   C clear   1-3 spawn at cursor   4-6 boss   7 ticks   8 scrappers   Tab hide panels"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	help.position = Vector2(PANEL_W + 20.0, 4.0)
	add_child(help)
	_build_tip()


func toggle_panels() -> void:
	for p in _panels:
		p.visible = not p.visible


func _process(delta: float) -> void:
	_update_tip()
	_tip_t -= delta
	if _tip_t <= 0.0:
		_tip_t = 0.3
		_refresh_tooltips()
	_refresh_t -= delta
	if _refresh_t > 0.0:
		return
	_refresh_t = 0.1
	for id in _rows:
		var row: Dictionary = _rows[id]
		var raw: int = sb.raw_stack(id)
		row["count"].text = str(raw)
		var active: bool = sb.stack(id) > 0
		var col := Color(1.0, 0.85, 0.4) if active else (Color(1.0, 0.45, 0.4) if raw > 0 else Color.WHITE)
		row["name"].add_theme_color_override("font_color", col)
	_stats.text = _stats_text()
	_wave_status.text = sb.waves.status
	_wave_history.text = "\n".join(sb.waves.history)
	if sb.waves.running and int(_level_slider.value) != sb.level:
		_level_slider.value = sb.level


func _refresh_tooltips() -> void:
	for id in _rows:
		var row: Dictionary = _rows[id]
		var k: int = sb.raw_stack(id)
		var text: String = row["summary"]
		var req: String = Up.get_row(id).get("requires", "")
		if req != "" and sb.raw_stack(req) <= 0:
			text += "\n\nINACTIVE: needs %s first." % Up.get_row(req).get("name", req)
		text += "\n\nNow (%d stack%s): %s" % [k, "" if k == 1 else "s", sb.rules.describe(id, k) if k > 0 else "not held"]
		text += "\nNext stack (%d): %s" % [k + 1, sb.rules.describe(id, k + 1)]
		row["tip"] = text


func _stats_text() -> String:
	var p = sb.player
	var state := ""
	if p.reloading:
		state = "  (reloading)"
	elif p.charging:
		state = "  (charging)"
	var props: Dictionary = p.pull_props()
	var lines: Array[String] = []
	lines.append("HP %d/%d    Ammo %d/%d%s" % [int(p.hp), int(p.max_hp), p.ammo, p.MAGAZINE, state])
	lines.append("Fire rate %.2f/s    Charge %.2fs    Bullets per pull %d    Heat %d/%d" % [p.fire_rate(), p.charge_time(), p.bullets_per_pull(), p.heat, p.heat_needed()])
	lines.append("Dodge: %s    Latched ticks: %d" % ["ready" if p.dodge_cd <= 0.0 else "%.1fs" % p.dodge_cd, p.latch_count])
	lines.append("Damage per bullet %.1f (before target bonuses)    Size x%.1f    Hits per bullet up to %d" % [props["damage"], props["size"], props["hits"]])
	lines.append("Fired %d    Hits %d    Kills %d    Total damage %d    Most-hit species: %s" % [sb.fired, sb.hits, sb.kills, int(sb.total_damage), sb.leading_species()])
	if sb.stack("adaptive_round") > 0:
		var sh: Dictionary = sb.species_hits
		lines.append("Adaptive Round: +%.1f%% vs %s    extra damage dealt %d    hits  rat %d  spider %d  alien %d" % [sb.adaptive_bonus() * 100.0, sb.leading_species() if sb.leading_species() != "" else "nothing yet", int(sb.adaptive_extra), sh.get("rat", 0), sh.get("spider", 0), sh.get("alien", 0)])
	lines.append("DPS (last 5 s) %.0f    Enemies %d    Bullets %d    Drones %d" % [sb.recent_dps(), sb.enemies.get_child_count(), sb.bullets.get_child_count(), sb.drones.get_child_count()])
	return "\n".join(lines)


# ------------------------------------------------------------------ builders --

func _make_panel(left: bool) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.88)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.anchor_left = 0.0 if left else 1.0
	panel.anchor_right = 0.0 if left else 1.0
	panel.offset_left = 0.0 if left else -PANEL_W
	panel.offset_right = PANEL_W if left else 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	add_child(panel)
	_panels.append(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)
	return box


func _header(box: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(l)


func _note(box: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return l


func _button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(cb)
	return b


func _check(box: Control, text: String, value: bool, cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 12)
	c.toggled.connect(cb)
	box.add_child(c)


func _build_left() -> void:
	var box := _make_panel(true)
	_header(box, "UPGRADES  (stacks)")
	_note(box, "Hover a row for what it does and its numbers.")
	for row in Up.all():
		var id: String = row["id"]
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		var name_l := Label.new()
		name_l.text = row["name"]
		name_l.custom_minimum_size.x = 112
		name_l.add_theme_font_size_override("font_size", 13)
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(name_l)
		h.add_child(_button("-", func(): sb.set_stack(id, sb.raw_stack(id) - 1), 28))
		var cnt := Label.new()
		cnt.text = "0"
		cnt.custom_minimum_size.x = 26
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(cnt)
		h.add_child(_button("+", func(): sb.set_stack(id, sb.raw_stack(id) + 1), 28))
		box.add_child(h)
		_rows[id] = {"box": h, "name": name_l, "count": cnt, "summary": row["summary"]}
		_row_by_box[h.get_instance_id()] = id
	box.add_child(HSeparator.new())
	box.add_child(_button("Clear all upgrades", func(): sb.stacks.clear()))


func _build_right() -> void:
	var box := _make_panel(false)
	_header(box, "WAVE TEST  (level 1-10)")
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_level_label)
	_level_slider = HSlider.new()
	_level_slider.min_value = 1
	_level_slider.max_value = 10
	_level_slider.step = 1
	_level_slider.value = sb.level
	_level_slider.focus_mode = Control.FOCUS_NONE
	_level_slider.value_changed.connect(_on_level_changed)
	box.add_child(_level_slider)
	var wh := HBoxContainer.new()
	_start_btn = _button("Start level", func(): sb.waves.start(int(_level_slider.value)))
	wh.add_child(_start_btn)
	wh.add_child(_button("Stop", func(): sb.waves.stop()))
	box.add_child(wh)
	_wave_status = _note(box, "")
	_wave_history = _note(box, "")
	_note(box, "Level sets enemy HP (x20 by level 10), enemies per wave and wave count. Levels 5 and 10 are the Rat King and Gate Warden (armored, adds at 75/50/25% HP). See levels.csv.")
	_on_level_changed(sb.level)

	box.add_child(HSeparator.new())
	_header(box, "SPAWN  (ring around you)")
	for sp in ["rat", "spider", "alien", "tick", "scrapper"]:
		for variant in ["base", "boss"]:
			if variant == "boss" and (sp == "tick" or sp == "scrapper"):
				continue
			var h := HBoxContainer.new()
			var l := Label.new()
			l.text = ("%s%s" % [sp.capitalize(), " boss" if variant == "boss" else ""])
			l.custom_minimum_size.x = 84
			l.add_theme_font_size_override("font_size", 12)
			h.add_child(l)
			var counts := [1, 5, 20] if variant == "base" else [1, 2]
			for c in counts:
				h.add_child(_button("x%d" % c, func(): sb.spawn_enemies(sp, variant, c), 40))
			box.add_child(h)
	box.add_child(_button("Clear enemies", func(): sb.clear_enemies()))

	box.add_child(HSeparator.new())
	_header(box, "ENEMIES")
	_check(box, "Enemies chase and attack", sb.enemies_chase, func(v): sb.enemies_chase = v)
	_note(box, "The level slider also sets the HP of manually spawned enemies.")

	box.add_child(HSeparator.new())
	_header(box, "PLAYER")
	_check(box, "God mode", sb.god_mode, func(v): sb.god_mode = v)
	_check(box, "Damage numbers", sb.show_numbers, func(v): sb.show_numbers = v)
	_check(box, "Particles and splatter", sb.juice_on, func(v): sb.set_juice(v))
	_check(box, "Screen shake", sb.shake_on, func(v): sb.shake_on = v)
	_check(box, "Sound effects", sb.audio.enabled, func(v): sb.audio.enabled = v)
	var vol := HSlider.new()
	vol.min_value = -24.0
	vol.max_value = 6.0
	vol.step = 1.0
	vol.value = sb.audio.master_db
	vol.focus_mode = Control.FOCUS_NONE
	vol.value_changed.connect(func(v): sb.audio.master_db = v)
	box.add_child(vol)
	_note(box, "Volume (slider above)")
	var h3 := HBoxContainer.new()
	h3.add_child(_button("Heal", func(): sb.heal()))
	h3.add_child(_button("Hurt me 25", func(): sb.hurt_player(25.0)))
	box.add_child(h3)
	box.add_child(_button("Reset counters", func(): sb.reset_counters()))

	box.add_child(HSeparator.new())
	_header(box, "GROW TUNING  (open question)")
	_charge_label = Label.new()
	_charge_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_charge_label)
	var cs := HSlider.new()
	cs.min_value = 0.0
	cs.max_value = 1.5
	cs.step = 0.05
	cs.value = sb.grow_charge_base
	cs.focus_mode = Control.FOCUS_NONE
	cs.value_changed.connect(_on_charge_changed)
	box.add_child(cs)
	_on_charge_changed(sb.grow_charge_base)
	_check(box, "Charge overlaps fire-rate lockout", sb.charge_overlaps, func(v): sb.charge_overlaps = v)


func _on_level_changed(v: float) -> void:
	sb.level = int(v)
	_level_label.text = "Level %d   enemy HP x%.1f" % [sb.level, sb.hp_mult()]


func _on_charge_changed(v: float) -> void:
	sb.grow_charge_base = v
	_charge_label.text = "Base charge time %.2fs (before x1.25 per stack)" % v


# ------------------------------------------------------------------- tooltip --
# Godot's built-in tooltip popup did not show in this window, so the upgrade
# tooltip is drawn here: find the upgrade row under the cursor and show its text
# in a panel beside the left column.

func _build_tip() -> void:
	_tip_panel = PanelContainer.new()
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.96)
	style.border_color = Color(1.0, 0.85, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_tip_panel.add_theme_stylebox_override("panel", style)
	_tip_label = Label.new()
	_tip_label.custom_minimum_size.x = 340
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_font_size_override("font_size", 13)
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_child(_tip_label)
	add_child(_tip_panel)


func _update_tip() -> void:
	var c: Control = get_viewport().gui_get_hovered_control()
	var id := ""
	while c != null:
		if _row_by_box.has(c.get_instance_id()):
			id = _row_by_box[c.get_instance_id()]
			break
		c = c.get_parent() as Control
	if id == "" or not _panels[0].visible:
		_tip_panel.visible = false
		return
	var text: String = _rows[id].get("tip", _rows[id]["summary"])
	_tip_label.text = "%s\n\n%s" % [Up.get_row(id).get("name", id).to_upper(), text]
	_tip_panel.reset_size()
	var vp := get_viewport().get_visible_rect().size
	var y := clampf(get_viewport().get_mouse_position().y - 20.0, 4.0, maxf(4.0, vp.y - _tip_panel.size.y - 4.0))
	_tip_panel.position = Vector2(PANEL_W + 8.0, y)
	_tip_panel.visible = true
