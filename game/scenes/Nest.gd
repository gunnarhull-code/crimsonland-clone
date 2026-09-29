extends CharacterBody2D
## A stationary spawner structure, per docs/crimsonland-clone/issues/21 -
## introduced at the 8-minute mark on top of the normal timed spawning from
## issues/17, not a replacement for it. Shows a health bar (HealthBar.gd)
## per direct playtest request ("the nests need to have a health bar so I
## can destroy them") - a Nest takes many hits, unlike an Enemy, so it's
## the one entity in this game where a progress readout actually matters.
##
## BUGFIX: this was a StaticBody2D, and Projectile's Area2D never once
## detected it (confirmed with an isolated headless test - a projectile
## passing directly through its collision shape for 60+ physics frames,
## zero body_entered events) despite identical, correctly-matching
## collision_layer/mask to Enemy.gd, which works. Switched to
## CharacterBody2D with a no-op move_and_slide() every physics frame,
## matching the one collision pattern already proven to work everywhere
## else in this project - immediately fixed it. Root cause not fully
## explained by Godot's documented Area2D/StaticBody2D behavior; treat
## this as the empirically-confirmed fix, not a fully understood one.

const BASE_HP := 150.0
const SPAWN_INTERVAL := 3.0
const XP_REWARD := 120.0
const RADIUS := 24.0

# Per direct playtest request: a Nest is now single-species ("a rat nest, an
# alien nest, etc.") rather than rolling Rat/Spider on every individual
# spawn, and stops producing new enemies after a fixed count rather than
# threatening forever as long as it survives.
const MAX_SPAWNS := 10
const NEST_SPECIES_COLOR := {
	"rat": Color(0.30, 0.38, 0.28),
	"spider": Color(0.40, 0.30, 0.20),
	"alien": Color(0.38, 0.24, 0.24),
}

const PARTICLE_BURST := preload("res://scenes/effects/ParticleBurst.tscn")

var hp: float = BASE_HP
var _max_hp: float = BASE_HP
var _spawn_timer: float = SPAWN_INTERVAL
var species: String = "rat"
var _spawns_remaining: int = MAX_SPAWNS

@onready var _body: Node2D = $Body
@onready var _health_bar: Node2D = $HealthBar


func setup(pos: Vector2) -> void:
	global_position = pos
	hp = BASE_HP * EnemySpawner.get_toughness_multiplier()
	_max_hp = hp
	species = _pick_species()
	_spawns_remaining = MAX_SPAWNS
	if _body:
		_body.configure(RADIUS, NEST_SPECIES_COLOR.get(species, Color(0.35, 0.32, 0.30)), Color(0.15, 0.13, 0.12), "hexagon", false)
	if _health_bar:
		_health_bar.set_fraction(1.0)


## Alien only once it's actually in the wave roster (matches wave 5's
## "First Contact" introduction) - a Rat/Alien Nest before aliens exist
## would be a spoiler with no payoff.
func _pick_species() -> String:
	var options := ["rat", "spider"]
	if EnemySpawner.get_current_wave() >= 5:
		options.append("alien")
	return options[randi() % options.size()]


func _process(delta: float) -> void:
	if _spawns_remaining <= 0:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_spawn_enemy()


func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()


func _spawn_enemy() -> void:
	_spawns_remaining -= 1
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
