Type: grilling
Status: open

## Question

New ticket, opened directly from playtesting/planning. Replace the six hard-coded weapon upgrades from [22](22-permanent-weapon-upgrades.md) with a real **weapon modification system**: data-driven mods that change how a weapon behaves, defined in a CSV, applied through generic effect handlers, so new mods can be added or retuned without touching code.

Motivation, stated directly by the user: "I want to make sure that we try to structure everything in systems so I can modify them easily in the future" - and to be told when something is being hard-coded instead.

## Problem: what is hard-coded today

- `UpgradeShop.gd`: `WEAPON_UPGRADES` (names, descriptions, costs), `PERK_UNLOCKS`, `PERK_COST`.
- `Player.gd` / `Projectile.gd`: upgrade effects keyed off `weapon_id == "smg"`, `SaveManager.has_upgrade("shotgun")`, `PIERCE_COUNT`, `KNOCKBACK_STRENGTH`, etc.
- Adding a mod today means editing shop code, player code, and projectile code.

## Proposed direction (to be grilled before building)

1. **`weapon_mods.csv`** (docs copy + `game/data` runtime copy, same as every other CSV). One row per mod, in the same spirit as `perks.csv`: `id, name, description, target_weapon, cost, trigger, effect_type, value, effect_type_2, value_2, special_handler_id, prerequisite_id`.
2. **Triggers**: `passive`, `on_fire`, `on_hit`, `on_kill`, `on_reload`, `on_reload_start`.
3. **Generic effect handlers** (small, reusable, parameterised by CSV values): stat multiplier/adder, damage over time (poison), burn, area burst, chain/arc jump, pierce count, knockback, extra projectile, fire-rate ramp, shockwave. Existing upgrades (Akimbo, Railgun Overcharge, Chain Reaction, Buckshot Knockback, Spin-Up Barrel, Cluster Warhead) become rows plus handler parameters.
4. **`WeaponModManager`** (or an extension of the existing effective-stat pipeline): resolves owned mods for a weapon and dispatches trigger events; `Player`/`Projectile` ask it instead of checking weapon ids.
5. **Shop is generated from the table**: `UpgradeShop` reads `weapon_mods.csv`; no per-mod code in the UI.
6. **Save format**: owned mods stored by id (already how `SaveManager` stores upgrades), with a migration for the existing six.
7. **Open design questions for the grilling pass**: slots or tiers per weapon (e.g. 2 mods per weapon)? Are mods permanent purchases only, or also found in-run? Can mods stack/prerequisite-chain? Which of the candidate mods below ship first?

## Candidate mods (from the original Crimsonland's perk list, filtered for this game)

Weapon-mod-shaped (need one handler each): Poison Bullets, Fire Bullets, Uranium Filled Bullets (big damage), Radioactive (damaging aura), Ion Gun Master (bigger chains/arcs, Electric Gun), Toxic Avenger / Veins of Poison (poison spreads), Angry Reloader (reload shockwave), Stationary Reloader (faster reload while still), Anxious Loader, My Favourite Weapon, Alternate Weapon (carry two - larger feature).

Pure-data stat perks (no new code, belong in `perks.csv`): Fastloader, Fastshot, Ammo Maniac, Sharpshooter, Barrel Greaser, Thick Skinned, Regeneration, Greater Regeneration, Long Distance Runner, Unstoppable, Reflex Boosted.

Survival/utility (later): Dodger/Ninja, Man Bomb, Fire Cough, Final Revenge, Living Fortress, Lifeline 50-50, Bandage, Doctor, Hot Tempered, Breathing Room, Plaguebearer.

Excluded as gimmick/meta or reliant on systems this game lacks: Perk Expert/Master, Instant Winner, Fatal Lottery, Random Weapon, Jinxed, Grim Deal, Death Clock, Infernal Contract, Bonus Magnet, Bonus Economist, Telekinetic, Monster Vision, Bloody Mess, Regression Bullets.

(Candidate list is from memory of the original game, not verified against a source.)

## Answer

_Not yet resolved - pending a grilling pass on the open questions above._
