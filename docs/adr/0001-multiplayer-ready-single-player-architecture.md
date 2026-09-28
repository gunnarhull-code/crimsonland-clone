# Structure the single-player MVP as if a second player were coming

The MVP is single-player only, but the user intends to eventually add multiplayer. We decided the Godot implementation should still: model the player as an instanceable scene rather than an Autoload singleton, capture input into a per-player state object each frame rather than reading `Input.*` directly inside gameplay logic, and have the perk/weapon effect systems take a player instance as an explicit parameter rather than assuming an implicit global "the player." We picked this over the simpler singleton/global-Input approach — which would be the obvious choice for a game that is, today, definitely single-player — because retrofitting multiple player instances onto code built around a singleton is a rewrite, not an extension, and none of these three choices cost anything extra for a single-player MVP.

## Considered Options

- Global Autoload singleton for player state + direct `Input.*` calls in gameplay code (simpler, but the standard trap that makes multiplayer conversion expensive later).
- Instanced player scene + captured input state + parameterized effect systems (chosen — same effort for the MVP, avoids the trap).
