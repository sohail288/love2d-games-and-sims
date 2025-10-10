# Love2D Games and Simulations

This repository collects small Love2D projects that explore gameplay and simulation ideas. The newest addition is a tactical battle prototype inspired by *Final Fantasy Tactics*, featuring an overhead view of a tile-based battlefield.

## Projects

- `tactics_battle/`: Overhead tactical combat prototype with grid rendering, unit placement, initiative-based turns, visible turn order, enemy AI, and a battle system supporting movement ranges plus melee/ranged attacks.
    - Turn resolution advances a global time unit counter, and actions can declare multi-unit time costs so scenarios can pace abilities and scripted events.
    - Unit movement now tween between tiles via `love.update(dt)` to prepare for richer animation while preserving deterministic logic in the battle system.
    - Scene-driven architecture powered by a reusable game state machine keeps the battle flow isolated from future menus, pause screens, and world navigation.
- `homing_rocket/`: Demonstrates steering behaviour for a homing projectile.
- `path_finding/`: Visualizes grid-based pathfinding with interactive menus.

## Running the Tactical Battle Prototype

1. Install [Love2D](https://love2d.org/).
2. From the repository root, run `love tactics_battle`.
3. Use the arrow keys to move the cursor, press **Space** to select the active unit, **Enter** to move to the highlighted tile, **A** to preview the attack range and strike enemies in reach, and **Tab** to end the turn. Enemy units will automatically take their turn when highlighted in the initiative display.

### Scenario System

- Scenarios are pure Lua tables stored under `tactics_battle/scenarios/` that describe the grid size, initial unit placements, scripted hooks, and custom victory/defeat evaluators.
- The HUD surfaces the active scenario name, objective tracker, and the reason supplied by the resolved victory condition to make mission progress clear.
- Objectives are evaluated after every state change, allowing scenarios to react to turn transitions or unit defeats without relying on the Love2D runtime.

## Development

### Tests

Run the Lua unit tests with:

```bash
lua tests/run_tests.lua
```

### Linting

A lightweight lint step checks Lua syntax:

```bash
find . -name '*.lua' -not -path './vendor/*' -print0 | xargs -0 -n1 luac -p
```

### Plans and Documentation

- `plans/project-plan.md` tracks the roadmap and history of features.
- `plans/tactics-battle-plan.md` outlines the tactical battle feature phases.
- `plans/technical-considerations.md` captures noteworthy technical notes.
- `STRUCTURE.md` summarizes the directory layout.
