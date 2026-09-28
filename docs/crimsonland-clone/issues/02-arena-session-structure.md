Type: grilling
Status: resolved

## Question

What is the MVP's session/arena structure — a single scripted level, or an endless survival loop? What size is the arena, and how does its boundary behave for the player vs. enemies?

## Answer

**Endless survival**, matching the original's Survival mode: a single static, non-scrolling **1280×720 (16:9)** arena. The only end condition is player death — no scripted content, no fixed win condition, no camera movement.

Boundary behavior is **asymmetric**:
- **Player**: hard-capped at the screen edge. The player can never leave the visible arena, even briefly.
- **Enemies**: soft/forgiving boundary. An enemy may drift a few seconds past the visible edge (as part of its wander behavior, see [06](06-enemy-ai-shape.md)) before organically wandering back in — no hard wall collision for enemies.

Chosen over a fixed 4:3 800×600 (the original's actual shipped resolution) because modern displays are widescreen by default and Godot handles this trivially; the mechanic that actually matters — one static screen, no scrolling — is preserved regardless of exact resolution.

**Addendum — player/enemy mutual collision tried and reverted**: a later playtest pass briefly gave Player and Enemy bodies real physical collision (pushing off each other instead of overlapping), undocumented on this ticket at the time. Direct playtest feedback reversed it: the player passes freely through enemies, and enemies pass freely through each other — nobody physically blocks anybody. Whether an enemy is "touching" the player for contact-damage purposes is still a plain distance check ([15](15-enemy-combat-stats.md)'s per-species `hitbox_radius_px` sum), entirely independent of physics collision. Enemies still don't *deliberately* stack on the player — that's just what letting bodies overlap freely looks like; no new steering behavior was added.
