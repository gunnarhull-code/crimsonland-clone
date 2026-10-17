extends Node2D
## Child of a monster: draws the things that sit on top of its sprite (status
## marks, cocoon, health bar). It only redraws when the monster says something changed.
var enemy


func _draw() -> void:
	if enemy != null:
		enemy._draw_overlay(self)
