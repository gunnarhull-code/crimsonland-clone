# Crimsonland Clone MVP — Map

## Destination

A complete, implementation-ready design spec for a single-level Crimsonland-clone MVP (Godot 2D, endless-survival arena, placeholder shapes/colors) — covering every core mechanic (movement, aiming, hitboxes, weapons, enemy AI, perks, leveling) precisely enough that a follow-up implementation effort can build a mechanically-proven playable prototype without further design decisions. Graphics/VFX polish, sound design, and "what makes this game different from Crimsonland" are explicitly follow-up work, not part of this spec.

## Notes

- **Domain**: 2D top-down arena survival shooter, intentional Crimsonland clone/parody (the user owns the Crimsonland copyright). Engine: **Godot 2D**.
- Ground any "what did the original do" question in [research-crimsonland-mechanics.md](research-crimsonland-mechanics.md) before guessing. Default to matching the original unless the user has stated a deliberate difference (several are already recorded below).
- Perks are data-driven via a local `perks.csv` (to live at `docs/crimsonland-clone/perks.csv` once authored). Maximize what's spreadsheet-editable; minimize hardcoded special-cases in Godot.
- **This map's tickets ARE the spec** — resolve each with a precise, implementation-ready answer, not vague direction. This overrides wayfinder's usual "decisions only, no content" framing for ticket bodies: the answer itself should read like a spec section.
- Present ticket status to the user as a **Kanban board** (visualize widget), refreshed after each resolution — the user does not want to browse individual ticket files to track progress.
- Perks' in-game descriptions are deliberately vague/qualitative to the player even though the underlying CSV values are precise — don't "fix" this by making descriptions numeric.

## Decisions so far

- [01 - Tech stack](issues/01-tech-stack.md): Godot 2D.
- [02 - Arena & session structure](issues/02-arena-session-structure.md): Endless survival, single static non-scrolling 1280×720 arena, death is the only end condition; player hard-capped at edge, enemies get a soft/forgiving boundary.
- [03 - Hitbox model](issues/03-hitbox-model.md): Circle hitboxes for everyone, centered on each character's center of mass, deliberately smaller than the full sprite so thin extremities never register hits.
- [04 - Weapon pickup & ammo model](issues/04-weapon-pickup-ammo-model.md): Start with Pistol only; weapons drop from kills and swap on pickup (no dual-wield); ammo is infinite — magazine size + reload time are the differentiators, not scarcity.
- [05 - Enemy roster](issues/05-enemy-roster.md): Spider, Rat, Alien, each with a slower "big/boss" variant (6 behavior profiles total).
- [06 - Enemy AI shape](issues/06-enemy-ai-shape.md): Two-phase state machine — dynamic re-rolling wander (every 1-2s, ~3 themed variants per species) → permanent aggro once the player enters a large radius, then species-specific chase.
- [07 - Weapon roster anchor](issues/07-weapon-roster-anchor.md): 5-6 weapons total; confirmed anchors are Pistol, a piercing Gauss-style gun, and an electric/chain weapon that arcs to one nearby enemy.
- [08 - Perk scope](issues/08-perk-scope.md): 20 perks total in the MVP library; 3 offered per level-up; descriptions shown to the player are intentionally vague.
- [09 - Controls (assumed)](issues/09-controls-assumption.md): WASD movement, mouse aim, left-click fire, movement/aim fully independent — assumed from the original, flagged as override-able.
- [10 - Enemy AI parameters](issues/10-enemy-ai-parameters.md): 450px aggro radius, 1-2s randomized wander re-roll, concrete wander/chase definitions per species, 60% boss speed multiplier, 1.5s soft-boundary steer-back threshold.
- [11 - Weapon stat table](issues/11-weapon-stat-table.md): 6-weapon roster (Pistol, Gauss Gun, Electric Gun, Shotgun, SMG, Heavy Cannon) with full stats in a new `weapons.csv`.
- [12 - Perk effect architecture](issues/12-perk-effect-architecture.md): `perks.csv` schema (effect_type/target/value/trigger + special_handler_id escape hatch), no prerequisite chains for MVP, validated with 3 worked example perks.
- [13 - Perk content authoring](issues/13-perk-content-authoring.md): all 20 MVP perks authored into [perks.csv](perks.csv), all original text; one (Lucky Break) uses the special_handler_id escape hatch.

## Not yet specified

- Godot project/scene structure (node hierarchy, autoloads) — will sharpen once the weapon, perk, and enemy-AI tickets below are resolved.
- Placeholder visual conventions per entity (exact shapes/colors per weapon, enemy, projectile, perk pickup).
- Simple SFX/VFX cues per weapon/perk event — confirmed minimal, but which cues exist isn't decided.
- Score/high-score display and persistence.
- Whether enemy spawning uses simple off-screen edge points only, or also stationary "nest" spawner structures like the original.

## Out of scope

- Brainstorming what differentiates this game from Crimsonland beyond the MVP's stated simplifications (single-player, simple graphics/sound) — a future effort once there's something to differentiate from.
- Multiplayer/co-op — the original supports local co-op; this MVP is single-player only.
- Splash/AoE damage weapons — deferred post-MVP; needs its own radius/falloff design and isn't core to the "leading your shots" feel driving this MVP.
- Ammo scarcity/ammo pickups — the MVP uses infinite ammo with reload time/magazine size as the differentiator instead.
- Multiple levels or additional game modes (Quest, Rush, etc. from the original) — MVP is a single endless-survival arena only.
- Live Google Sheets sync for perks — local CSV only for the MVP; live sync could be revisited later if re-exporting becomes a real annoyance.
- Chapter/Level/Checkpoint campaign progression with permanent Perk unlocks — a real future direction, captured in [future-progression-notes.md](future-progression-notes.md) so it isn't lost, but not part of this single-level MVP.
