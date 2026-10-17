extends CanvasLayer
## Always-on performance readout (top right). F2 hides or shows it. Green is
## fine, yellow is borderline, red means the frame rate is hurting.

var sb
var _label: Label
var _t := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.offset_left = -330.0
	_label.offset_right = -10.0
	_label.offset_top = 4.0
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		_label.visible = not _label.visible


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not _label.visible:
		return
	_t = 0.25
	var fps := Engine.get_frames_per_second()
	var col := Color(0.5, 1.0, 0.5) if fps >= 55.0 else (Color(1.0, 0.9, 0.3) if fps >= 30.0 else Color(1.0, 0.4, 0.3))
	_label.add_theme_color_override("font_color", col)
	var fx_n: int = sb.fx.count()
	_label.text = "%d FPS  (%.1f ms)\nenemies %d  bullets %d  text %d  particles %d\ndraw calls %d" % [
		fps, 1000.0 / maxf(fps, 1.0), sb.enemies.get_child_count(), sb.bullets.get_child_count(), fx_n,
		sb.particles.count(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
