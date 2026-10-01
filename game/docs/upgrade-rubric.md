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
- **Note:** this pillar is new. The 16 upgrades in the CSV are not yet re-tagged for it.

## Score

`score = number of pillars supported - engine cost penalty` (low 0, med 1, high 2).

- 4 or more: core, build first.
- 2-3: include if the roster needs it.
- 1 or less: cut first if scope is forced, or build last.

Every pillar counts the same for now. If one matters more (for example Synergy), weight it.

## Other columns

- `early_run_function` / `late_run_function`: what it does with one stack versus a built-up run. If both say the same thing, the upgrade is probably flat.
- `pairs_with`: the synergy partners. Any upgrade with none is an orphan.
- `deliberate_weakness`: the designed-in reason it can be a bad pick.
- `engine_cost`: low, med or high, for the stability caps (bullets, generation, explosions).

## How to use it

Fill a row before building any new upgrade. The value is in doing the thinking, not in referring back to it later.
