return {
    introScript = {
        { speaker = "Commander", text = "The campaign begins. Our scouts report movement near the ridge." },
        { speaker = "Advisor", text = "We should visit the nearby towns before committing to battle." }
    },
    locations = {
        {
            id = "oak_town",
            name = "Oak Town",
            type = "town",
            description = "A quiet farming community loyal to the crown.",
            position = { x = 96, y = 320 },
            script = {
                { speaker = "Villager", text = "Thank goodness you've arrived. Supplies are running low." },
                { speaker = "Commander", text = "Hold tight. We'll push the enemy back soon." }
            },
            mandatory = true
        },
        {
            id = "ridge_battlefield",
            name = "Ridge Battlefield",
            type = "battlefield",
            description = "Enemy patrols hold the ridge overlooking Oak Town.",
            scenario = "training_ground",
            position = { x = 320, y = 220 },
            battleChance = 0.7,
            victoryScript = {
                { speaker = "Scout", text = "The ridge is ours. Oak Town is safe for now." },
                { speaker = "Commander", text = "Prepare to march. We still have ground to cover." }
            }
        },
        {
            id = "pine_town",
            name = "Pine Town",
            type = "town",
            description = "A trade hub nestled in the forest.",
            position = { x = 540, y = 360 },
            script = {
                { speaker = "Merchant", text = "Welcome commander! Trade routes are open again thanks to you." },
                { speaker = "Commander", text = "Keep supplies flowing to the front." }
            }
        }
    },
    paths = {
        { from = "oak_town", to = "ridge_battlefield" },
        { from = "ridge_battlefield", to = "pine_town" }
    }
}
