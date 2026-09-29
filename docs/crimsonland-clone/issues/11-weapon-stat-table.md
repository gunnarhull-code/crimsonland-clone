Type: grilling
Status: resolved

## Question

Finalize the MVP's weapon roster and stats, building on the anchors fixed in [07 - weapon roster anchor](07-weapon-roster-anchor.md):

- Design the remaining 2-3 weapon slots (roster is 5-6 total: Pistol, piercing Gauss-style gun, electric/chain gun, plus these).
- For every weapon in the final roster, specify: fire rate, magazine size, reload time, projectile speed (bullets are confirmed projectile-based with real travel time, not hitscan — the user specifically likes "leading" slow-bullet shots as a feel, per the interview), accuracy/spread, and damage.
- For the electric/chain weapon specifically: its chain range and how many additional nearby enemies it can arc to (confirmed as "one nearby enemy" in the interview — confirm this stays fixed at 1 or becomes tunable).
- For the piercing Gauss-style gun: does it pierce an unlimited number of enemies in its line, or a capped number (the original's manual describes "kill 3 or more enemies per shot" as a capability, not a hard cap - decide what the MVP does)?

## Answer

**Roster: 6 weapons total.** Stats live in a `weapons.csv` (one row per weapon, one column per stat) — same tuning benefit as `perks.csv`, no hidden schema complexity since weapons have no special-case behavior beyond piercing/chaining.

| Weapon | Fire rate | Magazine | Reload | Projectile speed | Spread | Damage | Special |
|---|---|---|---|---|---|---|---|
| Pistol | 2/s | 12 | 1.2s | 700px/s | ~2° (tight) | Medium | Starting weapon, the baseline |
| Gauss Gun | 1/s | 5 | 1.8s | 900px/s | ~0° (precise) | High | Pierces up to 3 enemies per shot |
| Electric Gun | 3/s | 20 | 1.5s | 600px/s | Light | Medium-low | Arcs to 1 enemy within 150px of primary target, same full damage to both |
| Shotgun | 1/s | 6 | 1.8s | 650px/s | ~25° (wide) | Low-medium per pellet | Fires 6 pellets/shot |
| SMG | 8/s | 30 | 1.2s | 900px/s | ~10° (moderate) | Low | Volume-of-fire weapon |
| Heavy Cannon | 0.5/s | 4 | 2.5s | 300px/s | ~0° (precise) | Very high | Slowest bullet in the game — the deliberate "lead your shot" showcase (crosses the full 1280px arena in ~4.3s) |

**Addendum**: materialized as [weapons.csv](../weapons.csv) (this table's qualitative damage tiers — Medium/High/Low-medium/etc. — became concrete numbers there: Pistol 10, Gauss Gun 25, Electric Gun 7, Shotgun 4/pellet, SMG 5, Heavy Cannon 50 — consistent with the tiers above, provisional/tunable like every other CSV value).

**Retune from actual playtest**: the Pistol's original 2/s fire rate and 700px/s bullet speed felt sluggish in play ("slow, doesn't fire often enough") — bumped to 3.5/s fire rate, 1.0s reload (from 1.2s), 900px/s bullet speed (tied with SMG/Gauss Gun for fastest). This is exactly the kind of paper-spec-vs-actual-feel gap the MVP exists to surface; every other weapon's numbers are unchanged pending their own playtest.

**Second playtest round**: bullet speeds bumped further — Pistol 900→950, Gauss Gun 900→1400 ("way faster" per direct request, now clearly the fastest bullet in the game, fitting a piercing precision weapon), Electric Gun 600→700, Shotgun 650→750, SMG 900→950. Heavy Cannon's 300px/s is deliberately untouched — it's still the intentional slow "lead your shot" showcase.

**Heavy Cannon now explodes on impact** — 60px splash radius, flat damage to every enemy caught in it (no falloff), reversing the "defer splash/AoE post-MVP" call from this ticket's original Q15 answer. Requested directly during playtesting ("think bazooka") — the MVP surfacing real desires beats the paper spec's guess. See [map.md](../map.md)'s Out of scope section for the reversal note.

**Third playtest round — Electric Gun way, way slower**: 700→120px/s, now clearly the slowest bullet after the Heavy Cannon (previously it was mid-pack). Requested directly so the bullet actually travels slowly enough for the new chain-lightning VFX (see [19](19-placeholder-presentation.md)'s addendum) to read as a visible arc instead of an instant snap. Fire rate/magazine/damage unchanged.

**Heavy Cannon: "rocket taking off" launch curve** — the projectile now starts at a near-stationary 25px/s and ramps to its normal 300px/s cruise speed over a cubic ease-in across ~0.18s, instead of leaving the barrel at full speed. Requested directly ("start super slow for a tiny fraction of a second then speed way way up, like a rocket taking off"). The 300px/s cruise speed and ~4.3s arena-crossing time from the original table are otherwise unchanged.

**Addendum — projectile range becomes a real, designed stat**: previously every weapon's effective range was just an incidental side effect of a flat 3-second lifetime times whatever speed it happened to have - never an intentional number, and it showed: the Electric Gun's "way way slower" retune above shrank its effective range to ~360px almost by accident. Per direct request ("I want the range of most items to be at least three quarters of the screen, whatever that would be. And then maybe more if it is increased by a perk"), a new `range_px` column on [weapons.csv](../weapons.csv) gives each weapon an explicit, designed maximum travel distance, and `Projectile.gd` now expires by **distance traveled**, not elapsed time (the old flat lifetime is now just a generous 8s safety net against a pathological near-zero-speed case). Three-quarters of the 1280px design-width screen is 960px; every weapon clears that floor: Pistol/SMG 1400, Gauss Gun 2000 (the longest, fitting its precision-piercer identity), Electric Gun/Shotgun 1000 (closer-range weapons by design), Heavy Cannon 1600. `range` was also added to `Player.gd`'s `WEAPON_STAT_MAP` (as `weapon.range` → `range_px`), so it flows through the exact same additive/multiplicative `stat_modifiers` path every other weapon stat already uses - "maybe more if it is increased by a perk" now just needs a Perk authored against that target string whenever that's wanted; no new architecture required.
