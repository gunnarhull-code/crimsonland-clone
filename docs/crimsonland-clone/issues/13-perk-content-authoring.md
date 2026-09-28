Type: grilling
Blocked by: 12
Status: resolved

## Question

Author the actual 20 MVP perks using the schema from [12 - perk effect architecture](12-perk-effect-architecture.md): each perk's name, its vague in-game description text (per [08 - perk scope](08-perk-scope.md) — qualitative, no numbers shown to the player), and its precise underlying CSV values.

Draw on the original's real perk categories for inspiration (research doc, section 8: stat boosts, risk/reward trades, weapon modifiers, utility/pickup effects, pure-XP/gimmick perks) but the MVP's 20 don't need to be a subset of the original's 55 — invent where it serves the mechanics being proven.

## Answer

All 20 names and descriptions are original (not lifted from the original game's text) — drawing only on its perk *categories* for inspiration, per the note above. Authored into [perks.csv](../perks.csv), 22 rows for 20 distinct perks (Berserker and Glass Cannon each span 2 rows — the multi-row convention from [12](12-perk-effect-architecture.md) for a perk with two simultaneous stat effects):

- **Stat boosts**: Iron Skin (max_hp), Sprinter (move_speed), Second Wind (hp_regen), Late Bloomer (max_hp, on level-up).
- **Weapon modifiers**: Fast Hands (reload_time), Trigger Finger (fire_rate), Steady Hands (spread), Big Clips (magazine_size), Hot Loads (projectile_speed), Big Bore (damage), Marksman (spread), Overclock (fire_rate).
- **Utility**: Lucky Find (pickup_luck), Magnet Fingers (pickup_radius), Low Profile (aggro_radius_multiplier — ties back to [10](10-enemy-ai-parameters.md)'s 450px base radius), Sharp Mind (perk_choices_offered), Scavenger (pickup_radius).
- **Risk/reward** (2-row perks): Berserker (fire_rate up, max_hp down), Glass Cannon (damage up, max_hp down).
- **Special** (the one perk needing `special_handler_id`, validating that escape hatch is real and rare): Lucky Break — 15% chance on kill to drop a bonus pickup.

**Correction during authoring**: the draft shared with the user actually already totaled 20 before Lucky Break was added, which would have made 21 — one over the [Perk scope](08-perk-scope.md) cap. Dropped **Pack Mule** (a multiplicative magazine-size perk redundant with Big Clips' additive one) to hold the line at exactly 20.

Depends on [14 - Player vitals & leveling](14-player-vitals-and-leveling.md) (still open) to actually establish `player.max_hp`, `player.hp_regen`, and `weapon.damage` as real stats — this ticket doesn't block on that, it just assumes those names will exist.
