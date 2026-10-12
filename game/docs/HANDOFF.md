# Handoff: Crimsonland-clone V2 prototype

For a fresh Claude Code session (e.g. via remote control on the owner's PC). Read this first, then `design-v2-exponential-upgrades.md`. **Nothing for V2 has been coded yet.** Last updated 2026-10-12.

## Setup

- Repo: `gunnarhull-code/crimsonland-clone`, Godot 4.7 project in `game/` (GL Compatibility, GDScript).
- Branch with all design work: `claude/crimsonland-weapons-perks-enbrsj` (pushed; `git fetch origin` then check it out).
- Docs in `game/docs/`:
  - `design-v2-exponential-upgrades.md`: **the spec and source of truth.** Sections 1-12 are the original spec. **Section 13 is a long addendum of later owner decisions, and it overrides sections 1-12 where they differ.** Section numbers in 13 are out of order (13.11 sits before 13.9). Harmless, could be tidied.
  - `upgrade-rubric.csv` and `upgrade-rubric.md`: 30 upgrades, ten scoring pillars with definitions, per-upgrade descriptions, stacking rules and weights.
  - `roster-100.csv`: a 100-slot draft of the long-term upgrade roster (30 are in the rubric, the rest are one-line concepts).
  - `balance-system.md`: the plan for balancing 100 upgrades (calculator, simulation, outlier report).
  - `rubric-page/`: source for the phone/desktop page that shows the rubric. `template.html` plus `build.ps1`, see its README. The page is published as a private artifact: https://claude.ai/artifact/CjLSR36SKGLYJqBizP4g9v . Edits made on the page save in the viewer's browser only; its "Copy CSV" button exports the table so it can be pasted over `upgrade-rubric.csv`.
  - `design-weapons-perks-shop.md`: **superseded**, background only.
  - `HANDOFF.md`: this file.

## The owner's goals and working style

- Prototyping a Crimsonland-style top-down arena shooter, a **worthy fork of Crimsonland**. The feeling they want is close to a card-draft arena shooter where you pick upgrade cards between rounds, stretched over 10 levels.
- The prototype must answer: **(1) is it feasible to build? (2) is the idea interesting?** Polished core engine and balanced numbers, not lots of content. **Do not overextend.** If forced to choose, cut content.
- **Show designs for review before coding.** Do not start building until the owner says to proceed.
- **Data-driven with CSV.** Content lives in `game/data/*.csv` loaded by the `DataTables` autoload. V2 does the same. Code holds single-effect building blocks and CSV rows combine them into upgrades.
- The owner speaks in long, voice-dictated messages with interruptions and sometimes sarcasm. Read for intent. When asked for something "like the screenshot", reproduce the look closely (they were annoyed when it was made plain).
- They want the player to **feel clever**: bad builds must be possible, strong builds must feel earned, and a bad build should usually die.
- **No pop-culture references** in game names or text. Original names only.
- Dev environment notes: **Python is not installed** on the owner's PC. Use GDScript (headless Godot) or PowerShell for tooling. Godot was never run in the cloud sessions, so verify on the owner's PC.

## Core design, in short

- V2 is a **fork**: keep the current game untouched, create `game_v2/` (a copy). Pistol only. It changes only through upgrades.
- A run is **10 levels**. After each level clear, pick 1 of 3 upgrades. The player holds exactly L picks entering level L (10 useful picks). No XP level-ups. Two-portal choice after each level. Scenarios are about 24 authored plus generated.
- **Setting:** the junkyard at the end of all wormholes, where everything lost in space and time ends up. Weapon parts are salvage from other realities. Story is framing only (a line in CSVs, no cutscenes).
- **Never a dead run:** every run unlocks something. Win reward: pick 1 of 3 unlocks. **No heat levels.**
- **Stacking:** a stack doubles (or halves the N of an every-N trigger) where it fits. **No stack caps.** Duplicates are rare with many upgrades, but common in a small prototype roster, so watch for runaway upgrades there.
- **Performance caps** on bullets and explosions exist as safety valves only (placeholders 256 per pull, 1500 live, 60 explosions per frame, generation depth 3). Hundreds of bullets are welcome in the last level or two, not by level 3. A pull uses one round of ammo regardless of bullet count.
- **Balance targets:** the best build reaches about **100×** baseline damage per pull at level 10; a good build about 20×. Enemy **HP scales to 20× by level 10** (geometric; HP only for now). Enemy count per wave and number of waves also rise, so crowds become overwhelming. There is no guaranteed floor: a bad build dies. Break-even is measured by crowd clearing speed on normal levels and single-target damage on boss levels.
- **Bosses** on levels 5 (Rat King, a stream of rats) and 10 (Gate Warden, armored with escorts). They spawn immediately, adds are built into the boss, the level ends when the boss and everything spawned are dead, and **killing the boss early cancels unspawned waves**.
- **Upgrade weight (0 = tutorial, common; 1 = rarest, latest)** sets both unlock pick (1 + round(8w)) and draw frequency (0.1^w, with a late boost for advanced upgrades). Starters never get rarer. See spec 13.15 and the rubric page's timeline tab (a Gantt of unlock and offer chance).
- **Upgrade system pieces:** chained upgrades (a `requires` list, may never be drawn), linked abilities (hold two upgrades and a third is granted free), a combos table, ground pickups that are modified by your upgrades (13.4), and later visual weapon changes.
- **Renames and new upgrades:** the old "Split" is now **Spread** (one shot fans into several). The new **Split** fires an extra bullet in a random direction on each hit. Spawned bullets keep full base damage, but each of their other upgrades only has a 50% chance on the first generation, 25% on the second and so on (a coin flip per upgrade, per bullet). Split itself is guaranteed and does not fade. See 13.13 and 13.14.
- **Fire rate vs charge time** are separate stats. Charge time is zero by default and **Grow adds it** (13.12).

## Open questions (all marked *open* in the spec)

1. Grow's starting charge time in seconds, and whether charge overlaps the fire-rate lockout or adds to it (recommended: about 0.3 s, overlapping).
2. Whether to merge Echo into Split (Echo is the every-4th-hit version).
3. Chance tests for spawned bullets: whole upgrade (current) or per stack.
4. Draft rules: guarantee at least one new upgrade per offer? Any limit on how many different upgrades can be held?
5. Linked abilities: one stack of each, or scale with the lower stack count? Combo rewards: in-run bonus, unlock, or both?
6. Whether the weight also decides which upgrades unlock between runs.
7. Reaper's +150% max-HP cap (a total cap, not a stack cap): keep or remove.
8. Ground pickups: do their bullets count toward the fired and hit counters (recommended yes), does a burst count as a pull, spawn rate, and the pickup list.
9. Whether enemy speed and contact damage also scale (currently no), and whether bosses should spawn adds on a timer or at HP thresholds in detail.
10. The 71 concept upgrades in `roster-100.csv` need approving, cutting or renaming. A name and one-paragraph premise for the junkyard world has not been written yet.

## Suggested next steps

1. Get answers to the open questions above, especially 1 (charge time), which changes Grow's balance.
2. **Write the build calculator before the roster passes about 30 upgrades** (see `balance-system.md`). Do it in GDScript or PowerShell. It tests builds of exactly L picks for level L against the enemy line and the per-level ceiling.
3. Build step 1 of spec section 11 when the owner says to proceed: copy `game/` to `game_v2/`, add `upgrades.csv`, `upgrade_effects.csv` and `states.csv` plus loaders, implement the fire pipeline (with inheritance for spawned bullets) and the 5 starter upgrades. Keep it playable at each step.

## Existing code you'll need to know (`game/`)

- `scenes/Player.gd`: input capture, `_fire()`, perks via `stat_modifiers` and `get_effective_stat` (additive then multiplicative), weapon logic hardcoded on `weapon_id`, XP/level-up.
- `scenes/Projectile.gd`: per-weapon behavior hardcoded (`weapon_id == "gauss_gun"` etc.). V2 needs this generalized into upgrade-driven rules.
- `scenes/Enemy.gd`: single generic enemy scene, species data from `enemies.csv`, wander/chase state machine, take_damage. No status effects yet.
- `autoloads/DataTables.gd`: CSV loader. `SaveManager.gd`: JSON save at `user://save.json`. `EnemySpawner.gd`: authored + procedural waves, deterministic per wave seed.
- `scenes/ui/LevelUpChoice.gd`, `ResultsScreen.gd`, `UpgradeShop.gd`: existing UI to reuse or replace.
- Physics layers: projectiles are layer 4 with mask 2 (enemies). Enemy contact damage is in `Enemy._process_contact_damage`.
- The CSVs in `game/data/` may be column-aligned and have a trim step in `DataTables`. The rubric CSVs in `game/docs/` are plain (no padding, no commas inside cells).

## Practical notes

- Push regularly. The branch was last pushed on 2026-10-12.
- The earlier design sessions found the scratch folder cleaned overnight. Keep anything important in the repo.
