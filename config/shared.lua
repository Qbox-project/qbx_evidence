return {
    statuses = {
        gsr = {
            label = locale('statuses.gsr'),
            threshold = 2,
            chance = 0.7,
            duration = 900000, -- Time in ms that the state stays on the player
            cooldown = 30000, -- Time in ms until the state starts to decay
        }
    },
}