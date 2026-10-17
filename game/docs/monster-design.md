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
- **Effect (updated by the owner):** a ground patch (about 40-60 px). Stepping in holds the player in place for about 1 s (earlier draft: a 40% slow). A stuck player is easy prey for the next lunge, which is the trap.
- **Counterplay:** dodge cuts through a web so you are not stuck; blasts (Blast Ring, Shrapnel) burn webs; Chill makes webs brittle so they stop slowing you; Gravity Seed can pull monsters into webs. Webs can snare monsters too (rats running through them).
- **Limits:** about 12 s lifetime, around 8 at once.
- **Look:** pale web lines on the dark floor with a slight shimmer.
- **Owner decisions:** webs at the launch points **and a trail along the dash**, and stepping in a web **holds the player down for about a second** (not just a slow). Still open: Matriarch only, or elite spiders on normal levels too?

## Other owner ideas parked here

- **Slower bullets as an upgrade debuff.** Any upgrade can carry a `bullet_speed` number in `upgrades.csv` (already supported; nothing uses it yet). Candidates: Grow, Pierce, Shrapnel.
- **Shrink (built as an upgrade):** shrunk enemies are smaller (harder to hit) but take 50% more damage. A pickup version (a ground item that shrinks nearby enemies) is a later idea.
- **Pick your own stages** (see above).

## Idea: Maggot (new enemy, Vermin; owner idea, draft)

A hole opens in the earth and reveals maggots. Proposed: small and soft, slow individually, but they come in numbers and keep pouring while the hole is open. Possible behaviors to decide: wriggling swarm movement with no flanking; low damage per bite but they overwhelm if you stand still; the hole could be a destructible nest that stops the stream when destroyed (the code already had a Nest in the old game as a precedent). Counters: area builds (Shrapnel, Blast Ring, Volatile Core chains). Open: stream or one burst; destructible nest or timed; can they be burrowed-up too?

## Escalation rule (owner)

Later levels stack several themed spawning sequences at once. The point is to raise difficulty and give the player a reason to dodge, so dodgeable, telegraphed threats overlap more as levels go on (see `wave-spawning-design.md`).

## Tweaks after owner testing (2026-10-16)

- **Tick:** crawls fast from far away, but inside 150 px it moves in small hops (crouch, hop about 46 px with a visible lift, land) and hops onto the player to latch.
- **Scrapper:** turns very slowly (26 degrees per second, set by `turn_rate` in `monsters.csv`), so the player can run round behind it where the plate does not cover.
- **Personal space:** monsters (ticks included, until they latch) are pushed out of the player's body, so they bite from the edge and never stand in the middle of the player.
- **Screen shake:** scaled by how big the effect really is (blast radius and damage), so stack 1-2 effects are barely felt, stack 3-4 Shrapnel and big Volatile Core chains are strong. Smooth low-frequency sway, not random jitter. A strength slider is in the cheat menu.
- **Spider lunge leads the player:** the dash is aimed at where the player will be when it arrives (their velocity times travel time, set by `lead` in `monsters.csv`; 0 turns it off). The red warning line shows the predicted path. Running straight gets you hit; you have to dodge, or change direction after the aim locks (0.12 s before the dash). In a test, running spiders took about 2.4 times more damage from a leading dash than from an unleading one.
- **Rat pack (owner):** the more rats are alive, the faster and fiercer each one gets, but only slightly: from 10 rats (none) to 120 rats (full) each rat gains up to +20% speed and bites up to 30% faster, and its eyes glow brighter. Numbers: `pack_start`, `pack_full`, `pack_speed`, `pack_bite` on the rat row of `monsters.csv`.
- **Rat counts ramp hard:** `timeline.csv` now sends roughly 16 rats on level 1, about 40 on level 3, 110 on level 6, 170 on level 7, 240 on level 8 and 300+ on level 9, in overlapping bursts, pit streams and rushes. The Rat King (level 5) adds 8 rats every 1.5 s.

## Built 2026-10-17: Maggot, Matriarch webs, tick lunge

- **Maggot:** 8 HP, bites for 3, slow sinuous crawl (78 px/s), tiny. Spawned by the `maggot_pit` formation: a hole opens and maggots pour out in groups of four, then the hole closes. It is on timelines from level 2 (12 maggots) to level 9 (70). Not built: a destructible nest that stops the stream, and burrow-up maggots. (Owner did not answer the stream/nest question, so the pit simply runs for the length of the sequence.)
- **Matriarch webs:** the boss lays a web where it launches and every ~70 px along the dash. Stepping on a web holds the player for 1 s (shooting still works) and uses the web up. A dodge breaks free instantly; a dash in progress ignores webs; blasts burn them. Webs last 12 s, at most 16 at once. Numbers on the boss row of `monsters.csv` (`web_*`).
- **Tick lunge (replaces the hops):** inside 130 px the tick crouches (0.08 s), then pounces at 540 px/s with a visible leap and lands latched if it reaches you, with a 0.16 s recovery otherwise. Crawl speed is 225 (up from 215).
- **Scrapper:** turn rate raised from 26 to 55 degrees per second.

## Maggot rework (owner, 2026-10-17)

Owner: maggots were harmless. Rework:
- **Slightly faster and harder:** 100 px/s (was 78), bite 4 every 0.6 s.
- **Early levels: a trap.** `maggot_trap`: a ring of maggots (about 125 px out) springs up around the player after a 0.25 s warning (dirt mounds heave). Levels 2-4.
- **Later levels: spawn further out.** `maggot_ring`: ring at about 330 px with a 0.8 s warning, plus pit streams. Levels 6-9.
- **Leave them and they hatch.** A maggot alive for 16 s stops, wraps in a cocoon for 1.4 s, then becomes a **Fly** (not counted as a kill). Fly: 24 HP, 185 px/s, tiny, darts erratically (new direction every 0.2-0.45 s), sidesteps aimed shots, bites for 4. The level does not end until the flies are dead too.
- Still open: destructible nest, burrow-up maggots, webs snaring monsters.

## Upgrade added: Homing (owner idea)

Bullets curve softly toward the closest enemy ahead (turn 70 deg/s, 50 degree cone, 450 px range at stack 1, so no hard turns). Each stack doubles the turn rate and the cone (cone capped at 180). Skips enemies the bullet already hit. Weight 0.1 (early, common).

## Built 2026-10-17: destructible Nest

- A **pit entrance now makes a Nest**: a real monster (60 HP at level 1, scaled by level, radius 40) sitting in a hole. Bullets, blasts and poison hit it like any monster; it cannot be shoved, pulled or teleported.
- The nest **breeds the formation's monsters out of the hole** over time (count, interval and group size come from `formations.csv`), so `maggot_pit` is a nest that spits maggots and `rat_pit` a nest that spits rats.
- **Destroy it and the stream stops**: the rest never come out. If it runs dry it collapses on its own (not a kill). The level does not end while a nest is alive, so it is also an objective.
- The pit warning (a hole opening, 1.6-1.8 s) is unchanged; the nest rises out of it.
- A nest from the spawn buttons just breeds maggots (40 of them).
- Observation from a scripted bot: a stationary bot can never kill a Scrapper (the plate always faces it). At 55 degrees per second a Scrapper out-turns anyone circling it from further than about 220 px, so outflanking means running a tight arc close in. If that proves too hard in play, lower `turn_rate` for the Scrapper.

## Performance and look changes (2026-10-17, owner testing)

- **Owner report:** the game got ridiculously slow in big fights, and the earlier "optimisation" (cheaper rats and staggered updates in crowds) looked bad. Both were addressed.
- **Cause (measured with a real renderer, vsync off):** the monsters were drawn as many vector polygons rebuilt by script every frame. Hiding only the monsters' drawing took level 8 from 8.5 fps to 116 fps. Particles and splatter were the next biggest cost.
- **Fix:** monsters are still the same vector art, but drawn **once** at startup into a sprite sheet (`SbBaker.gd`: 12 walk frames per monster) and shown as single sprites; hit flash, poison and chill tint, size changes, and rotation are done by the GPU. Status marks, health bars, cocoons and warnings are drawn only when they change. Particles draw in a few batched calls, ground splatter is a few batched sprites, and floating text and rings share one node (`SbFxLayer.gd`). The crowd shortcuts were removed: every rat is full quality and updates every frame.
- **Result:** level 9 averages about 190 fps (was single digits at level 8); 400 chasing rats about 145 fps.
- **FPS counter:** top right (F2 hides it) shows FPS, frame time, enemy, bullet, text and particle counts, and draw calls.
- **Scrapper is twice the size** (radius 48, was 24); the wall formation spaces them by size.
- **Rat King adds are capped:** at most 100 rat adds alive at once (`add_cap` in `levels.csv`), spawning 5 every 1.5 s as space opens. The Gate Warden's escorts cap at 8.
