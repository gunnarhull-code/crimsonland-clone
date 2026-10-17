extends RefCounted
## Procedural art: everything is drawn with vector shapes, no image files.
## All monsters and the player are drawn facing +x (the caller sets the angle),
## so changing a look means editing one function here.

const ICHOR := {
	"rat": Color(0.62, 0.07, 0.10),
	"spider": Color(0.74, 0.88, 0.16),
	"alien": Color(0.25, 0.95, 0.70),
	"tick": Color(0.55, 0.06, 0.22),
	"scrapper": Color(0.85, 0.55, 0.2),
	"maggot": Color(0.88, 0.86, 0.45),
	"fly": Color(0.45, 0.85, 0.4),
	"nest": Color(0.42, 0.3, 0.2),
}


static func ichor(species: String) -> Color:
	return ICHOR.get(species, Color(0.7, 0.1, 0.1))


static var _units := {}   # unit circles by segment count, so ellipses cost no sin/cos per frame


static func _unit(seg: int) -> PackedVector2Array:
	if not _units.has(seg):
		var u := PackedVector2Array()
		for i in seg:
			u.append(Vector2(cos(TAU * i / seg), sin(TAU * i / seg)))
		_units[seg] = u
	return _units[seg]


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, seg: int = 16) -> void:
	var u := _unit(seg)
	var pts := PackedVector2Array()
	pts.resize(seg)
	for i in seg:
		pts[i] = Vector2(c.x + u[i].x * rx, c.y + u[i].y * ry)
	ci.draw_colored_polygon(pts, col)


static func _t(col: Color, tint: Color) -> Color:
	return Color(col.r * tint.r, col.g * tint.g, col.b * tint.b, col.a)


# --------------------------------------------------------------- monsters --

## species: rat | spider | alien. r is the hitbox radius, phase drives the walk
## cycle, tint multiplies every colour (hit flash, poison, chill), pop > 0 puffs
## the body up briefly when hit.
static func draw_enemy(ci: CanvasItem, species: String, boss: bool, r: float, angle: float,
		phase: float, tint: Color, pop: float, armored: bool, offset: Vector2 = Vector2.ZERO, extra: float = 0.0, low: bool = false) -> void:
	var s := 1.0 + pop
	ci.draw_set_transform(offset, angle, Vector2(s, s))
	match species:
		"rat":
			if low and not boss:
				_rat_low(ci, r, phase, tint, extra)
			else:
				_rat(ci, r, phase, tint, boss, extra)
		"spider":
			_spider(ci, r, phase, tint, boss)
		"tick":
			_tick(ci, r, phase, tint, extra)
		"maggot":
			_maggot(ci, r, phase, tint)
		"fly":
			_fly(ci, r, phase, tint)
		"nest":
			_nest(ci, r, phase, tint)
		"scrapper":
			_scrapper(ci, r, phase, tint, extra)
		_:
			_alien(ci, r, phase, tint, boss, armored)
	ci.draw_set_transform(offset, 0.0, Vector2.ONE)


static func _rat(ci: CanvasItem, r: float, phase: float, tint: Color, boss: bool, pack: float = 0.0) -> void:
	var fur := _t(Color(0.50, 0.42, 0.36), tint)
	var dark := _t(Color(0.30, 0.24, 0.20), tint)
	var pink := _t(Color(0.88, 0.60, 0.64), tint)
	# tail, swaying
	var tail := PackedVector2Array()
	for i in 7:
		tail.append(Vector2(-r * (1.0 + i * 0.30), sin(phase * 0.8 + i * 0.7) * r * 0.22 * (0.3 + i / 6.0)))
	ci.draw_polyline(tail, pink, maxf(1.5, r * 0.14))
	# legs
	for side in [-1.0, 1.0]:
		var sw := sin(phase + (0.0 if side > 0.0 else PI)) * r * 0.28
		_ellipse(ci, Vector2(r * 0.55 + sw, side * r * 0.78), r * 0.22, r * 0.14, dark, 8)
		_ellipse(ci, Vector2(-r * 0.55 - sw, side * r * 0.78), r * 0.22, r * 0.14, dark, 8)
	# body and head
	_ellipse(ci, Vector2(-r * 0.15, 0), r * 1.05, r * 0.78, fur)
	_ellipse(ci, Vector2(-r * 0.2, 0), r * 0.7, r * 0.42, _t(Color(0.66, 0.58, 0.50), tint))
	_ellipse(ci, Vector2(r * 0.85, 0), r * 0.62, r * 0.48, fur)
	ci.draw_circle(Vector2(r * 1.42, 0), r * 0.13, pink)
	# ears
	for side in [-1.0, 1.0]:
		ci.draw_circle(Vector2(r * 0.55, side * r * 0.52), r * 0.30, dark)
		ci.draw_circle(Vector2(r * 0.55, side * r * 0.52), r * 0.19, pink)
	# eyes and whiskers
	for side in [-1.0, 1.0]:
		ci.draw_circle(Vector2(r * 1.05, side * r * 0.26), r * (0.11 + 0.07 * pack), Color(0.95, 0.15 + 0.35 * pack, 0.15))
		ci.draw_circle(Vector2(r * 1.08, side * r * 0.23), r * 0.04, Color.WHITE)
		ci.draw_line(Vector2(r * 1.38, side * r * 0.10), Vector2(r * 1.8, side * r * 0.42), Color(0.9, 0.9, 0.9, 0.7), 1.0)
	if boss:
		var crown := PackedVector2Array()
		for i in 9:
			var a := PI * 0.5 + (TAU * i / 9.0)
			var rad := r * (0.62 if i % 2 == 0 else 0.42)
			crown.append(Vector2(r * 0.8, 0) + Vector2(cos(a), sin(a)) * rad)
		ci.draw_colored_polygon(crown, _t(Color(1.0, 0.82, 0.25), tint))
		ci.draw_circle(Vector2(r * 0.8, 0), r * 0.16, Color(0.9, 0.2, 0.2))


static func _spider(ci: CanvasItem, r: float, phase: float, tint: Color, boss: bool) -> void:
	var body := _t(Color(0.30, 0.18, 0.12), tint)
	var accent := _t(Color(0.97, 0.58, 0.22), tint)
	var lw := maxf(2.0, r * 0.14)
	# eight legs, two segments each, alternating gait
	for side in [-1.0, 1.0]:
		for i in 4:
			var root := Vector2(r * (0.5 - i * 0.28), side * r * 0.25)
			var ang_deg := 38.0 + i * 30.0
			var swing := sin(phase + (PI if (i % 2 == 0) == (side > 0.0) else 0.0)) * 0.32
			var ang: float = deg_to_rad(ang_deg) * side + swing * side
			var knee := root + Vector2.from_angle(ang) * r * 1.0
			var foot := knee + Vector2.from_angle(ang - side * 0.75) * r * 0.9
			ci.draw_polyline(PackedVector2Array([root, knee, foot]), body, lw)
			ci.draw_circle(knee, lw * 0.6, accent)
	_ellipse(ci, Vector2(-r * 0.62, 0), r * 0.92, r * 0.72, body)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.35, 0), Vector2(-r * 0.7, r * 0.26),
		Vector2(-r * 1.05, 0), Vector2(-r * 0.7, -r * 0.26)]), accent)
	_ellipse(ci, Vector2(r * 0.38, 0), r * 0.58, r * 0.46, _t(Color(0.38, 0.22, 0.15), tint))
	for e in [Vector2(0.72, 0.13), Vector2(0.72, -0.13), Vector2(0.6, 0.3), Vector2(0.6, -0.3)]:
		ci.draw_circle(e * r, r * 0.085, Color(1.0, 0.35, 0.15))
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(r * 0.92, side * r * 0.12), Vector2(r * 1.2, side * r * 0.05), accent, lw * 0.8)
	if boss:
		for i in 3:
			var x := -r * (0.3 + i * 0.45)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x, -r * 0.5), Vector2(x - r * 0.12, -r * 0.78), Vector2(x - r * 0.24, -r * 0.5)]), accent)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x, r * 0.5), Vector2(x - r * 0.12, r * 0.78), Vector2(x - r * 0.24, r * 0.5)]), accent)


static func _alien(ci: CanvasItem, r: float, phase: float, tint: Color, boss: bool, armored: bool) -> void:
	var skin := _t(Color(0.66, 0.38, 0.62), tint)
	var skin_dark := _t(Color(0.42, 0.22, 0.46), tint)
	var glow := _t(Color(0.35, 0.95, 0.85), tint)
	# feet
	for side in [-1.0, 1.0]:
		var sw := sin(phase + (0.0 if side > 0.0 else PI)) * r * 0.22
		_ellipse(ci, Vector2(-r * 0.75 + sw, side * r * 0.4), r * 0.3, r * 0.17, skin_dark, 8)
	# arms with claws, swinging
	for side in [-1.0, 1.0]:
		var sw2 := sin(phase + (PI if side > 0.0 else 0.0)) * r * 0.18
		var hand := Vector2(r * 0.78 + sw2, side * r * 0.98)
		ci.draw_polyline(PackedVector2Array([Vector2(0, side * r * 0.5), Vector2(r * 0.35, side * r * 0.85), hand]), skin_dark, maxf(2.0, r * 0.16))
		for k in 3:
			ci.draw_line(hand, hand + Vector2(r * 0.28, (k - 1) * r * 0.14), Color(0.9, 0.9, 0.85), 1.5)
	# torso and head
	_ellipse(ci, Vector2(-r * 0.25, 0), r * 0.82, r * 0.64, skin_dark)
	_ellipse(ci, Vector2(-r * 0.2, 0), r * 0.62, r * 0.46, skin)
	if armored or boss:
		var plate := _t(Color(0.56, 0.52, 0.47), tint)
		for i in 3:
			var x := -r * 0.7 + i * r * 0.42
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x, -r * 0.6), Vector2(x + r * 0.34, -r * 0.5),
				Vector2(x + r * 0.34, r * 0.5), Vector2(x, r * 0.6)]), plate)
			ci.draw_circle(Vector2(x + r * 0.17, -r * 0.34), r * 0.05, Color(0.2, 0.2, 0.2))
			ci.draw_circle(Vector2(x + r * 0.17, r * 0.34), r * 0.05, Color(0.2, 0.2, 0.2))
	_ellipse(ci, Vector2(r * 0.5, 0), r * 0.72, r * 0.62, skin)
	# antennae with glowing bulbs
	for side in [-1.0, 1.0]:
		var tip := Vector2(r * 1.15, side * r * 0.95)
		ci.draw_line(Vector2(r * 0.7, side * r * 0.4), tip, skin_dark, 1.5)
		ci.draw_circle(tip, r * 0.1, glow)
	# big glossy eyes
	for side in [-1.0, 1.0]:
		_ellipse(ci, Vector2(r * 0.78, side * r * 0.3), r * 0.3, r * 0.17, Color(0.04, 0.02, 0.08), 12)
		ci.draw_circle(Vector2(r * 0.86, side * r * 0.26), r * 0.05, Color.WHITE)
	ci.draw_line(Vector2(r * 1.12, -r * 0.14), Vector2(r * 1.12, r * 0.14), glow, 2.0)
	if boss:
		for i in 5:
			var y := (i - 2) * r * 0.26
			ci.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.2, y - r * 0.08), Vector2(-r * 0.12, y), Vector2(r * 0.2, y + r * 0.08)]), glow)


# ----------------------------------------------------------- status marks --

## Drawn in world orientation (no rotation) on top of the body.
static func draw_status(ci: CanvasItem, r: float, t: float, poisoned: bool, chilled: bool, stunned: bool, shards: int) -> void:
	if poisoned:
		for i in 3:
			var k := fmod(t * 0.9 + i * 0.33, 1.0)
			var p := Vector2(sin(i * 2.1 + t * 2.0) * r * 0.7, r * 0.5 - k * r * 1.6)
			ci.draw_circle(p, r * (0.10 + 0.08 * (1.0 - k)), Color(0.5, 1.0, 0.35, 0.85 * (1.0 - k)))
	if chilled:
		for i in 5:
			var a := TAU * i / 5.0 + 0.4
			var base := Vector2.from_angle(a) * r * 0.95
			ci.draw_colored_polygon(PackedVector2Array([base + Vector2.from_angle(a) * r * 0.45,
				base + Vector2.from_angle(a + 1.57) * r * 0.12, base + Vector2.from_angle(a - 1.57) * r * 0.12]),
				Color(0.7, 0.9, 1.0, 0.85))
	if stunned:
		for i in 3:
			var a := t * 5.0 + TAU * i / 3.0
			var p := Vector2(cos(a) * r * 0.8, -r * 0.9 + sin(a) * r * 0.25)
			ci.draw_circle(p, r * 0.12, Color(1.0, 0.95, 0.3))
	for i in shards:
		ci.draw_circle(Vector2.RIGHT.rotated(i * 1.1) * (r + 3.0), 2.0, Color(0.85, 0.95, 1.0))


# ----------------------------------------------------------------- player --

static func draw_player(ci: CanvasItem, r: float, angle: float, flash: float, recoil: float, t: float) -> void:
	ci.draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	var jacket := Color(0.33, 0.52, 0.88)
	var jacket_dark := Color(0.22, 0.36, 0.66)
	var hood := Color(0.18, 0.26, 0.36)
	var skin := Color(0.86, 0.68, 0.55)
	# scrap backpack
	ci.draw_rect(Rect2(-r * 1.0, -r * 0.55, r * 0.6, r * 1.1), Color(0.45, 0.34, 0.24))
	ci.draw_rect(Rect2(-r * 1.1, -r * 0.3, r * 0.2, r * 0.25), Color(0.7, 0.3, 0.2))
	ci.draw_circle(Vector2(-r * 0.8, r * 0.35), r * 0.14, Color(0.7, 0.7, 0.72))
	# arms toward the pistol
	var gun_x := r * 0.95 - recoil
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(0.0, side * r * 0.85), Vector2(gun_x, side * r * 0.22), jacket_dark, r * 0.32)
		ci.draw_circle(Vector2(gun_x, side * r * 0.2), r * 0.17, skin)
	# pistol
	ci.draw_rect(Rect2(gun_x - r * 0.1, -r * 0.13, r * 0.95, r * 0.26), Color(0.22, 0.23, 0.26))
	ci.draw_rect(Rect2(gun_x + r * 0.55, -r * 0.08, r * 0.3, r * 0.16), Color(0.9, 0.55, 0.15))
	# shoulders, head, goggles
	_ellipse(ci, Vector2(-r * 0.1, 0), r * 0.62, r * 1.0, jacket)
	_ellipse(ci, Vector2(0, 0), r * 0.52, r * 0.52, hood)
	for side in [-1.0, 1.0]:
		ci.draw_circle(Vector2(r * 0.34, side * r * 0.24), r * 0.14, Color(1.0, 0.85, 0.3))
		ci.draw_circle(Vector2(r * 0.37, side * r * 0.22), r * 0.05, Color.WHITE)
	if flash > 0.0:
		var k := flash / 0.06
		var m := Vector2(gun_x + r * 0.95, 0)
		var star := PackedVector2Array()
		for i in 10:
			var a := TAU * i / 10.0
			var rad := r * (1.1 if i % 2 == 0 else 0.35) * k
			star.append(m + Vector2(cos(a) * rad, sin(a) * rad * 0.7))
		ci.draw_colored_polygon(star, Color(1.0, 0.85, 0.35, 0.9))
		ci.draw_circle(m, r * 0.3 * k, Color(1.0, 1.0, 0.85))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Tick: small armoured parasite. `engorge` 0..1 swells the abdomen while latched.
static func _tick(ci: CanvasItem, r: float, phase: float, tint: Color, engorge: float) -> void:
	var body := _t(Color(0.50, 0.17, 0.15), tint)
	var plate := _t(Color(0.22, 0.12, 0.10), tint)
	var lw := maxf(1.5, r * 0.18)
	for side in [-1.0, 1.0]:
		for i in 4:
			var root := Vector2(r * (0.5 - i * 0.35), side * r * 0.4)
			var swing := sin(phase * 1.6 + i * 1.3 + (0.0 if side > 0.0 else PI)) * 0.35
			var ang: float = (0.7 + i * 0.28) * side + swing * side
			ci.draw_line(root, root + Vector2.from_angle(ang) * r * 1.15, plate, lw)
	var swell := 1.0 + engorge * 0.9
	_ellipse(ci, Vector2(-r * 0.45, 0), r * 1.05 * swell, r * 0.85 * swell, body)
	_ellipse(ci, Vector2(-r * 0.5, 0), r * 0.55 * swell, r * 0.4 * swell, _t(Color(0.78, 0.35, 0.28), tint))
	_ellipse(ci, Vector2(r * 0.55, 0), r * 0.5, r * 0.42, plate)
	ci.draw_line(Vector2(r * 0.95, 0), Vector2(r * 1.5, 0), Color(0.85, 0.8, 0.7), maxf(1.0, r * 0.12))


## Scrapper: junk golem. `plate_rad` is the width of the frontal bullet plate in radians.
static func _scrapper(ci: CanvasItem, r: float, phase: float, tint: Color, plate_rad: float) -> void:
	var rust := _t(Color(0.42, 0.26, 0.17), tint)
	var rust_dark := _t(Color(0.26, 0.16, 0.11), tint)
	var steel := _t(Color(0.60, 0.62, 0.66), tint)
	for side in [-1.0, 1.0]:   # stubby legs
		var sw := sin(phase + (0.0 if side > 0.0 else PI)) * r * 0.25
		_ellipse(ci, Vector2(-r * 0.3 + sw, side * r * 0.75), r * 0.38, r * 0.24, rust_dark, 8)
	var body := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		var rad := r * (0.95 if i % 2 == 0 else 0.8)
		body.append(Vector2(cos(a) * rad, sin(a) * rad))
	ci.draw_colored_polygon(body, rust)
	for k in 4:   # bolts and scrap patches
		var a := TAU * k / 4.0 + 0.5
		ci.draw_circle(Vector2.from_angle(a) * r * 0.55, r * 0.07, steel)
	ci.draw_rect(Rect2(-r * 0.7, -r * 0.2, r * 0.5, r * 0.4), rust_dark)
	# glowing lantern eye
	ci.draw_circle(Vector2(r * 0.35, 0), r * 0.2, Color(1.0, 0.55, 0.15))
	ci.draw_circle(Vector2(r * 0.4, 0), r * 0.09, Color(1.0, 0.95, 0.7))
	# frontal plate: a thick steel arc across the front
	if plate_rad > 0.0:
		ci.draw_arc(Vector2.ZERO, r * 1.08, -plate_rad * 0.5, plate_rad * 0.5, 20, steel, r * 0.34)
		ci.draw_arc(Vector2.ZERO, r * 1.22, -plate_rad * 0.5, plate_rad * 0.5, 20, _t(Color(0.78, 0.8, 0.84), tint), maxf(1.5, r * 0.08))


## Cheap rat for big crowds: tail, body, head, two eyes (about 8 draw calls instead of 40).
static func _rat_low(ci: CanvasItem, r: float, phase: float, tint: Color, pack: float) -> void:
	var fur := _t(Color(0.50, 0.42, 0.36), tint)
	var sway := sin(phase * 0.8) * r * 0.3
	ci.draw_polyline(PackedVector2Array([Vector2(-r, 0), Vector2(-r * 1.6, sway * 0.5), Vector2(-r * 2.3, sway)]), _t(Color(0.88, 0.60, 0.64), tint), maxf(1.5, r * 0.14))
	_ellipse(ci, Vector2(-r * 0.15, 0), r * 1.05, r * 0.78, fur, 10)
	_ellipse(ci, Vector2(r * 0.85, 0), r * 0.62, r * 0.48, fur, 8)
	var eye := Color(0.95, 0.15 + 0.35 * pack, 0.15)
	ci.draw_circle(Vector2(r * 1.05, r * 0.26), r * (0.12 + 0.07 * pack), eye)
	ci.draw_circle(Vector2(r * 1.05, -r * 0.26), r * (0.12 + 0.07 * pack), eye)


## Soft ground shadow polygon for a monster of this radius (cached unit circle).
static func shadow(radius: float) -> PackedVector2Array:
	var u := _unit(14)
	var pts := PackedVector2Array()
	pts.resize(14)
	for i in 14:
		pts[i] = Vector2(u[i].x * radius * 1.3 + 3.0, u[i].y * radius * 0.95 + 5.0)
	return pts


## Maggot: four soft segments on a squirming line.
static func _maggot(ci: CanvasItem, r: float, phase: float, tint: Color) -> void:
	var body := _t(Color(0.93, 0.90, 0.68), tint)
	var shade := _t(Color(0.74, 0.70, 0.46), tint)
	for i in 4:
		var x := -r * 0.9 * i
		var y := sin(phase * 1.4 + i * 1.1) * r * 0.45
		var rad := r * (1.0 - i * 0.14)
		ci.draw_circle(Vector2(x, y) + Vector2(0.5, 1.0), rad, shade)
		ci.draw_circle(Vector2(x, y), rad * 0.9, body)
	ci.draw_circle(Vector2(r * 0.35, sin(phase * 1.4) * r * 0.45), r * 0.18, Color(0.15, 0.1, 0.05))


## Fly: small, dark, glossy, with blurred buzzing wings.
static func _fly(ci: CanvasItem, r: float, phase: float, tint: Color) -> void:
	var body := _t(Color(0.13, 0.17, 0.2), tint)
	var sheen := _t(Color(0.25, 0.7, 0.55), tint)
	var buzz := 0.5 + 0.5 * sin(phase * 6.0)
	for side in [-1.0, 1.0]:
		var ang: float = side * (0.9 + 0.35 * buzz)
		var wing := PackedVector2Array()
		var u := _unit(10)
		for i in 10:
			var v := Vector2(u[i].x * r * 1.5, u[i].y * r * 0.55)
			wing.append((v + Vector2(r * 0.9, 0)).rotated(ang) + Vector2(-r * 0.2, 0))
		ci.draw_colored_polygon(wing, Color(0.85, 0.92, 1.0, 0.30 + 0.25 * buzz))
	_ellipse(ci, Vector2(-r * 0.35, 0), r * 0.95, r * 0.6, body, 10)
	_ellipse(ci, Vector2(-r * 0.4, 0), r * 0.5, r * 0.28, sheen, 8)
	ci.draw_circle(Vector2(r * 0.7, 0), r * 0.5, body)
	ci.draw_circle(Vector2(r * 0.85, r * 0.25), r * 0.22, Color(1.0, 0.25, 0.2))
	ci.draw_circle(Vector2(r * 0.85, -r * 0.25), r * 0.22, Color(1.0, 0.25, 0.2))


## Cocoon wrapped round a pupating maggot (drawn in world orientation).
static func draw_cocoon(ci: CanvasItem, r: float, shake: Vector2) -> void:
	_ellipse(ci, shake, r * 2.0, r * 1.4, Color(0.95, 0.93, 0.8, 0.9), 12)
	for i in 3:
		var y := (i - 1) * r * 0.6
		ci.draw_line(shake + Vector2(-r * 1.5, y), shake + Vector2(r * 1.5, y), Color(0.7, 0.68, 0.55, 0.9), 1.2)
	ci.draw_circle(shake + Vector2(r * 0.4, -r * 0.1), r * 0.3, Color(0.5, 0.65, 0.3, 0.7))


## Nest: a hole in the ground ringed with churned dirt, with something pale writhing inside.
static func _nest(ci: CanvasItem, r: float, phase: float, tint: Color) -> void:
	_ellipse(ci, Vector2.ZERO, r * 1.3, r * 1.3, _t(Color(0.25, 0.18, 0.12), tint), 16)
	_ellipse(ci, Vector2.ZERO, r * 1.05, r * 1.05, _t(Color(0.4, 0.29, 0.19), tint), 16)
	_ellipse(ci, Vector2.ZERO, r * 0.85, r * 0.85, Color(0.01, 0.01, 0.01), 16)
	for i in 6:   # clods of earth round the rim
		var a := TAU * i / 6.0 + 0.3
		ci.draw_circle(Vector2.from_angle(a) * r * 1.12, r * 0.14, _t(Color(0.5, 0.37, 0.25), tint))
	for i in 3:   # pale worms squirming in the dark
		var a2 := phase * 0.7 + i * 2.1
		var p := Vector2.from_angle(a2) * r * 0.35
		ci.draw_circle(p, r * 0.13, Color(0.93, 0.9, 0.68))
		ci.draw_circle(p + Vector2.from_angle(a2 + 1.6) * r * 0.18, r * 0.11, Color(0.8, 0.77, 0.55))
