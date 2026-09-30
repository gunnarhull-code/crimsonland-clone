# Handoff: Crimsonland-clone V2 prototype

For a fresh Claude Code session (e.g. via remote control on the owner's PC). Read this first, then `design-v2-exponential-upgrades.md`. Nothing for V2 has been coded yet.

## Setup

- Repo: `gunnarhull-code/crimsonland-clone`, Godot 4.7 project in `game/` (GL Compatibility, GDScript).
- Branch with all design work: `claude/crimsonland-weapons-perks-enbrsj` (`git fetch origin` then check it out).
- Docs on that branch, in `game/docs/`:
  - `design-v2-exponential-upgrades.md`: **current spec. This is the source of truth.**
  - `design-weapons-perks-shop.md`: **superseded** (weapon roster, mods, discovery shop). Only useful for background.
  - `HANDOFF.md`: this file.

## The owner's goals and working style

- Prototyping a Crimsonland-style top-down arena shooter. Wants it to be a **worthy fork of Crimsonland**, not just "improved weapons and perks plus roguelite".
- Two questions the prototype must answer: **(1) is it feasible to build? (2) is the idea interesting?** That means the core engine has to be polished and the numbers balanced. It does not mean lots of content.
- **Do not overextend.** Fun game within reasonable constraints, not "the next indie hit". If forced to choose, cut content.
- **Show designs for review before coding.** The owner has explicitly said to get details straight first. Do not start building until they've answered the open decisions below or told you to proceed.
- **Data-driven with CSV.** The existing game keeps content in `game/data/*.csv` (`weapons`, `perks`, `enemies`, `waves`) loaded by the `DataTables` autoload. V2 should do the same.
- The owner speaks in long, voice-dictated messages with interruptions. Read them for intent.
- They want the player to **feel clever**: bad builds must be possible, strong builds must feel earned.

## The three feature sets considered

1. **Classic Crimsonland + physical bullet upgrades.** One starting weapon, changed only by upgrades (e.g. Grow: bullet size ×2, more damage). About 20 upgrades, 5 unlocked at start. Beat 20 waves to win and unlock more.
2. **Per-weapon upgrades.** Several weapons, a different one forced each round, so you upgrade them evenly and remember each build.
3. **Exponential upgrades (chosen as the main focus and first prototype).** Slay-the-Spire-style build variety. Upgrades multiply each other, with states (poison etc.) and every-Nth-bullet triggers. Pistol only. Details below.

The owner chose **set 3**. Sets 1 and 2 are parked, not rejected.

## Decisions made

- V2 is a **fork**: keep the current game untouched, create `game_v2/` (a copy) for V2.
- Pistol only. No weapon pickups, no weapon shop. The pistol changes only via upgrades.
- Upgrades are **exponential and interacting**: e.g. Split doubles bullets (2 stacks = 4 bullets), so a Poison-on-hit upgrade then poisons all 4. Not just +damage.
- Triggers count *all* bullets, including ones spawned by other upgrades ("every 4th bullet spawns another bullet, and that one counts too"). Needs caps to stay stable.
- States on enemies (poison, chill), and payoffs that read them ("debuffed enemies take ×2").
- Enemy behaviors should be **antitheses of builds** (armor vs Split spam, regeneration vs slow poison). No ranged shooters. At most web/slow traps, shields.
- Spiders lunge; rats bite from behind.
- **Never a dead run:** every run, win or lose, unlocks something. A win gives an extra reward.
- A run is 10 levels drawn from a large scenario pool, with a two-portal choice after each level (each portal shows only the dominant enemy icon).
- Roughly 24 authored scenarios plus generated ones (seeded, like the current `EnemySpawner`).

## Open decisions (the owner has not answered these)

1. Upgrades only at level clears (11 per run) versus keeping XP level-ups. Recommended: level clears.
2. One ammo round per pull regardless of bullet count (recommended) versus per bullet.
3. Split's per-bullet damage penalty (×0.75): keep or not.
4. More self-damaging risky upgrades (like Blast Ring) or keep them rare.
5. Scenario count (~24 authored + generated).
6. Win reward (pick 1 of 3 unlocks + a "heat" level).

Ask about these before coding. If the owner says "use your recommendations", go with the recommended option for each.

## Existing code you'll need to know (`game/`)

- `scenes/Player.gd`: input capture, `_fire()`, perks via `stat_modifiers` and `get_effective_stat` (additive then multiplicative), weapon logic hardcoded on `weapon_id`, XP/level-up.
- `scenes/Projectile.gd`: per-weapon behavior hardcoded (`weapon_id == "gauss_gun"` etc.). V2 needs this generalized into upgrade-driven rules.
- `scenes/Enemy.gd`: single generic enemy scene, species data from `enemies.csv`, wander/chase state machine, take_damage. No status effects yet.
- `autoloads/DataTables.gd`: CSV loader. `SaveManager.gd`: JSON save at `user://save.json`. `EnemySpawner.gd`: authored + procedural waves, deterministic per wave seed.
- `scenes/ui/LevelUpChoice.gd`, `ResultsScreen.gd`, `UpgradeShop.gd`: existing UI to reuse or replace.
- Physics layers: projectiles are layer 4 with mask 2 (enemies). Enemy contact damage is in `Enemy._process_contact_damage`.

## Recommended first step

Build order is in section 11 of the V2 spec. Step 1: copy `game/` to `game_v2/`, add `upgrades.csv` and `states.csv` plus loaders, implement the fire pipeline with counters and caps, and the 5 default upgrades. Keep it playable at each step.

## Practical notes

- Push regularly. The previous session's container could lose unpushed work.
- Godot was not installed in the previous (cloud) session, so nothing has been run there. On the owner's PC, run the game to verify each step.
