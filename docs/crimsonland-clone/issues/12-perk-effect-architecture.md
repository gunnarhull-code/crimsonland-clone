Type: grilling
Status: claimed

## Question

Design the `perks.csv` schema and the Godot-side effect system architecture, given the standing requirement (from the interview, recorded in map.md's Notes): **maximize what's spreadsheet-editable, minimize hardcoded special-cases.**

Specifically:
- Define the column schema for `perks.csv` — the user explicitly said to add as many columns as needed per perk (e.g. separate columns per stat modified, modifier type, trigger condition) rather than cramming everything into one generic "value" field.
- Identify which categories of the 20 perks (see [08 - perk scope](08-perk-scope.md) for scope, effects will span stat boosts, risk/reward trades, weapon modifiers, utility/pickup effects, and pure-XP/gimmick effects per the research doc's section 8 examples) can be expressed as **pure data** the game logic reads generically (e.g. "additively modify player.max_hp by X").
- Identify which perk categories genuinely need a **hardcoded handler** in Godot (e.g. anything with a unique behavior no generic stat-modifier system covers), and minimize that set as much as possible — a small `effect_id`/`special_handler` column referencing a Godot-side case is an acceptable fallback, but the goal is to keep that list short.
- A small Godot prototype exercising 2-3 example perks from different categories (a pure stat boost, a weapon modifier, and a suspected "needs hardcoding" case) would validate the schema before [13 - perk content authoring](13-perk-content-authoring.md) commits to it for all 20.

Note: prerequisite/stacking chains exist in the original (e.g. a perk requiring another already be taken) — decide whether the MVP's 20 perks need this at all, and if so, how the CSV expresses it.
