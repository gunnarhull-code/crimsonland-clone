extends Node2D
## Brood Seed drone: chases the nearest enemy and bites it for a few seconds.

const Up := preload("res://sandbox/SbUpgrades.gd")

var sb
var _life := 6.0
var _bite_t := 0.0
var _target = null
var _retarget_t := 0.0


func setup(p_sb, pos: Vector2) -> void:
	sb = p_sb
	global_position = pos
	_life = Up.p("brood_seed", "life")


func _physics_process(delta: float) -> void:
	if Up.p("brood_seed", "life") > 0.0:
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
	_retarget_t -= delta
	if _retarget_t <= 0.0 or _target == null or not is_instance_valid(_target) or _target.dead:
		_retarget_t = 0.3
		_target = _nearest()
	_bite_t -= delta
	if _target == null:
		return
	var to: Vector2 = _target.global_position - global_position
	var reach: float = _target.radius + 6.0
	if to.length() > reach:
		global_position += to.normalized() * Up.p("brood_seed", "speed") * delta
	elif _bite_t <= 0.0:
		_bite_t = Up.p("brood_seed", "bite_interval")
		sb.rules.deal_hit(_target, Up.p("brood_seed", "bite"),
			{"st": sb.bullet_stacks(0), "gen": sb.GEN_HARD_LIMIT, "base": Up.p("brood_seed", "bite"), "pos": global_position, "drone": true})
	queue_redraw()


func _nearest():
	var best = null
	var best_d := INF
	for e in sb.enemies.get_children():
		if e.dead:
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(0.85, 0.5, 1.0))
	draw_circle(Vector2(2, 0), 1.5, Color(0.1, 0.05, 0.15))
