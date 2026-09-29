extends Node2D
## A dull, low-contrast grass-like texture tiled across the whole Arena, per
## direct playtest request: the flat solid-color background gave no visual
## reference point, so the player and enemies' actual speed was hard to
## judge. Colors are deliberately close together (small per-channel deltas)
## - texture for motion cues, not decoration ("super dull... don't want it
## to burn my eyes").

const BASE_COLOR := Color(0.24, 0.28, 0.19)
const BLADE_COLOR_A := Color(0.27, 0.31, 0.22)
const BLADE_COLOR_B := Color(0.21, 0.25, 0.17)
const TILE_SIZE := 64.0
const BLADES_PER_TILE := 5

var _tiles_x: int = 0
var _tiles_y: int = 0
var _blades: Array = []


func setup(arena_size: Vector2) -> void:
	_tiles_x = int(ceil(arena_size.x / TILE_SIZE))
	_tiles_y = int(ceil(arena_size.y / TILE_SIZE))
	_generate_blades()
	queue_redraw()


## A fixed seed keeps the texture stable across restarts within a session -
## it's a static backdrop, not something that should visibly reshuffle.
func _generate_blades() -> void:
	_blades = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for ty in _tiles_y:
		for tx in _tiles_x:
			var tile_origin := Vector2(tx, ty) * TILE_SIZE
			for i in BLADES_PER_TILE:
				var pos := tile_origin + Vector2(rng.randf_range(0.0, TILE_SIZE), rng.randf_range(0.0, TILE_SIZE))
				var size := Vector2(rng.randf_range(2.0, 4.0), rng.randf_range(6.0, 14.0))
				var color: Color = BLADE_COLOR_A if rng.randf() < 0.5 else BLADE_COLOR_B
				_blades.append({"pos": pos, "size": size, "color": color})


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(_tiles_x, _tiles_y) * TILE_SIZE), BASE_COLOR)
	for b in _blades:
		draw_rect(Rect2(b["pos"], b["size"]), b["color"])
