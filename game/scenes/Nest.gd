extends StaticBody2D
## A stationary spawner structure, per docs/crimsonland-clone/issues/21 -
## introduced at the 8-minute mark on top of the normal timed spawning from
## issues/17, not a replacement for it. Shows a health bar (HealthBar.gd)
## per direct playtest request ("the nests need to have a health bar so I
## can destroy them") - a Nest takes many hits, unlike an Enemy, so it's
## the one entity in this game where a progress readout actually matters.

const BASE_HP := 150.0
const SPAWN_INTERVAL := 3.0
const XP_REWARD := 120.0
const RADIUS := 24.0

const PARTICLE_BURST := preload("res://scenes/effects/ParticleBurst.tscn")

var hp: float = BASE_HP
var _max_hp: float = BASE_HP
var _spawn_timer: float = SPAWN_INTERVAL

@onready var _body: Node2D = $Body
@onready var _health_bar: Node2D = $HealthBar


func setup(pos: Vector2) -> void:
	global_position = pos
	hp = BASE_HP * EnemySpawner.get_toughness_multiplier()
	_max_hp = hp
	if _body:
		_body.configure(RADIUS, Color(0.35, 0.32, 0.30), Color(0.15, 0.13, 0.12), "hexagon", false)
	if _health_bar:
		_health_bar.set_fraction(1.0)


func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_spawn_enemy()


func _spawn_enemy() -> void:
	var species := "rat" if randf() < 0.6 else "spider"
	var offset := Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	EnemySpawner.spawn_enemy_at(species, "base", global_position + offset)


func take_damage(amount: float) -> void:
	hp -= amount
	if _health_bar:
		_health_bar.set_fraction(hp / _max_hp)
	if hp <= 0.0:
		_die()


func _die() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		player.on_nest_destroyed(XP_REWARD)
	var burst := PARTICLE_BURST.instantiate()
	get_tree().current_scene.get_node("Effects").add_child(burst)
	burst.global_position = global_position
	burst.fire(8, Color(0.5, 0.47, 0.45))
	AudioManager.play_nest_destroyed()
	queue_free()
