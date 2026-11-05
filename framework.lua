local STATE_KEY = 'lion_weaponanims'
local FRAMEWORK_RESOURCES = {
    esx = 'es_extended',
    qbcore = 'qb-core',
    qbox = 'qbx_core',
    ox = 'ox_core'
}

local esxCore
local qbCore
local activeFramework
local errorsReported = {}
local lastRequest = {}

local function detectFramework()
    if Config.Framework ~= 'auto' then
        return Config.Framework
    end

    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    if GetResourceState('ox_core') == 'started' then return 'ox' end

    return 'standalone'
end

local function getFramework()
    local framework = detectFramework()

    if framework ~= activeFramework then
        activeFramework = framework
        esxCore = nil
        qbCore = nil
        errorsReported = {}
        print(('[lion_weaponanims] Framework: %s'):format(framework))
    end

    local resource = FRAMEWORK_RESOURCES[framework]
    if resource and GetResourceState(resource) ~= 'started' then
        return nil
    end

    return framework
end

local function isAllowedJob(jobName)
    return type(jobName) == 'string' and Config.AllowedJobs[jobName] == true
end

local function hasAllowedGroup(groups)
    if type(groups) ~= 'table' then return false end

    for name, grade in pairs(groups) do
        if isAllowedJob(name) and type(grade) == 'number' and grade >= 0 then
            return true
        end
    end

    return false
end

local function hasAllowedPrimaryJob(playerData)
    local job = playerData and playerData.job
    if not job or not isAllowedJob(job.name) then return false end

    if Config.RequireDuty and job.onduty ~= true then return false end

    return true
end

local function resolveAllowed(source, framework)
    if framework == 'standalone' then
        return true
    end

    if framework == 'esx' then
        esxCore = esxCore or exports['es_extended']:getSharedObject()
        local player = esxCore and esxCore.GetPlayerFromId(source)
        if not player then return false end

        local job = player.job or (player.getJob and player.getJob())
        return job and isAllowedJob(job.name) or false
    end

    if framework == 'qbcore' then
        qbCore = qbCore or exports['qb-core']:GetCoreObject()
        local player = qbCore and qbCore.Functions.GetPlayer(source)
        return player and hasAllowedPrimaryJob(player.PlayerData) or false
    end

    if framework == 'qbox' then
        local player = exports.qbx_core:GetPlayer(source)
        local data = player and player.PlayerData
        if not data then return false end

        if hasAllowedPrimaryJob(data) then return true end
        if Config.QboxAllowSecondaryJobs and not Config.RequireDuty then
            return hasAllowedGroup(data.jobs)
        end

        return false
    end

    if framework == 'ox' then
        local player = exports.ox_core:GetPlayer(source)
        if not player or not player.charId then return false end
        return hasAllowedGroup(exports.ox_core:CallPlayer(source, 'getGroups'))
    end

    if framework == 'custom' then
        if type(Config.CustomJobResolver) ~= 'function' then return false end
        return isAllowedJob(Config.CustomJobResolver(source))
    end

    return false
end

local function setPlayerAllowed(source, allowed)
    local state = Player(source).state
    if state[STATE_KEY] ~= allowed then
        state:set(STATE_KEY, allowed, true)
    end
end

local function refreshPlayer(source)
    source = tonumber(source)
    if not source or source < 1 or not GetPlayerName(source) then return end

    local framework = getFramework()
    local allowed = false

    if framework then
        local success, result = pcall(resolveAllowed, source, framework)
        if success then
            allowed = result == true
            errorsReported[framework] = nil
        elseif not errorsReported[framework] then
            errorsReported[framework] = true
            print(('[lion_weaponanims] Failed to read %s player data: %s'):format(framework, tostring(result)))
        end
    end

    setPlayerAllowed(source, allowed)
end

local function refreshSoon(source)
    if source then
        SetTimeout(0, function() refreshPlayer(source) end)
    end
end

exports('refreshPlayer', refreshPlayer)

RegisterNetEvent('lion_weaponanims:requestSync', function()
    local source = source
    local now = GetGameTimer()
    if lastRequest[source] and now >= lastRequest[source] and now - lastRequest[source] < 3000 then return end

    lastRequest[source] = now
    refreshPlayer(source)
end)

AddEventHandler('playerDropped', function()
    lastRequest[source] = nil
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    if getFramework() == 'esx' then refreshSoon(playerId) end
end)

AddEventHandler('esx:setJob', function(playerId)
    if getFramework() == 'esx' then refreshSoon(playerId) end
end)

AddEventHandler('esx:playerLogout', function(playerId)
    if getFramework() == 'esx' and GetPlayerName(playerId) then
        setPlayerAllowed(playerId, false)
    end
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local playerId = source
    if getFramework() == 'qbcore' or getFramework() == 'qbox' then
        refreshSoon(playerId)
    end
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(playerId)
    local framework = getFramework()
    if (framework == 'qbcore' or framework == 'qbox') and GetPlayerName(playerId) then
        setPlayerAllowed(playerId, false)
    end
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(playerId)
    if getFramework() == 'qbcore' or getFramework() == 'qbox' then
        refreshSoon(playerId)
    end
end)

AddEventHandler('QBCore:Server:SetDuty', function(playerId)
    if Config.RequireDuty and (getFramework() == 'qbcore' or getFramework() == 'qbox') then
        refreshSoon(playerId)
    end
end)

AddEventHandler('qbx_core:server:onGroupUpdate', function(playerId)
    if getFramework() == 'qbox' then refreshSoon(playerId) end
end)

AddEventHandler('ox:playerLoaded', function(playerId)
    if getFramework() == 'ox' then refreshSoon(playerId) end
end)

AddEventHandler('ox:playerLogout', function(playerId)
    if getFramework() == 'ox' and GetPlayerName(playerId) then
        setPlayerAllowed(playerId, false)
    end
end)

AddEventHandler('ox:setGroup', function(playerId)
    if getFramework() == 'ox' then refreshSoon(playerId) end
end)

AddEventHandler('ox:setActiveGroup', function(playerId)
    if getFramework() == 'ox' then refreshSoon(playerId) end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() or resource == FRAMEWORK_RESOURCES[Config.Framework]
        or (Config.Framework == 'auto' and (resource == 'qbx_core' or resource == 'qb-core'
            or resource == 'es_extended' or resource == 'ox_core')) then
        SetTimeout(1000, function()
            for _, playerId in ipairs(GetPlayers()) do
                refreshPlayer(playerId)
            end
        end)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == FRAMEWORK_RESOURCES[activeFramework] then
        activeFramework = nil
        esxCore = nil
        qbCore = nil

        for _, playerId in ipairs(GetPlayers()) do
            local playerState = Player(tonumber(playerId)).state
            if playerState[STATE_KEY] ~= false then
                playerState:set(STATE_KEY, false, true)
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.ServerSyncInterval)

        for _, playerId in ipairs(GetPlayers()) do
            refreshPlayer(playerId)
        end
    end
end)
