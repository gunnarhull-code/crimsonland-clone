extends Node2D
## A dropped weapon per issues/04's pickup-and-swap model. Auto-collected
## within the player's pickup radius (issues/13's Magnet Fingers/Scavenger
## perks) rather than requiring an exact walk-over.
##
## Each weapon gets its own icon silhouette rather than a generic ring+dot -
## per direct playtest request ("give the weapons shape, not circles"). This
## is deliberately a different shape language from ProjectileVisual.gd's
## bullet shapes for the same weapon - the gun and its bullet aren't the
## same thing ("bullets are different from guns").

const WEAPON_COLORS := {
	"pistol": Color(0.98, 0.97, 0.96),
	"gauss_gun": Color(0.95, 0.78, 0.27),
	"electric_gun": Color(0.435, 0.722, 0.910),
	"shotgun": Color(0.69, 0.68, 0.65),
	"smg": Color(0.95, 0.57, 0.29),
	"heavy_cannon": Color(0.7, 0.23, 0.23),
}

const PLATE_COLOR := Color(0.11, 0.105, 0.10)

var weapon_id: String = "pistol"


func setup(w_id: String) -> void:
	weapon_id = w_id
	queue_redraw()


func _draw() -> void:
	var color: Color = WEAPON_COLORS.get(weapon_id, Color.WHITE)
	var plate := PackedVector2Array([Vector2(0.0, -13.0), Vector2(11.0, 0.0), Vector2(0.0, 13.0), Vector2(-11.0, 0.0)])
	draw_colored_polygon(plate, PLATE_COLOR)
	match weapon_id:
		"pistol":
			_draw_square(color)
		"gauss_gun":
			_draw_long_diamond(color)
		"electric_gun":
			_draw_bolt(color)
		"shotgun":
			_draw_fan(color)
		"smg":
			_draw_bars(color)
		"heavy_cannon":
			_draw_rocket(color)
		_:
			draw_circle(Vector2.ZERO, 4.0, color)


func _draw_square(color: Color) -> void:
	draw_rect(Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)), color)


func _draw_long_diamond(color: Color) -> void:
	var pts := PackedVector2Array([Vector2(0.0, -9.0), Vector2(3.5, 0.0), Vector2(0.0, 9.0), Vector2(-3.5, 0.0)])
	draw_colored_polygon(pts, color)


func _draw_bolt(color: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(-4.0, -8.0), Vector2(1.0, -1.0), Vector2(-2.0, 1.0),
		Vector2(4.0, 8.0), Vector2(1.0, 1.0), Vector2(2.0, -1.0),
	])
	draw_colored_polygon(pts, color)


func _draw_fan(color: Color) -> void:
	var pts := PackedVector2Array([Vector2(-6.0, -7.0), Vector2(6.0, 0.0), Vector2(-6.0, 7.0)])
	draw_colored_polygon(pts, color)


func _draw_bars(color: Color) -> void:
	for dx in [-5.0, 0.0, 5.0]:
		draw_rect(Rect2(Vector2(dx - 1.2, -7.0), Vector2(2.4, 14.0)), color)


func _draw_rocket(color: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(8.0, 0.0), Vector2(2.0, -5.0), Vector2(-8.0, -5.0),
		Vector2(-8.0, 5.0), Vector2(2.0, 5.0),
	])
	draw_colored_polygon(pts, color)


func _process(_delta: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= player.get_pickup_radius():
		player.pick_up_weapon(weapon_id)
		queue_free()
