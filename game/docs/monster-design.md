# Monster design (draft, for review)

Status: **design only, nothing built.** Theme is temporary (owner: "themes are temp"). Builds on spec section 7 and 13.10 of `design-v2-exponential-upgrades.md`.

## Design pillars

1. **Fair, never cheap.** Every dangerous move has a glow and a sound before it lands.
2. **Each monster counters a way of building.** A monster is a question for the build, not a bag of HP.
3. **They have a job, not just a path to you.** Roles: swarmer, hunter, tank, disruptor, support. Chasing is the fallback.
4. **They make you move.** Standing and shooting should always lose to something. The answer is positioning, not only dodging.
5. **Mixed crowds are the real puzzle.** Tank in front of squishy things, hunter hitting you while you handle a swarm.
6. **Upgrades talk to monsters.** Shockwave, Chill, Gravity Seed and the rest visibly change monster behavior, in both directions.
7. **Cheap to build.** Behaviors are small data-driven pieces; a new monster is mostly a CSV row.

## Theme (temporary)

The junkyard at the end of all wormholes. Everything lost here is still alive, and it adapted. Four families:

- **Vermin:** locals that thrived in the junk.
- **Salvage-born:** scrap that learned to move.
- **Strays:** travellers from other realities who lost their way.
- **Gate-things:** born of the wormholes.

## Player addition: dodge

Dash on Space, about a 1.5 s cooldown, short invulnerability (numbers are placeholders). Shakes off a latched tick and stuns it briefly. Also answers lunges and stomps.

## Roster v0

Marked **(1)** are proposed for the first build batch.

| monster | family | role | what it does | counters | what beats it |
|---|---|---|---|---|---|
| **Rat** (1) | Vermin | swarmer | Moves as a loose pack. Roughly a third break off and swing around to bite from behind. Scatters briefly when the pack leader dies. | builds that only cover the front | Blast Ring, Ricochet, Echo, Orbit Shard, Shockwave |
| **Tick** (1) | Vermin | disruptor | Small and fast, low to the ground. Latches onto you on touch or attack. Poisons you for damage over time, stacking per tick. Stays until you dodge: the dodge drops it and stuns it for about 1 s. | players who stand still, and slow reaction | dodge, Shockwave (shoves it off), Blast Ring, killing it after it drops |
| **Spider** (1) | Vermin | hunter | Stalks you at medium range, then crouches with a glow for about 0.5 s and dashes in a straight line. Sidesteps shots aimed straight at it. | single-bullet builds, standing still | Spread, Zigzag, Pierce, Chill, dodge |
| **Scrapper** (1) | Salvage-born | tank | Slow golem of bottles and wire. A frontal plate blocks bullets from the front; its back is soft. | head-on single-direction fire | Ricochet, Echo, Split, Poison, Pierce, moving around it |
| **Brute** (1) | Strays | tank | Alien. Flat armor (-4 per hit). Heals if left alone for 2 s. Winds up and slams a ring around itself when you are close. | many weak bullets, slow poison-only damage | Grow, Exploit, burst damage, staying out of the ring |
| **Can Bomb** | Salvage-born | swarmer | Rolling cans that light a fuse when near you, then explode. | clumped play | Shrapnel and Volatile Core chain them, Gravity Seed packs them, Shockwave |
| **Mender** | Strays | support | Weak alien that stays behind tanks and heals or shields nearby monsters with a visible beam. Kill-the-healer puzzle. | brute-force damage into one tank | Pierce, Zigzag, Bond Arc, Fault Line |
| **Blinker** | Gate-things | disruptor | Flickers and reappears behind you after a ring telegraph, bites, blinks away. | turtling in one spot | Gravity Seed, Still Field, Shockwave, dodge |
| **Mound King** | Salvage-born | boss (level 5) | The Rat King. Streams rats; later phases add Can Bombs. | weak single-target builds | burst, area |
| **Gate Warden** | Gate-things | boss (level 10) | Armored; escorts at HP thresholds; slam and blink moves. | many weak bullets | big hits, ticks, Third Strike, Heat Coil |

## Behavior parts (the data-driven building blocks)

- **Movement:** swarm, stalk (orbit at range), lunge (telegraph then dash), flank, blink, crawl.
- **Attack:** bite, latch, stomp, fuse-explode.
- **Defense:** flat armor, frontal plate, regen, sidestep.
- **Group:** pack morale (scatter on leader death), heal beam, haste aura.
- **Death:** burst into small ones, leave a goo patch, explode.
- Every attack part has a telegraph (glow time, color, sound) and a reaction to the player's upgrades (shove, slow, pull, stun).

## Open questions

1. First build batch: the five marked (1), or fewer?
2. Tick poison on the player: damage per second per tick, and does it also slow you or block reloading?
3. Dodge numbers: cooldown, distance, invulnerability length.
4. Should monsters respond to the draft (for example, more flankers when the player owns Blast Ring), or stay fixed per level? Spec 13.10 says scenario draws vary the enemy mix.
5. Level mapping: which monsters appear on which levels (a simple intro curve)?
