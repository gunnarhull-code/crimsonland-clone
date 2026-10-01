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
- **Run draw:** levels 1-10 have difficulty bands (level 1 = difficulty 1-2 … level 10 = 9-10).
- **Portals:** after a level, draw 2 scenarios from the next band. Each portal shows the `hint_icon` of the species that dominates it (an alien or a spider), with nothing else revealed.
- Boss scenarios at levels 5 and 10.

---

## 9. Unlocks (never a dead run)

- **Every run end (win or lose):** unlock 1 upgrade, weighted by `unlock_weight` and tier. Death before level 3 still unlocks a tier-1 item.
- **Win bonus:** pick 1 of 3 locked upgrades to unlock, plus a "heat" level (harder enemies) for the next run.
- Start with the 5 defaults (★). Save the unlocked set in `save.json`.
- The unlocked pool is what the pick-1-of-3 draws from. More unlocks means more build variety.

---

## 10. Balance targets and the tool to check them

Balance needs numbers, not feel. Targets (first pass, to be validated):

| build quality | damage per pull vs. baseline |
|---|---|
| no synergy (random picks) | 1.5-3× |
| decent (2-3 related picks) | 4-8× |
| strong (planned loop) | 12-25× |
| broken (should not be reachable) | > 40× |

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

Still open:
2. **Ammo:** a "multi-bullet pull" is one click that fires several bullets (because of Split). Does it spend 1 round or 1 per bullet? (Recommended: 1 per pull.)
6. **Scenario count:** ~24 authored + generated?
7. **Win bonus:** pick 1 of 3 unlocks plus a heat level?

Consequence to watch: with no Split penalty, Split at 4 stacks would be ×16 bullets. Cap is 3 stacks (×8) for now; the balance tool decides.
