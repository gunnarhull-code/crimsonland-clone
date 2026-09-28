Type: prototype

## Question

Graduated from the map's "Not yet specified" fog: what does the MVP actually look and sound like, given the standing constraint that graphics/VFX/audio are "super simple" placeholders — the mechanics are what matter, not production values.

- A shape/color convention per entity: player, each of the 3 enemy Species + their Boss Variants ([05](05-enemy-roster.md)), each of the 6 weapons' projectiles ([11](11-weapon-stat-table.md)), and perk pickups if any exist as world objects.
- Concrete enemy footprint sizes — [03](03-hitbox-model.md) fixed hitboxes as circles at center-of-mass but deferred exact radius per species; [17](17-enemy-spawn-pacing.md)'s ~250 concurrent-enemy cap used a placeholder 40px average diameter assumption that needs replacing with real numbers once this ticket picks actual sizes.
- A minimal SFX/VFX cue per meaningful event: firing each weapon type, an enemy taking a hit, an enemy dying, the player taking damage, leveling up (per [14](14-player-vitals-and-leveling.md)'s pause + choice + 0.5s invulnerability), and picking up a weapon.

This is a prototype-type ticket — resolve it by making something concrete (a rough visual mockup, even ASCII/wireframe-level) to react to, not by describing shapes in prose.
