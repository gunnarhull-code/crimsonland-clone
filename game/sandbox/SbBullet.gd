extends Node2D
## One bullet. Collision is a manual segment-vs-circle test against the
## Sandbox's enemies (no Area2D), so fast bullets can't tunnel.

var sb
var velocity := Vector2.ZERO
var damage := 10.0
var radius := 3.0
var hits_left := 1
var falloff := 0.2
var hit_set := {}
var _len := 14.0


func setup(p_sb, pos: Vector2, dir: Vector2, props: Dictionary) -> void:
	sb = p_sb
	global_position = pos
	velocity = dir * props["speed"]
	damage = props["damage"]
	radius = 3.0 * props["size"]
	_len = 14.0 * props["size"]
	hits_left = props["hits"]
	falloff = props["falloff"]
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + velocity * delta
	global_position = to
	for e in sb.enemies.get_children():
		if e.dead or hit_set.has(e.get_instance_id()):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(e.global_position, from, to)
		if closest.distance_to(e.global_position) <= e.radius + radius:
			sb.bullet_hit(self, e)
			if is_queued_for_deletion():
				return
	if not Rect2(Vector2(-60, -60), sb.ARENA + Vector2(120, 120)).has_point(to):
		queue_free()


func _draw() -> void:
	var half := _len / 2.0
	var c := Color(1.0, 0.92, 0.45)
	draw_line(Vector2(-half, 0), Vector2(half, 0), c, radius * 2.0)
	draw_circle(Vector2(half, 0), radius, c)
	draw_circle(Vector2(-half, 0), radius, c)
