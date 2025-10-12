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
3. Use the arrow keys to move the cursor, press **Space** to select the active unit, **Enter** to move to the highlighted tile, **A** to preview the attack range and strike enemies in reach. Turns now end automatically once the acting unit has no remaining actions; press **Tab** only when you want to skip any remaining options. Enemy units will automatically take their turn when highlighted in the initiative display.

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

```bash
LUAC_EXEC=$(ci_preview/detect_luac.sh)
find . -type f -name '*.lua' -not -path './vendor/*' -not -path './.lua/*' -print0 | xargs -0 -n1 "$LUAC_EXEC" -p
```

### CI love.js Preview

GitHub Actions packages the tactical battle project as a `.love` archive, pairs it with the `love.js` runtime, and uploads the bundle as a downloadable artifact on each push or pull request. The workflow lives at `.github/workflows/lovejs-preview.yml` and performs the following:

1. Run Lua unit tests and linting to guard the build.
2. Zip `tactics_battle/` into `game.love`.
3. Download the `love.js` 11.4 runtime and drop the generated `index.html` shell into the bundle.
4. Upload the resulting directory as the `lovejs-preview` artifact.

To reproduce the preview locally:

```bash
mkdir -p build/lovejs
cd tactics_battle && zip -9 -r ../build/tactics_battle.love . && cd ..
curl -L -o build/lovejs-runtime.zip https://github.com/TannerRogalsky/love.js/releases/download/11.4/love.js-11.4.zip
unzip -o build/lovejs-runtime.zip -d build/lovejs
mv build/lovejs/love.js-11.4/* build/lovejs/ && rm -rf build/lovejs/love.js-11.4
cp build/tactics_battle.love build/lovejs/game.love
lua ci_preview/generate_preview_html.lua --output build/lovejs/index.html
# optionally customize the launch button label
# lua ci_preview/generate_preview_html.lua --start-button-label "Play Tactical Demo"
```

### Plans and Documentation

- `plans/project-plan.md` tracks the roadmap and history of features.
- `plans/tactics-battle-plan.md` outlines the tactical battle feature phases.
- `plans/battle-flow-state-machine-plan.md` captures the phased rollout for the turn flow controller.
- `plans/technical-considerations.md` captures noteworthy technical notes.
- `STRUCTURE.md` summarizes the directory layout.
