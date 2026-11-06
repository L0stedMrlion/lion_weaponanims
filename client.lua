local STATE_KEY = 'lionWeaponAnim'
local FRAMEWORK_STATE_KEY = 'lionWeaponAnimsFramework'


local function getFramework()
    local active = GlobalState[FRAMEWORK_STATE_KEY]
    if type(active) == 'string' then return active end

    local configured = type(Config.Framework) == 'string' and Config.Framework:lower() or 'auto'
    if configured ~= 'auto' then return configured end

    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    return 'standalone'
end

local function isPlayerAllowed(serverId)
    if getFramework() == 'standalone' then return true end
    if not serverId or serverId <= 0 then return false end

    return Player(serverId).state[STATE_KEY] == true
end

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
local lastLocalPed = 0
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

AddEventHandler('playerSpawned', function()
    clearPed(PlayerPedId())
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

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
        if clipsetsReady then
            local ped = PlayerPedId()
            if ped ~= lastLocalPed then
                clearPed(lastLocalPed)
                lastLocalPed = ped
            end

            local allowed = isPlayerAllowed(GetPlayerServerId(PlayerId()))
            applyPed(ped, allowed)
            Wait(allowed and Config.PlayerUpdateInterval or 750)
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
                    local allowed = isPlayerAllowed(serverId)

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
