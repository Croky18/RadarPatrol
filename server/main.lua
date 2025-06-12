local ESX, QBCore = nil, nil

if Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Framework == 'esx' then
    if ESX == nil and exports['es_extended'] then
        ESX = exports['es_extended']:getSharedObject()
    end
end

RegisterNetEvent('policeradar:issueFine', function(targetId, speed, fine, plate)
    local isNPC = (targetId == -1)
    local playerName = GetPlayerName(targetId) or 'Onbekend'

    if isNPC and Config.Debug then
        print("[DEBUG] NPC voertuig geflitst met " .. math.floor(speed) .. " km/u | Plaat: " .. (plate or 'Onbekend'))
    end

    if isNPC and Config.Debug and Config.EnableDiscordLogs and Config.DiscordWebhook ~= "" then
        local embed = {
            {
                title = "🚔 NPC Geflitst | Speed Camera (DEBUG)",
                description = string.format("Snelheid: **%d km/u**\nKenteken: **%s**\nBoete (gesimuleerd): **€%d**", math.floor(speed), plate or 'Onbekend', math.floor(fine)),
                color = 15844367,
                footer = { text = os.date("%d-%m-%Y | %H:%M:%S") }
            }
        }
        PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers)
            if Config.Debug then print("[Webhook] NPC Test verzonden: status " .. tostring(err)) end
        end, 'POST', json.encode({ username = "SpeedCam Logger", embeds = embed }), { ['Content-Type'] = 'application/json' })
        return
    end

    if isNPC then return end

    local xPlayer = ESX and ESX.GetPlayerFromId(targetId) or QBCore.Functions.GetPlayer(targetId)
    if not xPlayer then
        if Config.Debug then
            print("[Radar DEBUG] Kon speler niet vinden met ID: " .. tostring(targetId))
        end
        return
    end

    if Config.Debug then
        print(string.format("[Radar DEBUG] Boete geven aan speler %s (ID %d) voor %d km/u, boete €%d", playerName, targetId, math.floor(speed), math.floor(fine)))
    end

    local bank = ESX and xPlayer.getAccount('bank').money or xPlayer.Functions.GetMoney("bank")
    local cash = ESX and xPlayer.getMoney() or xPlayer.Functions.GetMoney("cash")

    if bank >= fine then
        if ESX then
            xPlayer.removeAccountMoney('bank', fine)
            TriggerClientEvent('esx:showNotification', targetId, "Je bent geflitst met " .. math.floor(speed) .. " km/u. Boete: €" .. fine)
        else
            xPlayer.Functions.RemoveMoney("bank", fine, "speeding-ticket")
            TriggerClientEvent('QBCore:Notify', targetId, "Je bent geflitst met " .. math.floor(speed) .. " km/u. Boete: €" .. fine, "error")
        end
    elseif (not ESX and (bank + cash) >= fine) then
        -- Alleen QBCore: bank + cash
        local remaining = fine - bank
        xPlayer.Functions.RemoveMoney("bank", bank, "speeding-ticket")
        xPlayer.Functions.RemoveMoney("cash", remaining, "speeding-ticket")
        TriggerClientEvent('QBCore:Notify', targetId, "Je bent geflitst met " .. math.floor(speed) .. " km/u. Boete: €" .. fine .. " Betaald met cash", "error")
    else
        local warningText = "⚠️ Je bent geflitst met " .. math.floor(speed) .. " km/u maar had niet genoeg geld! De volgende boete zal DUBBEL zijn!"
        if ESX then
            TriggerClientEvent('esx:showNotification', targetId, warningText)
        else
            TriggerClientEvent('QBCore:Notify', targetId, warningText, "error", 8000)
        end
    end

    -- Discord log voor spelers
    if Config.EnableDiscordLogs and Config.DiscordWebhook and Config.DiscordWebhook ~= "" then
        local embed = {
            {
                title = "🚔 Snelheidsflits | Speed Camera",
                description = string.format("Speler: **%s**\nSnelheid: **%d km/u**\nKenteken: **%s**\nBoete: **€%d**", playerName, math.floor(speed), plate or 'Onbekend', math.floor(fine)),
                color = 15158332,
                footer = { text = os.date("%d-%m-%Y | %H:%M:%S") }
            }
        }
        PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers)
            if Config.Debug then print("[Webhook] Verzonden: status " .. tostring(err)) end
        end, 'POST', json.encode({ username = "SpeedCam Logger", embeds = embed }), { ['Content-Type'] = 'application/json' })
    elseif Config.EnableDiscordLogs then
        print("[WARNING] DiscordWebhook is niet ingevuld in config.lua!")
    end
end)
