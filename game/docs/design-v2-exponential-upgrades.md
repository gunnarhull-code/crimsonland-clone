# V2 spec: exponential upgrades (pistol-only fork)

Status: **spec for review, nothing implemented.** Supersedes the mod/shop parts of `design-weapons-perks-shop.md`. The current game stays untouched; V2 lives in a copy (`game_v2/`) with its own data tables.

Two questions this prototype exists to answer:
1. **Feasible?** Can the engine below be built and stay stable at big bullet counts?
2. **Interesting?** Does stacking upgrades make players feel clever, with bad builds possible and great builds earned?

---

## 1. Guardrails (scope)

- One weapon: the pistol. It only changes through upgrades.
- Reuse the existing systems: CSV tables + `DataTables` loader, enemy scene, wave spawner, level-up screen, `SaveManager` JSON.
- **All content is CSV rows.** Code holds a small fixed vocabulary of *actions* and *triggers*; upgrades, states, enemies and scenarios are data. Adding an upgrade should be a new row, not new code, unless it needs a new action.
- Simple over clever: about 16 upgrades, 2 states, 3 enemy species with 1-2 behaviors each, in slice one.
- Polish target: numbers balanced, not content volume. If forced to choose, cut content.

---

## 2. Run structure

- A run = **10 levels**, drawn from a scenario pool (target: many, see section 8).
- After each level: **1 upgrade pick (choose 1 of 3)**, then **a portal choice (1 of 2)** that decides the next scenario.
- Win = clear level 10. Lose = die.
- Every run unlocks something (section 9).

**Why upgrades come only at level clears (not XP level-ups):** the number of picks per run is fixed (10, plus 1 at the start = 11), so balance targets can be computed ("by level 5 you have 6 upgrades"). XP-based levelling makes the pick count vary with how the player fights. XP is dropped in V2 unless you want it back.

---

## 3. Data tables (all under `game_v2/data/`)

### Upgrades are built from effects (owner decision)

**Code holds single-effect building blocks ("effects"). Spreadsheet rows combine them into upgrades.** An upgrade can have any number of effects; each effect does exactly one thing. This keeps the code small and testable (each effect is programmed once) while content lives in CSV.

#### `upgrades.csv` (one row per upgrade)

`id, name, description, category, tier, unlocked_default, max_stacks, tags`

- `category`: `shape`, `state`, `trigger`, `payoff`, `utility` (UI grouping).
- `max_stacks`: cap on duplicate picks (0 = uncapped).
- `tags`: used by `payoff` effects and enemy counters (`poison`, `explosive`, `multi`).

#### `upgrade_effects.csv` (one row per effect; many rows can share an `upgrade_id`)

| column | meaning |
|---|---|
| `upgrade_id` | which upgrade this effect belongs to |
| `trigger` | when it runs: `passive`, `on_fire`, `on_hit`, `on_kill`, `every_n_fired`, `every_n_hits` |
| `every_n` | N for the `every_n_*` triggers (base value) |
| `action` | one effect from the vocabulary in 4.4 |
| `value`, `value_2` | numeric parameters of the action |
| `stack_rule` | how this effect scales with stacks: `add` (value × stacks), `mult` (value ^ stacks), `reduce_n` (N − 1 per extra stack, min 2), `count` (stacks is the count) |

**Example, Blast Ring** = two rows: `explode(radius 90, damage_mult 1.2)` and `self_damage(8)`, both `every_n_fired` with N=5. **Grow** = `size_mult 2` and `damage_mult 1.25`. A "debuff" is just another effect row on the same upgrade.

### `states.csv` (enemy states)

`id, name, duration_sec, tick_interval_sec, tick_damage, stack_cap, speed_mult, damage_taken_mult, color`

### `enemies.csv` (extends today's file)

Adds `behavior` (id from the behavior list in section 7) and `tags` (e.g. `armored`, `regenerating`, `swarm`) alongside the existing hp/damage/speed columns.

### `scenarios.csv`

`id, name, theme, difficulty (1-10), rat_count, spider_count, alien_count, boss_species, boss_count, formation, behavior_flags, hint_icon`

`hint_icon` is what the portal shows (a species icon).

### `unlocks.csv`

`upgrade_id, unlock_weight, tier` (tier 1-3, higher tiers unlock later and less often).

---

## 4. Engine rules (the part that must be exactly right)

### 4.1 Firing pipeline (per trigger pull)

1. **Bullet count** = `(1 + Σ additive sources) × Π multiplier sources`, then clamped.
   - additive: e.g. Bloodshot (+1 per 25 current HP).
   - multiplier: Split (×2 per stack).
   - **Example:** 2 Split stacks = ×4. Bloodshot at 100 HP + 2 Splits = (1 + 4) × 4 = 20 bullets.
2. Each bullet gets its stats: damage, size, speed, pierce, pattern. Same additive-then-multiplicative order as today's `get_effective_stat`.
3. Fire the bullets in a fan. Then run `on_fire` triggers once per bullet, and count each bullet toward the `fired` counter.
4. Ammo: **one pull uses one round regardless of bullet count.** Magazine and reload work as today, otherwise multipliers would drain ammo.

### 4.2 Counters

Two run-wide counters, both counting **all** bullets, including ones spawned by upgrades:
- `fired`: increments when a bullet is created.
- `hits`: increments when a bullet hits an enemy.

`every_n_fired` triggers fire when `fired % N == 0`; `every_n_hits` when `hits % N == 0`. A bullet spawned by an upgrade (e.g. "spawn a random bullet") **counts as a bullet**, so it can feed other triggers. That is the exponential loop you described.

### 4.3 Safety caps (so a great build can't freeze the game)

| cap | starting value |
|---|---|
| bullets per pull | 32 |
| live bullets at once | 300 |
| generation depth (a bullet spawned by an upgrade is generation +1; generation ≥ 3 can't spawn more) | 3 |
| explosions per frame | 20 |

When a cap blocks a bullet, it silently doesn't spawn. Caps are constants in one file so they can be tuned after profiling.

### 4.4 Action vocabulary (the fixed code surface)

Stat: `bullets_add`, `bullets_add_per_hp` (value = HP per +1 bullet), `bullets_mult`, `damage_mult`, `size_mult`, `speed_mult`, `fire_rate_mult`, `pierce_add`, `pattern_zigzag`, `ricochet_add`.
Effect: `apply_state(id, stacks)`, `explode(radius, damage_mult)`, `self_damage(amount)`, `heal(amount)`, `shove(radius, force)`, `spawn_bullet(random_direction)`, `damage_vs_state(state|any, mult)`.

About 17 actions, each implemented once. Everything in section 5 is built from them via `upgrade_effects.csv` rows.

---

## 5. Upgrade roster (slice one, first-pass numbers)

Baseline pistol: 10 damage, 3.5 shots/s, 12-round magazine (about 35 damage/s). Defaults marked ★.

| upgrade | trigger | effect | stack rule | cap |
|---|---|---|---|---|
| ★ **Split** | passive | bullets ×2 (no damage change) | mult | 3 |
| ★ **Grow** | passive | `size_mult` 2 + `damage_mult` 1.25 (two effects) | mult | 3 |
| ★ **Poison** | on_hit | apply Poison (1 stack) | add | 3 |
| ★ **Pierce** | passive | +2 pierce | add | 3 |
| ★ **Quickdraw** | passive | fire rate ×1.25 | mult | 4 |
| **Exploit** | passive | debuffed enemies take ×1.75 from bullets | mult | 2 |
| **Shrapnel** | on_hit | every hit explodes: radius 40, 40% damage | add radius | 2 |
| **Chill** | on_hit | apply Chill | count | 2 |
| **Bloodshot** | passive | +1 bullet per 25 current HP | none | 1 |
| **Field Medic** | every_n_fired (N=6) | heal 4 HP | reduce_n | 3 |
| **Blast Ring** | every_n_fired (N=5) | `explode` radius 90, 120% damage + `self_damage` 8 HP (two effects) | reduce_n | 2 |
| **Shockwave** | every_n_fired (N=4) | shove all enemies within 160 | reduce_n | 3 |
| **Echo** | every_n_hits (N=4) | spawn 1 bullet in a random direction (counts as a bullet) | reduce_n | 2 |
| **Zigzag** | passive | bullets weave side to side | none | 1 |
| **Ricochet** | passive | +1 wall/enemy bounce | add | 3 |
| **Volatile Core** | on_kill | dead enemies explode (radius 50, 60% of the killed enemy's max HP as damage) | none | 1 |

Deliberate weak links (so bad builds exist): Zigzag (just `pattern_zigzag`) does nothing for damage by itself and makes aim less precise; Blast Ring hurts you; Shockwave with a slow fire rate rarely triggers; Chill without a payoff does little. Field Medic needs a high bullet count to matter. The pistol's slow rate makes every_n_fired upgrades feel bad until multipliers arrive, which is intended.

**Sanity check for a great build** (the loop the design should reward): Split ×2, Grow ×2, Poison ×2, Exploit, Echo. Bullets per pull: ×4, each at full damage. Each poisoned; Exploit multiplies damage on poisoned enemies; Echo bullets count toward the next Echo. With no Split penalty this is already ×4 raw damage from Split alone, so the real ceiling needs checking with the balance tool. That is the ceiling I'm aiming for. See section 10.

---

## 6. States (`states.csv`, first pass)

| id | duration | tick | effect | stack cap |
|---|---|---|---|---|
| `poison` | 4s | 1s, 3 damage × stacks | ticks damage | 5 |
| `chill` | 3s | none | speed ×0.6 | 1 (refreshes) |

"Debuffed" means any state active. Refresh rule: applying a state adds a stack up to the cap and resets the timer. Later ideas (not slice one): `burn` that spreads on death, `mark`.

---

## 7. Enemy behaviors (counters to builds)

Design rule: each behavior is the **antithesis of a build**, so build choices matter. All start as simple rules.

| species | behavior | counters | how to answer it |
|---|---|---|---|
| Spider (base) | **Lunge**: short telegraph, then a fast dash | standing still, slow single-target builds | keep moving, Chill, Shockwave |
| Rat | **Back-biter**: aims behind you | builds that only cover the front | Blast Ring, Ricochet, Echo |
| Alien | **Armored**: flat -4 damage per bullet hit (min 1) | many low-damage bullets (rapid fire, Split spam of weak shots); poison ticks are unaffected | any damage-per-bullet upgrade, Poison |
| Alien | **Regenerator**: heals 3/s if not hit for 2s | slow poison-only builds | burst damage, Exploit |
| Later | Web-thrower (slow zone), Shielded (front block) | | |

Armor takes 4 off every hit, so a 10-damage bullet does 6. Since Split no longer lowers per-bullet damage, armor punishes weak bullets in general, and the counters are damage-per-bullet upgrades and states. Enemy data gets a `tags` column so `payoff` upgrades and counters both read the same tags.

No ranged shooters, per your note.

---

## 8. Scenarios and portals

- A scenario is one `scenarios.csv` row (composition + formation + behaviors + difficulty).
- **Pool size:** hand-authoring 200 is too much. Plan: author ~24 scenarios, then **generate** the rest from `theme × formation × intensity` templates with a seeded RNG (same seed = same level, matching how `EnemySpawner` already works). The pool can grow later without code changes.
- **Run draw:** difficulty comes from the level scaling table in 13.10 (enemy HP, enemies per wave, number of waves), not from rating bands. Scenarios are drawn for variety of enemy mix, formation and behaviors. The `difficulty` column of `scenarios.csv` is no longer used for gating.
- **Portals:** after a level, draw 2 scenarios. Each portal shows the `hint_icon` of the species that dominates it (an alien or a spider), with nothing else revealed.
- Boss scenarios at levels 5 and 10.

---

## 9. Unlocks (never a dead run)

- **Every run end (win or lose):** unlock 1 upgrade, weighted by `unlock_weight` and tier. Death before level 3 still unlocks a tier-1 item.
- **Win bonus:** pick 1 of 3 locked upgrades to unlock. No heat levels (owner removed them).
- Start with the 5 defaults (★). Save the unlocked set in `save.json`.
- The unlocked pool is what the pick-1-of-3 draws from. More unlocks means more build variety.

---

## 10. Balance targets and the tool to check them

Balance needs numbers, not feel. Targets (first pass, to be validated):

**Updated by the owner (13.10):** the target is a **range**, with no guaranteed floor. The best possible build reaches about **100×** baseline damage per pull at the final level. A good build reaches around 20×. A bad build falls behind the enemies and **dies**, and that is intended. **Enemies scale to 20× by the final level** (geometric, 1× at level 1), so a build needs roughly 20× damage by level 10 just to keep pace. The old ceiling was 40× for any build.

Picks equal the level number. The ceiling is the most a perfect build can reach at that level (geometric from 1× to 100× at level 10). Enemy scale is the break-even line:

| level | enemy scale (20× by level 10) | ceiling (best build) |
|---|---|---|
| 1 | 1.0× | 1.6× |
| 2 | 1.4× | 2.5× |
| 3 | 1.9× | 4× |
| 4 | 2.7× | 6.3× |
| 5 (boss) | 3.7× | 10× |
| 6 | 5.2× | 16× |
| 7 | 7.2× | 25× |
| 8 | 10× | 40× |
| 9 | 14× | 63× |
| 10 | 20× | 100× |

Break-even and best are therefore 20× and 100× at the end: a build at 20× barely survives, and a perfect one has a 5× margin. The calculator flags a build above the ceiling for its level (too strong too early). It also reports the level where each build falls below the enemy line, to show how long it survives. Example: ten Grow picks give 3.5× at level 10, far below 20×, so that build dies.

**Tool:** a small script (`tools/build_calc.py`) that reads `upgrades.csv`, takes a list of picks, and prints expected bullet count, per-bullet damage, hit chance assumptions, and damage per pull. It runs over all pick combinations of size ≤ 8 and flags builds over the "broken" threshold. This is the "difference of one number" safety net. The numbers in section 5 are a starting point for it, not final.

---

## 11. Build order

1. **Fork + data model:** copy to `game_v2/`; `upgrades.csv`, `states.csv`, loader; player upgrade stacks; fire pipeline (4.1-4.3); the 5 default upgrades. Playable.
2. **States + trigger upgrades:** poison/chill, Exploit, `every_n_*` triggers, the rest of the roster.
3. **Run loop:** fixed 10-level structure, pick after each level, results and unlock.
4. **Balance tool** and a tuning pass.
5. **Enemy behaviors** (lunge, back-biter, armored, regenerator).
6. **Scenarios and portals**, then the generator.

Each step ends playable.

---

## 12. Decisions

Answered:
1. **Picks:** level clears only (11 per run). XP level-ups dropped.
3. **Split penalty:** none. Split is the single effect `bullets_mult` ×2. The owner may add a separate debuff effect later.
4. **Self-damage upgrades:** keep rare.
5. **Effects model:** single-effect building blocks in code, combined into upgrades in the spreadsheet (see section 3).

2. **Ammo:** one round per pull, regardless of bullet count (owner: use recommendation).
6. **Scenario count:** about 24 authored plus generated (owner: use recommendation).
7. **Win bonus:** pick 1 of 3 unlocks. Heat levels were later removed by the owner.

No decisions are open. Section 13 holds ideas added later, with their own open questions.

Consequence to watch: with no Split penalty, Split at 4 stacks would be ×16 bullets. Cap is 3 stacks (×8) for now; the balance tool decides.

---

## 13. Addendum: ideas added after the first review

None of this is built. Items marked *open* need an owner answer before coding. These add to the sections above and do not replace them, except where noted.

### 13.1 Setting and tone

- **Premise:** the character is stranded in a junkyard of the multiverse, a place where everything lost in space and time ends up, and is trying to escape. Level 10 is the way out.
- **Why it helps:** it explains the mix of themes without needing consistent lore. Weapon parts are salvage from different realities, enemies are strays from elsewhere, portals are wormholes between scrap-heaps, and unlocks are salvage found.
- **Rules:** original names only, no pop-culture references anywhere in names, text or docs. Upgrades are called **salvage** in the UI. Story is framing only: a line per scenario or unlock in the CSVs, an opening line and a win screen. No dialogue, cutscenes or lore tracking.
- **Focus:** upgrades change the weapon. Character perks are optional and rare. The pistol should be able to mutate into something strange by the end of a run.

### 13.2 Stacking and unlock rules

- **Stackable by default.** Most upgrades can be picked more than once, with a `stack_rule` per effect and a `max_stacks` cap. Multipliers always need a cap. A hyperbolic stack rule (each extra stack adds less) is a candidate for chance-based effects. *Open:* a limit on how many different upgrades a player may hold.
- **Draw rule:** each 1-of-3 offer should contain at least one upgrade the player doesn't own, so runs don't collapse into one upgrade. *Open: confirm.*
- **Stack tooltips** show the next stack, for example "Split 2 to 3: 4 bullets to 8".
- **Chained upgrades.** An upgrade may list one or two upgrades in a `requires` column. It joins the draw pool only once those are owned. Meeting the requirement makes it eligible, nothing more. It may still never appear in a run. Keep chains to two steps and about three chains in slice one. A prerequisite must be useful on its own.
- **Linked abilities.** If the player holds both upgrades in a pair, a third upgrade is applied automatically and costs no pick. A short announcement shows when it fires. Links are hidden until found, with a small hint on the pick screen. *Open:* whether a link needs one stack of each or scales with the lower stack count.
- **Combos table.** One table covers both. A row lists required upgrades (with minimum stacks) and a grant. If the grant is an upgrade it is a linked ability. If the grant is an unlock or a cosmetic it is a combo achievement for a themed build. Order of picks doesn't matter. Slice one: 3 to 5 combos. *Open:* whether combo rewards are in-run bonuses, permanent unlocks, or both.

### 13.3 New upgrade ideas

Names are original. Everything is data built from effects, plus the new actions noted.

| upgrade | idea | needs |
|---|---|---|
| **Soul Snatcher** | +0.1% damage per kill in the run, shown on screen as a running total. Counts all kills (bullets, poison, explosions). Resets each run | new `kills` counter, `damage_per_kill` action |
| **Reaper** | chained, requires Soul Snatcher. +0.1% max HP per kill, and current HP rises with it. Capped (for example +150%) | `max_hp_per_kill` action |
| **Gravity Seed** | a hit pulls nearby enemies into a clump for a short time. Boosts every explosion | `pull(radius, force)` action |
| **Shard Bloom** | hits embed shards in the enemy. At 6 shards they detonate together | new state `shard`, detonate-at-cap rule |
| **Third Strike** | two hits on an enemy within 3 s stuns it, a third disintegrates it | per-enemy hit tracking |
| **Bond Arc** | a hit links the enemy to the nearest one. Damage and states are shared along the link | link action |
| **Twin Gate** | the first two walls hit become a linked portal pair for bullets and enemies. Expensive. Later | portal system |
| **Still Field** | a hit creates a zone that freezes everything inside, then releases bullets with extra speed | zone action |

Percent values assume +0.1% per kill. The raw ".001" is meaningless as a flat bonus on 10 damage or 100 HP. *Open: confirm percent.*

**Keyword tags.** Each strange upgrade carries a tag (clump, link, shard, stasis, gate). Payoffs read tags, not upgrade names, so one payoff works with any upgrade carrying the tag. Players learn the combos, such as clump plus explosion, by experimenting.

**Grow rework.** Grow also adds a charge time: each stack lengthens the fire interval by a percentage. It is implemented as `fire_rate_mult` below 1, as a third effect on the same upgrade. A charge that has started always finishes. One charge is one pull, so Split does not change it. Tuning goal: damage multiplier must exceed time cost, or Grow is a nerf. Candidate numbers: damage ×1.6, size ×2, +25% charge per stack. Add a muzzle glow during the charge. A hold-to-charge skill version is a separate later upgrade.

**Field Medic** heals the player, which is a perk. Rework it into a weapon effect (for example a proc that refunds a round) or cut it.

**Cut or deferred:** small-object character items in the style of other roguelites are out. Mechanics worth considering, not decided: a proc weight on each bullet that lowers the chance of further effects (a softer alternative to the generation cap in 4.3), and a rare "cursed" upgrade category for risky upgrades.

### 13.4 Pickups (reverses part of "no pickups")

The earlier decision "no weapon pickups" stands for swapping weapons. **Addendum:** temporary pickups that modify the pistol are allowed. A pickup applies an upgrade's effects as a temporary stack with a limited number of charges, for example "next 20 rounds do fire", and everything else in the build multiplies it.
- Charges count **pulls**, so Split doesn't drain them faster (matches the ammo decision).
- Fire needs a `burn` state in `states.csv` (listed as a later idea in section 6).
- Source: enemy drops on a small chance per kill. Collecting a second one adds more charges.
- Slice one: two or three pickups.

### 13.5 Later (bigger version, not the MVP)

- **Visual changes:** each upgrade visibly changes the weapon or character. Weapon has 4 to 6 attachment slots, each upgrade names a slot and a sprite, shared pieces are recolored. Bullet color, size and trail follow the upgrade. Reserve `slot` and `visual_id` columns in `upgrades.csv` now.
- **Slice one version:** bullet color and size per upgrade with placeholder shapes.

### 13.7 Upgrade fixes (from the rubric pass)

Not every upgrade needs every pillar. Missing a couple is normal, and a handful of slow builders is fine. These changes aim for "felt immediately" and a real choice on each pick, and cut engine cost where possible.
- **Soul Snatcher, Reaper:** front-loaded. +5% damage at pick, then +0.1% per kill. +10 max HP at pick, then +0.1% per kill.
- **Field Medic** is replaced by **Reclaimer**: every 6th bullet refunds a round. It stops being a heal.
- **Zigzag:** weaving bullets cross the same enemy twice, so on-hit effects trigger twice.
- **Cost on formerly automatic picks:** Split fans into a spread (strong close, weaker at range). Poison trades 20% direct damage for its ticks. Pierce loses 20% damage per enemy passed. Quickdraw drains the magazine faster. Ricochet loses 15% damage per bounce. Some plain anchors are fine among the 5 starting upgrades.
- **Exploit:** +15% damage to everything, plus the large bonus against debuffed enemies, so it is felt at once.
- **Cost reductions:** Volatile Core uses a fixed blast size. Echo's spawned bullets are limited to generation 2. Twin Gate stays but is scheduled last.

**Five new upgrades** (all in `upgrade-rubric.csv`): **Brood Seed** (kills may hatch a drone that bites for about 6 s), **Orbit Shard** (every 5th bullet orbits you as a shield for 5 s), **Fault Line** (a bullet's path cracks and erupts after 1.5 s), **Heat Coil** (heat builds per pull and full heat fires a huge piercing beam), and **Adaptive Round** (bonus damage against the species you've hit most this level, a deliberate slow builder).

### 13.8 Target: 100 upgrades (long term)

The prototype only needs 16 to 24. 100 is the goal for the bigger version. Rough breakdown: bullet shape and behavior 12, states 12, triggers 14, payoffs 12, alien and space 14, ammo and rhythm 10, chained follow-ups 16, linked abilities 10. Limits: new effect types grow from about 17 to perhaps 40 and each is coded once, and balance cost rises with the number of combinations, so the build calculator (section 10) should exist before the roster passes about 30. It is not written yet and Python is not installed on the owner's PC, so use GDScript or another available tool.

### 13.10 Balance ceiling: 100× late in the run

The balance target is a **range at the final level: about 20× to 100× baseline damage per pull**, depending on how well the player builds. It is not a guaranteed 100×. Chaos late in the run is intended (see the table in section 10).
- **Same upgrade stacks add; different upgrades multiply.** Within one upgrade, extra stacks add (for example Grow +25% damage per stack: 3.5× after 10 stacks), so spamming one pick loses. Across upgrades, effects multiply (bullet count × damage × state ticks × payoffs), so complementary builds grow exponentially. Ten picks of ×1.5 each would be 58×, which is why plain stat upgrades should use the `add` stack rule, with `mult` kept for true engine multipliers like Split's bullet count.
- **No guaranteed floor.** There is no built-in growth curve and no minimum per upgrade. A bad build should lose. Failure comes from enemy scaling.
- **Enemy scaling: 20× by level 10**, geometric (about ×1.39 per level, 20 to the power of (level minus 1) / 9). It applies to **enemy HP only** for now (owner decision). Speed and contact damage do not scale. 
- **Level scaling (owner decision):** as levels go up, enemies gain more HP, **and** each level spawns more enemies at a time and/or more waves. There must be an **overwhelming factor** late in the run, so players have a reason to improve their build: crowds should be too big to handle with a weak build. Numbers vary by enemy species (a swarm species scales in count, a heavy species in HP).
  - **Dials, all data:** a per-level scaling table (`scaling.csv`: `level, hp_mult, count_mult, wave_count`), plus per-species scaling multipliers in `enemies.csv` (for example `hp_scale_weight`, `count_scale_weight`).
  - **HP dial:** reaches 20× by level 10 as above. Count and waves come on top, so total enemy HP in a level grows faster than 20×. That makes multi-hit and area builds (Split, Shrapnel, Pierce, explosions) more valuable than single-target damage alone.
  - **First guess:** enemies per wave about 3× and waves from 1 to 3 by level 10. Tune by playtesting.
  - **How the break-even line is measured (owner decision):** clearing speed is a contributing factor. The calculator reports two measures against the enemy line: **crowd clearing speed** on normal levels (area, multi-hit and splash count fully), and **single-target damage** on boss levels 5 and 10 (only damage landing on one enemy counts). A single boss is one target, so clearing speed alone would hide a weak single-target build. Result: a pure area build struggles against bosses and a pure single-target build is overwhelmed by crowds, so players must plan for both.
  - **Bosses spawn adds (owner decision).** Both measures then matter at once. The number and kind of adds depends on the boss's species, nature and theme. For example, a **Rat King** spawns a large stream of rats, while a heavier boss spawns few. Adds also scale with the level scaling table.
    - **Data:** boss rows in `enemies.csv` get `adds_species`, `adds_count`, `adds_interval_sec` and `adds_trigger` (`timer`, or an HP threshold such as `hp_50`). Adding a boss is a CSV row.
    - **Examples to design:** Rat King (constant rats), a spider matriarch (spiderlings when she drops to certain HP thresholds), a heavy armored alien (a few escorts). Names are placeholders.
  - Section 8's difficulty bands are replaced by this.
- **Caps matter.** Bullets per pull are capped at 32, so most of the 100× has to come from damage multipliers, states, triggers and kill-scaling payoffs like Soul Snatcher, not from bullet count alone. The caps in 4.3 need stress-testing at this scale, especially live bullets (300) and explosions per frame (20).
- **Enemies must keep up.** Late levels need enough HP or density that a 100× build is exciting and not trivial. Tune scenario difficulty bands (section 8) against this curve.
- **Picks are fixed by level.** Entering level L the player holds exactly L picks (one at the start plus one per cleared level), so level 8 means 8 picks, level 5 means 5. Every stack is a pick. The "11 picks per run" in section 2 is really **10 useful picks**, since the pick after clearing level 10 comes after the win.
- **Per-pick multiplier needed.** 100× in 10 picks is about ×1.58 damage per pick on average, and 20× is about ×1.35. Total damage counts every source (bullets, splash, poison ticks, triggers), so a pick that adds a second damage source counts heavily.
- **Chains cost picks.** A chained upgrade costs its prerequisite pick as well, so it must be worth two picks. Linked abilities are free and are the most pick-efficient reward.
- **Calculator scope.** Test builds of exactly L picks for level L only, not every combination up to 8.
- **Early levels are the risk.** A build that reaches 30×+ by level 4 ruins the arc. The build calculator should flag that, using the level it is reachable at (picks so far = level + 1).

### 13.11 Boss levels (levels 5 and 10)

**Rules (owner decisions):**
- The boss **spawns immediately** when the level starts.
- The waves are **built into the boss**: its adds (see 13.10) are its waves, driven by a timer or by HP thresholds.
- The level ends when the **boss is dead and every enemy already spawned is dead**.
- **Killing the boss sooner spares the remaining waves.** When the boss dies, spawning stops, so waves that have not appeared yet never do. Enemies already on the field still have to be cleared. This rewards burst and single-target damage, and ties to the boss damage measure in 13.10.
- Boss HP and add counts scale with the level scaling table, and boss rows are data in `enemies.csv`.

**Sketch: Level 5, the Rat King.** A huge rat on a mound of junk, with a back-biting attack.
- **Adds:** a constant stream of rats on a timer (about every 2 seconds) that grows with the level scaling.
- **Theme:** crowds. Area builds shred the rats, but the King keeps feeding them until it dies.
- **Answers:** burst on the boss to stop the stream, or area builds to hold the flood. Chill and Shockwave help with the swarm. Placeholder numbers, to tune.

**Sketch: Level 10, the Gate Warden** (the guardian of the way out). A slow, heavily armored alien.
- **Behavior:** armored (flat damage reduction per hit). Small bullets from Split spam do very little to it.
- **Adds:** a few armored escorts at HP thresholds (75%, 50% and 25%).
- **Theme:** a damage check. It punishes weak bullets and rewards big hits, poison ticks, and anything that ignores armor, such as Third Strike or Heat Coil's beam.
- **Why it ends the run:** a build that only clears crowds cannot kill it, which is the point of having the final test be single-target damage.

*Open:* confirm that an early boss kill cancels unspawned waves (recommended: yes).

### 13.9 Rubric

`upgrade-rubric.md` and `upgrade-rubric.csv` score each upgrade against ten pillars: Synergy, Risk, Counterplay, Readable, Run arc, Alien and unusual, Player skill, Power fantasy, Felt immediately and Draft tension. Every pick should be felt in the next level and be a real choice, not an obvious one. The pillar list is a brainstorm and may change. Fill a row before building any upgrade.

