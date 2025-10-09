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
