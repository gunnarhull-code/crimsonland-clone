extends Node2D
## A dropped weapon per issues/04's pickup-and-swap model. Auto-collected
## within the player's pickup radius (issues/13's Magnet Fingers/Scavenger
## perks) rather than requiring an exact walk-over.

const WEAPON_COLORS := {
	"pistol": Color(0.98, 0.97, 0.96),
	"gauss_gun": Color(0.95, 0.78, 0.27),
	"electric_gun": Color(0.435, 0.722, 0.910),
	"shotgun": Color(0.69, 0.68, 0.65),
	"smg": Color(0.95, 0.57, 0.29),
	"heavy_cannon": Color(0.7, 0.23, 0.23),
}

var weapon_id: String = "pistol"


func setup(w_id: String) -> void:
	weapon_id = w_id
	queue_redraw()


func _draw() -> void:
	var color: Color = WEAPON_COLORS.get(weapon_id, Color.WHITE)
	draw_circle(Vector2.ZERO, 10.0, Color(0.11, 0.105, 0.10))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, color, 3.0)
	draw_circle(Vector2.ZERO, 4.0, color)


func _process(_delta: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= player.get_pickup_radius():
		player.pick_up_weapon(weapon_id)
		queue_free()
