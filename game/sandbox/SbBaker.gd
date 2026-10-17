extends Node
## Draws every monster once, at startup, into one sprite sheet: 12 walk-cycle
## frames per monster, facing right. After that a monster on screen is a single
## sprite (rotated, scaled and tinted by the GPU) instead of dozens of polygons
## the CPU has to rebuild every frame, which is what made big crowds crawl.
## The art itself is still the vector drawing in SbArt.gd; this just caches it.
## If the sheet cannot be produced (headless runs), monsters fall back to
## drawing themselves directly.

const Art := preload("res://sandbox/SbArt.gd")
const Monsters := preload("res://sandbox/SbMonsters.gd")

const FRAMES := 12
const CELL := 160

var ready_flag := false
var atlas: Texture2D
var _rows := {}      # key -> row index
var _specs: Array = []


## Lookup key: species, variant and a flag (0 normal, 1 pack-angry rat / swollen tick).
static func key(species: String, variant: String, flag: int = 0) -> String:
	return "%s_%s_%d" % [species, variant, flag]


func rect(k: String, frame: int) -> Rect2:
	return Rect2(frame * CELL, _rows[k] * CELL, CELL, CELL)


func has_key(k: String) -> bool:
	return _rows.has(k)


func bake() -> void:
	for s in Monsters.all():
		var p: Dictionary = s["p"]
		var spec := {"species": s["species"], "variant": s["variant"], "r": s["hitbox_radius_px"],
			"armored": p.get("armor", 0.0) > 0.0, "extra": 0.0, "flag": 0}
		if s["species"] == "scrapper":
			spec["extra"] = deg_to_rad(p.get("plate_arc", 0.0))
		_add(spec)
		if s["species"] == "rat" or s["species"] == "tick":
			var angry := spec.duplicate()
			angry["flag"] = 1
			angry["extra"] = 1.0
			_add(angry)
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL * FRAMES, CELL * _specs.size())
	vp.transparent_bg = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var canvas := BakeCanvas.new()
	canvas.specs = _specs
	vp.add_child(canvas)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty() or img.get_width() < CELL * FRAMES:
		return   # no renderer (headless): monsters draw themselves
	atlas = ImageTexture.create_from_image(img)
	ready_flag = true


func _add(spec: Dictionary) -> void:
	_rows[key(spec["species"], spec["variant"], spec["flag"])] = _specs.size()
	_specs.append(spec)


## The canvas that is drawn once into the sheet.
class BakeCanvas extends Node2D:
	var specs: Array = []

	func _draw() -> void:
		for row in specs.size():
			var s: Dictionary = specs[row]
			for k in 12:
				var centre := Vector2(k * 160 + 80, row * 160 + 80)
				Art.draw_enemy(self, s["species"], s["variant"] == "boss", s["r"], 0.0, TAU * k / 12.0,
					Color(1, 1, 1), 0.0, s["armored"], centre, s["extra"])
