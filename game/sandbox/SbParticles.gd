extends Node2D
## Tiny particle system for sparks, gore bits and debris. Kinds: "dot" and
## "line" (a streak along the velocity). Capped so a big build can't tank the
## frame rate. Drawing is batched: all particles of a similar size go out in one
## draw_multiline call, not one draw call each.

const MAX := 600
const BURSTS_PER_FRAME := 40

var enabled := true
var bursts_this_frame := 0
var _p: Array = []   # [pos, vel, life, max_life, size, color, kind, drag]


func add(pos: Vector2, vel: Vector2, life: float, size: float, color: Color, kind: String = "dot", drag: float = 3.0) -> void:
	if not enabled or _p.size() >= MAX:
		return
	_p.append([pos, vel, life, life, size, color, kind, drag])


func count() -> int:
	return _p.size()


## `count` particles leaving `pos` around direction `dir` (spread in radians).
func burst(pos: Vector2, dir: Vector2, count: int, speed: float, spread: float, life: float,
		size: float, color: Color, kind: String = "dot", drag: float = 3.0) -> void:
	if not enabled or bursts_this_frame >= BURSTS_PER_FRAME:
		return
	bursts_this_frame += 1
	var base := dir.angle()
	for i in count:
		var a := base + randf_range(-spread, spread)
		var v := Vector2.from_angle(a) * speed * randf_range(0.4, 1.0)
		add(pos, v, life * randf_range(0.6, 1.0), size * randf_range(0.7, 1.2), color, kind, drag)


func _physics_process(delta: float) -> void:
	bursts_this_frame = 0
	var i := 0
	while i < _p.size():
		var p: Array = _p[i]
		p[2] -= delta
		if p[2] <= 0.0:
			_p[i] = _p[_p.size() - 1]
			_p.pop_back()
			continue
		p[1] = p[1] * maxf(0.0, 1.0 - p[7] * delta)
		p[0] = p[0] + p[1] * delta
		i += 1
	queue_redraw()


func _draw() -> void:
	# bucket by line width so each bucket is a single draw call
	var pts := {}
	var cols := {}
	for p in _p:
		var k: float = p[2] / p[3]
		var c: Color = p[5]
		c.a *= minf(1.0, k * 1.6)
		var w: int
		var a: Vector2 = p[0]
		var b: Vector2
		if p[6] == "line":
			var v: Vector2 = p[1]
			var d := v.normalized() if v.length() > 1.0 else Vector2.RIGHT
			b = a - d * p[4] * (1.5 + v.length() * 0.012)
			w = clampi(roundi(p[4] * 0.45), 1, 4)
		else:
			b = a + Vector2(0.6, 0.0)
			w = clampi(roundi(p[4] * (0.5 + 0.5 * k) * 2.0), 2, 12)
		if not pts.has(w):
			pts[w] = PackedVector2Array()
			cols[w] = PackedColorArray()
		pts[w].append(a)
		pts[w].append(b)
		cols[w].append(c)
	for w in pts:
		draw_multiline_colors(pts[w], cols[w], float(w))
