Type: grilling
Status: resolved

## Question

Graduated from the map's "Not yet specified" fog: the original has stationary "Nest" structures that continuously produce enemies until destroyed, in addition to ordinary off-screen spawning (research doc, section 6). [17 - Enemy spawn pacing](17-enemy-spawn-pacing.md) speced pure timed off-screen-edge spawning and never mentioned Nests.

Does the MVP add Nest structures (destroyable, spawn-generating, presumably placed at fixed or random Arena positions), or does [17](17-enemy-spawn-pacing.md)'s simple timed spawning stay the whole spawning model for this MVP?

## Answer

Nests are in — added as a third rung on [17](17-enemy-spawn-pacing.md)'s escalation timeline (Rat/Spider from the start, Alien at 2min, Boss Variants at 5min, **Nests at 8min**), not present from session start.

- **HP**: 150 (a real but not tedious objective — roughly half an Alien Boss Variant's HP).
- **Behavior**: stationary, deals no contact damage itself — the threat is what it produces, not the Nest directly. Spawns one Rat or Spider (matching the normal spawn-mix weighting active at that point in the session) every 3s while alive, additive on top of [17](17-enemy-spawn-pacing.md)'s normal timed spawning (doesn't replace or pause it).
- **Placement**: random position inside the Arena, with a minimum distance from the player's current position at spawn time so it can't appear on top of them.
- **Cadence**: once the 8-minute mark hits, a new Nest appears every 90s, capped at 2 simultaneous Nests.
- **Reward**: destroying a Nest awards XP as if it were a kill (120 XP, matching Alien Boss Variant's tier from [15](15-enemy-combat-stats.md)) — a real tactical payoff for prioritizing it over the enemies it's producing.
- Enemies a Nest spawns count toward [17](17-enemy-spawn-pacing.md)'s ~250 concurrent-enemy cap like any other enemy.

**Addendum — health bar**: a Nest takes 150 HP (scaled by the current wave's toughness) worth of hits to bring down, unlike an Enemy which dies in a handful - with no HP readout, it wasn't clear how close one was to destroyed. Reported directly ("the nests need to have a health bar so I can destroy them"). New reusable `HealthBar.gd`/`.tscn` (dark backing + colored fill, redrawn on `set_fraction()`) is now a child of `Nest.tscn`, updated every `take_damage()` call - the one entity in this game that currently needs this kind of progress readout.

**Bugfix — the health bar showed, but the Nest couldn't actually be damaged**: reported directly right after the addendum above shipped ("nests have a life bar... but I can't do any damage to it, and bullets don't collide with it"). Confirmed with an isolated headless test: a Projectile fired directly through a Nest's collision shape for 60+ physics frames produced zero `body_entered` events, despite `collision_layer`/`collision_mask` matching Enemy's exactly (which does work). The differentiating factor, found empirically rather than from documented Godot behavior: Nest was a `StaticBody2D` that never moved after being positioned once; Enemy is a `CharacterBody2D` that calls `move_and_slide()` every physics frame. Switching Nest to `CharacterBody2D` with a no-op `move_and_slide()` call each frame (`velocity = Vector2.ZERO; move_and_slide()`) immediately fixed detection - verified the same test now registers the hit and reduces `hp`. This isn't a fully-understood root cause (Godot's own docs don't describe StaticBody2D as undetectable by Area2D), just the empirically-confirmed fix; worth remembering if any other never-moving `StaticBody2D` gets added to this project later.

**Addendum — single-species Nests with a spawn cap**: per direct playtest request ("make sure that nests have a limited number of mobs that spawn from it. And make it the same type of mob. So there's a rat nest, an alien nest, etc."), a Nest now rolls one species once at `setup()` (Rat or Spider always available, Alien added to the pool once `EnemySpawner.get_current_wave() >= 5`, matching Alien's own wave-5 introduction) and spawns only that species for every one of its `_spawn_enemy()` calls, tinting its hexagon body toward that species' color. It also stops spawning after `MAX_SPAWNS = 10` total (still destroyable and still worth the XP after that point, it just stops producing more threats) rather than indefinitely as long as it survives.
