# Battle Flow State Machine Plan

- **Status:** Phase 1 complete; follow-up enhancements planned.

## Overview
Establish a dedicated turn-phase state machine that orchestrates the player phase, drives automatic turn completion, and provides hooks for synchronising UI, animations, and enemy responses. The system should replace ad-hoc checks in `BattleState` with a reusable flow controller.

## Phases
- **Phase 1 – Player Turn Automation (Complete):** Introduce the state machine, wire it into `BattleState`, and ensure player turns end automatically after actions or on skip input.
- **Phase 2 – Expanded Phase Hooks (Planned):** Expose additional callbacks for cinematics, dialogue, or tutorial prompts during the turn summary window.
- **Phase 3 – Enemy & Ally Reuse (Planned):** Evaluate extending the machine to coordinate allied NPCs or enemy phases for consistent sequencing.

## Acceptance Criteria
- Player turns transition through `awaiting_input`, `resolving_action`, `turn_summary`, and `ending_turn` without manual `endTurn` calls.
- Movement and attack completions trigger callbacks so `BattleState` can refresh highlights, objectives, and battle evaluations.
- When no valid actions remain, the machine ends the turn automatically and optionally surfaces a skip input that delegates to the machine.
- Automated flow integrates with existing animations without desynchronising Love2D updates.
