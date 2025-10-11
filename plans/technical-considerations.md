# Technical Considerations

## Love2D Module Structure
- Logic that must be unit tested is implemented in pure Lua modules (e.g., grid and turn management) so that it can be required without the Love runtime.

## Testing Strategy
- Custom lightweight Lua test harness ensures unit coverage without external dependencies.
- Tests set up package paths for project modules to allow running with the standard Lua interpreter.

## CI Preview Builds
- The love.js runtime is downloaded during CI to avoid committing large binaries; the workflow keeps the version pinned so cache behaviour stays predictable.
- Preview HTML is generated from Lua to keep configuration colocated with the rest of the codebase and enable automated tests to validate template changes.
- Build artifacts should retain the original `game.love` archive for reproducibility and manual debugging when issues surface in the browser runtime.
- GitHub Actions dependencies (checkout, artifact upload, etc.) must track the latest supported major versions to avoid sudden workflow failures due to deprecations.
- When GitHub's cache service began returning HTTP 400 responses to `leafo/gh-actions-lua@v9`, disabling the build cache input on v11 restored reliable installs without materially impacting job duration.
- The Lua installer action may create a workspace-level `.lua` directory; lint discovery scripts must restrict results to regular files and explicitly skip the directory contents so `luac` does not attempt to parse them.

## Rendering Constraints
- Battlefield rendering relies on Love2D's immediate mode drawing; separation of concerns keeps drawing isolated from game state logic.

## Tactical Battle Mechanics
- BattleSystem module centralizes rules for movement, actions, and outcome evaluation to enable deterministic unit tests.
- Movement range is computed with a breadth-first search over the grid while treating occupied tiles as obstacles.
- Combat resolution removes defeated units from both the battlefield and initiative order to maintain consistent turn flow.
- EnemyAI module evaluates reachable tiles, prioritising closer proximity to opposing units, and selects the lowest HP target when attacking to keep behaviour deterministic for testing.
- Combat resolution now factors defender orientation into critical hit odds, and the battle system exposes an injectable RNG so unit tests can remain deterministic.
- TurnManager exposes the ordered initiative list so that the HUD can display the active and upcoming units without mutating the underlying sequence.
- Scenario definitions live in standalone Lua tables that expose hooks and victory/defeat evaluators; shared scenario state is passed into BattleSystem contexts so scripted objectives and HUD updates can be exercised in unit tests without Love2D.
- Turn resolution aggregates per-action time costs, advancing a global time unit counter so scenarios can throttle expensive abilities or trigger hooks after specific durations.
- Movement commands build tile-by-tile paths that the battle state tweens through during `love.update(dt)`, separating deterministic grid logic from presentation.
- The `BattleFlowStateMachine` monitors player phases; `BattleState` forwards action completions and animation callbacks so turn summaries and automatic endings stay synchronised with rendered movement.

## State Management
- A lightweight `Game` module coordinates named states, ensuring `enter`, `exit`, `update`, and `render` lifecycles remain isolated per scene.
- States receive the game context so they can share assets (fonts, configuration) without resorting to globals, easing future additions like pause or world map scenes.
- Unit tests stub the Love2D API to validate state transitions and battle scene initialization without requiring the engine runtime.
- Narrative states (start menu, world map, cutscenes) compose via callbacks rather than globals so campaign flow can react to battle outcomes while staying testable.
- World map data is stored in plain Lua tables and mirrored into the shared context, enabling persistence between state transitions without serialisation.

## World Navigation
- World maps describe connections as simple graphs; the map module runs a breadth-first search to produce the shortest path between destinations.
- Active travel serialises its remaining path so battles or cutscenes can interrupt the journey and resume it on return to the map state.
- Locations flag mandatory stops to require player interaction, while optional towns are automatically passed unless chosen as the destination.
