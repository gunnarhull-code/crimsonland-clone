Type: grilling

## Question

Surfaced while resolving [10 - enemy AI parameters](10-enemy-ai-parameters.md): nothing on this map yet defines enemy HP, the damage enemies deal to the player on contact, or the XP reward per kill.

- For each Species (Spider, Rat, Alien, per [05](05-enemy-roster.md)): base HP, contact damage per hit, this species' specific Attack Cooldown value (the per-enemy repeat-hit interval fixed conceptually in [14](14-player-vitals-and-leveling.md) — no player-wide invulnerability, so this cooldown is what actually paces how much damage one enemy can deal), and XP awarded per kill.
- For each Species' Boss Variant: how HP/damage/XP scale up (the user's framing in [10](10-enemy-ai-parameters.md) is "danger telegraphed through size/HP rather than movement," so Boss Variants should be tankier/harder-hitting even though they move at the same 60%-speed multiplier as their base form).
- Whether HP/damage/XP also scale over session time (the original scales enemy toughness over time in Survival mode, per the research doc section 7) or stay fixed per species for the MVP.
