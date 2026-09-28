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
