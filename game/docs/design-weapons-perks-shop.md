# Design: Mods, quirky weapons, enemy verbs, discovery shop

Status: **proposal, nothing implemented.** Read, mark up, and tell me what to change before any code is written.

Goal: fun, unique, simple effects that play off each other. Rounds-style physical perks, weapons with one weird rule each, enemies with one readable attack verb, and a shop where you *discover* items.

---

## 1. Mods: the shared vocabulary

A **mod** is a small rule hooked into a projectile's life (on fire, each tick, on hit, on expire).

- A **weapon** = base stats + *innate* mods.
- A **perk** (projectile kind) = a mod you *add*.

Today, Gauss pierce, Electric chain, Cannon explosion and Shotgun knockback are hardcoded `if weapon_id == ...` branches in `Player.gd` / `Projectile.gd`. Under this design they become mods (`Pierce`, `Chain`, `Explode`, `Knockback`), so any perk can grant them to any weapon, and Gauss can gain `Explode`.

Mods belong to the **player**, not the weapon, so they carry over when you swap weapons. The weapon's own stats (rate, pellet count, speed, size) decide how a mod feels:

| Mod | Pistol (fast, single) | Shotgun (6 pellets) | Heavy Cannon (slow, big) |
|---|---|---|---|
| **Boomerang**: returns after range, hits on the way back, catching it refunds the round | Ammo management becomes a game | Six returning pellets | The rocket comes back at you |
| **Minelayer**: shots stop after ~0.3s and become proximity mines, fire rate -40% | Mine trail while you run | Carpet of six mines | One giant mine |
| **Ricochet**: bounces off walls and off enemies once | Trick shots | Chaos | Bouncing rockets |
| **Split**: on hit, splits ±30° | Cheap crowd control | Exponential pellets | Splits *before* exploding |

More candidates: **Homing**, **Orbit** (shots circle you for 2s), **Delayed Volley** (shots hang, then all release), **Sticky** (3 stuck shots pop an enemy), **Backblast** (also fires one shot behind you), **Twin** (Akimbo), **Pierce**, **Chain**, **Explode**, **Knockback**.

Duplicate picks stack intensity (Split ×2 = 3-way) instead of being blocked.

### Debuff mods (paired with strong mods so nothing is a free pick)

- **Recoil**: each shot shoves you back.
- **Loud**: aggro radius ×1.5.
- **Heavy Rounds**: slower bullets, plus knockback.
- **Misfire**: 10% duds.
- **Slippery**: momentum on movement.

Plain stat perks (Iron Skin, Sprinter, etc.) stay as they are, as the cheap/common tier.

---

## 2. Quirky weapons

Each gets one weird rule that mods can then bend. Existing weapons are kept and converted to innate mods.

- **Flare Gun**: ignites enemies, and fire spreads between clumped enemies (rat packs).
- **Sawblade Launcher**: slow blades that bounce around for ~4s.
- **Magnet Gun**: hits pull nearby enemies into a clump (great with splash).
- **Nail Gun**: nails stick, and enemies with 3+ nails pop.
- **Slot Gun**: each shot rolls a random mod from your perk list.
- **Flail**: orbiting ball on a chain (melee-feel).

---

## 3. Enemy verbs (one each; telegraph, counter, synergy)

| Enemy | Verb | Counter / synergy |
|---|---|---|
| **Rat** | **Back-biter**: aims at the point *behind* you (opposite your movement/aim direction). Uses the existing `_chase_aim_offset` mechanism. | Keep moving, turn around, Backblast, Minelayer |
| **Spider** | **Web-spinner**: stops, lobs a web; a telegraphed circle lands ~1s later and leaves a ~3s slow zone | Read the circle and step out. Webs slow *you* only |
| **Alien** | **Shielded**: frontal damage heavily reduced | Flank, or use Ricochet / Boomerang |

Later: spitter, bloater (explodes on death).

---

## 4. Discovery shop (new)

### Rules

- A shop opens **every N waves** (proposed: after waves 3, 6, 9, then every 3rd; a `shop_after` flag in `waves.csv` so it's tunable).
- Each shop offers ~3 weapons and ~3 perks/mods at prices.
- Items are in one of two states:
  - **Undiscovered** (`???`): you see name, icon, one-line concept ("Shots return to you"), rarity, price, and **▲/▼ direction arrows** for stats, but **no magnitudes**.
  - **Discovered**: full stat card.
- **Buying an undiscovered item does two things at once:**
  1. it permanently **discovers** it, revealing its numbers and adding it to the random pool;
  2. you get it now, this run.
- **Undiscovered items never appear in level-up choices or weapon drops.** Only discovered ones do. So discovery *widens your pool*, and the shop is where you widen it.
- Discovered items can still be bought in shops at a price as a **guaranteed** pick, versus the randomness of level-ups and drops.
- Numbers are fixed per item, not rolled. The mystery is only "what are the numbers", never "will it be different next time".
- Concept text is always clear. Only the magnitudes are hidden, so a buy is a gamble on *how good*, not on *what it is*.

### Currency

**Scrap**, dropped by kills, per run. Rough scale (to tune): rat 2, spider 4, alien 8, boss ×6; prices 30 (common) to 150 (rare). At ~3 purchases per shop the player has to choose.

### Meta-progression

Discovered set is saved in `save.json`. Run 1 starts with a small default-discovered set (pistol and the basic stat perks) so the game is playable. Breadth of discovery is the long-term progression. An optional codex screen shows discovered items and silhouettes of undiscovered ones.

### Integration with existing code

- `SaveManager`: add `discovered_weapons` and `discovered_perks` sets, persisted. **The existing `unlocked_perks` means "applied automatically at spawn"**, which is a different concept, so it gets renamed or retired (see questions).
- `DataTables` + CSVs: add `rarity`, `price`, `discovered_by_default` columns to `weapons.csv` and `perks.csv`; perks gain `mod_id` and `stackable`.
- `Player._roll_perk_choices` and `Enemy._maybe_drop_weapon`: filter to discovered items only.
- `EnemySpawner`: when a wave clears and `shop_after` is set, open the shop instead of straight-advancing.
- New `ShopScreen` scene: card layout (the current button-list `UpgradeShop` had layout issues before), paused like `UpgradeShop`.

---

## 5. Build order

1. Mod system refactor; move Pierce / Chain / Explode / Knockback / Twin onto it. Gameplay unchanged.
2. Add Boomerang, Minelayer, Ricochet, Split + Recoil and Loud debuffs.
3. Discovery data model (columns, save, pool filtering) + ShopScreen + scrap.
4. Rat back-biting, spider webs.
5. New weapons, alien shield, codex.

Each step ends playable.

---

## 6. Open questions (my recommendation first)

1. **Existing post-death shop** (banked score, permanent weapon upgrades like Akimbo, start-wave picker). Recommend: **retire the upgrades and perks** (they become mods you discover), **keep the start-wave picker**. Alternative: keep both shops.
2. **Weapon slots.** Currently picking up a weapon replaces the current one. Recommend: keep single slot, so the shop's weapon buy is a swap. Alternative: 2 slots with a swap key, which makes mods carrying across weapons matter more.
3. **Shop cadence.** Every 3 waves as proposed, or less often?
4. **Hidden info.** Recommend arrows but no magnitudes. Alternative: hide everything except the name.
5. **Rerolls.** Allow a paid shop reroll? Recommend not for the first pass.
