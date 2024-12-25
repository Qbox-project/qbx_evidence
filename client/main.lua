local config = require 'config.client'
local sharedConfig = require 'config.shared'
local casings = {}
local currentCasing = 0
local bloodDrops = {}
local currentBloodDrop = 0
local fingerprints = {}
local currentFingerprint = 0
local shotsFired = 0
local recentlyGSR = false

exports.ox_inventory:displayMetadata({
    collector = locale('collector'),
    location = locale('location'),
    caliber = locale('casing.caliber'),
    bloodType = locale('blood.bloodtype')
})

local function dropBulletCasing()
    local randX = math.random() + math.random(-1, 1)
    local randY = math.random() + math.random(-1, 1)
    local coords = GetOffsetFromEntityInWorldCoords(cache.ped, randX, randY, 0)

    TriggerServerEvent('qbx_evidence:server:createCasing', coords)
end

---@param casingId integer
local function drawCasing(casingId)
    local coords = GetEntityCoords(cache.ped)

    if #(coords - casings[casingId].coords) >= 1.5 then return end

    qbx.drawText3d({
        text = ('[~g~G~s~] %s'):format(locale('casing.label')),
        coords = casings[casingId].coords
    })

    if IsControlJustReleased(0, 47) then
        local streets = qbx.getStreetName(casings[casingId].coords)
        local zone = qbx.getZoneName(casings[casingId].coords)
        local location = {
            main = streets.main,
            zone = zone
        }

        TriggerServerEvent('qbx_evidence:server:collectCasing', casingId, location)
    end
end

---@param dropId integer
local function drawBloodDrop(dropId)
    local coords = GetEntityCoords(cache.ped)

    if #(coords - bloodDrops[dropId].coords) >= 1.5 then return end

    qbx.drawText3d({
        text = ('[~g~G~s~] %s'):format(locale('blood.label')),
        coords = bloodDrops[dropId].coords
    })

    if IsControlJustReleased(0, 47) then
        local streets = qbx.getStreetName(bloodDrops[dropId].coords)
        local zone = qbx.getZoneName(bloodDrops[dropId].coords)
        local location = {
            main = streets.main,
            zone = zone
        }

        TriggerServerEvent('qbx_evidence:server:collectBlood', dropId, location)
    end
end

---@param coords vector3
---@return string
local function getStreetLabel(coords)
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street1 = GetStreetNameFromHashKey(s1)
    local street2 = GetStreetNameFromHashKey(s2)
    local streetLabel = street1
    if street2 then
        streetLabel = streetLabel .. ' | ' .. street2
    end
    local sanitized = streetLabel:gsub("%'", "")
    return sanitized
end

local function getPlayerDistanceFromCoords(coords)
    local pos = GetEntityCoords(cache.ped)
    return #(pos - coords)
end

---@class DrawEvidenceIfInRangeArgs
---@field evidenceId integer
---@field coords vector3
---@field text string
---@field metadata table
---@field serverEventOnPickup string

---@param args DrawEvidenceIfInRangeArgs
local function drawEvidenceIfInRange(args)
    if getPlayerDistanceFromCoords(args.coords) >= 1.5 then return end
    qbx.drawText3d({text = args.text, coords = args.coords})
    if IsControlJustReleased(0, 47) then
        TriggerServerEvent(args.serverEventOnPickup, args.evidenceId, args.metadata)
    end
end

---@param evidence table<number, {coords: vector3}>
---@return number? evidenceId
local function getCloseEvidence(evidence)
    local pos = GetEntityCoords(cache.ped, true)
    for evidenceId, v in pairs(evidence) do
        local dist = #(pos - v.coords)
        if dist < 1.5 then
            return evidenceId
        end
    end
end

RegisterNetEvent('qbx_evidence:client:addBloodDrop', function(dropId, newBlood)
    bloodDrops[dropId] = newBlood
end)

RegisterNetEvent('qbx_evidence:client:removeBloodDrop', function(dropId)
    bloodDrops[dropId] = nil
    currentBloodDrop = 0
end)

RegisterNetEvent('qbx_evidence:client:addFingerPrint', function(fingerId, fingerprint, coords)
    fingerprints[fingerId] = {
        fingerprint = fingerprint,
        coords = vec3(coords.x, coords.y, coords.z - 0.9)
    }
end)

RegisterNetEvent('qbx_evidence:client:removeFingerprint', function(fingerId)
    fingerprints[fingerId] = nil
    currentFingerprint = 0
end)

RegisterNetEvent('qbx_evidence:client:addCasing', function(casingId, newCasing)
    casings[casingId] = newCasing
end)

RegisterNetEvent('qbx_evidence:client:removeCasing', function(casingId)
    casings[casingId] = nil
    currentCasing = 0
end)

local function flashlightLoop()
    CreateThread(function()
        while cache.weapon do
            local sleep = 1000

            if IsPlayerFreeAiming(cache.playerId) then
                sleep = 10
                currentCasing = getCloseEvidence(casings) or currentCasing
                currentBloodDrop = getCloseEvidence(bloodDrops) or currentBloodDrop
                currentFingerprint = getCloseEvidence(fingerprints) or currentFingerprint
            end

            Wait(sleep)
        end
    end)
end

local function playerShootingLoop()
    CreateThread(function()
        while cache.weapon do
            if IsPedShooting(cache.ped) then
                shotsFired += 1

                if shotsFired > sharedConfig.statuses.gsr.threshold and not recentlyGSR and math.random() <= config.statuses.gsr.chance then
                    TriggerServerEvent('qbx_evidence:server:setGSR')

                    recentlyGSR = true

                    SetTimeout(sharedConfig.statuses.gsr.cooldown, function()
                        recentlyGSR = false
                    end)
                end

                dropBulletCasing()
            end

            if not recentlyGSR and shotsFired ~= 0 then
                local delay = math.random(5000, 10000)

                SetTimeout(sharedConfig.statuses.gsr.cooldown + delay, function()
                    shotsFired = math.max(shotsFired - 1, 0)
                end)
            end

            Wait(0)
        end
    end)
end

lib.onCache('weapon', function(weapon)
    if not weapon then return end

    if QBX.PlayerData.job.type == 'leo' then
        if not QBX.PlayerData.job.onduty or weapon ~= `WEAPON_FLASHLIGHT` then return end

        flashlightLoop()
    else
        local weaponTypeGroup = GetWeapontypeGroup(weapon)

        if config.blacklistedWeaponGroups[weaponTypeGroup] then return end

        playerShootingLoop()
    end
end)

AddEventHandler('gameEventTriggered', function(event, args)
    if event ~= 'CEventNetworkEntityDamage' then return end

    local victim = args[1]
    local attacker = args[2]

    if not IsPedAPlayer(victim) and not IsPedAPlayer(attacker) then return end

    local randX = math.random() + math.random(-1, 1)
    local randY = math.random() + math.random(-1, 1)
    local coords = GetOffsetFromEntityInWorldCoords(cache.ped, randX, randY, 0)

    TriggerServerEvent('qbx_evidence:server:createBloodDrop', coords)
end)

CreateThread(function()
    while true do
        Wait(0)
        if currentCasing and currentCasing ~= 0 then
            drawCasing(currentCasing)
        end

        if currentBloodDrop and currentBloodDrop ~= 0 then
            drawBloodDrop(currentBloodDrop)
        end

        if currentFingerprint and currentFingerprint ~= 0 then
            drawEvidenceIfInRange({
                evidenceId = currentFingerprint,
                coords = fingerprints[currentFingerprint].coords,
                text = locale('fingerprint_text'),
                metadata = {
                    type = locale('fingerprint'),
                    street = getStreetLabel(fingerprints[currentFingerprint].coords),
                    fingerprint = fingerprints[currentFingerprint].fingerprint
                },
                serverEventOnPickup = 'qbx_evidence:server:addFingerprintToInventory'
            })
        end
    end
end)