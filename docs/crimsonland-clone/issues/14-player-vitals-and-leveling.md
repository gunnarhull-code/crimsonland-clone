Type: grilling
Status: resolved

## Question

Define the player's health/damage model and the XP/leveling model — neither was addressed directly in the interview, and both are load-bearing for the MVP:

- **Health**: does the player have an HP pool (able to take multiple hits, as the original implies via perks like "Thick Skinned: -33% max HP for -33% damage taken" and "Regeneration") or is it one-hit-death? If an HP pool, what's the base value, and how is damage from enemy contact/projectiles applied (flat per-hit? per-second while in contact?)?
- Is there any temporary invulnerability window — the original grants a shield on every level-up in addition to the perk choice (research doc, section 9) — does the MVP copy this?
- **Death condition**: exact trigger (HP reaches 0, presumably) and what happens on death (session just ends — confirmed via [02](02-arena-session-structure.md) that death is the only end condition; does anything else need to happen, e.g. a score/results screen?).
- **XP**: earned from kills only, or also survival time/other sources? What curve — copy the original's documented `1000 * (1 + level^1.8)` formula (research doc, section 9), or use something simpler for the MVP?
- Confirm the level-up choice screen presents 3 perks (per [08](08-perk-scope.md)) and whether gameplay pauses during the choice or continues in real-time (the original's is a real-time prompt, not a full pause, per the "gaining enough experience... choosing one of five" framing — verify this is what's wanted here too).

## Answer

**Base HP**: 100. (The original's actual base HP was never confirmed by any available source — research turned up only a low-health-warning threshold at HP≤20, not a max value — so this is our own number, not a "matched to the original" one.)

**Contact damage model**: matches the original's real mechanic (confirmed via decompiled-source documentation, not fan speculation): each enemy tracks its **own independent attack cooldown** between successive hits on the player — roughly ~1s baseline, refined per species in [15](15-enemy-combat-stats.md). Critically, **there is no player-wide invulnerability window** — multiple enemies overlapping the player each hit on their own cooldown, so standing in a crowd stacks damage from all of them simultaneously. This replaces the earlier "tick every 0.5s" draft, which was a guess made before this fact was confirmed.

**Level-up flow** (corrected from the initial draft): the game **pauses** while the perk choice is shown — not real-time. Invulnerability is granted **after** the player picks a perk, when gameplay resumes, for **0.5s** (not 1.5s, and not granted at the moment of leveling up itself). This is the only invulnerability window in the game — it does not apply to ordinary contact damage per the point above.

**Death & aftermath**: HP reaches 0 → session ends immediately, shows a results screen (score/level reached, survival time). No retry-run stats or leaderboard for the MVP.

**XP source**: kills only, not survival time.

**XP curve**: `xp_required = 100 × level^1.5` (rounded) — a gentler shape than the original's `1000 × (1 + level^1.8)`, chosen so early levels come fast during MVP playtesting. Must be tuned jointly with enemy spawn/difficulty pacing (opened as [17 - Enemy spawn pacing](17-enemy-spawn-pacing.md)) so leveling frequency and enemy toughening feel matched.
