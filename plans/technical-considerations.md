# Technical Considerations

## Love2D Module Structure
- Logic that must be unit tested is implemented in pure Lua modules (e.g., grid and turn management) so that it can be required without the Love runtime.

## Testing Strategy
- Custom lightweight Lua test harness ensures unit coverage without external dependencies.
- Tests set up package paths for project modules to allow running with the standard Lua interpreter.

## Rendering Constraints
- Battlefield rendering relies on Love2D's immediate mode drawing; separation of concerns keeps drawing isolated from game state logic.

## Tactical Battle Mechanics
- BattleSystem module centralizes rules for movement, actions, and outcome evaluation to enable deterministic unit tests.
- Movement range is computed with a breadth-first search over the grid while treating occupied tiles as obstacles.
- Combat resolution removes defeated units from both the battlefield and initiative order to maintain consistent turn flow.
- EnemyAI module evaluates reachable tiles, prioritising closer proximity to opposing units, and selects the lowest HP target when attacking to keep behaviour deterministic for testing.
- TurnManager exposes the ordered initiative list so that the HUD can display the active and upcoming units without mutating the underlying sequence.
- Scenario definitions live in standalone Lua tables that expose hooks and victory/defeat evaluators; shared scenario state is passed into BattleSystem contexts so scripted objectives and HUD updates can be exercised in unit tests without Love2D.
- Turn resolution aggregates per-action time costs, advancing a global time unit counter so scenarios can throttle expensive abilities or trigger hooks after specific durations.
- Movement commands build tile-by-tile paths that the battle state tweens through during `love.update(dt)`, separating deterministic grid logic from presentation.
- The `BattleFlowStateMachine` monitors player phases; `BattleState` forwards action completions and animation callbacks so turn summaries and automatic endings stay synchronised with rendered movement.

## State Management
- A lightweight `Game` module coordinates named states, ensuring `enter`, `exit`, `update`, and `render` lifecycles remain isolated per scene.
- States receive the game context so they can share assets (fonts, configuration) without resorting to globals, easing future additions like pause or world map scenes.
- Unit tests stub the Love2D API to validate state transitions and battle scene initialization without requiring the engine runtime.
