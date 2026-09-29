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

**Addendum — the arena is no longer a single static screen**: per direct playtest request ("the map needs to be way bigger... zoom out the screen a little bit... full screen it"), this ticket's original "single static, non-scrolling 1280×720 arena... no camera movement" call is reversed:
- The Arena's actual world size is now **3840×2160** (3× each dimension, same 16:9 ratio, 9× the area) — a new `ArenaConfig` Autoload is the single source of truth for it, replacing the old assumption (baked into Player's edge clamp and Enemy's soft boundary) that `get_viewport_rect().size` equals the arena's bounds.
- A `Camera2D` is now a child of the Player scene (so it follows for free, no manual follow logic), clamped to the Arena's true edges via `limit_left/top/right/bottom`, with smoothing enabled.

**Addendum — zoom direction bugfix**: the first three zoom passes (`1.15` → `1.5` → `2.6`) were all written on the mistaken assumption that a *larger* `Camera2D.zoom` value zooms *out*. It's the opposite - `zoom` is a magnification factor, so each of those actually zoomed further **in**, making three consecutive "zoom out" requests each land worse than the last ("STILL ZOOM WAY OUT", then "you're zooming in, getting closer towards the character. i want a bigger view"). Fixed by using a value below 1.0 - `0.4` first (~3200×1800 area, close to the full 3840×2160 Arena), called "a little too far" the other way, `0.55` next ("I like the distance"), nudged in "just a tad" to settle at **`zoom = Vector2(0.62, 0.62)`** (~2064×1161 area).
- The game window now launches fullscreen (`window/size/mode=3`), with `window/stretch/aspect="keep"` so the 1280×720 design resolution scales to the display without distortion.
- The **250 concurrent-enemy cap** from [17](17-enemy-spawn-pacing.md) is deliberately *not* rescaled to the new 9× area — that cap was already flagged there as provisional pending real perf profiling, and a bigger world at the same enemy count directly supports the "spread them out more" request from an earlier playtest round ([10](10-enemy-ai-parameters.md)'s chase-spread addendum) rather than fighting it.
