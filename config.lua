-- _       _________ _______  _                   _______  _______  _______  _______  _           _______  _       _________ _______  _______
--( \      \__   __/(  ___  )( (    /|   |\     /|(  ____ \(  ___  )(  ____ )(  ___  )( (    /|   (  ___  )( (    /|\__   __/(       )(  ____ \
--| (         ) (   | (   ) ||  \  ( |   | )   ( || (    \/| (   ) || (    )|| (   ) ||  \  ( |   | (   ) ||  \  ( |   ) (   | () () || (    \/
--| |         | |   | |   | ||   \ | |   | | _ | || (__    | (___) || (____)|| |   | ||   \ | |   | (___) ||   \ | |   | |   | || || || (_____
--| |         | |   | |   | || (\ \) |   | |( )| ||  __)   |  ___  ||  _____)| |   | || (\ \) |   |  ___  || (\ \) |   | |   | |(_)| |(_____  )
--| |         | |   | |   | || | \   |   | || || || (      | (   ) || (      | |   | || | \   |   | (   ) || | \   |   | |   | |   | |      ) |
--| (____/\___) (___| (___) || )  \  |   | () () || (____/\| )   ( || )      | (___) || )  \  |   | )   ( || )  \  |___) (___| )   ( |/\____) |
--(_______/\_______/(_______)|/    )_)   (_______)(_______/|/     \||/       (_______)|/    )_)   |/     \||/    )_)\_______/|/     \|\_______)
--
-- By @Mrlion
-- Full credits to animations to: https://www.lcpdfr.com/downloads/gta5mods/character/54273-kos-tactical-weapon-reanimations/ (This a version a I use on my project)

Config = {
    -- Enables/disables version check for new updates
    VersionCheck = true,

    -- Enables or disables the custom weapon movement animations for specific jobs
    -- Add or remove job names here depending on which jobs will use the animations
    AllowedJobs = {
        police = true,
        sahp = true,
        sheriff = true
    },

    -- How often the script checks and updates your own players weapon animation
    -- Lower values make changes react faster but cause slightly more frequent checks
    -- Higher values reduce checks but make animation changes slightly less immediate
    -- * Recommended value: 100
    PlayerUpdateInterval = 100,

    -- How often the script checks other players around you
    -- This controls synchronization of the custom animations for other allowed players
    -- Lower values update other players more frequently
    -- * Recommended value: 500
    OtherPlayersUpdateInterval = 500,

    -- How long the script waits between attempts if the custom animation clipsets fail to load
    -- The normal clipset loading process has a 10 second timeout
    -- * Recommended value: 2000
    ClipsetRetryInterval = 2000,

    -- How long the script waits for all custom clipsets to load before retrying
    -- Time is in milliseconds.
    -- * Recommended value: 10000
    ClipsetLoadTimeout = 10000
}
