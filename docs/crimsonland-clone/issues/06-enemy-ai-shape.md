Type: grilling
Status: resolved

## Question

What shape does enemy AI take — steady beeline pursuit (like the original's documented "gradually enter and make their way toward the player"), or something more organic?

## Answer

A deliberate **departure from the original's simple beeline** — a two-phase state machine per enemy instance:

1. **Wander phase** (on spawn): the enemy has **no fixed single pattern**. Every **1-2 seconds**, it re-rolls between roughly **three themed pathing variants unique to its species** (e.g. Rat's variants are fast/tight/erratic; Alien's are looser and slower; Spider's are circular/figure-eight-ish, per [05](05-enemy-roster.md)). This dynamic re-rolling is itself the point — it's what makes wandering read as "looking around" rather than a scripted loop.
2. **Aggro phase**: triggered once the player enters a **large radius** (~half the screen) around the enemy. Aggro is **permanent** once triggered — the enemy never reverts to wandering, even if the player then moves far away. (Considered and rejected: aggro that can be lost — it would make the state machine more complex and let players exploit kiting in/out of the radius for no real gameplay benefit.) Chase behavior is species-specific (Spider's is charge-stop-charge, described above).

Exact numeric parameters (the radius size, the re-roll interval, the concrete wander-variant definitions and chase-style specifics for Rat and Alien) are deferred to [10 - enemy AI parameters](10-enemy-ai-parameters.md) — this ticket only fixes the state-machine *shape*.
