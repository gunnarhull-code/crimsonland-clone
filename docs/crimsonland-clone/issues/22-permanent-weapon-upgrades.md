Type: grilling
Status: implemented

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
  "unlocked_upgrades": ["gauss_gun", "smg"]
}
```
`unlocked_upgrades` is a flat set of weapon ids — since this first pass gives each weapon at most one permanent mechanic upgrade, owning it is boolean, not tiered (no per-upgrade tier count needed, unlike Perks). Loaded once at game start (`SaveManager._ready()`); written immediately after every purchase (small, infrequent writes — no need to batch). This is the first persistence anything in this codebase has ever needed; every other Autoload ([16](16-multiplayer-readiness-architecture.md)'s architecture) is pure in-memory session state.

### Applying upgrades: a second, deliberately different mechanism from Perks

**Revised after direct feedback**: the first draft below tried to force these into [12](12-perk-effect-architecture.md)'s additive/multiplicative stat-modifier system (bigger magazine, more pierce, wider spread — bigger numbers). Rejected: "go with actual mechanic changes, not just bigger numbers." A mechanic change — an unlimited-pierce beam, a cascading chain, knockback, a fire rate that ramps while held, cluster bomblets — is exactly the kind of thing [12](12-perk-effect-architecture.md) defined `special_handler_id` for: *not* reducible to math against a stat. Since every permanent upgrade in the revised list below is a one-time behavioral unlock (not a stacking tier), the mechanism is simpler than a tiered stat system needs to be:

- `SaveManager.has_upgrade(weapon_id: String) -> bool` — each weapon has at most one permanent mechanic upgrade in this first pass, so a flat owned-set (`{"gauss_gun": true, "smg": true}` in the save file) is enough; no tiers, no CSV, no schema to design yet.
- Each weapon's own script checks it directly at the exact point its behavior diverges — `Projectile.gd`'s `_on_body_entered`/`_try_chain`/`_explode` for Gauss/Electric/Heavy Cannon, `Player.gd`'s `_fire`/`_update_weapon` for Pistol/Shotgun/SMG. No generic dispatch layer, because there's nothing generic about "explosions now spawn bomblets" — it's bespoke by nature, same as Lucky Break was the one perk that needed real code instead of data.
- This is intentionally a *different* extension point from Perks, not a unification of the two — Perks stay pure stat math via `stat_modifiers`; permanent weapon upgrades stay pure behavior branches via `SaveManager.has_upgrade()`. Trying to force both through one system would mean bending one of them to fit the other for no real benefit.

### Where it sits in the flow

`ResultsScreen` (per [14](14-player-vitals-and-leveling.md)/[02](02-arena-session-structure.md)) currently shows stats and waits for any key to restart. That becomes a two-step flow: stats panel → **Upgrade Shop panel** (lists affordable/owned upgrades, spend Banked Score, any number of purchases) → press to restart. The shop reads/writes `SaveManager` directly; restart still just reloads the Arena scene exactly as already built, now with `Player._ready()` picking up whatever was purchased.

### Proposed starting upgrade list — one real mechanic change per weapon, one-time unlock each

| Weapon | Upgrade | What actually changes | Cost (Banked Score) | Implementation sketch |
|---|---|---|---|---|
| Pistol | **Akimbo** | Each trigger pull fires two bullets in a slight V-spread instead of one — a real firing-pattern change, not a damage/rate number. | 150 | `Player._fire()`: if unlocked, loop the single-shot branch twice with a small fixed offset angle instead of once. |
| Gauss Gun | **Railgun Overcharge** | The pierce cap is removed entirely — the beam punches through every enemy in its line, not just 3. Turns it from "a piercing shot" into "a line that erases everything in it." | 300 | `Projectile.gd`: skip the `pierce_remaining` decrement/cutoff check entirely when unlocked, instead of raising `PIERCE_COUNT`. |
| Electric Gun | **Chain Reaction** | Instead of arcing to exactly one nearby enemy, it keeps cascading to the next-nearest untouched enemy in range, each jump doing less damage than the last, until no target is left in range. Turns a single arc into a real chain. | 300 | `Projectile.gd`'s `_try_chain()`: loop instead of a single jump, tracking a damage-falloff multiplier per jump (e.g. ×0.7 each time), still respecting `_hit_enemies` so it can't double-hit. Each jump still fires a `ZapLine`. |
| Shotgun | **Buckshot Knockback** | Pellets physically shove enemies back on hit. A new mechanic no weapon has: enemies briefly get pushed instead of just damaged. | 250 | `Enemy.gd` needs a short-lived external-impulse state (e.g. `_knockback_velocity` that decays over ~0.2s and overrides normal wander/chase velocity while active) so `Projectile.gd` has something to push. |
| SMG | **Spin-Up Barrel** | Fire rate ramps up the longer the trigger is held continuously (starts at its normal rate, climbs toward roughly double over ~1.5s), resetting the moment you release or have to reload. Turns "volume of fire" into an actual spin-up minigun. | 250 | `Player.gd`: track continuous-hold duration in `_update_weapon()`, scale the SMG's effective `fire_rate_per_sec` by a ramp curve while held, reset the timer on release/reload. |
| Heavy Cannon | **Cluster Warhead** | On explosion, also flings out 3-4 small bomblets that arm mid-air and detonate a moment later, each with their own smaller blast — one big explosion becomes a primary blast plus a handful of secondary ones. | 350 | `Projectile.gd`'s `_explode()`: spawn a few small `Bomblet` instances with a short fuse timer and a smaller `EXPLOSION_RADIUS`-style AoE of their own, flung outward at random angles/speeds. |

This list is still the part most worth pushback on. A couple are more involved than others to build (Chain Reaction and Cluster Warhead touch existing systems; Buckshot Knockback and Spin-Up Barrel are genuinely new mechanics with no precedent in the codebase yet) — flag now if any should be simplified, swapped, or dropped from the first pass.

### Not yet resolved

- Exact costs (numbers above are placeholders, same "provisional, tunable" status every other number in this project gets pending actual play).
- Whether Banked Score should show anywhere during a run (e.g. a small "lifetime total" HUD readout) or only appear at the Upgrade Shop.
- Whether an upgrade can be un-bought/respecced, or purchases are final (leaning final, matching the no-respec stance implicit in Perks never being un-chosen mid-run).
- Whether each weapon should ever get a *second* permanent upgrade later (a real tier/tree), or stays capped at one mechanic swap each - the flat boolean save shape above deliberately doesn't block that later, it just doesn't build for it now.

### Implemented — plus permanent Perks, per "go ahead with the next thing... I also want permanent perks that carry over"

Built essentially as drafted above, all six weapon upgrades exactly as sketched, plus one addition beyond this ticket's original scope: **permanent Perk unlocks**, sitting in the same shop, spending the same Banked Score. Rather than opening all 20 Perks to permanent purchase (overlapping with in-run Perk choices in ways that weren't worth designing through right now), only the four `stat_boost`-category Perks from [13](13-perk-content-authoring.md) are offered - Iron Skin, Sprinter, Second Wind, Late Bloomer - flat universal baseline boosts, at 200 Banked Score each. A permanently-owned Perk applies via `Player._apply_permanent_perks()` at `_ready()`, calling the exact same `apply_perk()` a level-up choice calls - it's a baseline the run starts with, not a new mechanism.

The death→continue flow changed from the original "press to restart" sketch, superseded by direct feedback in the same request ("let's make it click a button to continue"): `ResultsScreen` now has a real Continue button (`continue_pressed` signal) instead of restarting on any key/click, which opens `UpgradeShop.tscn` - list of upgrade/perk purchase buttons, a wave picker (see [23](23-wave-based-spawning-and-difficulty-markers.md)), and a Start Run button that sets `SaveManager.next_run_start_wave` and reloads the Arena.

Verified end-to-end headlessly with temporary instrumentation: death correctly banks the run's Score, Continue opens the shop, a purchase correctly deducts cost and flips `has_upgrade()`, the save file is written to `user://save.json`, and - critically, since this is the first persistence this codebase has ever had - a **separate, fresh process launch** correctly loads the same purchased upgrade back from disk. Each of the six weapon mechanics was also individually verified in isolation (cascading Chain Reaction damage falloff, Cluster Warhead bomblets detonating and cleaning themselves up, Railgun Overcharge never freeing on hit, Buckshot Knockback actually moving the enemy, Akimbo's two-projectile spawn, and the permanent Perk's stat change landing before `_ready()` reads it).

**Bugfix — the shop was unusable**: reported directly ("the upgrade menu after you die doesn't work. It's just a bunch of text"). The original layout's actual content (title, score, 10 purchase buttons across two sections, the wave picker, the Start Run button) was ~700px tall packed into a `PanelContainer` positioned to leave only ~680px of vertical room in the 720px-tall design viewport - the Start Run button and several of the later buttons were almost certainly rendered past the bottom edge of the screen, unreachable, leaving only the header labels actually visible (exactly "a bunch of text," since nothing below the headers could be seen or clicked). This is precisely the kind of overflow the original death→continue flow's much smaller LevelUpChoice/ResultsScreen panels never had to deal with, since neither has anywhere near 10 buttons. Fixed by wrapping the two purchase lists in a `ScrollContainer` with a fixed height, so the wave picker and Start Run button always have guaranteed room below it regardless of how many upgrades/perks exist, and shrinking the buttons themselves (44px, smaller font, single-line text) to fit more in view before scrolling is even needed. Verified via temporary instrumentation: the Panel now renders at exactly its intended 800×690 size at (240, 15), and the Start Run button's screen position (y≈577) is comfortably within the 720px-tall viewport.
