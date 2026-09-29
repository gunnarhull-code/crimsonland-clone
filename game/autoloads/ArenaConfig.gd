extends Node
## Single source of truth for the Arena's world-space size. Per direct
## playtest request the map is now much bigger than the visible screen (see
## issues/02's addendum reversing its original "single static screen, no
## camera movement" call) - anything that used to assume
## `get_viewport_rect().size` equals the arena's bounds (Player's edge
## clamp, Enemy's soft boundary) reads this instead.

var size: Vector2 = Vector2(3840.0, 2160.0)
