local ESX = exports.es_extended:getSharedObject()

local ALLOWED_JOBS = Config.AllowedJobs
local STATE_KEY = 'lionWeaponAnim'

local CLIPSETS = {
    pistol = 'lion_weaponanim_pistol',
    rifle = 'lion_weaponanim_rifle',
    cover1h = 'lion_weaponanim_cover_1h',
    stealth1h = 'lion_weaponanim_stealth_1h',
    stealth2h = 'lion_weaponanim_stealth_2h',
    stealthUnarmed = 'lion_weaponanim_stealth_unarmed'
}

local REQUIRED_CLIPSETS = {
    CLIPSETS.pistol,
    CLIPSETS.rifle,
    CLIPSETS.cover1h,
    CLIPSETS.stealth1h,
    CLIPSETS.stealth2h,
    CLIPSETS.stealthUnarmed
}

local WEAPON_GROUPS = {
    [GetHashKey('GROUP_PISTOL')] = {
        movement = CLIPSETS.pistol,
        stealthMovement = CLIPSETS.stealth1h,
        cover = CLIPSETS.cover1h
    },
    [GetHashKey('GROUP_STUNGUN')] = {
        movement = CLIPSETS.pistol,
        stealthMovement = CLIPSETS.stealth1h,
        cover = CLIPSETS.cover1h
    },
    [GetHashKey('GROUP_SMG')] = {
        movement = CLIPSETS.rifle,
        stealthMovement = CLIPSETS.stealth2h
    },
    [GetHashKey('GROUP_RIFLE')] = {
        movement = CLIPSETS.rifle,
        stealthMovement = CLIPSETS.stealth2h
    },
    [GetHashKey('GROUP_MG')] = {
        movement = CLIPSETS.rifle,
        stealthMovement = CLIPSETS.stealth2h
    },
    [GetHashKey('GROUP_SHOTGUN')] = {
        movement = CLIPSETS.rifle,
        stealthMovement = CLIPSETS.stealth2h
    },
    [GetHashKey('GROUP_SNIPER')] = {
        movement = CLIPSETS.rifle,
        stealthMovement = CLIPSETS.stealth2h
    }
}

local clipsetsReady = false
local localAllowed = false
local applied = {}

local function loadClipsets()
    for i = 1, #REQUIRED_CLIPSETS do
        RequestClipSet(REQUIRED_CLIPSETS[i])
    end

    local timeout = GetGameTimer() + Config.ClipsetLoadTimeout

    while GetGameTimer() < timeout do
        local ready = true

        for i = 1, #REQUIRED_CLIPSETS do
            if not HasClipSetLoaded(REQUIRED_CLIPSETS[i]) then
                ready = false
                break
            end
        end

        if ready then
            clipsetsReady = true
            print('^3[lion_weaponanims] ^7Custom clipsets loaded successfully!')
            return
        end

        Wait(0)
    end

    local missing = {}

    for i = 1, #REQUIRED_CLIPSETS do
        if not HasClipSetLoaded(REQUIRED_CLIPSETS[i]) then
            missing[#missing + 1] = REQUIRED_CLIPSETS[i]
        end
    end

    print(('^3[lion_weaponanims] ^7ERROR: custom clipsets were registered but did not load: %s'):format(table.concat(missing, ', ')))
end

local function clearPed(ped)
    local state = applied[ped]
    if not state then return end

    if DoesEntityExist(ped) then
        if state.movement then
            ResetPedWeaponMovementClipset(ped)
        end

        if state.strafe then
            ResetPedStrafeClipset(ped)
        end

        if state.cover then
            ClearPedCoverClipsetOverride(ped)
        end

        if state.stealthMovement then
            ResetPedMovementClipset(ped, 0.25)
        end
    end

    applied[ped] = nil
end

local function isPedInStealth(ped)
    local state = GetPedStealthMovement(ped)
    return state == true or state == 1
end

local function applyPed(ped, allowed)
    if not clipsetsReady or ped == 0 or not DoesEntityExist(ped) then
        clearPed(ped)
        return
    end

    if not allowed or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
        clearPed(ped)
        return
    end

    local weapon = GetSelectedPedWeapon(ped)
    local group = WEAPON_GROUPS[GetWeapontypeGroup(weapon)]
    local stealth = isPedInStealth(ped)

    if not group then
        local state = applied[ped]

        if stealth then
            if not state then
                state = {}
                applied[ped] = state
            end

            if state.movement then
                ResetPedWeaponMovementClipset(ped)
                state.movement = nil
            end

            if state.strafe then
                ResetPedStrafeClipset(ped)
                state.strafe = nil
            end

            if state.cover then
                ClearPedCoverClipsetOverride(ped)
                state.cover = nil
            end

            if not state.stealthMovement then
                SetPedMovementClipset(ped, CLIPSETS.stealthUnarmed, 0.25)
                state.stealthMovement = true
            end
        else
            clearPed(ped)
        end

        return
    end

    local state = applied[ped]
    if not state then
        state = {}
        applied[ped] = state
    end

    if state.stealthMovement then
        ResetPedMovementClipset(ped, 0.25)
        state.stealthMovement = nil
    end

    local wantedMovement = stealth and group.stealthMovement or group.movement

    if state.movement ~= wantedMovement then
        if state.movement then
            ResetPedWeaponMovementClipset(ped)
        end

        SetPedWeaponMovementClipset(ped, wantedMovement)
        state.movement = wantedMovement
    end

    if state.strafe then
        ResetPedStrafeClipset(ped)
        state.strafe = nil
    end

    if state.cover ~= group.cover then
        if state.cover then
            ClearPedCoverClipsetOverride(ped)
        end

        if group.cover then
            SetPedCoverClipsetOverride(ped, group.cover)
        end

        state.cover = group.cover
    end
end

local function setAllowed(job)
    local allowed = job and ALLOWED_JOBS[job.name] == true or false

    if localAllowed == allowed then
        if LocalPlayer.state[STATE_KEY] ~= allowed then
            LocalPlayer.state:set(STATE_KEY, allowed, true)
        end
        return
    end

    localAllowed = allowed
    LocalPlayer.state:set(STATE_KEY, allowed, true)

    if not allowed then
        clearPed(PlayerPedId())
    end
end

RegisterNetEvent('esx:playerLoaded', function(playerData)
    setAllowed(playerData and playerData.job)
end)

RegisterNetEvent('esx:setJob', function(job)
    setAllowed(job)
end)

RegisterNetEvent('esx:setPlayerData', function(key, value)
    if key == 'job' then
        setAllowed(value)
    end
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    setAllowed(nil)
end)

AddEventHandler('playerSpawned', function()
    clearPed(PlayerPedId())
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    LocalPlayer.state:set(STATE_KEY, false, true)

    for ped in pairs(applied) do
        clearPed(ped)
    end
end)

CreateThread(function()
    while not clipsetsReady do
        loadClipsets()

        if not clipsetsReady then
            Wait(Config.ClipsetRetryInterval)
        end
    end
end)

CreateThread(function()
    while true do
        local playerData = ESX.GetPlayerData()

        if playerData and playerData.job then
            setAllowed(playerData.job)
            break
        end

        Wait(Config.JobCheckInterval)
    end
end)

CreateThread(function()
    while true do
        if clipsetsReady then
            applyPed(PlayerPedId(), localAllowed)
            Wait(localAllowed and Config.PlayerUpdateInterval or 750)
        else
            Wait(Config.OtherPlayersUpdateInterval)
        end
    end
end)

CreateThread(function()
    while true do
        if not clipsetsReady then
            Wait(1000)
        else
            local seen = {}
            local players = GetActivePlayers()
            local myPlayer = PlayerId()

            for i = 1, #players do
                local player = players[i]

                if player ~= myPlayer then
                    local serverId = GetPlayerServerId(player)
                    local ped = GetPlayerPed(player)
                    local allowed = Player(serverId).state[STATE_KEY] == true

                    if ped ~= 0 then
                        seen[ped] = true
                        applyPed(ped, allowed)
                    end
                end
            end

            for ped in pairs(applied) do
                if ped ~= PlayerPedId() and not seen[ped] then
                    clearPed(ped)
                end
            end

            Wait(Config.OtherPlayersUpdateInterval)
        end
    end
end)
