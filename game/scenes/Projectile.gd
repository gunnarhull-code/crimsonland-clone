extends Area2D
## A single weapon shot. Handles the Gauss Gun's pierce (up to 3, per
## issues/11), the Electric Gun's chain-to-one-nearby-enemy (issues/07,
## issues/11), and the Heavy Cannon's splash explosion on impact - added
## per direct playtest request ("think bazooka"), reversing issues/15's
## original "defer splash/AoE post-MVP" call now that the MVP is actually
## being played.

const MAX_LIFETIME := 3.0
const CHAIN_RANGE := 150.0
const PIERCE_COUNT := 3
const EXPLOSION_RADIUS := 60.0

# Heavy Cannon "rocket taking off" launch curve - per direct playtest
# request. Starts near-stationary, then rapidly ramps to its normal cruise
# speed (`speed`, from weapons.csv) over a tiny fraction of a second via a
# cubic ease-in, instead of leaving the arena at full speed instantly.
const ROCKET_LAUNCH_START_SPEED := 25.0
const ROCKET_LAUNCH_ACCEL_SEC := 0.18

const PARTICLE_BURST := preload("res://scenes/effects/ParticleBurst.tscn")
const ZAP_LINE := preload("res://scenes/effects/ZapLine.tscn")

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: float = 10.0
var weapon_id: String = "pistol"
var pierce_remaining: int = 0

var _hit_enemies: Array = []
var _lifetime: float = 0.0
var _rocket_launch_timer: float = 0.0

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
			_visual.configure_capsule(9.0, 3.0, Color(0.98, 0.97, 0.96))
		"gauss_gun":
			_visual.configure_line(28.0, Color(0.95, 0.78, 0.27))
		"electric_gun":
			_visual.configure_bolt(14.0, Color(0.435, 0.722, 0.910))
		"shotgun":
			_visual.configure_pellet(5.0, Color(0.69, 0.68, 0.65))
		"smg":
			_visual.configure_capsule(7.0, 2.5, Color(0.95, 0.57, 0.29))
		"heavy_cannon":
			_visual.configure_rocket(22.0, 7.0, Color(0.7, 0.23, 0.23))
		_:
			_visual.configure_dot(3.0, Color.WHITE)


func _physics_process(delta: float) -> void:
	var travel_speed := speed
	if weapon_id == "heavy_cannon":
		_rocket_launch_timer += delta
		var t: float = clamp(_rocket_launch_timer / ROCKET_LAUNCH_ACCEL_SEC, 0.0, 1.0)
		travel_speed = lerp(ROCKET_LAUNCH_START_SPEED, speed, t * t * t)
	global_position += direction * travel_speed * delta
	_lifetime += delta
	if _lifetime > MAX_LIFETIME or _is_off_arena():
		queue_free()


func _is_off_arena() -> bool:
	var size: Vector2 = ArenaConfig.size
	return global_position.x < -50.0 or global_position.x > size.x + 50.0 \
		or global_position.y < -50.0 or global_position.y > size.y + 50.0


func _on_body_entered(body: Node) -> void:
	if _hit_enemies.has(body) or not body.has_method("take_damage"):
		return
	_hit_enemies.append(body)
	body.take_damage(damage)
	_hit_particles(body.global_position)
	AudioManager.play_hit()

	if weapon_id == "heavy_cannon":
		_explode(body.global_position)
		queue_free()
		return

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
		_hit_particles(closest.global_position)
		_zap_line(origin.global_position, closest.global_position)
		AudioManager.play_hit()


## Heavy Cannon: full damage to every enemy within EXPLOSION_RADIUS of the
## impact point, not just whatever was directly hit - "think bazooka."
func _explode(center: Vector2) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if _hit_enemies.has(e):
			continue
		if center.distance_to(e.global_position) <= EXPLOSION_RADIUS:
			_hit_enemies.append(e)
			e.take_damage(damage)
	var burst := PARTICLE_BURST.instantiate()
	get_tree().current_scene.get_node("Effects").add_child(burst)
	burst.global_position = center
	burst.fire(10, Color(0.85, 0.35, 0.15))


func _hit_particles(at: Vector2) -> void:
	var burst := PARTICLE_BURST.instantiate()
	get_tree().current_scene.get_node("Effects").add_child(burst)
	burst.global_position = at
	burst.fire(3, Color(0.95, 0.95, 0.92))


func _zap_line(from: Vector2, to: Vector2) -> void:
	var zap := ZAP_LINE.instantiate()
	get_tree().current_scene.get_node("Effects").add_child(zap)
	zap.fire(from, to, Color(0.6, 0.85, 1.0))
