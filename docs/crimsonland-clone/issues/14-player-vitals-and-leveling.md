Type: grilling

## Question

Define the player's health/damage model and the XP/leveling model — neither was addressed directly in the interview, and both are load-bearing for the MVP:

- **Health**: does the player have an HP pool (able to take multiple hits, as the original implies via perks like "Thick Skinned: -33% max HP for -33% damage taken" and "Regeneration") or is it one-hit-death? If an HP pool, what's the base value, and how is damage from enemy contact/projectiles applied (flat per-hit? per-second while in contact?)?
- Is there any temporary invulnerability window — the original grants a shield on every level-up in addition to the perk choice (research doc, section 9) — does the MVP copy this?
- **Death condition**: exact trigger (HP reaches 0, presumably) and what happens on death (session just ends — confirmed via [02](02-arena-session-structure.md) that death is the only end condition; does anything else need to happen, e.g. a score/results screen?).
- **XP**: earned from kills only, or also survival time/other sources? What curve — copy the original's documented `1000 * (1 + level^1.8)` formula (research doc, section 9), or use something simpler for the MVP?
- Confirm the level-up choice screen presents 3 perks (per [08](08-perk-scope.md)) and whether gameplay pauses during the choice or continues in real-time (the original's is a real-time prompt, not a full pause, per the "gaining enough experience... choosing one of five" framing — verify this is what's wanted here too).
