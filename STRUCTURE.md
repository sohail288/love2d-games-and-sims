# Repository Structure

```
.
.├── .github/
.│   └── workflows/
.│       └── lovejs-preview.yml
├── README.md
├── STRUCTURE.md
├── ci_preview/
│   ├── generate_preview_html.lua
│   └── html_template.lua
├── homing_rocket/
├── path_finding/
├── plans/
│   ├── project-plan.md
│   ├── lovejs-preview-plan.md
│   ├── tactics-battle-plan.md
│   ├── technical-considerations.md
│   └── narrative-world-plan.md
├── tactics_battle/
│   ├── conf.lua
│   ├── Game.lua
│   ├── main.lua
│   ├── scenarios/
│   │   ├── init.lua
│   │   └── training_ground.lua
│   ├── states/
│   │   ├── BattleState.lua
│   │   ├── CutsceneState.lua
│   │   ├── StartMenuState.lua
│   │   └── WorldMapState.lua
│   ├── systems/
│   │   ├── BattleSystem.lua
│   │   ├── EnemyAI.lua
│   │   ├── TurnManager.lua
│   │   └── DialogueSystem.lua
│   ├── ui/
│   │   └── Cursor.lua
│   └── world/
│       ├── Battlefield.lua
│       ├── Grid.lua
│       ├── Unit.lua
│       ├── WorldMap.lua
│       └── default_map.lua
└── tests/
    ├── run_tests.lua
    ├── test_lovejs_preview_template.lua
    └── tactics_battle/
        ├── test_battlefield.lua
        ├── test_battle_system.lua
        ├── test_enemy_ai.lua
        ├── test_game.lua
        ├── test_grid.lua
        ├── test_narrative_states.lua
        ├── test_scenarios.lua
        └── test_turn_manager.lua
```
