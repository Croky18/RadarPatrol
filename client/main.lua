local radarActive = false
local fineAmount = 50
local speedLimit = 100
local radarRange = 30
local lastMenuOpen = 0

local ESX, QBCore = nil, nil

CreateThread(function()
    if Config.Framework == 'esx' then
        while not ESX do
            ESX = exports['es_extended']:getSharedObject()
            Wait(100)
        end
    elseif Config.Framework == 'qbcore' then
        QBCore = exports['qb-core']:GetCoreObject()
    end
end)

RegisterCommand('radar', function()
    local currentTime = GetGameTimer()
    if currentTime - lastMenuOpen < 1000 then return end
    lastMenuOpen = currentTime

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then
        if Config.Debug then print("🚫 Niet in voertuig") end
        return
    end

    if GetEntitySpeed(veh) > 1.0 then
        if Config.Framework == 'esx' then
            ESX.ShowNotification("Radar kan niet geactiveerd worden tijdens het rijden!")
        else
            QBCore.Functions.Notify("Radar kan niet geactiveerd worden tijdens het rijden!", "error")
        end
        radarActive = false
        return
    end

    local vehModel = GetEntityModel(veh)
    if not Config.WhitelistedVehicles[vehModel] then
        if Config.Debug then print("🚫 Geen geautoriseerd voertuig") end
        if Config.Framework == 'esx' then
            ESX.ShowNotification("Je zit niet in een politievoertuig!")
        else
            QBCore.Functions.Notify("Je zit niet in een politievoertuig!", "error")
        end
        return
    end

    local job = nil
    if Config.Framework == 'esx' then
        job = ESX.GetPlayerData().job.name
    elseif Config.Framework == 'qbcore' then
        job = QBCore.Functions.GetPlayerData().job.name
    end

    if job ~= 'police' then
        if Config.Debug then print("🚫 Geen politie job") end
        return
    end

    if Config.Debug then print("✅ Alle voorwaarden geslaagd - menu wordt geopend") end

    lib.registerContext({
        id = 'radar_menu',
        title = 'Radar Configuratie',
        options = {
            {
                title = '💰Stel Boete Bedrag In',
                onSelect = function()
                    local input = lib.inputDialog('Boete Instellen', {
                        {type = 'number', label = 'Bedrag (€)', default = fineAmount}
                    })
                    if input then fineAmount = input[1] end
                    lib.showContext('radar_menu') -- menu open houden
                end
            },
            {
                title = '📣Stel Snelheidslimiet In',
                onSelect = function()
                    local input = lib.inputDialog('Limiet Instellen', {
                        {type = 'number', label = 'Limiet (km/u)', default = speedLimit}
                    })
                    if input then speedLimit = input[1] end
                    lib.showContext('radar_menu')
                end
            },
            {
                title = '👮Stel Detectiezone In (meter)',
                onSelect = function()
                    local input = lib.inputDialog('Zone Instellen', {
                        {type = 'number', label = 'Detectie Radius', default = radarRange}
                    })
                    if input then radarRange = input[1] end
                    lib.showContext('radar_menu')
                end
            },
            {
                title = '✅ Start Radar',
                onSelect = function()
                    radarActive = true
                    local msg = "Speed camera geactiveerd met ingestelde waardes"
                    if Config.Framework == 'esx' then
                        ESX.ShowNotification(msg)
                    else
                        QBCore.Functions.Notify(msg, "success")
                    end
                end
            },
            {
                title = '❌ Stop Radar',
                onSelect = function()
                    radarActive = false
                    local msg = "Speed camera gedeactiveerd"
                    if Config.Framework == 'esx' then
                        ESX.ShowNotification(msg)
                    else
                        QBCore.Functions.Notify(msg, "error")
                    end
                end
            }
        }
    })

    lib.showContext('radar_menu')
end)

CreateThread(function()
    while true do
        Wait(500)
        if radarActive then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            local vehModel = GetEntityModel(veh)
            local coords = GetEntityCoords(ped)

            if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped or not Config.WhitelistedVehicles[vehModel] then
                radarActive = false
                if Config.Framework == 'esx' then
                    ESX.ShowNotification("Radar automatisch gedeactiveerd (verkeerde situatie)")
                else
                    QBCore.Functions.Notify("Radar automatisch gedeactiveerd (verkeerde situatie)", "error")
                end
                goto continue
            end

            if GetEntitySpeed(veh) > 1.0 then
                radarActive = false
                if Config.Framework == 'esx' then
                    ESX.ShowNotification("Radar automatisch uitgeschakeld (je rijdt)")
                else
                    QBCore.Functions.Notify("Radar automatisch uitgeschakeld (je rijdt)", "error")
                end
                goto continue
            end

            for _, vehEntity in pairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(vehEntity) and vehEntity ~= veh then
                    local driverPed = GetPedInVehicleSeat(vehEntity, -1)
                    if driverPed and driverPed ~= 0 then
                        -- Check of bestuurder een speler is
                        if IsPedAPlayer(driverPed) then
                            local targetSpeed = GetEntitySpeed(vehEntity) * 3.6
                            local dist = #(coords - GetEntityCoords(vehEntity))
                            if dist < radarRange and targetSpeed > speedLimit then
                                local plate = GetVehicleNumberPlateText(vehEntity)
                                local netId = NetworkGetEntityOwner(vehEntity)
                                local serverId = netId and GetPlayerServerId(netId) or -1
                                if Config.Debug then
                                    print("[Radar DEBUG] Geflitst: Plate:", plate, "Speed:", math.floor(targetSpeed), "ServerID:", serverId)
                                end
                                if serverId ~= -1 then
                                    TriggerServerEvent('policeradar:issueFine', serverId, targetSpeed, fineAmount, plate)
                                else
                                    if Config.Debug then
                                        print("[Radar DEBUG] Ongeldige ServerID, boete niet verstuurd.")
                                    end
                                end
                                Wait(5000)
                            end
                        else
                            -- Bestuurder is NPC, controleer snelheid en afstand
                            local targetSpeed = GetEntitySpeed(vehEntity) * 3.6
                            local dist = #(coords - GetEntityCoords(vehEntity))
                            if dist < radarRange and targetSpeed > speedLimit then
                                local plate = GetVehicleNumberPlateText(vehEntity)
                                if Config.Debug then
                                    print("[Radar DEBUG] NPC geflitst: Plate:", plate, "Speed:", math.floor(targetSpeed))
                                end
                                TriggerServerEvent('policeradar:issueFine', -1, targetSpeed, fineAmount, plate)
                                Wait(5000)
                            end
                        end
                    end
                end
            end
            ::continue::
        end
    end
end)
