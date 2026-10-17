# Wave spawning design (draft, for review)

Status: **design only.** The owner said wave spawning "needs serious work" and has not yet answered the questions at the bottom.

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
