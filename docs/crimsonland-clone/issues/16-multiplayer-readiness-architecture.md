Type: grilling
Status: resolved

## Question

Surfaced by the user while resolving [14 - Player vitals & leveling](14-player-vitals-and-leveling.md): this MVP stays single-player, but the game is meant to grow into multiplayer eventually. Decide what structural principles the Godot implementation must follow *now* so that adding multiplayer later doesn't require rebuilding core systems:

- Should player-specific state (position, HP, current weapon, active perks, input) be keyed/instanced per-player from the start, rather than assumed to be a single global/singleton player node?
- Should the simulation (enemy AI, spawning, projectile movement, damage resolution) be structured as logic separable from local rendering/input handling, even though the MVP runs everything on one machine with no network layer?
- Do the generic systems already spec'd — the perk effect engine ([12](12-perk-effect-architecture.md), targets like `player.max_hp`) and weapon stats ([11](11-weapon-stat-table.md)) — need their `target` references to resolve against a specific player instance rather than an implicit global "the player," so a future multiplayer build can apply the same CSV-driven logic per-player without a rewrite?
- Are there any Godot-specific patterns (node/scene structure, autoloads vs. instanced nodes) that are known traps for later multiplayer conversion, worth avoiding from the first commit?

This is architecture guidance for the eventual implementation effort, not code written by this map (the destination is still a spec).

## Answer

Four structural principles the Godot implementation must follow, even though the MVP is single-player:

1. **Instanced player scene, not a singleton.** Model the player as a proper `Player.tscn` with HP/speed/weapon/perks as instance properties, spawned into the Arena — never an Autoload singleton holding "the" player's stats. This is the single biggest structural blocker to multiplayer if done wrong.
2. **Input capture separated from simulation.** Capture input into a small per-player input state (move vector, aim position) once per frame; all movement/aim/fire logic reads that state, never `Input.*` directly inside gameplay code. Makes swapping local input for networked input later a swap of *where the state comes from*, not a rewrite of *how it's used*.
3. **Perk/weapon effect systems take a player instance as an explicit parameter.** `perks.csv` targets like `player.max_hp` resolve via something like `apply_perk_effect(perk_row, target_player)` — never a hardcoded `$Player` path baked into the system itself.
4. **Autoloads are for genuinely global systems only** — the enemy spawner, the session/game clock, audio. Anything inherently per-player (HP, perks, current weapon, input state) never goes in an Autoload or a loose "Globals.gd" script.

No new CONTEXT.md terms — these are general Godot/architecture patterns, not domain vocabulary. This did meet the bar for an ADR (hard to reverse, surprising without context for a single-player game, a real trade-off with a genuine simpler alternative) — recorded as [ADR-0001](../../adr/0001-multiplayer-ready-single-player-architecture.md).
