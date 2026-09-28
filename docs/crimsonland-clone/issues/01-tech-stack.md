Type: grilling
Status: resolved

## Question

What engine/tech stack will the MVP prototype be built in, given the priority is fast iteration on core mechanics feel over final production values?

## Answer

**Godot 2D.**

Considered against Web (HTML5 Canvas/TypeScript) and Python+Pygame. Chosen because it's free, has built-in 2D physics/collision (relevant for the circle-hitbox model in [03](03-hitbox-model.md)), and — unlike a throwaway web prototype — it's a real path to a shippable game if the MVP's mechanics prove out, without a rewrite.
