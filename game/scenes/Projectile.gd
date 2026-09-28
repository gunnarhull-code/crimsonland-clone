extends Area2D
## A single weapon shot. Handles the Gauss Gun's pierce (up to 3, per
## issues/11) and the Electric Gun's chain-to-one-nearby-enemy (issues/07,
## issues/11) - the only two weapons with special bullet behavior.

const MAX_LIFETIME := 3.0
const CHAIN_RANGE := 150.0
const PIERCE_COUNT := 3

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: float = 10.0
var weapon_id: String = "pistol"
var pierce_remaining: int = 0

var _hit_enemies: Array = []
var _lifetime: float = 0.0

@onready var _visual: Node2D = $Visual


func setup(dir: Vector2, stats: Dictionary, w_id: String) -> void:
	direction = dir
	speed = stats["projectile_speed_px_s"]
	damage = stats["damage"]
	weapon_id = w_id
	rotation = direction.angle()
	if weapon_id == "gauss_gun":
		pierce_remaining = PIERCE_COUNT
	_configure_visual()


func _configure_visual() -> void:
	match weapon_id:
		"pistol":
			_visual.configure_dot(3.0, Color(0.98, 0.97, 0.96))
		"gauss_gun":
			_visual.configure_line(28.0, Color(0.95, 0.78, 0.27))
		"electric_gun":
			_visual.configure_dot(4.0, Color(0.435, 0.722, 0.910))
		"shotgun":
			_visual.configure_dot(2.5, Color(0.69, 0.68, 0.65))
		"smg":
			_visual.configure_dot(2.5, Color(0.95, 0.57, 0.29))
		"heavy_cannon":
			_visual.configure_dot(12.0, Color(0.7, 0.23, 0.23))
		_:
			_visual.configure_dot(3.0, Color.WHITE)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_lifetime += delta
	if _lifetime > MAX_LIFETIME or _is_off_arena():
		queue_free()


func _is_off_arena() -> bool:
	var size: Vector2 = get_viewport_rect().size
	return global_position.x < -50.0 or global_position.x > size.x + 50.0 \
		or global_position.y < -50.0 or global_position.y > size.y + 50.0


func _on_body_entered(body: Node) -> void:
	if _hit_enemies.has(body) or not body.has_method("take_damage"):
		return
	_hit_enemies.append(body)
	body.take_damage(damage)
	AudioManager.play_hit()

	if weapon_id == "electric_gun":
		_try_chain(body)
		queue_free()
		return

	if weapon_id == "gauss_gun" and pierce_remaining > 0:
		pierce_remaining -= 1
		return

	queue_free()


func _try_chain(origin: Node) -> void:
	var closest: Node = null
	var closest_dist := CHAIN_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == origin or _hit_enemies.has(e):
			continue
		var d: float = origin.global_position.distance_to(e.global_position)
		if d <= closest_dist:
			closest_dist = d
			closest = e
	if closest:
		closest.take_damage(damage)
		AudioManager.play_hit()
