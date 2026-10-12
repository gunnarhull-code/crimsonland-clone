extends CanvasLayer
## Sandbox panels, built in code: upgrades on the left, spawn + tuning on the
## right, live stats along the bottom.

const Up := preload("res://sandbox/SbUpgrades.gd")

const PANEL_W := 250.0

var sb
var _panels: Array = []
var _count_labels := {}
var _stats: Label
var _level_label: Label
var _charge_label: Label
var _refresh_t := 0.0


func _ready() -> void:
	_build_left()
	_build_right()
	_stats = Label.new()
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_theme_font_size_override("font_size", 13)
	_stats.add_theme_color_override("font_shadow_color", Color.BLACK)
	_stats.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_stats.position = Vector2(PANEL_W + 20.0, 720.0 - 150.0)
	add_child(_stats)
	var help := Label.new()
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.text = "WASD move   Mouse aim/fire   R reload   H heal   C clear   1-3 spawn 5 at cursor   4-6 spawn boss at cursor   Tab hide panels"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	help.position = Vector2(PANEL_W + 20.0, 4.0)
	add_child(help)


func toggle_panels() -> void:
	for p in _panels:
		p.visible = not p.visible


func _process(delta: float) -> void:
	_refresh_t -= delta
	if _refresh_t > 0.0:
		return
	_refresh_t = 0.1
	for id in _count_labels:
		_count_labels[id].text = str(sb.stack(id))
	_stats.text = _stats_text()


func _stats_text() -> String:
	var p = sb.player
	var rate: float = p.fire_rate()
	var ct: float = p.charge_time()
	var state := ""
	if p.reloading:
		state = "  (reloading)"
	elif p.charging:
		state = "  (charging)"
	var lines: Array[String] = []
	lines.append("HP %d/%d    Ammo %d/%d%s" % [int(p.hp), int(p.MAX_HP), p.ammo, p.MAGAZINE, state])
	lines.append("Fire rate %.2f/s    Charge %.2fs    Bullets per pull %d" % [rate, ct, p.bullets_per_pull()])
	lines.append("Damage per bullet %.1f (before Exploit)    Size x%.1f    Hits per bullet up to %d" % [p.bullet_damage(), p.size_mult(), p.max_enemy_hits()])
	var every: int = p.reclaim_every()
	lines.append("Reclaimer: %s    Bloodshot extra bullets: %d" % [("every %d bullets" % every) if every > 0 else "off", p.extra_bullets()])
	lines.append("Fired %d    Hits %d    Kills %d    Total damage %d" % [sb.fired, sb.hits, sb.kills, int(sb.total_damage)])
	lines.append("DPS (last 5 s) %.0f    Enemies %d    Bullets %d" % [sb.recent_dps(), sb.enemies.get_child_count(), sb.bullets.get_child_count()])
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
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	return box


func _header(box: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(l)


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
	for row in Up.all():
		var id: String = row["id"]
		var h := HBoxContainer.new()
		h.tooltip_text = row["summary"]
		var name_l := Label.new()
		name_l.text = row["name"]
		name_l.custom_minimum_size.x = 100
		name_l.tooltip_text = row["summary"]
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(name_l)
		h.add_child(_button("-", func(): sb.set_stack(id, sb.stack(id) - 1), 28))
		var cnt := Label.new()
		cnt.text = "0"
		cnt.custom_minimum_size.x = 26
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_count_labels[id] = cnt
		h.add_child(cnt)
		h.add_child(_button("+", func(): sb.set_stack(id, sb.stack(id) + 1), 28))
		box.add_child(h)
	box.add_child(HSeparator.new())
	box.add_child(_button("Clear all upgrades", func(): sb.stacks.clear()))
	var tip := Label.new()
	tip.text = "Hover a name for what it does."
	tip.add_theme_font_size_override("font_size", 11)
	tip.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	box.add_child(tip)


func _build_right() -> void:
	var box := _make_panel(false)
	_header(box, "SPAWN  (ring around you)")
	for sp in ["rat", "spider", "alien"]:
		for variant in ["base", "boss"]:
			var h := HBoxContainer.new()
			var l := Label.new()
			l.text = ("%s%s" % [sp.capitalize(), " boss" if variant == "boss" else ""])
			l.custom_minimum_size.x = 80
			h.add_child(l)
			var counts := [1, 5, 20] if variant == "base" else [1, 2]
			for c in counts:
				h.add_child(_button("x%d" % c, func(): sb.spawn_enemies(sp, variant, c), 40))
			box.add_child(h)
	var h2 := HBoxContainer.new()
	h2.add_child(_button("Clear enemies", func(): sb.clear_enemies()))
	box.add_child(h2)

	box.add_child(HSeparator.new())
	_header(box, "ENEMIES")
	_check(box, "Enemies chase and attack", sb.enemies_chase, func(v): sb.enemies_chase = v)
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_level_label)
	var level_slider := HSlider.new()
	level_slider.min_value = 1
	level_slider.max_value = 10
	level_slider.step = 1
	level_slider.value = sb.level
	level_slider.focus_mode = Control.FOCUS_NONE
	level_slider.value_changed.connect(_on_level_changed)
	box.add_child(level_slider)
	_on_level_changed(sb.level)
	var tip := Label.new()
	tip.text = "Level sets HP of NEW spawns (x20 by level 10)."
	tip.add_theme_font_size_override("font_size", 11)
	tip.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)

	box.add_child(HSeparator.new())
	_header(box, "PLAYER")
	_check(box, "God mode", sb.god_mode, func(v): sb.god_mode = v)
	_check(box, "Damage numbers", sb.show_numbers, func(v): sb.show_numbers = v)
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
