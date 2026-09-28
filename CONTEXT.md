# Crimsonland Clone

A minimalist top-down survival shooter, an intentional clone/parody of Crimsonland. Single static arena, escalating enemy pressure, weapon pickups, and a spreadsheet-driven perk system.

## Language

### Arena & session

**Arena**:
The single, static, non-scrolling play space the player and all enemies occupy for a session.
_Avoid_: Level, map, screen (screen means the display, not the play space)

**Session**:
One continuous run in the Arena, from spawn to player death. The MVP has exactly one session type: endless survival.
_Avoid_: Run, game, round

### Enemies

**Species**:
One of the enemy archetypes (Spider, Rat, Alien) with its own Wander Variants and Chase Style.
_Avoid_: Enemy type, monster class

**Boss Variant**:
A slower version of a base Species sharing the exact same Wander Variants and Chase Style, distinguished by a flat speed multiplier (and eventually stats like HP, not yet defined).
_Avoid_: Big variant, elite, mini-boss

**Wander Phase**:
The behavior an enemy performs from spawn until it Aggroes — has not yet noticed the player.
_Avoid_: Idle phase, patrol

**Wander Variant**:
One of a Species' ~3 distinct movement patterns cycled through during its Wander Phase, re-rolled at random every 1-2 seconds. Each Species defines its own set and speed.
_Avoid_: Wander pattern, idle animation

**Aggro**:
The permanent state an enemy enters once the player enters its Aggro Radius. An enemy never reverts from Aggro back to the Wander Phase.
_Avoid_: Alert, awakened, activated

**Aggro Radius**:
The distance from an enemy to the player at which that enemy transitions from Wander Phase to Aggro. Currently a flat 450px for all Species.
_Avoid_: Detection range, aggro range

**Chase Style**:
A Species' movement pattern once Aggroed — e.g. Spider's stutter-step charge-stop-charge, Rat's constant-speed beeline, Alien's steady straight-line charge.
_Avoid_: Attack pattern, pursuit behavior

### Perks & leveling

**Perk**:
A passive upgrade the player chooses at a Level-Up, defined as a row in `perks.csv`. Its in-game description is deliberately vague/qualitative; the CSV also holds the precise numeric values the game logic reads.
_Avoid_: Upgrade, ability, buff

**Level-Up Choice**:
The prompt shown when the player levels up, offering 3 random Perks to choose from.
_Avoid_: Perk screen, upgrade menu

### Weapons

**Pickup & Swap**:
The MVP's weapon-acquisition model: the player starts with the Pistol; killed enemies drop a new weapon; picking one up replaces (swaps) the currently-held weapon rather than adding to an inventory.
_Avoid_: Loot, weapon inventory

**Pierce Cap**:
The fixed maximum number of enemies a single piercing shot (the Gauss Gun) can hit in one line before stopping.
_Avoid_: Pierce count, penetration limit

**Chain Range**:
The distance within which the Electric Gun's shot arcs from its primary target to one additional nearby enemy.
_Avoid_: Chain radius, arc distance
