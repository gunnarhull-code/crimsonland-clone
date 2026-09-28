Type: grilling
Status: resolved

## Question

Surfaced while resolving [10 - enemy AI parameters](10-enemy-ai-parameters.md): nothing on this map yet defines enemy HP, the damage enemies deal to the player on contact, or the XP reward per kill.

- For each Species (Spider, Rat, Alien, per [05](05-enemy-roster.md)): base HP, contact damage per hit, this species' specific Attack Cooldown value (the per-enemy repeat-hit interval fixed conceptually in [14](14-player-vitals-and-leveling.md) — no player-wide invulnerability, so this cooldown is what actually paces how much damage one enemy can deal), and XP awarded per kill.
- For each Species' Boss Variant: how HP/damage/XP scale up (the user's framing in [10](10-enemy-ai-parameters.md) is "danger telegraphed through size/HP rather than movement," so Boss Variants should be tankier/harder-hitting even though they move at the same 60%-speed multiplier as their base form).
- Whether HP/damage/XP also scale over session time (the original scales enemy toughness over time in Survival mode, per the research doc section 7) or stay fixed per species for the MVP.

## Answer

**Base stats per species** (sized against [weapons.csv](../weapons.csv)'s Pistol, which deals 10 damage):

| Species | HP | Damage/hit | Attack Cooldown | XP |
|---|---|---|---|---|
| Rat | 15 | 5 | 0.6s | 5 |
| Spider | 30 | 8 | 1.0s | 10 |
| Alien | 60 | 15 | 1.5s | 20 |

**Boss Variant**: flat multiplier on the base species' stats above — HP ×5, damage ×2, XP ×6.

**Scaling over session time**: matches the original — confirmed via [GameFAQs' Survival Mode Guide](https://gamefaqs.gamespot.com/pc/921162-crimsonland/faqs/34357) ("monsters grow in strength as your level rises... get faster and more numerous"; splash weapons that work early become "useless" late-game). A single global **Toughness Multiplier**, `1 + elapsed_minutes × 0.15`, applies uniformly to every enemy's HP and damage (base and Boss Variant alike) — after 10 minutes, ~2.5× toughness; after 20 minutes, ~4×.

Movement speed does **not** scale with session time — it stays fixed at the values [10 - Enemy AI parameters](10-enemy-ai-parameters.md) already set, even though the source material's "faster" applies to speed too. Reopening that ticket's per-species speed values to also carry a time multiplier would mean re-deriving every wander/chase number against elapsed time instead of just re-stating it — scaling toughness alone gets the "even common monsters are made of iron" late-game feel with one clean knob instead of two interacting ones.

"More numerous" — spawn rate and species mix over time — is [17 - Enemy spawn pacing](17-enemy-spawn-pacing.md)'s concern, not this ticket's; the two should still be tuned together once both exist.
