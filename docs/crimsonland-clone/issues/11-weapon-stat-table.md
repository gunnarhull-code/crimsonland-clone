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
