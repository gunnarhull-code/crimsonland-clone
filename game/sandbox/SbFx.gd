extends Node2D
## Short-lived visual: floating text ("text") or an expanding ring ("ring").

var kind := "text"
var life := 0.7
var t := 0.0
var text := ""
var color := Color.WHITE
var radius := 40.0
var font_size := 14


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := t / life
	match kind:
		"text":
			draw_string(ThemeDB.fallback_font, Vector2(-14, -40.0 * k), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, 1.0 - k * k))
		"ring":
			var r := radius * lerpf(0.5, 1.0, minf(k * 4.0, 1.0))
			draw_circle(Vector2.ZERO, r, Color(color, 0.30 * (1.0 - k)))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color, 1.0 - k), 2.0)
