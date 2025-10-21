# Project Plan

## Roadmap

1. Establish core tactical battle prototype with overhead grid rendering and unit management. *(Complete)*
2. Implement user interface for issuing commands, including movement and attack actions. *(Complete)*
3. Add AI-controlled opponents with decision-making for movement and targeting.
4. Expand content with additional unit classes, abilities, and environmental effects.
5. Polish presentation with animations, audio, and scenario scripting.
6. Introduce a narrative campaign loop with start menu, world map navigation, tweened travel, and dialogue-driven cutscenes. *(In Progress)*
7. Provide CI-powered love.js preview builds so stakeholders can review tactical combat updates in a browser.

## History

- *2025-10-08*: Initialized tactical battle prototype plan and implemented foundational grid, unit, and turn systems.
- *2025-10-08*: Implemented turn-based battle system with movement ranges, attacks, and unit elimination rules.
- *2025-10-08*: Added initiative-driven enemy AI, turn order HUD, and attack flow fixes for the tactical battle prototype.
- *2025-10-09*: Added reusable scenario definitions with objective tracking, victory/defeat evaluators, and extended unit tests.
- *2025-10-09*: Introduced a reusable game state machine with a dedicated battle state to prepare for menus, pause screens, and world navigation scenes.
- *2025-10-10*: Implemented a player turn flow state machine with automated end-of-turn handling and a skip-turn shortcut.
- *2025-10-11*: Began narrative layer rollout with dialogue system, cutscene handling, and world map planning.
- *2025-10-12*: Added shortest-path world travel with mid-route battles and town visit menus triggered from the map.
- *2025-10-13*: Added love.js CI preview pipeline scaffolding to publish playable builds from GitHub Actions.
- *2025-10-13*: Introduced end-of-turn orientation selection with facing-driven critical hit modifiers for tactical combat.
- *2025-10-21*: Hardened the love.js preview workflow by guaranteeing the Lua compiler installation and adding an override hook for custom toolchains.
