# Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── lovejs-preview.yml
├── README.md
├── STRUCTURE.md
├── ci_preview/
│   ├── build_previews.lua
│   ├── detect_changed_games.lua
│   ├── game_manifest.lua
│   ├── generate_preview_html.lua
│   ├── generate_preview_index.lua
│   ├── html_template.lua
│   ├── index_template.lua
│   └── preview_builder.lua
├── homing_rocket/
│   ├── Vector.lua
│   ├── main.lua
│   └── vendor/
│       └── knife/
│           └── timer.lua
├── path_finding/
│   ├── Entity.lua
│   ├── Node.lua
│   ├── NodeMap.lua
│   ├── NodeMapGenerator.lua
│   ├── Obstacle.lua
│   ├── Simulator.lua
│   ├── Vector.lua
│   ├── globals.lua
│   ├── main.lua
│   ├── menu/
│   │   ├── ContextMenu.lua
│   │   └── MainMenu.lua
│   └── vendor/
│       ├── class.lua
│       ├── knife/
│       │   └── timer.lua
│       └── push.lua
├── plans/
│   ├── battle-flow-state-machine-plan.md
│   ├── lovejs-preview-plan.md
│   ├── narrative-world-plan.md
│   ├── project-plan.md
│   ├── tactics-battle-plan.md
│   └── technical-considerations.md
├── tactics_battle/
│   ├── Game.lua
│   ├── conf.lua
│   ├── config.lua
│   ├── lib/
│   │   ├── api_client.lua
│   │   ├── dkjson.lua
│   │   └── simple_yaml.lua
│   ├── main.lua
│   ├── scenarios/
│   │   ├── init.lua
│   │   └── training_ground.lua
│   ├── states/
│   │   ├── BattleState.lua
│   │   ├── CutsceneState.lua
│   │   ├── DevMenuState.lua
│   │   ├── StartMenuState.lua
│   │   └── WorldMapState.lua
│   ├── systems/
│   │   ├── BattleFlowStateMachine.lua
│   │   ├── BattleSystem.lua
│   │   ├── DialogueSystem.lua
│   │   ├── EnemyAI.lua
│   │   └── TurnManager.lua
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
    ├── tactics_battle/
    │   ├── test_battle_flow_state_machine.lua
    │   ├── test_battle_system.lua
    │   ├── test_battlefield.lua
    │   ├── test_dev_menu_state.lua
    │   ├── test_enemy_ai.lua
    │   ├── test_game.lua
    │   ├── test_grid.lua
    │   ├── test_narrative_states.lua
    │   ├── test_scenarios.lua
    │   └── test_turn_manager.lua
    ├── test_changed_games.lua
    ├── test_detect_luac.lua
    ├── test_lint_command.lua
    ├── test_lovejs_preview_template.lua
    ├── test_lovejs_workflow.lua
    ├── test_preview_builder.lua
    ├── test_preview_index_template.lua
    └── test_vendor_dependencies.lua
```
