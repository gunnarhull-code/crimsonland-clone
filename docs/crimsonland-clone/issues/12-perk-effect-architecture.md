Type: grilling
Status: resolved

## Question

Design the `perks.csv` schema and the Godot-side effect system architecture, given the standing requirement (from the interview, recorded in map.md's Notes): **maximize what's spreadsheet-editable, minimize hardcoded special-cases.**

Specifically:
- Define the column schema for `perks.csv` — the user explicitly said to add as many columns as needed per perk (e.g. separate columns per stat modified, modifier type, trigger condition) rather than cramming everything into one generic "value" field.
- Identify which categories of the 20 perks (see [08 - perk scope](08-perk-scope.md) for scope, effects will span stat boosts, risk/reward trades, weapon modifiers, utility/pickup effects, and pure-XP/gimmick effects per the research doc's section 8 examples) can be expressed as **pure data** the game logic reads generically (e.g. "additively modify player.max_hp by X").
- Identify which perk categories genuinely need a **hardcoded handler** in Godot (e.g. anything with a unique behavior no generic stat-modifier system covers), and minimize that set as much as possible — a small `effect_id`/`special_handler` column referencing a Godot-side case is an acceptable fallback, but the goal is to keep that list short.
- A small Godot prototype exercising 2-3 example perks from different categories (a pure stat boost, a weapon modifier, and a suspected "needs hardcoding" case) would validate the schema before [13 - perk content authoring](13-perk-content-authoring.md) commits to it for all 20.

Note: prerequisite/stacking chains exist in the original (e.g. a perk requiring another already be taken) — decide whether the MVP's 20 perks need this at all, and if so, how the CSV expresses it.

## Answer

**`perks.csv` columns**: `id`, `name`, `description` (vague in-game text), `category`, `effect_type`, `target`, `value`, `trigger`, `special_handler_id` (nullable), `prerequisite_id` (nullable, unused for now — column stays for schema stability, but no MVP perk sets it).

**Prerequisite/stacking chains**: skipped for the MVP's 20 perks — real UI/logic complexity (checking availability, graying out choices) for a feature that doesn't test any mechanic this MVP needs to prove.

**Effect Type**: `additive` (add `value` to `target`) or `multiplicative` (scale `target` by `value`). Covers any perk expressible as pure math against a stat — reload time, fire rate, damage, spread, pickup radius, move speed, max HP, etc.

**Trigger**: starts as `passive` (always-on, the common case), `on_kill`, `on_hit`, `on_levelup` — but the engine's trigger dispatch must be a lookup keyed by trigger name (not a hardcoded if/else chain), so adding a new trigger value later is additive, not a redesign.

**`special_handler_id`**: used whenever a perk's effect genuinely can't be expressed as Effect Type + target + value — i.e. "can this be reduced to math against a stat?" is the test, not a target count. Confirmed example: a perk that spawns a bonus pickup on kill (a game action, not a stat change) needs one; a perk that boosts a stat by a percentage never does, no matter how unusual the stat.

**Validation — 3 worked examples** (paper prototype, no Godot code written; that's the implementation effort's job):

| id | name | description | category | effect_type | target | value | trigger | special_handler_id |
|---|---|---|---|---|---|---|---|---|
| steady_hands | Steady Hands | "Your aim feels steadier." | weapon_modifier | multiplicative | weapon.spread | 0.5 | passive | — |
| lucky_find | Lucky Find | "You seem to find better items." | utility | additive | player.pickup_luck | 0.2 | passive | — |
| lucky_break | Lucky Break | "Kills sometimes leave something behind." | special | special | — | 0.15 | on_kill | bonus_pickup_on_kill |

Steady Hands and Lucky Find prove the generic additive/multiplicative path handles ordinary stat perks with zero hardcoding. Lucky Break proves the `special_handler_id` escape hatch is reachable and rare — exactly the shape this ticket set out to validate.
