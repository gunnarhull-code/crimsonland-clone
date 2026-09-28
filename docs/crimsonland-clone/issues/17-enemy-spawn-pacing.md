Type: grilling
Status: resolved

## Question

Surfaced by the user while resolving [14 - Player vitals & leveling](14-player-vitals-and-leveling.md): the XP curve there needs to be balanced against how quickly the arena actually gets harder, and nothing on this map yet defines that pacing.

- Initial enemy spawn rate, and how the spawn interval decreases over session time (matching the research doc's finding that the original scales time/level-based, not by wave-clear — see [research-crimsonland-mechanics.md](../research-crimsonland-mechanics.md) section 7).
- Any cap on concurrent enemies alive in the Arena at once.
- How the species mix shifts over time (e.g. do Boss Variants — from [05](05-enemy-roster.md) — start appearing only after some time/level threshold, or can they spawn from the start at low frequency?).
- How this pacing should be tuned jointly with the XP curve from [14](14-player-vitals-and-leveling.md) so leveling frequency and enemy toughening feel matched — neither racing ahead of the other.

## Answer

**Spawn interval**: `spawn_interval_sec = max(0.3, 2.0 − elapsed_minutes × 0.15)` — one enemy every 2s at session start, ramping to one every 0.3s (the floor) by ~11-12 minutes. Same linear shape as the Toughness Multiplier from [15](15-enemy-combat-stats.md).

**Concurrent enemy cap**: derived from the Arena, not an arbitrary constant, per the instruction to fill the screen as full as it'll hold. No enemy species has an exact hitbox/sprite size yet (still fog — see map.md's Not yet specified, "placeholder visual conventions per entity"), so this uses a working assumption: ~40px average enemy footprint diameter + 20px spacing so a screen full of enemies still reads as distinct individuals rather than a fused blob → a 60×60px cell per enemy. `921,600px² (1280×720 Arena) ÷ 3,600px² ≈ 256`, rounded to **250 concurrent enemies**.

Flagged explicitly: this number will need to be re-derived once actual enemy sprite sizes are picked (fog item), and confirmed against real Godot frame-time profiling once implemented — 250 individually-simulated wander/chase state machines plus per-enemy collision checks against the player is untested territory for this project, and no ticket has speced any optimization technique (object pooling, spatial partitioning) that would make a number this high comfortably cheap. The design *intent* (screen-filling swarms) is fixed; the exact ceiling is provisional.

**Species mix over time**: Rat and Spider only for the first 2 minutes. Alien introduced at the 2-minute mark. Boss Variants introduced at the 5-minute mark, starting rare (~1 in 20 spawns) and growing slowly alongside the Toughness Multiplier — so lategame difficulty comes from both tougher common enemies and more frequent Boss Variants together.

**XP curve sanity check**: holds up — ~420 XP over the first 2 minutes at the Q1 spawn rate with Rat/Spider-only kills clears level 2 (283 XP) and approaches level 3 (520 XP) on the `100 × level^1.5` curve from [14](14-player-vitals-and-leveling.md).

**Addendum — pack spawns and themed waves**: per direct playtest request ("sometimes they need to spawn in groups... give some personal touches to the way they spawn and the waves, not just a bunch of random enemies"), the trickle spawn from Q1 is no longer the only spawn shape:
- **Pack spawns**: each trickle-spawn roll has a 12-35% chance (scaling with elapsed minutes, same shape as other difficulty scaling) to spawn a same-species cluster of 3-6 instead of a single enemy, scattered within ~40px of one edge point.
- **Themed waves**: independently, starting 35s into a run and then every 55s, a named formation spawn fires and is announced on the HUD (`EnemySpawner.wave_announced` → `HUD.gd`'s new WaveLabel, shown ~2.5s): **Rat Swarm** (10-16 rats, clustered, available from the start), **Spider Ambush** (6-10 spiders dropped in a ring around the player, from 0.5min), **Alien Vanguard** (4-7 aliens marching in a line from one edge, from 2.5min, matching Alien's introduction at [17](17-enemy-spawn-pacing.md) Q1/[15](15-enemy-combat-stats.md)), **Pincer Assault** (a mixed-species split spawn from two opposite edges, from 4min). Each wave's enemies spawn staggered ~0.12s apart rather than all at once, so the formation reads as a beat rather than a pop. All wave spawns still respect the 250 concurrent-enemy cap above and reuse the same species/variant/boss-chance rolls as the regular trickle spawn — waves are a *delivery pattern* on top of the existing pacing model, not a separate difficulty curve.
