# Narrative and World Navigation Plan

- **Status:** Completed
- **Owner:** Core gameplay team

## Overview
Introduce a lightweight narrative layer that frames tactical encounters with a start menu, interactive world map, and dialogue-driven cutscenes. The goal is to guide players through a simple campaign loop that alternates between towns, story moments, and a battlefield scenario.

## Phases

### Phase 1: Foundation *(Completed)*
- Add reusable dialogue system module for sequencing speaker lines.
- Implement cutscene state that renders scripted dialogue and returns control when finished.
- Update battle state to invoke completion callbacks when encounters resolve.

### Phase 2: World Navigation *(Completed)*
- Build a world map model representing at least three destinations (town, battlefield, town).
- Create world map state with keyboard navigation and selection handling.
- Hook battlefield selection into the existing scenario system.

### Phase 3: Narrative Loop *(Completed)*
- Implement start menu that launches the narrative loop and persists world progress.
- Surface town conversations via cutscenes triggered from the map.
- Add contextual messaging after battles and visits to reinforce progression.

## Acceptance Criteria
- Players begin at a start menu that can launch the adventure or exit the game.
- Selecting a location on the world map transitions to the correct scene (town cutscene or battlefield) and returns afterward.
- Dialogue sequences advance via player input and can be unit tested without the Love2D runtime.
- Battle completions trigger callbacks that allow the campaign flow to react to victory, defeat, or draws.
- World progression (visited locations, status messages) persists while the application runs.

## History
- *2025-10-11*: Documented plan and completed foundational dialogue, cutscene, and world navigation phases while wiring battle completion callbacks.
- *2025-10-12*: Expanded world navigation with shortest-path travel, tweened movement, random battlefield encounters, and town visit prompts on arrival.
