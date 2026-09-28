# Post-MVP: chapter/checkpoint progression

Explicitly out of scope for the MVP (see [map.md](map.md)). Captured here so it isn't lost — not a ticket, not something to resolve now. Revisit once the MVP's endless-survival loop is actually playable and proven.

## The structure, as described

- The full game is organized into **Chapters**, each **12 Levels** long.
- Between consecutive Levels (if you didn't die), you get the *option* to carry over a couple of your current Perks into the next Level.
- Every **4 Levels**, there's a **Checkpoint** guarded by a **Miniboss**. Defeating it grants the Checkpoint — you can resume a future attempt from there.
- **Every Checkpoint resets your Perks** — so Perk carryover only ever matters *within* a 4-Level block, never across a Checkpoint.
- Dying between Checkpoints sends you back to the last Checkpoint, and your build (Perks) auto-resets.
- Your build also resets after completing a full Chapter (12 Levels), even without dying.
- Separately, defeating a Miniboss or a Chapter-end Boss **permanently unlocks a new Perk** into your available pool, out-of-session — this persists across all the resets above.

## My read on the balance

The core instinct is sound and it's a well-worn pattern for good reason: **separate in-run power from permanent meta-progression.** Your build (in-run Perks) is always temporary and always gets wiped — at a Checkpoint, on death, after a Chapter — but the *pool of Perks you can draft from* permanently grows every time you clear a Miniboss or Boss. That's exactly how games like Hades or Dead Cells avoid the classic problem of a power-fantasy game becoming trivial forever once a player gets strong: the "overpowered" feeling is real but bounded to a single push between resets, while the permanent reward is that each future push starts from a slightly better pool, not a slightly stronger character.

Two things worth being deliberate about before this gets designed for real:

1. **The punishment stacks.** Dying between Checkpoints costs you both progress (back to the last Checkpoint) *and* power (build reset) at the same time. That's a legitimate, common roguelite choice (Rogue Legacy and early Risk of Rain both do this), but it's harsh enough that it deserves an explicit "yes, that's the intent" rather than falling out of the rules by accident — worth confirming once you're actually tuning this, ideally after playtesting how it feels.
2. **Open question for later**: does a permanently-unlocked Perk change what's *offered* during the level-up choice screen (i.e. you start a Chapter with access to only a subset of the 20+ Perks, and each Miniboss/Boss kill adds one more to that pool), or does it do something else? That's the detail that determines whether `perks.csv` eventually needs an "unlocked by default / unlocked via X" column — not a decision to make now, just the shape of the question waiting here.

Not yet resolved, deliberately: exact carryover count ("a couple" perks — how many, chosen by the player or automatic?), and how a Boss differs from a Miniboss beyond appearing at Chapter-end rather than every 4 Levels.
