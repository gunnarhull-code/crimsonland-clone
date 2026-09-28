Type: grilling

## Question

Surfaced by the user while resolving [14 - Player vitals & leveling](14-player-vitals-and-leveling.md): this MVP stays single-player, but the game is meant to grow into multiplayer eventually. Decide what structural principles the Godot implementation must follow *now* so that adding multiplayer later doesn't require rebuilding core systems:

- Should player-specific state (position, HP, current weapon, active perks, input) be keyed/instanced per-player from the start, rather than assumed to be a single global/singleton player node?
- Should the simulation (enemy AI, spawning, projectile movement, damage resolution) be structured as logic separable from local rendering/input handling, even though the MVP runs everything on one machine with no network layer?
- Do the generic systems already spec'd — the perk effect engine ([12](12-perk-effect-architecture.md), targets like `player.max_hp`) and weapon stats ([11](11-weapon-stat-table.md)) — need their `target` references to resolve against a specific player instance rather than an implicit global "the player," so a future multiplayer build can apply the same CSV-driven logic per-player without a rewrite?
- Are there any Godot-specific patterns (node/scene structure, autoloads vs. instanced nodes) that are known traps for later multiplayer conversion, worth avoiding from the first commit?

This is architecture guidance for the eventual implementation effort, not code written by this map (the destination is still a spec).
