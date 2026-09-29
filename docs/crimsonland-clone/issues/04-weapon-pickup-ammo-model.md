Type: grilling
Status: resolved

## Question

How do players acquire weapons during a run, and how does ammo work?

## Answer

Matches the original exactly (see research doc, section 3):

- Player **starts with a Pistol only**.
- Additional weapons **drop from killed enemies**. Picking one up **swaps** the currently-held weapon — no carrying/dual-wielding multiple guns in the MVP.
- **Ammo is infinite** — there is no ammo-pickup or ammo-scarcity mechanic of any kind. What differentiates weapons from each other is **magazine size and reload time** (plus fire rate, projectile speed, accuracy, and damage — see [11 - weapon stat table](11-weapon-stat-table.md)), not how much ammo you have left.

**Addendum — dropped weapons despawn**: a dropped weapon now disappears after 10s if the player never collects it (blinking for the last 2s as a warning), rather than sitting on the ground forever. Requested directly during playtesting. Doesn't change the drop-chance model above - only what happens to a drop nobody picks up.
