# Love2D Games and Simulations

This repository collects small Love2D projects that explore gameplay and simulation ideas. The newest addition is a tactical battle prototype inspired by *Final Fantasy Tactics*, featuring an overhead view of a tile-based battlefield.

## Projects

- `tactics_battle/`: Overhead tactical combat prototype with grid rendering, unit placement, initiative-based turns, visible turn order, enemy AI, and a battle system supporting movement ranges plus melee/ranged attacks.
    - Turn resolution advances a global time unit counter, and actions can declare multi-unit time costs so scenarios can pace abilities and scripted events.
    - Unit movement now tween between tiles via `love.update(dt)` to prepare for richer animation while preserving deterministic logic in the battle system.
    - Scene-driven architecture powered by a reusable game state machine keeps the battle flow isolated from future menus, pause screens, and world navigation.
    - After exhausting actions a facing-selection prompt lets you choose orientation; attackers striking from the sides or rear gain higher critical odds, rewarding careful positioning.
    - Narrative layer adds a start menu, dialogue-driven cutscenes, and a world map linking two towns with a battlefield scenario.
- `homing_rocket/`: Demonstrates steering behaviour for a homing projectile.
- `path_finding/`: Visualizes grid-based pathfinding with interactive menus.

## Running the Tactical Battle Prototype

1. Install [Love2D](https://love2d.org/).
2. From the repository root, run `love tactics_battle`.
3. Use the arrow keys to move the cursor and press **Space** to open the action menu. Choose whether to move or attack first, confirm with **Enter**, then resolve the remaining action when the menu reappears. Facing selection always closes the turn, so be sure to point the unit in the direction you want to guard last.
4. Press **Tab** to skip directly to facing if you want to end the turn early. Enemy units will automatically take their turn when highlighted in the initiative display.

### Scenario System

- Scenarios are pure Lua tables stored under `tactics_battle/scenarios/` that describe the grid size, initial unit placements, scripted hooks, and custom victory/defeat evaluators.
- The HUD surfaces the active scenario name, objective tracker, and the reason supplied by the resolved victory condition to make mission progress clear.
- Objectives are evaluated after every state change, allowing scenarios to react to turn transitions or unit defeats without relying on the Love2D runtime.

### Narrative Layer

- Start the prototype from a menu that launches the campaign or quits the application.
- Navigate a connected world map (town, battlefield, town) where the party tweens along the shortest route, automatically visiting intermediate stops. Battlefields can interrupt the journey with encounters, while towns expose their menus via **Space** once you arrive.
- Cutscenes use a reusable dialogue system, advancing with the Enter or Space keys and returning to the map when finished.

## Development

### Tests

Run the Lua unit tests with:

```bash
lua tests/run_tests.lua
```

### Linting

A lightweight lint step checks Lua syntax:

Ensure the Lua compiler is available locally. The helper script `ci_preview/detect_luac.sh` looks for common compiler
names and supports a `LUAC_EXECUTABLE` override when a custom path is required.

```bash
LUAC_EXEC=$(ci_preview/detect_luac.sh)
find . -type f -name '*.lua' -not -path './vendor/*' -not -path './.lua/*' -print0 | xargs -0 -n1 "$LUAC_EXEC" -p
```

### CI love.js Preview

GitHub Actions packages the tactical battle project as a `.love` archive, pairs it with the `love.js` runtime, and uploads the bundle as a downloadable artifact on each push or pull request. The same workflow now publishes the preview to GitHub Pages so reviewers can launch it directly in the browser. The workflow lives at `.github/workflows/lovejs-preview.yml` and performs the following:

1. Run Lua unit tests and linting to guard the build.
2. Zip `tactics_battle/` into `game.love`.
3. Use the maintained `love.js` 11.5 npm distribution to build the compatibility runtime via `npx love.js -c`.
4. Upload the resulting directory as the `lovejs-preview` artifact.
5. Publish the static site bundle to GitHub Pages and surface a deployment link on each successful run.

When a run finishes, expand the **Deploy to GitHub Pages** step on the workflow summary page to copy the preview URL. GitHub also records the link under the `github-pages` environment for quick access.

To reproduce the preview locally:

```bash
rm -rf build && mkdir -p build
cd tactics_battle && zip -9 -r ../build/tactics_battle.love . && cd ..
npx --yes love.js -c build/tactics_battle.love build/lovejs --title "Tactics Battle Preview"
cp build/tactics_battle.love build/lovejs/game.love
lua ci_preview/generate_preview_html.lua --output build/lovejs/index.html --game-archive game.love --lovejs-path love.js --game-script game.js
# optionally customize the launch button label
# lua ci_preview/generate_preview_html.lua --start-button-label "Play Tactical Demo"
```

The `npx --yes love.js` command downloads the compatibility toolchain on demand; install Node.js 18+ locally to mirror the CI environment.

Open `build/lovejs/index.html` in a browser and press **Launch Preview** to stream the runtime. The loader now reports download progress and surfaces an error message if the love.js script fails to initialize so you can retry without refreshing.

### Plans and Documentation

- `plans/project-plan.md` tracks the roadmap and history of features.
- `plans/tactics-battle-plan.md` outlines the tactical battle feature phases.
- `plans/battle-flow-state-machine-plan.md` captures the phased rollout for the turn flow controller.
- `plans/technical-considerations.md` captures noteworthy technical notes.
- `STRUCTURE.md` summarizes the directory layout.
