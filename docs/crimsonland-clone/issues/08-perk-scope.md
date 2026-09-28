Type: grilling
Status: resolved

## Question

How many perks does the MVP ship with, how many are offered as choices at each level-up, and how detailed should their in-game descriptions be?

## Answer

- **20 perks total** in the MVP's `perks.csv` library (vs. the original's ~55).
- **3 random perks offered as choices** at each level-up (the original's own base count is ambiguous between sources — see research doc, section 8 — so this isn't a "match the original" call, it's picking the smallest number that still forces a real trade-off).
- In-game descriptions shown to the player are **intentionally vague/qualitative** — e.g. "increases your pickup luck for items," with no percentage or number shown — even though the underlying CSV holds precise numeric values the game logic actually reads. This is a deliberate design choice (easy to tighten language later without touching values) and should not be "fixed" into showing numbers.

How those precise CSV values are structured, and which perks can be pure-data vs. need a hardcoded handler, is deferred to [12 - perk effect architecture](12-perk-effect-architecture.md). Authoring the actual 20 perks is deferred to [13 - perk content authoring](13-perk-content-authoring.md), blocked on 12.
