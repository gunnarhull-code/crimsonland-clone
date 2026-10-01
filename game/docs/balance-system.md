# Balance system for 100 upgrades (draft)

Goal: reach 100 upgrades without any one number breaking the game, using the targets in section 10 and 13.10 of the V2 spec: best build about 100× at level 10, a good build about 20×, enemies scale to 20× HP, and weak builds die. Picks equal the level number, and same-upgrade stacks add while different upgrades multiply.

## 1. Roster plan

`roster-100.csv` lists all 100 slots in eight groups: shape 12, states 12, triggers 14, payoffs 12, alien and space 14, ammo and rhythm 10, chained 16, linked 10. 29 are already in the rubric. 71 are one-line concepts for you to cut, rename or approve. Every slot a concept earns must pass the rubric (`upgrade-rubric.md`) before it is built.

## 2. Every upgrade is described by numbers, not feel

Add these columns to the upgrade data so a script can reason about it:
- `solo_mult`: damage-per-pull multiplier from one stack with no partners.
- `partner_mult`: the extra multiplier when its best partner is present, and who that partner is.
- `crowd_value` and `single_value`: how much it helps clearing a crowd versus killing one big target (the two measures in 13.10).
- `power_tier`: 1, 2 or 3. Tier 3 costs more to draw or sits behind a chain.

## 3. The calculator (build all of this before the roster passes about 30)

1. **Exact calculator:** takes a build (a list of exactly L picks for level L) and returns crowd clearing speed and single-target damage as multiples of the baseline pistol. It uses the same effect rows as the game, so it can't drift from the data.
2. **Level check:** compare each result with the enemy line (1× to 20×) and the ceiling (1.6× to 100×). Flag a build above the ceiling for its level.
3. **Exhaustive search for the top:** for each level, search for the best possible build. If the best at level 10 isn't about 100×, the numbers need changing. If anything beats 100× or beats the ceiling early, it's a bug.
4. **Random-player sampling:** simulate thousands of runs with three player types: a random picker, a rule-of-thumb picker (takes things that match what it already has), and a planner. Each draws from the real 1-of-3 offers. Targets to tune: the planner usually wins, the rule-of-thumb picker wins sometimes, and the random picker mostly loses. A one-upgrade spammer must lose.
5. **Outlier report:** for every upgrade, record pick rate and the win rate of builds that contain it. An upgrade that wins far more than average is too strong, and one that never appears in winning builds is too weak or has no good partner.

## 4. Check the calculator against the real game

The calculator is only trustworthy if it matches the game. Run a headless Godot bot that plays full runs with a fixed build, and compare its measured damage per pull and clear speed to the calculator. A gap of more than about 15% means a bug in the calculator or the game. Use the same build lists.

## 5. Process for each new upgrade

1. Write the one-line concept and fill the rubric row.
2. Add its effect rows to the CSV.
3. Run the calculator: check solo and partner multipliers, check no build exceeds the ceiling.
4. Run the random-player sampling and read the outlier report.
5. Adjust one number at a time. Re-run.
6. Only then playtest by hand.

## 6. Where the numbers show up

The phone page has a `roster-100` tab listing every slot. After the calculator exists, a `balance` tab should show each upgrade's solo multiplier, best partner, pick rate and win rate, with outliers highlighted. That is how you can look at all 100 and see which ones are off.

## 7. Tooling note

Python is not installed on the owner's PC. Write the calculator and simulation in GDScript (runs headless in the existing Godot install) or another tool that is available.
