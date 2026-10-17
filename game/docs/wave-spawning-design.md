# Wave spawning design (draft, for review)

Status: **design only (no code).** The owner said wave spawning "needs serious work". Answers so far are in "Owner decisions" below.

## What is wrong today

Read from `SbWaves.gd`:

- Every enemy of a wave appears on the same frame in a ring 350-450 px around the player, so the player is instantly surrounded with no read and no direction.
- The next wave only starts after the last enemy is dead plus 2 s, which leaves dead time while stragglers hunt the player and a gap before the next wave.
- Waves have the same shape every time (a flat list of counts), there is no warning, and no deliberate mixing of monster roles.

## Proposal: a spawn director with telegraphed rifts

1. **Rifts.** Wormhole gates open at the arena edge with a glow and sound about 1 s before monsters pour out. Fits the junkyard-at-the-end-of-all-wormholes setting and gives the player something to read.
2. **Formations** (a `formations.csv`): stream (a trickle from one gate), pincer (two opposite gates), ring close-in, pack with a leader, flood of weak ones, ambush behind the player (only after a calm moment, telegraphed). Each formation lists species, counts, gate positions, and timing.
3. **Pacing.** Replace "wave, clear, next wave" with an intensity curve (build-up, peak, breather). The next group starts when the field thins out or a timer runs out, so crowds overlap.
4. **Role-aware packs.** Deliberate combinations, for example a Scrapper with ticks behind it, or a rat swarm with flankers, instead of random counts.
5. **Level scripts.** `levels.csv` becomes a timed list of events (at 0 s a stream from the left gate, at 12 s a pincer, ...), authored and testable; generated variants later (spec section 8). A cheat triggers any formation on demand.
6. **Safety rules.** No spawn within a minimum distance of the player; cap on live enemies (the 400 cap already exists); bosses spawn immediately with adds as their waves (spec 13.11).

## Questions for the owner

1. What bothers you most today: the instant ring, dead time between waves, every wave feeling the same, or lack of pressure and variety in mixes?
2. Authored timeline per level, a random director with a budget, or an authored skeleton with random details?
3. Overlapping waves, or strictly clear-first with telegraphed gates?
4. Should some spawns react to the player's build (for example more flankers if the player owns Blast Ring), or stay fixed per level?

## Owner decisions (2026-10-16)

- **What bothers them:** everything appearing at once in a ring, every wave feeling the same, and mixes that lack pressure and variety. (Dead time between waves was not ticked.)
- **Structure:** **authored timeline per level** (a CSV list of timed events).
- **Overlap model: themed spawning sequences, one signature per enemy type.** Not "wave then clear". Examples from the owner: groups of rats all at once; a row of aliens every couple of seconds. Sequences from different species overlap on the level timeline.
- **Consequence for the design:** a formation is a *species-themed sequence* (a pattern in time and space), not just a count. `formations.csv` rows should describe: species, count, gate or edge, timing (all at once, drip every N s, rows), and the telegraph. A level's timeline then places several of these sequences. See the open questions below.

## Next questions (still open)

1. Which signature sequence for each species? (draft below)
2. Where do monsters come from: telegraphed rifts at the edges, or anywhere?
3. How long is the warning before a sequence arrives?
4. Do later levels run several sequences at once, or just faster and bigger ones?

### Draft signature sequences (for the owner to change)

| species | signature sequence |
|---|---|
| Rat | a burst: 8-12 at once from one gate, plus flankers peeling off |
| Spider | singles or pairs dropping in every few seconds, so there is always a hunter on you |
| Alien Brute | a row of 3-5 marching in from one edge, one every ~2 s |
| Tick | a fast scatter from several gates at once, arriving low and quick |
| Scrapper | a slow wall: 2-3 side by side advancing together, tick packs behind them |

## Owner decisions, round 2 (2026-10-16)

- **Entrances: a mix, with themes.** Some sequences arrive dramatically (a glowing rift at the edge); some **burrow up out of the dirt**; some start with **a hole opening in the earth that reveals maggots** (a new enemy, see `monster-design.md`). The entrance is part of the sequence's theme, so it is a column in `formations.csv` (`entrance`: rift | burrow | pit | edge).
- **Warning: varies by sequence.** Big or ambush sequences get a longer telegraph; drips get almost none. A `warning_sec` column per formation.
- **Escalation: stack more themed sequences at once**, with the focus on **amping up difficulty and giving the player a reason to dodge**. Design rule: each level adds more overlapping, telegraphed, dodgeable threats (lunges, stomps, latches, webs, bursts), so the dodge cooldown becomes a resource the player has to manage, not a panic button.
- **Signature sequences per species:** the draft table above is the starting point (rat burst, spider drip, alien row, tick scatter, scrapper wall). To be tuned in play.

## Implementation plan (not started; waiting for the owner to say build)

1. `formations.csv` and a `SbDirector` that runs a level's timeline: events placed at times, each naming a formation, entrance and gate position.
2. Entrances: rift (edge glow), burrow (dirt mound heaves, monster emerges), pit (hole opens, pour out of it, hole closes after a while); each with its own telegraph and sound.
3. Rebuild `levels.csv` as per-level timelines using those formations (level 1 one theme, level 9 several overlapping).
4. Cheat menu: trigger any formation with any entrance on demand, scrub the level timeline.
5. Maggot enemy once its design is agreed.

## Built (2026-10-16): wave director step 1

- `formations.csv` (7 sequences: rat burst, rat pit, rat rush, spider drip, alien march, tick scatter, scrapper wall) and `timeline.csv` (authored timelines for levels 1-4 and 6-9).
- `SbSpawner.gd`: entrances **rift** (glowing gate at an edge), **burrow** (mounds heave, monsters burst up), **pit** (a hole opens and monsters pour out, then it closes), **edge** (chevron warning, walk in). Patterns: burst, drip, scatter, wall. Monsters rise out of the ground for a moment and cannot act while emerging. Entrances stay at least 280 px from the player.
- `SbWaves.gd` now runs the timeline. A level ends when every event has started, every sequence has closed and every monster is dead. Boss levels (5, 10) are unchanged. Levels without a timeline fall back to the old counts.
- Cheats: pick any sequence and run it, and "Skip +10 s" jumps the timeline.
- Not built yet: Maggot enemy, themed pit nests that can be destroyed, ambush-from-behind sequences, sequences that react to the player's build, boss sequences, escalation tuning, the Matriarch webs.
