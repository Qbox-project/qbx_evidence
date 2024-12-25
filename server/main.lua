local sharedConfig = require 'config.shared'
local casings = {}
local bloodDrops = {}
local fingerDrops = {}
local playerGSR = {}

local function generateId(table)
    local id = lib.string.random('11111')
    if not table then return id end
    while table[id] do
        id = lib.string.random('11111')
    end
    return id
end

---@param source integer
---@return boolean
local function hasGSR(source)
    return playerGSR[source] and playerGSR[source] > os.time()
end
exports('HasGSR', hasGSR)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    playerGSR[source] = nil
end)

RegisterNetEvent('qbx_evidence:server:setGSR', function()
    playerGSR[source] = os.time() + sharedConfig.statuses.gsr.duration
end)

RegisterNetEvent('qbx_evidence:server:createCasing', function(coords)
    local weapon = exports.ox_inventory:GetCurrentWeapon(source)
    local ammo = exports.ox_inventory:Items(weapon.name).ammoname
    local casingId = lib.string.random('111111')
    local casingData = {
        serial = weapon.metadata.serial,
        caliber = ammo.label,
        coords = vec3(coords.x, coords.y, coords.z - 0.9),
        created = GetGameTimer(),
    }

    casings[casingId] = casingData

    TriggerClientEvent('qbx_evidence:client:addCasing', -1, casingId, casingData)
end)

RegisterNetEvent('qbx_evidence:server:collectCasing', function(casingId, location)
    if not casings[casingId] then return end

    local src = source
    local casing = casings[casingId]
    local player = exports.qbx_core:GetPlayer(src)
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)

    if not player or #(playerCoords - casing.coords) > 5.0 then return end

    local name = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
    local metadata = {
        label = locale('casing.label'),
        caliber = casing.caliber,
        collector = name,
        location = ('%s, %s'):format(location.main, location.zone),
    }

    local collected = exports.ox_inventory:AddItem(src, 'evidence', 1, metadata)

    if not collected then
        exports.qbx_core:Notify(src, 'Your inventory is full...', 'error')
        return
    end

    TriggerClientEvent('qbx_evidence:client:removeCasing', -1, casingId)
    casings[casingId] = nil
end)

RegisterNetEvent('qbx_evidence:server:createBloodDrop', function(coords)
    local bloodType = exports.qbx_core:GetMetadata(source, 'bloodtype')
    local dropId = lib.string.random('111111')
    local bloodData = {
        bloodType = bloodType,
        coords = vec3(coords.x, coords.y, coords.z - 0.9),
        created = GetGameTimer(),
    }

    bloodDrops[dropId] = bloodData

    TriggerClientEvent('qbx_evidence:client:addBloodDrop', -1, dropId, bloodData)
end)

RegisterNetEvent('qbx_evidence:server:collectBlood', function(dropId, location)
    if not bloodDrops[dropId] then return end

    local src = source
    local blood = bloodDrops[dropId]
    local player = exports.qbx_core:GetPlayer(src)
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)

    if not player or #(playerCoords - blood.coords) > 5.0 then return end

    local name = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
    local metadata = {
        label = locale('blood.label'),
        bloodtype = blood.bloodType,
        collector = name,
        location = ('%s, %s'):format(location.main, location.zone),
    }

    local collected = exports.ox_inventory:AddItem(src, 'evidence', 1, metadata)

    if not collected then
        exports.qbx_core:Notify(src, 'Your inventory is full...', 'error')
        return
    end

    TriggerClientEvent('qbx_evidence:client:removeBloodDrop', -1, dropId)
    bloodDrops[dropId] = nil
end)

RegisterNetEvent('qbx_evidence:server:createFingerDrop', function(coords)
    local player = exports.qbx_core:GetPlayer(source)
    local fingerId = generateId(fingerDrops)
    fingerDrops[fingerId] = player.PlayerData.metadata.fingerprint
    TriggerClientEvent('qbx_evidence:client:addFingerPrint', -1, fingerId, player.PlayerData.metadata.fingerprint, coords)
end)

RegisterNetEvent('qbx_evidence:server:addFingerprintToInventory', function(fingerId, fingerInfo)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local playerName = player.PlayerData.charinfo.firstname..' '..player.PlayerData.charinfo.lastname
    local streetName = fingerInfo.street
    local fingerprint = fingerInfo.fingerprint
    local metadata = {}
    metadata.type = 'Fingerprint Evidence'
    metadata.description = 'Fingerprint ID: '..fingerprint
    metadata.description = metadata.description..'\n\nCollected By: '..playerName
    metadata.description = metadata.description..'\n\nCollected At: '..streetName
    if not exports.ox_inventory:RemoveItem(src, 'empty_evidence_bag', 1) then
        return exports.qbx_core:Notify(src, locale('error.have_evidence_bag'), 'error')
    end
    if exports.ox_inventory:AddItem(src, 'filled_evidence_bag', 1, metadata) then
        TriggerClientEvent('qbx_evidence:client:removeFingerprint', -1, fingerId)
        fingerDrops[fingerId] = nil
    end
end)

CreateThread(function()
    while true do
        for source, expiration in pairs(playerGSR) do
            if os.time() >= expiration then
                playerGSR[source] = nil
            end
        end

        Wait(1000)
    end
end)