# Monster design (draft, for review)

Status: **first batch built** (Rat flank + morale, Tick latch, Spider stalk/lunge/sidestep, Alien Brute armor/regen/stomp, Scrapper front plate, player dodge). Numbers live in `game/sandbox/monsters.csv`. Later batches (Can Bomb, Mender, Blinker, bosses) are not built. Theme is temporary (owner: "themes are temp"). Builds on spec section 7 and 13.10 of `design-v2-exponential-upgrades.md`.

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

## Built so far (batch 1)

- **Dodge:** Space, 1.5 s cooldown, 0.18 s dash, 0.25 s invulnerable. Shakes off every latched tick (stunned 1 s).
- **Tick:** latches on touch, 3 damage/s each to you, up to 6 at once. Shockwave also shoves it off (0.6 s stun). Blast Ring and any blast can kill it while it is on you. Swells while attached.
- **Spider:** circles at ~250 px, then a 0.55 s red wind-up (ring plus a line showing the dash), then a straight dash for 1.5x bite damage, then 0.7 s recovery. Sidesteps ~45% of shots that are aimed at it, so Velocity (faster bullets), Spread and Zigzag beat it.
- **Rat:** about a third are flankers: orbit to behind you, then commit to the bite (gives up flanking after 3-4.5 s). When a rat dies, nearby rats scatter for about a second.
- **Alien Brute:** armor 4, regenerates 3 HP/s (scaled with level HP) after 2 s unhit, and stomps (0.85 s red ring wind-up, 18 damage in the ring).
- **Scrapper:** frontal plate (150 degrees) blocks bullets entirely, Ricochet bounces off it; blasts, poison and Heat Coil beams ignore it.
- **Level curve:** `levels.csv` introduces ticks at level 2 and scrappers at level 3.

## Later ideas (owner)

- **Pick your stages:** let the player choose which levels or scenarios to play, to tailor their own experience (stage selection before or between levels). Not designed yet. Ties into the portal choice in spec section 8.

## Idea: Spider Matriarch webs (owner, draft)

The boss spider leaves spiderweb traps where it launches.

- **Where:** a web at each launch point; optionally a thin trail along the dash path. The dash wind-up already marks where it lands, so webs mark where it has been.
- **Effect:** a ground patch (about 40-60 px). Stepping in slows the player to about 40% for 2 s, longer while standing in it. A stuck player is easy prey for the next lunge, which is the trap.
- **Counterplay:** dodge cuts through a web so you are not stuck; blasts (Blast Ring, Shrapnel) burn webs; Chill makes webs brittle so they stop slowing you; Gravity Seed can pull monsters into webs. Webs can snare monsters too (rats running through them).
- **Limits:** about 12 s lifetime, around 8 at once.
- **Look:** pale web lines on the dark floor with a slight shimmer.
- **Open:** launch point only or a trail? slow or brief hold? Matriarch only, or elite spiders on normal levels too?

## Other owner ideas parked here

- **Slower bullets as an upgrade debuff.** Any upgrade can carry a `bullet_speed` number in `upgrades.csv` (already supported; nothing uses it yet). Candidates: Grow, Pierce, Shrapnel.
- **Shrink (built as an upgrade):** shrunk enemies are smaller (harder to hit) but take 50% more damage. A pickup version (a ground item that shrinks nearby enemies) is a later idea.
- **Pick your own stages** (see above).
