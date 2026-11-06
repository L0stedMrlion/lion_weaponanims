local function CheckVersion()
    Wait(2000)
    PerformHttpRequest('https://raw.githubusercontent.com/L0stedMrlion/lion_scripts_versions/main/versions.json',
        function(err, responseData, headers)
            local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')
            local resourcename = "lion_weaponanims"

            if not responseData or responseData == "" then
                print("^1[" .. resourcename .. "] Unable to run version check.^7")
                return
            end

            local ok, versions = pcall(json.decode, responseData)
            if not ok or not versions or not versions[resourcename] then
                print("^1[" .. resourcename .. "] Failed to parse versions.json^7")
                return
            end

            local data = versions[resourcename]
            local newest = type(data) == "table" and tostring(data.version or "") or tostring(data)

            if newest == "" then return end

            local current = currentVersion:gsub("%s+", "")
            local latest  = newest:gsub("%s+", "")

            if current ~= latest then
                print("^3An update is available for " .. resourcename .. "^7")
                print("^3Your Version: ^1" .. current .. "^3 | Latest Version: ^2" .. latest .. "^7")
                print(
                    "^3Download the latest release from ^4https://github.com/L0stedMrlion/lion_weaponanims/releases")
            end
        end)
end

if Config.VersionCheck then
    CheckVersion()
end

local STATE_KEY = 'lionWeaponAnim'
local FRAMEWORK_STATE_KEY = 'lionWeaponAnimsFramework'
local currentFramework
local esxCore
local qbCore

local function resourcePresent(resource)
    local state = GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

local function detectFramework()
    local selected = type(Config.Framework) == 'string' and Config.Framework:lower() or 'auto'

    if selected ~= 'auto' then
        if selected == 'standalone' or selected == 'esx' or selected == 'qbcore' or selected == 'qbox' then
            return selected
        end

        return 'invalid'
    end

    if resourcePresent('qbx_core') then return 'qbox' end
    if resourcePresent('es_extended') then return 'esx' end
    if resourcePresent('qb-core') then return 'qbcore' end

    return 'standalone'
end

local function syncFramework()
    local detected = detectFramework()

    if detected ~= currentFramework then
        currentFramework = detected
        esxCore = nil
        qbCore = nil
        GlobalState[FRAMEWORK_STATE_KEY] = detected
    end
end

local function readPlayerJob(playerId)
    local playerData

    if currentFramework == 'qbox' then
        if GetResourceState('qbx_core') ~= 'started' then return nil end

        local ok, player = pcall(function()
            return exports['qbx_core']:GetPlayer(playerId)
        end)
        if ok and player then playerData = player.PlayerData end
    elseif currentFramework == 'esx' then
        if GetResourceState('es_extended') ~= 'started' then return nil end

        if not esxCore then
            local ok, core = pcall(function()
                return exports['es_extended']:getSharedObject()
            end)
            if ok then esxCore = core end
        end

        if not esxCore then return nil end

        local ok, player = pcall(function()
            return esxCore.GetPlayerFromId(playerId)
        end)
        if ok and player then
            if player.job then return player.job.name end
            if player.getJob then
                local jobOk, job = pcall(function() return player.getJob() end)
                if jobOk and job then return job.name end
            end
        end
    elseif currentFramework == 'qbcore' then
        if GetResourceState('qb-core') ~= 'started' then return nil end

        if not qbCore then
            local ok, core = pcall(function()
                return exports['qb-core']:GetCoreObject()
            end)
            if ok then qbCore = core end
        end

        if not qbCore or not qbCore.Functions then return nil end

        local ok, player = pcall(function()
            return qbCore.Functions.GetPlayer(playerId)
        end)
        if ok and player then playerData = player.PlayerData end
    end

    return playerData and playerData.job and playerData.job.name or nil
end

local function setEligibility(playerId, allowed)
    playerId = tonumber(playerId)
    if not playerId or not GetPlayerName(playerId) then return end

    local state = Player(playerId).state
    if state[STATE_KEY] ~= allowed then
        state:set(STATE_KEY, allowed, true)
    end
end

local function refreshPlayer(playerId)
    playerId = tonumber(playerId)
    if not playerId or not GetPlayerName(playerId) then return end

    local allowed = false
    if currentFramework == 'standalone' then
        allowed = true
    else
        local jobName = readPlayerJob(playerId)
        allowed = type(jobName) == 'string' and Config.AllowedJobs[jobName] == true
    end

    setEligibility(playerId, allowed)
end

local function refreshAllPlayers()
    syncFramework()
    for _, playerId in ipairs(GetPlayers()) do
        refreshPlayer(playerId)
    end
end

local function scheduleRefresh(playerId)
    playerId = tonumber(playerId)
    if not playerId then return end

    SetTimeout(200, function()
        syncFramework()
        refreshPlayer(playerId)
    end)
end

AddEventHandler('esx:playerLoaded', function(playerId)
    scheduleRefresh(playerId)
end)

AddEventHandler('esx:setJob', function(playerId)
    scheduleRefresh(playerId)
end)

AddEventHandler('esx:playerLogout', function(playerId)
    setEligibility(playerId, false)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    scheduleRefresh(player and player.PlayerData and player.PlayerData.source)
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(playerId)
    scheduleRefresh(playerId)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(playerId)
    setEligibility(playerId, false)
end)

AddEventHandler('qbx_core:server:onGroupUpdate', function(playerId)
    scheduleRefresh(playerId)
end)

AddEventHandler('playerJoining', function()
    scheduleRefresh(source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'qbx_core' or resourceName == 'es_extended' or resourceName == 'qb-core' then
        SetTimeout(300, refreshAllPlayers)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, playerId in ipairs(GetPlayers()) do
            setEligibility(playerId, false)
        end
    elseif resourceName == 'qbx_core' or resourceName == 'es_extended' or resourceName == 'qb-core' then
        esxCore = nil
        qbCore = nil
        SetTimeout(300, refreshAllPlayers)
    end
end)

CreateThread(function()
    refreshAllPlayers()

    while true do
        Wait(math.max(500, tonumber(Config.FrameworkSyncInterval) or 2000))
        refreshAllPlayers()
    end
end)
