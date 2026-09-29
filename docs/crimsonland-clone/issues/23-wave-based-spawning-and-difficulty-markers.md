Type: grilling
Status: implemented

## Question

New ticket, opened directly from playtesting (per map.md's Frontier status allowing reopening). A single combined request, replacing [17](17-enemy-spawn-pacing.md)'s continuous timer-based spawn model entirely:

> "lets make the enemies difficulty and spawning go more wave like, like wait until they're all dead before the next wave. but make it more thematic and tailored than it is. also make enemy spawners after the first few waves. The waves should be the same every time you play it."

Plus, from the same conversation: "i also want you to be able to jump into a difficulty marker, instead of having to reset to 1."

Four distinct asks:
1. **Wait-for-clear pacing**: the next wave only starts once the current one is fully dead, not on a timer.
2. **Thematic/tailored**: authored compositions and formations, not randomized rolls from species-mix percentages.
3. **Spawners (Nests) after the first few waves**: tied to wave count, not elapsed minutes.
4. **Deterministic**: the same wave content every time, not different each playthrough.
5. **Difficulty markers**: a way to start a new run at a wave you've already reached, instead of always at wave 1.

## Answer

### Waves replace continuous spawning entirely

[17](17-enemy-spawn-pacing.md)'s original model - a spawn timer that ramps 2.0s→0.3s, filling toward a 250 concurrent cap, with species mix widening by elapsed minutes - and its own later addendum (pack spawns + periodic themed-wave bursts layered on top of that trickle) are both **superseded**, not layered under this. `EnemySpawner.gd` was rewritten: there is no more continuous trickle. The only things that spawn enemies now are discrete, numbered waves and the Nests they introduce. The 250 concurrent cap is kept as a safety ceiling, unused in practice at authored-wave sizes.

### Wait-for-clear

Each wave has a roster (built from its composition) queued with a small spawn stagger (0.12s apart, so a wave arrives as a beat, not a pop). The next wave only starts once **all** of the following are simultaneously true: every queued spawn from this wave has actually spawned, the "enemies" group is empty, and any Nest this wave spawned is destroyed (Nests aren't in the "enemies" group, so they needed their own check - otherwise a wave could never clear while its Nest kept refilling the group). A short 2.5s pause follows a clear before the next wave starts, so it reads as a beat, not an instant jump.

### Thematic and tailored: authored waves.csv

Ten hand-authored waves in [waves.csv](../waves.csv), each with a name, an explicit species/count composition (rat/spider/alien counts, plus an optional boss species+count), a formation (`cluster`/`ring`/`line`/`pincer` - reusing the formation code from [17](17-enemy-spawn-pacing.md)'s now-superseded themed-wave addendum), and whether it introduces a Nest:

| # | Name | Composition | Formation | Nest |
|---|---|---|---|---|
| 1 | First Blood | 6 rats | cluster | |
| 2 | Scurry | 10 rats, 2 spiders | cluster | |
| 3 | Web and Fang | 6 rats, 6 spiders | ring | |
| 4 | Vermin Tide | 14 rats, 4 spiders | line | |
| 5 | First Contact | 8 rats, 6 spiders, 2 aliens | cluster | yes |
| 6 | Eight-Legged Siege | 4 rats, 14 spiders, 2 aliens | ring | |
| 7 | Alien Vanguard | 6 rats, 6 spiders, 8 aliens | line | |
| 8 | The First Boss | 10 rats, 6 spiders, 2 aliens, 1 Rat Boss | cluster | yes |
| 9 | Chitin Storm | 8 rats, 16 spiders, 4 aliens, 1 Spider Boss | ring | |
| 10 | Full Invasion | 12 rats, 12 spiders, 10 aliens, 1 Alien Boss | pincer | |

All numbers are first guesses, same "provisional, tunable pending actual play" status as every other CSV in this project. Past wave 10, composition scales procedurally (species counts grow ~12%/wave, a boss species/count and a formation are rolled) rather than being hand-authored indefinitely - the "tailored" ask was reasonably satisfied by 10 real hand-built waves; endless procedural continuation past that keeps the game endless without needing infinite authored content.

### Spawners after the first few waves

Nest introduction is now the `spawns_nest` column on whichever wave is active, not an elapsed-minutes threshold - the first one arrives at wave 5 ("First Contact"), a second at wave 8 ("The First Boss"), matching the existing `NEST_CAP` of 2 from [21](21-spawner-nests.md). Procedural waves beyond 10 spawn a new Nest every 4th wave, capped the same way.

### Deterministic: seeded per wave, not per run

Every wave - authored or procedural - is spawned using a `RandomNumberGenerator` seeded with **its own wave number** (`rng.seed = current_wave`), used for every random choice that wave needs (scatter jitter, ring angles, formation/boss rolls for procedural waves). Composition itself is fixed by the CSV for authored waves, so nothing about wave 5 varies between playthroughs; procedural waves are equally reproducible because their generation is a pure function of the wave number through that seeded RNG. This is what actually makes a "difficulty marker" meaningful - jumping straight to wave 8 produces byte-for-byte the same wave 8 as reaching it normally, not a different roll.

### Difficulty markers

`SaveManager.highest_wave_reached` persists (`SaveManager.report_wave_reached()` fires the moment a wave clears) - see [22](22-permanent-weapon-upgrades.md) for the save file this shares. `UpgradeShop.tscn`'s wave picker lets the player pick any wave from 1 up to their highest ever reached before starting a new run; `EnemySpawner.register_arena()` reads `SaveManager.next_run_start_wave` instead of always starting at 1. "Instead of having to reset to 1" is satisfied directly - a player who's cleared wave 8 can jump straight back into wave 8 on their next run, skipping the climb.

### Toughness moved from elapsed time to wave number

[15](15-enemy-combat-stats.md)'s Toughness Multiplier (`1 + elapsed_minutes × 0.15`) doesn't make sense once a run can *start* at wave 8 with zero elapsed minutes - a jumpable difficulty marker has to mean something fixed. `EnemySpawner.get_toughness_multiplier()` now returns `1 + (current_wave - 1) × 0.12`, and `Enemy.gd`/`Nest.gd` read that instead of `SessionClock.get_toughness_multiplier()` (removed - dead code once nothing called it). `SessionClock` itself still exists as a raw stopwatch (start/stop/elapsed_sec) in case a future feature wants real elapsed time again, but nothing currently reads it.

### Verification

Verified headlessly with temporary instrumentation (removed before committing): a fresh run's wave 1 spawns exactly 6 rats; killing them all advances to wave 2 (12 enemies: 10 rats + 2 spiders, matching the CSV); setting `SaveManager.next_run_start_wave = 5` and starting fresh correctly spawns wave 5's full 16-enemy roster (8+6+2) instead of wave 1's. One real bug caught this way: the wave-advance code initially never incremented `current_wave`, so clearing a wave silently repeated it forever - fixed before this shipped.

**Addendum — ring formation was too close to be a fair ambush**: `RING_RADIUS` (used by the `ring` formation - enemies dropping in evenly spaced around the player, e.g. "Web and Fang"/"Eight-Legged Siege") was 320px. Reported directly ("I like when you spawn a ring of guys around me, but... I want them spawned way further. I don't want them spawned so close I can barely escape"). Increased to 600px - enough room to actually react and reposition before the ring closes in, rather than starting the encounter nearly surrounded.
