Type: grilling

## Question

Graduated from the map's "Not yet specified" fog, now that every gameplay system has a resolved design: design the Godot scene/node structure for the MVP.

- What are the top-level scenes (Arena, Player, Enemy, Weapon/Projectile, level-up UI, results screen) and how do they compose?
- Per [16 - Multiplayer-readiness architecture](16-multiplayer-readiness-architecture.md): Player is an instanced scene (not a singleton), Autoloads are reserved for genuinely global systems (enemy spawner, session/game clock, audio) — what actually goes in those Autoloads, and what's a regular instanced node?
- How do `perks.csv` and `weapons.csv` get loaded (on game start into an in-memory table both the perk-effect system and weapon system read), and where does that loading logic live?
- How is a single Enemy scene parameterized per Species/Boss Variant ([05](05-enemy-roster.md), [10](10-enemy-ai-parameters.md), [15](15-enemy-combat-stats.md)) — one Enemy.tscn with exported per-species data, or a base scene with per-species inherited scenes?
