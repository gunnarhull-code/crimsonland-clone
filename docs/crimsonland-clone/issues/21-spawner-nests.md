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
