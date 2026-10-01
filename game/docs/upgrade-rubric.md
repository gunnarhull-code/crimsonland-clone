# Upgrade rubric (draft)

A way to judge whether an upgrade belongs in V2, turned into a score. It keeps design decisions with the designer: playtests and outside feedback are data that feeds this, not the answer. Mirrors the pillars-supported and early-versus-late columns from a spreadsheet-based design process.

Data: `upgrade-rubric.csv` (import into a sheet).

## Pillar definitions

Tag an upgrade with a pillar only if it passes that pillar's test. When in doubt, leave the tag off.

### Synergy
**Meaning:** the upgrade becomes much stronger, or does something new, when combined with specific other upgrades. This is the "I feel clever" pillar.
- **Test:** can you name at least two upgrades it pairs with, and say what the pairing does?
- **Counts:** multiplies or reads another upgrade's effect, state or tag (for example Exploit reading any debuff).
- **Does not count:** being generally good on its own, or a plain stat bump.

### Risk
**Meaning:** the upgrade has a real cost or dependency, so picking it can be a mistake and a strong build feels earned.
- **Test:** is there a realistic build where this is a bad pick?
- **Counts:** self-damage, being useless without a partner, a trade-off against another stat, a condition that is hard to meet.
- **Does not count:** just being weak. A weak upgrade with no upside is a bad design, not a risk.

### Counterplay
**Meaning:** the upgrade answers an enemy behavior, or is answered by one. Enemies are the antitheses of builds.
- **Test:** can you name a specific enemy behavior (armored, regenerator, lunge, back-biter, swarm) this is good or bad against?
- **Counts:** beating armor, covering your back, slowing lungers, clearing swarms.
- **Does not count:** damage that works the same against everything.

### Readable
**Meaning:** a player can tell what the upgrade did from what is on screen, without reading a tooltip.
- **Test:** watching a recording with no UI, could you tell this upgrade is active?
- **Counts:** visible bullet changes, explosions, status colors, a clear sound or effect on each proc.
- **Does not count:** hidden numeric changes, such as a small fire-rate or damage bonus.

### Run arc
**Meaning:** the upgrade plays differently early in a run (one stack) than late (built up).
- **Test:** do the `early_run_function` and `late_run_function` columns say meaningfully different things?
- **Counts:** a trigger that is rare at first and constant later, a payoff that needs a state source, a counter that grows with the run.
- **Does not count:** the same effect that is just bigger.

### Alien and unusual
**Meaning:** the upgrade changes what the weapon is or how it works in a way ordinary shooters don't. It should feel like salvage from another reality.
- **Test:** would a player describe it as strange, not just as stronger?
- **Counts:** bending space or gravity, linking enemies, bullets that behave oddly, new rules for ammo or health.
- **Does not count:** stat increases, however large. No pop-culture references in names or text.

### Player skill
**Meaning:** the upgrade still rewards aiming, movement and positioning, so the player's hands matter and the build doesn't play itself.
- **Test:** does a good player get noticeably more out of it than a poor one?
- **Counts:** shots that need lining up (pierce, ricochet angles), timing windows, positioning for portals or zones, focus fire.
- **Does not count:** automatic effects, homing, or a flat stat bump.

### Power fantasy
**Meaning:** built up, the upgrade produces a screen-filling, satisfying moment that makes the player feel overpowered.
- **Test:** would a player want to screenshot or clip the moment it goes off?
- **Counts:** chain explosions, crowd-wide effects, a snowball that visibly takes over a late level.
- **Does not count:** a quiet numeric gain that never shows up on screen. This differs from Synergy, which is about the combo, not the spectacle.

### Felt immediately
**Meaning:** with a single stack, the effect is noticeable in the very next level after the pick. No pick should be so slight that the player barely feels it.
- **Test:** would a player notice the change within the first 30 seconds of the next level, without being told?
- **Counts:** a visible or audible change at stack 1, such as a new bullet, a new explosion, a status on enemies, a different shot feel.
- **Does not count:** slow-building payoffs, upgrades that do nothing without a partner, small percentage bonuses.
- **Note:** this is different from Readable. Readable is about understanding what it did. Felt immediately is about it making a difference right away.

### Draft tension
**Meaning:** when offered, the upgrade competes with other strong or meaningful options, so choosing it is a real strategic decision and not an obvious one.
- **Test:** is there a plausible build or moment where a thoughtful player would pick something else over it, and another where they would pick it over the best alternative?
- **Counts:** strong in some builds and weak in others, commits the build to a direction, has a real downside, or starts a chain.
- **Does not count:** always the best pick, or never worth taking.

## Score

`score = number of pillars supported - engine cost penalty` (low 0, med 1, high 2).

The score only answers one question: how well does this upgrade fit the game we want? More pillars means more reasons to say yes, so pillars can be added, weighted or dropped freely as the feel of the game becomes clearer. The pillar list is not final.

- 6 or more: core, build first.
- 4-5: include if the roster needs it.
- 3 or less: cut first if scope is forced, or build last.

Bands were rescaled as the list grew (now ten pillars). Every pillar counts the same for now. If one matters more (for example Synergy), weight it.

## Candidate pillars (brainstorm, not adopted)

Ideas from a card-draft arena shooter where players pick upgrade cards between rounds (a rough match for 10 levels of picks), and from other survivor-style games. Add any that sound like the feel you want.

- **Double-edged:** one card has an upside and a downside together, for example more damage and less health. Close to Risk, but about the same card doing both.
- **Comeback:** helps a struggling player recover, which matters because there are no dead runs.
- **Absurdity:** deliberately silly or extreme, in a way that makes players laugh.
- **Changes movement:** alters how the player moves or positions, not just how the gun shoots.
- **Surprise:** does something the player didn't predict, for example an effect that triggers from another upgrade.
- **Build identity:** pushes the player toward a named, recognizable build, so later picks get easier to choose.
- **Evolution:** unlocks or upgrades into something new when paired with another upgrade. Matches chained upgrades and linked abilities.
- **Escalation:** gets stronger as enemy density rises, so late levels feel bigger.
- **Short-run fit:** matters within the 11 picks of one run, not only over a long campaign.

## Other columns

- `early_run_function` / `late_run_function`: what it does with one stack versus a built-up run. If both say the same thing, the upgrade is probably flat.
- `pairs_with`: the synergy partners. Any upgrade with none is an orphan.
- `deliberate_weakness`: the designed-in reason it can be a bad pick.
- `engine_cost`: low, med or high, for the stability caps (bullets, generation, explosions).

## How to use it

Fill a row before building any new upgrade. The value is in doing the thinking, not in referring back to it later.
