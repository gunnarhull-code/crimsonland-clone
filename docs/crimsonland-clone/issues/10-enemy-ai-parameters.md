Type: grilling
Status: resolved

## Question

Detail the exact numeric/behavioral parameters for the enemy AI state machine fixed in [06 - enemy AI shape](06-enemy-ai-shape.md):

- The aggro radius: an exact value (or formula relative to the 1280×720 arena from [02](02-arena-session-structure.md)), not just "large, ~half the screen."
- The wander re-roll interval: exact seconds (or a range), and whether it's fixed or randomized per-roll.
- For each of Spider, Rat, and Alien: the concrete definitions of their ~3 themed wander variants (what shape/pattern each variant actually traces, and each variant's speed), and their chase-style parameters once aggroed (Spider's "charge-stop-charge" is described in [06](06-enemy-ai-shape.md) and [05](05-enemy-roster.md) but not quantified; Rat and Alien's chase styles aren't detailed at all yet).
- How the "big/boss" variant's slower speed is derived (a flat multiplier? a fixed value per species?).
- Whether the soft arena-boundary drift for wandering enemies (from [02](02-arena-session-structure.md): "only a couple seconds" off-screen) has a specific max duration and how enemies re-enter (do they retain their pre-drift wander variant, or re-roll on return?).

## Answer

**Aggro radius**: flat 450px for all species.

**Wander re-roll interval**: randomized 1.0-2.0s per roll (not fixed) — keeps the "looking around" read organic rather than metronomic.

**Spider** — Wander Variants: *Loop* (small circle, ~40px radius), *Figure-eight* (~60px lobes), *Skitter-pause* (dart 30-50px in a random direction, then freeze ~0.5s); wander speed 60% of chase speed. Chase Style: charge-stop-charge — burst ~0.4s at high speed, pause ~0.3s, repeat.

**Rat** — Wander Variants: *Tight loop* (~20px radius, fast), *Zigzag dart* (quick alternating-direction darts), *Freeze-scurry* (short scurry, brief freeze, shorter than Spider's); wander speed 90% of chase speed (Rat barely changes gear — speed is its identity). Chase Style: straight relentless beeline at full constant speed, no stutter — the swarm-rush contrast to Spider.

**Alien** — Wander Variants: *Wide loop* (~100px radius, slow), *Long drift* (slow straight wander for a few seconds, then turns), *Idle sway* (minor side-to-side, nearly stationary); wander speed 40% of chase speed. Chase Style: steady constant-speed straight-line charge, no burst, no stutter — the brute contrast to both other species.

**Boss Variant speed**: a flat multiplier of 60% applied to whichever Wander Variant or Chase Style speed the base species is currently using — danger is telegraphed through size/HP (not yet defined, see gap below), not movement.

**Soft arena-boundary drift**: threshold is ~1.5s (within the "second or two" the user specified). Once a wandering enemy has been past the visible edge longer than that threshold, it stops pursuing its current Wander Variant's target point and instead steers — smoothly, blended with its existing velocity, not a teleport or snap — back toward a point inside the Arena, so it never reads as unnatural. Once back inside, it resumes its current Wander Variant rather than re-rolling (avoids a visual pop right on re-entry).

**Gap surfaced**: enemy HP, contact damage dealt to the player, and per-kill XP reward are not defined anywhere on this map yet — needed before Boss Variant "danger via size/HP" above can actually be implemented. New ticket opened: [15 - enemy combat stats](15-enemy-combat-stats.md).

**Addendum — Spider's charge-stop-charge randomized**: the fixed ~0.4s burst / ~0.3s pause above read as a metronome in actual play, not a jerky spider. Per direct playtest request, both numbers (and the burst's travel speed) are now randomized per cycle: burst 0.15-0.55s at 0.6-1.5× chase speed, pause 0.12-0.5s. Same randomization applied to the Skitter-pause Wander Variant's freeze length (was fixed ~0.5s, now the same 0.12-0.5s range) and its dart speed (0.6-1.5×), so the jerkiness is consistent whether the Spider is wandering or chasing. Rat and Alien's timings are untouched.

**Addendum — chase no longer perfect-tracks the player, across all species**: every species' chase beelined at the player's exact current position with the direction snapping instantly every frame - with several enemies aggroed at once, that reads as one tight clump perfectly mirroring the player's every move, not a spread-out crowd. Per direct playtest request ("I don't want them all following me perfectly... they need to be spread out more"), each aggroed enemy now:
- Aims at the player's position plus a personal offset (30-110px, random direction) instead of the exact position, so simultaneous chasers fan out around the player rather than converging on one point.
- Turns toward that target at a capped rate (70-1000°/s, randomized per enemy) instead of snapping - a low roll overshoots corners into a wide arc; a high roll reads as near-perfect tracking. "Some of them can, sometimes."

Both the offset and the turn-rate cap reroll every 2-4s per enemy (not fixed for its whole chase), so no enemy is locked into one flanking spot or one turn sharpness for the whole encounter. This sits entirely inside `_process_chase` - the aggro trigger, the 450px radius, and each species' base chase speed above are unchanged; only how directly each enemy steers toward the player changed.
