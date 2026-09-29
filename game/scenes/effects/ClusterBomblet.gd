extends Node2D
## A small delayed secondary explosion flung out by the Heavy Cannon's
## Cluster Warhead permanent upgrade (issue 22). Self-contained with its
## own fuse timer rather than tied to the parent Projectile's lifetime -
## that Projectile is already queue_free()'d by the time this detonates.

const FUSE_SEC := 0.35
const RADIUS := 35.0

const PARTICLE_BURST := preload("res://scenes/effects/ParticleBurst.tscn")

var damage: float = 0.0
var _timer: float = 0.0


func fire(dmg: float) -> void:
	damage = dmg
	_timer = FUSE_SEC


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_detonate()
		queue_free()


func _detonate() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= RADIUS:
			e.take_damage(damage)
	var burst := PARTICLE_BURST.instantiate()
	get_tree().current_scene.get_node("Effects").add_child(burst)
	burst.global_position = global_position
	burst.fire(6, Color(0.85, 0.45, 0.2))
