# Crimsonland (2003) — Mechanics Research Report

Researched to ground MVP design decisions in the real original game's mechanics. Cross-reference this before assuming a "Crimsonland does it this way" fact in any ticket.

## 1. Screen/Arena
- Original 2003 release: fixed low resolutions, confirmed **800×600 (4:3)**; widescreen (960×800-era patch) added later. 2014 HD re-release added modern resolutions.
- Play area is a **single-screen bounded arena** — player starts in the middle, enemies gradually enter and move toward the player (Wikipedia). TV Tropes: "a featureless plain."
- No camera scrolling documented in any source — treated as a static single-screen space, enemies entering from off-screen/edges. High-confidence inference, not a direct dev statement.

## 2. Player Movement & Aiming
- **WASD for movement, mouse for aim/fire**, confirmed for the original 2003 PC version. Movement and aim are **independently tracked** (separate `move_dx/move_dy` and `aim_x/aim_y` state, per a reverse-engineering write-up at banteg.xyz) — twin-stick feel despite mouse aim.
- **No dash/dodge** as a base mechanic. Evasion is simulated passively via perks (Dodger = chance to avoid an attack; Ninja, requires Dodger, greatly increases it) — automatic, not player-activated.
- Movement speed is a flat base value, modified by equipped weapon (heavy weapons like the Mean Minigun slow the player) and by perks (Speed power-up doubles run speed temporarily; Long Distance Runner increases speed the longer you run continuously).

## 3. Weapons
~25–30 weapons in the base game; 2 unlocked by default (Pistol, Assault Rifle). Full stat table (Type / Clip / Reload / Fire rate) from the Neoseeker Tactics Guide:

| Weapon | Type | Clip | Reload | Fire rate |
|---|---|---|---|---|
| Pistol | Medium | 12 | 1.2s | 84 rpm |
| Assault Rifle | Automatic | 25 | 1.2s | 512 rpm |
| Shotgun / Sawed-Off | Spread | 12 | 1.9s | ~70 rpm |
| JackHammer | Auto-shotgun | 16 | 3.0s | 428 rpm |
| Submachine Gun | Automatic, inaccurate | 30 | 1.2s | 680 rpm |
| Flamethrower / Blow Torch | Fire, short range, continuous | 30 | 1.5–2.0s | constant |
| Gauss Gun / Gauss Shotgun | **Piercing** ("kill 3+ enemies per shot") | 5 / 4 | 1.6–2.1s | 57–99 rpm |
| Rocket Launcher / Seeker / Mini-Swarmers / Rocket Minigun | Splash, projectile | 4–16 | 1.2–1.8s | varies |
| Ion/Plasma family | Splash/energy | 3–20 | 1.3–3.0s | varies |
| Pulse Gun | Special, near-instant reload | 16 | 0.1s | 599 rpm |
| Splitter Gun | Bullets split on hit, chain, can hurt player | 8 | 2.2s | 85 rpm |

- Every weapon has a **finite clip and a reload time** — the "no reload" model is specific to the separate Weapon Picker mode only, not base Survival/Quest play.
- **Pickup model**: start with Pistol only; additional weapons drop from killed enemies (first kill guaranteed to drop one; drop rate higher while still holding the Pistol); picking up a weapon on the ground **swaps** your current one (no dual-wield by default — a perk, "Alternate Weapon," allows carrying two, swapped via the reload key).

## 4. Bullet/Projectile Physics
- Standard guns fire simulated projectiles with travel time (not instant hitscan); rocket/splash weapons clearly travel with visible speed and blast radius. No exact velocity numbers documented anywhere found.
- **Piercing** is a dedicated weapon family (Gauss/Cutter), not a perk.
- **Spread/inaccuracy** varies by weapon (shotguns wide, SMG called out as "extremely inaccurate"); the Sharpshooter perk tightens accuracy + adds a laser sight, implying a baseline spread/cone per weapon that perks can modify.

## 5. Hit Detection / Hitboxes
- **Not concretely documented anywhere.** Circle-based collision is the reasonable genre-standard assumption, not a confirmed fact.

## 6. Enemies
Roster (Neoseeker "Fiends" section, most detailed source found):
- **Aliens** — steady constant walking pace; small red variant is fast/dangerous melee.
- **Zombies** — constant pace, slowest, low threat.
- **Lizards** — fast, constant slither pace, swarm in masses.
- **Spiders** — irregular movement (pause, then burst-travel a long distance), melee.
- **Red Spiders** — ranged, fire projectile bolts.
- **8-Legged Terrors** — large ranged spider, "magnet head" shoots damaging bolts.
- **Spideroids** — mini-boss, splits into smaller spiders on death.
- **Farms/Nests** — stationary spawner structures producing enemies until destroyed.
- Color-coding affects difficulty/XP reward (red = strong/low XP, yellow = weak/low XP, green/blue/purple = higher XP).
- Spawn logic (per the banteg.xyz reverse-engineering post) uses timed triggers (`trigger_ms`) and radial positioning (`radial_points`) — i.e. continuous timed spawning at points around a radius/edge, not wave-clear gating.

## 7. Spawning & Difficulty Scaling
- Survival mode: difficulty increases substantially over time — monsters grow tougher, faster, and more numerous as level/time rises (GameFAQs Survival guide). Splash weapons that work early become "useless" late-game, forcing a pivot to piercing/shotgun-style weapons.
- Scaling is **time/level-based, not wave-counted**.
- **Endless structure confirmed**: Survival goes on until the player dies — no fixed session length or objective beyond survival.

## 8. Perks System
- **55 total perks** (Steam Community compiled list; Neoseeker individually documents ~45+ with full manual text).
- **Choice model**: level-up presents a choice of perks (right-mouse-button prompt). Sources conflict on the base count — TV Tropes implies 5, with "Perk Expert"/"Perk Master" meta-perks each adding one more option, which is internally inconsistent with a base of 5. Treat "3–5, expandable via meta-perks" as the safe range — **not a hard fact to copy exactly**.
- **Prerequisites/stacking exist**: e.g. Ninja requires Dodger; Greater Regeneration requires Regeneration; Perk Master requires Perk Expert.
- **Effects span**: stat boosts (Fastloader, Fastshot, Ammo Maniac), risk/reward trades (Infernal Contract: −99% HP for 3 extra perks; Thick Skinned: −33% max HP for −33% damage taken), weapon modifiers (Barrel Greaser, Sharpshooter, poison/uranium/radioactive bullet effects), utility (Telekinetic, Bonus Magnet, Monster Vision), pure-XP/gimmick perks (Bloody Mess, Death Clock, Grim Deal).

## 9. Scoring/XP/Leveling
- XP earned via kills. Manual text: "When you gain enough experience to gain an experience level you are entitled to one (1) perk."
- **Exponential XP curve**, documented formula: `XP required = 1000 * (1 + level^1.8)` (e.g. Level 2 = 2,000, Level 10 = 53,195, Level 30 = 429,860).
- Level-up grants a **temporary shield/invulnerability** in addition to the perk choice.
- No combo/multiplier system beyond a temporary "Double Experience" power-up and passive XP-boost perks (Bloody Mess, Lean Mean Exp Machine).

## 10. Game Modes
Base 2003 game: Quest, Survival, Rush, Typ'o'Shooter (+ hidden Gembine). 2014 re-release added Nukefism/Weapon Picker/Blitz.
- **Survival**: start with Pistol only, all previously-unlocked weapons/perks available for random drop/offer; continuous escalating spawns; only end condition is player death; score is the sole persistent objective (local + online high scores).
- **Rush**: fixed Assault Rifle loadout, no perks, infinite ammo, enemies approach specifically from left/right screen sides (contrast case showing Survival's spawn pattern isn't simply two-sided).

### Notable open/unclear points
- Exact perks-per-levelup base count (3 vs 5 — sources conflict).
- Hitbox shape/size and exact bullet velocity/spread values — not documented anywhere, likely only recoverable via decompilation.
- Full original resolution list beyond confirmed 800×600.

**Sources**: [Wikipedia](https://en.wikipedia.org/wiki/Crimsonland), [Crimsonland Fandom Wiki](https://crimsonland.fandom.com/wiki/Crimsonland_(Game)), [TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Crimsonland), [Neoseeker Tactics Guide v1.20](https://www.neoseeker.com/crimsonland/faqs/93305-tactics.html), [GameFAQs Survival Mode Guide](https://gamefaqs.gamespot.com/pc/921162-crimsonland/faqs/34357), [banteg.xyz reverse-engineering post](https://banteg.xyz/posts/crimsonland/), Steam Community discussions/guides.
