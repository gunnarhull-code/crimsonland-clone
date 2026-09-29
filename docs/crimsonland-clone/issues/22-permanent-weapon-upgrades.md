Type: grilling
Status: drafted — architecture decided, content list is a proposal pending confirmation

## Question

New ticket, opened directly from playtesting rather than the original interview (per map.md's Frontier status allowing reopening): the player wants a post-death **upgrade screen** that spends a persistent currency on upgrades that **permanently change how a weapon works**, surviving across runs. This is explicitly a *different* system from the deferred Chapters/Checkpoints idea in [future-progression-notes.md](../future-progression-notes.md) (permanent Perk-pool unlocks via Miniboss/Boss kills) — confirmed separate and simpler for now, not an extension of that idea.

Three things were confirmed directly with the user before drafting this:
1. **Persistence**: real save-to-disk, surviving closing and relaunching the game (not just in-memory across deaths in one session).
2. **Currency**: reuse Score — no new tracked number.
3. **Scope**: standalone post-death upgrade shop; no Chapters/Checkpoints/Miniboss-unlock structure attached.

What's left to decide: the save file's shape, how a permanent upgrade actually alters a weapon (reusing [12](12-perk-effect-architecture.md)'s stat-modifier architecture vs. new hardcoding), where the shop sits in the death→restart flow, and the actual starting list of upgrades.

## Answer

### Currency: "Banked Score" vs. in-run Score

The in-run Score (weighted kills + survival time, per [20](20-score-display.md)) is unchanged — still shown live, still shown on the results panel. Separately, **the full amount of each run's final Score is added to a persistent lifetime total** on death — call it **Banked Score**. Upgrades are purchased by spending down Banked Score. This keeps the in-run number meaning exactly what it already means (a per-run performance score) while giving the permanent system its own pool, without inventing a second tracked resource the player has to learn.

### Save file

A new `SaveManager` Autoload owns a single JSON file at `user://save.json`:
```json
{
  "banked_score": 0,
  "upgrades": { "pistol_magazine": 2, "electric_chain": 1 }
}
```
`upgrades` maps upgrade id → tier currently owned (0 if absent). Loaded once at game start (`SaveManager._ready()`); written immediately after every purchase (small, infrequent writes — no need to batch). This is the first persistence anything in this codebase has ever needed; every other Autoload ([16](16-multiplayer-readiness-architecture.md)'s architecture) is pure in-memory session state.

### Applying upgrades: extend the existing stat-modifier system, don't build a second one

[12](12-perk-effect-architecture.md) already has exactly the right shape for this — `effect_type` (additive/multiplicative) against a `target` stat string, read generically by `Player.get_effective_stat()` / `get_effective_weapon_stats()`. Permanent upgrades reuse that verbatim:

- A new `weapon_upgrades.csv` (same pattern as `perks.csv`): `id, weapon_id, name, description, cost, effect_type, target, value, max_tier`.
- At `Player._ready()`, before anything else, every owned upgrade (looked up by id → tier in the save file) gets fed into `stat_modifiers` via the same `_apply_single_effect()` perks already use — tier 2 of an additive upgrade just applies the additive effect twice (or once with `value * tier`, equivalent). Perks chosen mid-run then layer on top of this permanent baseline exactly like they layer on top of the weapon's raw CSV stats today — no interaction code needed, it falls out of the existing layering.
- **This requires promoting a few currently-hardcoded weapon mechanics into real stats first**, so they're addressable as a `target` string at all:
  - Gauss Gun's pierce count (`Projectile.gd`'s `PIERCE_COUNT := 3` constant) → new `weapons.csv` column `pierce_count`, read like every other stat.
  - Electric Gun's chain count (currently always exactly 1, hardcoded in `_try_chain`) → new `weapons.csv` column `chain_targets`.
  - Heavy Cannon's explosion radius (`Projectile.gd`'s `EXPLOSION_RADIUS := 60.0` constant) → new `weapons.csv` column `explosion_radius_px`.
  - Shotgun's pellet count (hardcoded `for i in 6` in `Player._fire()`) → new `weapons.csv` column `pellet_count`.

  This is a genuine architecture improvement independent of this feature: it closes the gap between "things expressible as stat math" and "things that were actually hardcoded anyway despite being simple numbers" — the same gap [12](12-perk-effect-architecture.md) already fought to minimize for Perks. Once done, a future Perk could also target `weapon.pierce_count` etc. for free.

### Where it sits in the flow

`ResultsScreen` (per [14](14-player-vitals-and-leveling.md)/[02](02-arena-session-structure.md)) currently shows stats and waits for any key to restart. That becomes a two-step flow: stats panel → **Upgrade Shop panel** (lists affordable/owned upgrades, spend Banked Score, any number of purchases) → press to restart. The shop reads/writes `SaveManager` directly; restart still just reloads the Arena scene exactly as already built, now with `Player._ready()` picking up whatever was purchased.

### Proposed starting upgrade list (draft — six weapons, one or two each, needs your sign-off before authoring into the CSV)

| Weapon | Upgrade | Effect | Tiers | Cost (Banked Score) |
|---|---|---|---|---|
| Pistol | Extended Mag | +1 magazine_size / tier | 5 | 50 × tier |
| Pistol | Quick Reload | −0.1s reload_time / tier | 3 | 75 × tier |
| Gauss Gun | Deeper Pierce | +1 pierce_count / tier | 2 (3→5 total) | 150 × tier |
| Electric Gun | Double Arc | chain_targets 1→2 | 1 (one-time) | 300 |
| Shotgun | Wider Spread | +1 pellet_count / tier | 3 (6→9 total) | 100 × tier |
| SMG | Bigger Drum | +10 magazine_size / tier | 3 | 80 × tier |
| Heavy Cannon | Bigger Boom | +15px explosion_radius_px / tier | 3 (60→105px) | 200 × tier |

This list is the part most worth pushback on — it's a first guess at what "permanently change how weapons work" should mean concretely, not a locked decision like the architecture above.

### Not yet resolved

- Exact cost curve/balance (numbers above are placeholders, same "provisional, tunable" status every other CSV value in this project gets).
- Whether Banked Score should show anywhere during a run (e.g. a small "lifetime total" HUD readout) or only appear at the Upgrade Shop.
- Whether an upgrade can be un-bought/respecced, or purchases are final (leaning final, matching the no-respec stance implicit in Perks never being un-chosen mid-run).
