Type: grilling
Status: resolved

## Question

Graduated from the map's "Not yet specified" fog: [14 - Player vitals & leveling](14-player-vitals-and-leveling.md) already established that death shows a results screen with "score/level reached and survival time," but never defined what score actually is.

- Is score its own tracked number, or is it just XP total / kill count re-labeled?
- Is score shown live during play (a HUD element), or only revealed on the results screen at death?
- Does anything besides kills contribute to score (survival time, Boss Variant kills weighted higher)?

## Answer

**Score is its own tracked number**, separate from XP — XP measures how strong you got (affected by Perks), score measures how well you played, and those diverge once Perks change your power without changing your skill.

**Formula**: weighted kill count + survival time in seconds. Weights match the XP weighting already set in [15 - Enemy combat stats](15-enemy-combat-stats.md): Rat = 1, Spider = 2, Alien = 4, any Boss Variant = ×6 its base species' weight.

**Displayed live**, via a HUD element, not just revealed on the results screen at death — small, free feedback that makes the escalating chaos feel earned in the moment. The HUD's implementation (Control/CanvasLayer) is covered by the same Godot-doc verification in flight for [18 - Godot scene structure](18-godot-scene-structure.md).
