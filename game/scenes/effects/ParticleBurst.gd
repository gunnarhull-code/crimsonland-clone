extends Node2D
## One generic reusable particle burst (docs/crimsonland-clone/issues/19):
## small colored squares flung outward from the spawn point, fading over
## ~0.3s. Used for hits, deaths, level-up, and Nest destruction alike -
## parameterized by count/color, not a bespoke effect per event.

const LIFETIME := 0.3
const SIZE := 3.0

var _particles: Array = []


func fire(count: int, color: Color) -> void:
	for i in count:
		var angle := randf() * TAU
		var speed := randf_range(80.0, 220.0)
		_particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.RIGHT.rotated(angle) * speed,
			"color": color,
			"life": 0.0,
		})
	queue_redraw()


func _process(delta: float) -> void:
	if _particles.is_empty():
		queue_free()
		return
	var alive: Array = []
	for p in _particles:
		p["life"] += delta
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.9
		if p["life"] < LIFETIME:
			alive.append(p)
	_particles = alive
	queue_redraw()


func _draw() -> void:
	for p in _particles:
		var c: Color = p["color"]
		c.a = 1.0 - (p["life"] / LIFETIME)
		draw_rect(Rect2(p["pos"] - Vector2(SIZE, SIZE) / 2.0, Vector2(SIZE, SIZE)), c)
