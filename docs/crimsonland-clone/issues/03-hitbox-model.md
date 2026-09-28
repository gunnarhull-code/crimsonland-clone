Type: grilling
Status: resolved

## Question

What hitbox shape and placement should the MVP use for the player and enemies?

## Answer

**Circle hitboxes** for the player and every enemy — cheapest collision math, no rotation edge cases, and the original never confirmed anything more elaborate anyway (see research doc, section 5).

Critically: each circle is sized and positioned at the character's **center of mass**, not a generic bounding circle around the full sprite. The radius is deliberately **smaller than the visual silhouette** wherever an enemy has thin/decorative extremities (a spider's legs, a monster's tail or toe) — those parts must never register a hit. Radius is tuned per enemy type by hand, not derived from a single generic formula (e.g. "50% of sprite width").

Exact per-enemy radius values are not yet set — that falls out of the enemy roster/visual work, not this ticket.
