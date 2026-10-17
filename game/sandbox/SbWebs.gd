extends Node2D
## Spider webs laid by the Matriarch. Stepping on one holds the player in place
## for about a second (shooting still works). The player's dodge breaks free
## instantly; a dodge in progress ignores webs; blasts burn them away. A web is
## used up when it catches the player, and it fades after its lifetime.

const MAX := 16

var sb
var _webs: Array = []   # {pos, t, life, r, hold}


func add(pos: Vector2, radius: float, hold: float, life: float) -> void:
	if _webs.size() >= MAX:
		_webs.pop_front()
	_webs.append({"pos": pos, "t": 0.0, "life": life, "r": radius, "hold": hold})


func clear() -> void:
	_webs.clear()


## Blasts burn webs inside the blast.
func burn(pos: Vector2, radius: float) -> void:
	_webs = _webs.filter(func(w): return w["pos"].distance_to(pos) > radius + w["r"])


func _physics_process(delta: float) -> void:
	var p = sb.player
	for w in _webs:
		w["t"] += delta
		if p.hp > 0.0 and not p.is_invulnerable() and p.held_t <= 0.0 \
				and w["pos"].distance_to(p.global_position) <= w["r"] + p.RADIUS * 0.4:
			p.web_hold(w["hold"])
			w["t"] = w["life"]   # used up
	_webs = _webs.filter(func(w): return w["t"] < w["life"])
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for w in _webs:
		var a := clampf((w["life"] - w["t"]) / 2.0, 0.0, 1.0) * clampf(w["t"] / 0.25, 0.0, 1.0)
		var r: float = w["r"] * minf(1.0, 0.4 + w["t"] * 3.0)
		var c := Color(0.88, 0.92, 1.0, 0.75 * a)
		for i in 8:
			var ang := TAU * i / 8.0
			draw_line(w["pos"], w["pos"] + Vector2.from_angle(ang) * r, c, 1.5)
		for k in [0.35, 0.65, 1.0]:
			draw_arc(w["pos"], r * k, 0.0, TAU, 20, Color(c.r, c.g, c.b, c.a * 0.8), 1.2)
		draw_circle(w["pos"] + Vector2(sin(now * 3.0 + w["pos"].x), 0) * 1.5, 2.0, Color(1, 1, 1, 0.5 * a))
