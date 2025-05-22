Config = {}

-- Kies je framework: 'qbcore' of 'esx'
Config.Framework = 'esx' -- pas dit aan naar 'esx' of 'qbcore'

-- Debug modus aan/uit (toont prints in F8 console)
Config.Debug = false

-- Discord Log voor de politie
Config.EnableDiscordLogs = false -- Zet op false om logs uit te schakelen
Config.DiscordWebhook = 'HIER JE DISCORDWEBHOOK URL' -- Voeg hier je webhook URL toe

-- Whitelisted police vehicles (model hashes)
Config.WhitelistedVehicles = {
    [`police`] = true,
    [`police2`] = true,
    [`police3`] = true,
    [`fbi`] = true
}