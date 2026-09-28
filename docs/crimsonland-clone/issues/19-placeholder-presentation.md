Type: prototype
Status: resolved

## Question

Graduated from the map's "Not yet specified" fog: what does the MVP actually look and sound like, given the standing constraint that graphics/VFX/audio are "super simple" placeholders — the mechanics are what matter, not production values.

- A shape/color convention per entity: player, each of the 3 enemy Species + their Boss Variants ([05](05-enemy-roster.md)), each of the 6 weapons' projectiles ([11](11-weapon-stat-table.md)), and perk pickups if any exist as world objects.
- Concrete enemy footprint sizes — [03](03-hitbox-model.md) fixed hitboxes as circles at center-of-mass but deferred exact radius per species; [17](17-enemy-spawn-pacing.md)'s ~250 concurrent-enemy cap used a placeholder 40px average diameter assumption that needs replacing with real numbers once this ticket picks actual sizes.
- A minimal SFX/VFX cue per meaningful event: firing each weapon type, an enemy taking a hit, an enemy dying, the player taking damage, leveling up (per [14](14-player-vitals-and-leveling.md)'s pause + choice + 0.5s invulnerability), and picking up a weapon.

This is a prototype-type ticket — resolve it by making something concrete (a rough visual mockup, even ASCII/wireframe-level) to react to, not by describing shapes in prose.

## Answer

Resolved via an interactive visual prototype (3 structurally different variants + a combined final pick): [Placeholder Visual Variants](https://claude.ai/artifact/AJ7m7pL9aeiByNsL5EBxir). The winning design merges Variant A (bold per-species shape) and Variant C (hitbox-transparent circle silhouette):

**Core principle**: every character's outer silhouette is a circle sized *exactly* to its hitbox radius — what's visible is what can hit you, no thin decorative extremities beyond the collision shape (satisfies [03](03-hitbox-model.md)'s "well thought out, not lazy" hitbox requirement directly, by making the hitbox and the sprite the same shape). Inside that circle sits a bold, flat-colored geometric shape unique per species — stronger silhouette recognition than a thin icon would give.

**Confirmed hitbox radii** (display mockup used 4x scale for visibility; these are the actual game values):
- Player: **14px**, cyan (`#6FB8E8`), triangle inner shape.
- Rat: **10px** base / **16px** Boss Variant, green (`#6FCF6F`), 3-dot cluster inner shape (its own motif, not a smaller player triangle).
- Spider: **16px** base / **26px** Boss Variant, orange (`#F2924A`), diamond inner shape.
- Alien: **22px** base / **35px** Boss Variant, red (`#E85D5D`), hexagon inner shape.
- Boss Variants additionally get a 3px white outline ring.

Filled into [enemies.csv](../enemies.csv)'s `hitbox_radius_px` column, left blank since [18](18-godot-scene-structure.md).

**Weapon projectiles**: Pistol = small white/cyan dot, Gauss = thin yellow line, Electric = small cyan zigzag, Shotgun = cluster of 5 small gray dots, SMG = small orange dot, Heavy Cannon = large bold red-brown circle.

**SFX/VFX cues** (minimal, per weapon/event): fire = tiny muzzle flash matching weapon color; enemy hit = brief white flash on the shape; enemy death = shape shrinks and fades over 0.15s; player hit = red screen-edge vignette pulse; level-up = 0.5s golden ring expanding from the player + short chime (matches [14](14-player-vitals-and-leveling.md)'s pause + choice + 0.5s post-choice invulnerability); Nest destroyed = shape cracks into 3 fading fragments.

**Particle effects**: one generic, reusable burst — 4-8 small colored squares spawned at the event position, randomized outward velocity, fading out over ~0.3s — parameterized by count/color/speed per event rather than a bespoke system each time:
- Muzzle flash accent: 1-2 particles, weapon's own color.
- Enemy hit impact: 2-3 particles, white.
- Enemy death: 5-6 particles, matching that species' inner-shape color from the palette above — layers on top of the existing shrink-fade, doesn't replace it.
- Nest destroyed: 8 particles, gray/debris-colored — formalizes the "cracks into 3 fragments" cue into the same reusable system instead of a separate one-off.
- Level-up: 6 particles, golden, radiating alongside the expanding ring.

Lives in an `Effects` container alongside the `Enemies`/`Projectiles` containers from [18](18-godot-scene-structure.md)'s scene structure — same instancing pattern, not a new architectural concept.

**Addendum — bullets and gun pickups get real shapes, not generic dots/rings**: direct playtest feedback ("give the weapons shape, not circles — bullets are different from guns") pointed out that the "circle = hitbox" principle above had silently spread to things that aren't hitboxes at all — every bullet was a dot (or, for Gauss, a line), and every dropped weapon was the same ring-and-dot regardless of which weapon it was. Two independent shape languages now exist, deliberately different from each other for the same weapon:
- **Bullets** (`ProjectileVisual.gd`): Pistol/SMG = elongated capsule, Gauss Gun = long thin beam (unchanged), Electric Gun = small jagged bolt glyph, Shotgun = forward-pointing pellet triangle, Heavy Cannon = tapered rocket nose-cone.
- **Weapon pickups** (`WeaponPickup.gd`): Pistol = square, Gauss Gun = long diamond, Electric Gun = bolt outline, Shotgun = fan/wedge, SMG = three stacked bars, Heavy Cannon = rocket silhouette. Sits on a small dark diamond plate (not a circle) for ground contrast.

The circle-hitbox rule itself is untouched — it still applies to every Player/Enemy silhouette via `EntityVisual.gd`, unchanged.

**Addendum — Electric Gun chain gets a VFX line**: the chain-lightning jump from the primary target to the nearby enemy it arcs to was previously invisible (both just took damage with no visual link). A brief jagged line (`ZapLine.gd`, same reusable-effect pattern as `ParticleBurst.gd`) now draws between the two enemies for ~0.15s on every chain hit, so the arc is legible.
