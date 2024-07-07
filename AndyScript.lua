--! DON'T CHANGE THESE
local script_version = "0.1.8"
local script_url = "https://raw.githubusercontent.com/Lancito01/AndyScript/main/AndyScript.lua"
--! DON'T CHANGE THESE

--#region auto-updater
-- Auto-Updater by Hexarobi, modified by Ren, tysm to the both of u <3
local wait_for_restart = false
local please_wait_while_updating_menu = menu.divider(menu.my_root(), "Please wait...")

local function convert_backslashes_to_forwardslashes(str)
    return str:gsub("\\", "/")
end

local function parse_url_host_and_path(url)
    return url:match("://(.-)/"), "/" .. url:match("://.-/(.*)")
end

local toast = util.toast
local format = string.format

local SCRIPTS_DIR = convert_backslashes_to_forwardslashes(filesystem.scripts_dir())
local SCRIPT_RELPATH = convert_backslashes_to_forwardslashes(SCRIPT_RELPATH)
local STORE_DIR = convert_backslashes_to_forwardslashes(filesystem.store_dir())
local SCRIPT_PATH = SCRIPTS_DIR .. SCRIPT_RELPATH
local VERSION_DIR = STORE_DIR .. SCRIPT_NAME .. "/"
local VERSION_PATH = VERSION_DIR .. "version.txt"

local WAITING_FOR_HTTP_RESULT = true

if not filesystem.exists(VERSION_DIR) then
    filesystem.mkdirs(VERSION_DIR)
end

local function toast_formatted(str, ...)
    toast(format(str, ...))
end

local function read_version_id(path)
    local file = io.open(path)
    if file then
        local version = file:read()
        file:close()
        return version
    else
        toast("Error reading version file.")
    end
end

local function write_version_id(path, version_id)
    local file = io.open(path, "wb")
    if file == nil then
        toast("Error saving version ID file: " .. path)
        return false
    end
    file:write(version_id)
    file:close()
    return true
end

local function replace_current_script(result)
    local file = io.open(SCRIPT_PATH, "wb")
    if file == nil then
        toast("Error updating " .. SCRIPT_PATH .. ". Could not open file for writing.")
        return false
    end
    file:write(result .. "\n")
    file:close()
    return true
end

local function update_script(url)
    local url_host, url_path = parse_url_host_and_path(url)

    local function http_success(result, headers, status_code)
        WAITING_FOR_HTTP_RESULT = false

        -- No update neccessary if true
        if status_code == 304 then
            if not SCRIPT_SILENT_START then
                toast_formatted("%s is up to date! (%s)", SCRIPT_NAME, script_version)
            end
            -- It is safe to return, the script will not do anything (in terms of updating) and will continue as normal
            return
        end

        -- If we've just updated and GitHub did not give us a version ID / cache ID for some reason, ignore replacing the script and move on
        local temp_version_str =
        "temp/unknown" -- do not delete this, it is used for a check a little further down other than the next line
        if read_version_id(VERSION_PATH) == temp_version_str then
            write_version_id(VERSION_PATH, "")
            -- It is now safe to resume normal script operation
            return
        end


        -- Otherwise, if GitHub sends out a empty result/data, continue as normal. Something may have broke on GitHub's end.
        if not result or result == "" then
            toast_formatted("Error updating %s. Found empty script file.", SCRIPT_NAME)
            return
        end

        -- If GitHub has sent us the version ID / cache ID, then store it (so we can verify if we should update in the future),
        -- else store something temporary so that when the script restarts right after, it knows not to keep restarting and updating
        local saved_version_id = false
        if headers then
            for header_key, header_value in pairs(headers) do
                if header_key:lower() == "etag" then --? header_key:lower() is the same as string.lower(header_key)
                    write_version_id(VERSION_PATH, header_value)
                    saved_version_id = true
                end
            end
        end

        if not saved_version_id then
            write_version_id(VERSION_PATH, temp_version_str)
            --toast("Was not able to write the version ID to file. This may cause the script to update upon relaunch.")
        end

        -- We have done our safety checks, it is safe to replace the script.
        replace_current_script(result) -- this writes the result (the file contents) to the current script path.

        toast_formatted("Updated %s. Restarting...", SCRIPT_NAME)
        wait_for_restart = true
        util.yield(2900) -- Avoid restart loops by giving time for any other scripts to also complete updates
        wait_for_restart = false
        util.restart_script()
    end

    local function http_fail()
        WAITING_FOR_HTTP_RESULT = false
        toast_formatted("Error updating %s. Failed to download update.", SCRIPT_NAME)
    end

    local function http_add_cache_header_if_cached()
        -- Only use cached version if the file still exists on disk
        if filesystem.exists(VERSION_PATH) then
            -- Use ETags to only fetch files if they have been updated
            -- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag
            local cached_version_id = read_version_id(VERSION_PATH)
            if cached_version_id then
                async_http.add_header("If-None-Match", cached_version_id)
            end
        end
    end

    async_http.init(url_host, url_path, http_success, http_fail)
    http_add_cache_header_if_cached() --* if applicable, adds header to http before it is dispatched
    async_http.dispatch()             --* sends out the http request and does either http_success or http_fail
end

-- http_success in English terms:
-- if it recieves status 304 (ONLY WHEN HEADER "If-None-Match" IS SENT DURING DISPATCH) it will NOT replace or restart the script
-- else, it

update_script(script_url)
while WAITING_FOR_HTTP_RESULT or wait_for_restart do
    util.yield()
end
menu.delete(please_wait_while_updating_menu)
-- End of auto-updater
--#endregion auto-updater

util.require_natives(1663599433)
util.keep_running()

local store = filesystem.store_dir()
local AndyScript_store = store .. SCRIPT_NAME
local shortcut_path = AndyScript_store .. "/shortcuts.txt"

local notif_prefix = format("[%s] ", SCRIPT_NAME)
local og_toast = util.toast
local og_log = util.log
util.toast = function(str, flag) ---@diagnostic disable-line
    assert(str ~= nil, "No string given")
    if flag ~= nil then
        og_toast(notif_prefix .. tostring(str), flag)
    else
        og_toast(notif_prefix .. tostring(str))
    end
end
util.log = function(str) ---@diagnostic disable-line
    assert(str ~= nil, "No string given.")
    og_log(notif_prefix .. tostring(str))
end

--On Script Start
local settings_filepath = AndyScript_store .. "/settings.txt"
if not filesystem.exists(settings_filepath) then
    local filehandle = io.open(settings_filepath, "w")
    if filehandle then
        filehandle:close()
    end
end

local playtime_filepath = AndyScript_store .. "/playtime.txt"
if not filesystem.exists(playtime_filepath) then
    local filehandle = io.open(playtime_filepath, "w")
    if filehandle then
        filehandle:write(0)
        filehandle:close()
    end
end

local function read_playtime_file(filepath)
    local filehandle = io.open(filepath)
    local time = 0
    if filehandle then
        time = filehandle:read("a")
        filehandle:close()
        return time
    else
        util.toast("Error reading playtime file.")
    end
end
local script_playtime = tonumber(read_playtime_file(playtime_filepath)) -- reading current playtime

util.create_tick_handler(function()
    script_playtime += 1
    util.yield(1000)
end)

local function save_playtime_to_file(playtime)
    local filehandle = io.open(playtime_filepath, "w")
    if filehandle then
        filehandle:write(playtime)
        filehandle:close()
    else
        util.toast("Error writing to playtime file.")
    end
end

local function read_settings_file()
    local filehandle = io.open(settings_filepath)
    local tbl = {}
    if filehandle then
        for line_text in filehandle:lines() do ---@diagnostic disable-next-line
            local prefix, suffix = string.partition(line_text, "=")
            tbl[prefix] = suffix ==
                "true" -- since the setting is imported as a string ("true" or "false"), the == serves as a logical test to convert it to a boolean
        end
        return tbl
    else
        util.toast("Error reading settings file.")
    end
end

local settings = read_settings_file() -- input settings state from file

local user_name = settings.hide_name_on_script_startup and "User" or players.get_name(players.user())
local possible_welcome_phrases = { -- 12 normal, 1 rare
    "Glad you're here, %s.",
    "Welcome, %s. We hope you brought pizza.",
    "%s just slid into the script.",
    "Welcome, %s. Hi!",
    "%s joined the party.",
    "Glad you're here, %s.",
    "Yay you made it, %s!",
    "%s just landed.",
    "Good to see you, %s.",
    "%s just showed up!",
    "%s is here.",
    "%s hopped into the script.",
    "Hey %s, you found the rare welcome phrase! Feel free to flex it in AndyScript Discord. :D"
}

local chosen_welcome_phrase_index = math.random(1, 100) == 1 and #possible_welcome_phrases or
    math.random(#possible_welcome_phrases - 1)
local welcome_phrase = string.format(possible_welcome_phrases[chosen_welcome_phrase_index], user_name)
if not SCRIPT_SILENT_START then util.toast("Loaded AndyScript-dev\n\n" .. welcome_phrase) end

--Functions // Defining
local function format_time(time, longer) -- shoutout to ma boy da sussy man
    local seconds_in_minute = 60
    local seconds_in_hour = seconds_in_minute * 60
    local seconds_in_day = seconds_in_hour * 24

    local days = (time // seconds_in_day)
    local hours = (time % seconds_in_day) // seconds_in_hour
    local minutes = (time % seconds_in_hour) // seconds_in_minute
    local seconds = (time % seconds_in_minute)

    local word_days = days == 1 and "day" or "days"
    local word_hours = hours == 1 and "hour" or "hours"
    local word_minutes = minutes == 1 and "minute" or "minutes"
    local word_seconds = seconds == 1 and "second" or "seconds"

    if longer then
        if time >= seconds_in_day then
            return string.format("%d %s, %d %s, %d %s, and %d %s", days, word_days, hours, word_hours, minutes,
                word_minutes, seconds, word_seconds)
        elseif time >= seconds_in_hour then
            return string.format("%d %s, %d %s, and %d %s", hours, word_hours, minutes, word_minutes, seconds,
                word_seconds)
        elseif time >= seconds_in_minute then
            return string.format("%d %s and %d %s", minutes, word_minutes, seconds, word_seconds)
        else
            return string.format("%d %s", seconds, word_seconds)
        end
    end

    return string.format("%.2d" .. ":" .. "%.2d" .. ":" .. "%.2d" .. ":" .. "%.2d", days, hours, minutes, seconds)
end

local explosion_names = {
    [0] = "Off",
    "Grenade",
    "Grenade Launcher",
    "Sticky Bomb",
    "Molotov",
    "Rocket",
    "Tankshell",
    "Octane",
    "Car",
    "Plane",
    "Petrol Pump",
    "Bike",
    "Steam",
    "Flame",
    "Water Hydrant",
    "Gas Canister",
    "Boat",
    "Ship Destroyed",
    "Truck",
    "Bullet",
    "Smoke Grenade Launcer",
    "Smoke Grenade",
    "BZ Gas",
    "Flare",
    "Gas Canister",
    "Extinguisher",
    "Programmable AR",
    "Train",
    "Barrel",
    "Propane",
    "Blimp",
    "Flame Explosion",
    "Tanker",
    "Plane Rocket",
    "Vehicle Bullet",
    "Gas Tanker",
    "Bird Crap",
    "Railgun",
    "Blimp 2",
    "Firework",
    "Snowball",
    "Proximity Mine",
    "Valkyrie Cannon",
    "Air Defense",
    "Pipebomb",
    "Vehicle Mine",
    "Explosive Ammo",
    "APC Shell",
    "Cluster Bomb",
    "Gas Bomb",
    "Incendiary Bomb",
    "Standard Bomb",
    "Torpedo",
    "Underwater Torpedo",
    "Bombushka Cannon",
    "Secondary Bomb Cluster",
    "Hunter Barrage",
    "Hunter Cannon",
    "Rogue Cannon",
    "Underwater Mine",
    "Orbital Cannon",
    "Wide Standard Bomb",
    "Explosive Ammo Shotgun",
    "Oppressor MK2 Cannon",
    "Kinetic Mortar",
    "Kinetic Vehicle Mine",
    "EMP Vehicle Mine",
    "Spike Vehicle Mine",
    "Slick Vehicle Mine",
    "TAR Vehicle Mine",
    "Drone",
    "Raygun",
    "Buried Mine",
    "Script Missile",
}

local function save_settings_to_file()
    local filehandle = io.open(settings_filepath, "w")
    if filehandle then
        for setting, value in pairs(settings) do
            filehandle:write(setting .. "=" .. tostring(value) .. "\n")
        end
        filehandle:close()
    else
        util.toast("Error saving settings to settings file.")
    end
end

local function announce(string)
    if settings.announce_actions then
        util.toast(string)
    end
end

local function request_model(hash, timeout)
    local end_time = os.time() + (timeout or 5)
    STREAMING.REQUEST_MODEL(hash)
    while not STREAMING.HAS_MODEL_LOADED(hash) and end_time >= os.time() do
        util.yield()
    end
    return STREAMING.HAS_MODEL_LOADED(hash)
end

local function request_control(entity, timeout)
    local end_time = os.time() + (timeout or 5)
    NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entity)
    while not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(entity) and end_time >= os.time() do
        NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entity)
        util.yield()
    end
    return NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(entity)
end

local some_ped_list = {
    "a_m_m_bevhills_02",  --1
    "a_m_m_business_01",  --2
    "a_m_m_bevhills_01",  --3
    "a_m_m_farmer_01",    --4
    "a_m_m_paparazzi_01", --5
    "a_m_m_prolhost_01",  --6
    "a_m_m_stlat_02"      --7
}

local function get_vehicle_ped_is_in(ped, includeLastVehicle)
    if includeLastVehicle or PED.IS_PED_IN_ANY_VEHICLE(ped, false) then
        return PED.GET_VEHICLE_PED_IS_IN(ped, false)
    end
    return 0
end

local was_in_transition = false
local announce_transition_end = false
local give_weapons_after_transition = false

local function on_transition_exit()
    if announce_transition_end then
        util.toast("No longer in transition!")
    end
    if give_weapons_after_transition then
        util.yield(1000)
        menu.trigger_command(menu.ref_by_path("Self>Weapons>Get Weapons>All Weapons", 38), "")
        announce("All weapons given.")
    end
end

--Main Menu
menu.divider(menu.my_root(), "Main")
local self_tab = menu.list(menu.my_root(), "Self", {}, "")
local online_tab = menu.list(menu.my_root(), "Online", {}, "")
menu.action(menu.my_root(), "Players shortcut", {}, 'Takes you to "Players" list.', function()
    menu.trigger_command(menu.ref_by_path('Players'), "")
end)
local vehicles_tab = menu.list(menu.my_root(), "Vehicles", {}, "")
local world_tab = menu.list(menu.my_root(), "World", {}, "")
local fun_tab = menu.list(menu.my_root(), "Fun", {},
    "Most of these are suggestions on my Discord. You should join! Link is in \"About\" tab.")
local settings_tab = menu.list(menu.my_root(), "Settings", {}, "")
menu.divider(menu.my_root(), "Information")
local info_tab = menu.list(menu.my_root(), "About", {}, "")

--Self tab
--Weapons tab
local weapons_in_self_tab = menu.list(self_tab, "Weapons", {}, "", function() end)
--Loops tab
local loops_in_self_tab = menu.list(self_tab, "Loops", {}, "", function() end)

--Explosive bullets
do
    local current
    local coords = v3.new()
    menu.list_select(weapons_in_self_tab, "Explosive Ammo", {}, "", explosion_names, 0, function(index)
        current = index - 1
        local explosion_id =
            current -- this SHOULD have a -1 because lua starts indexes at 1, not 0 BUT! if you look at the table definition, ma boy the sus man told me how to make it 0 based to my brain can rest easy
        if current ~= -1 then
            while current + 1 == index do
                current = index - 1
                if WEAPON.GET_PED_LAST_WEAPON_IMPACT_COORD(players.user_ped(), coords) then
                    local x, y, z = v3.get(coords)
                    FIRE.ADD_OWNED_EXPLOSION(players.user_ped(), x, y, z, explosion_id, 1.0, true, false, 0)
                end
                util.yield()
            end
        else
            announce("Explosive Ammo is off.")
        end
    end)
end

--Godmode
menu.toggle(self_tab, "Godmode", { "andygodmode" },
    "Toggles several Stand features such as Godmode, Gracefulness, and Vehicle Godmode all at the same time to make you invincible against mortals.",
    function(state)
        local switch_for_godmode = state and "On" or "Off"
        menu.trigger_command(menu.ref_by_path("Self>Immortality", 38), switch_for_godmode)
        menu.trigger_command(menu.ref_by_path("Self>Gracefulness", 38), switch_for_godmode)
        menu.trigger_command(menu.ref_by_path("Self>Auto Heal", 38), switch_for_godmode)
        menu.trigger_command(menu.ref_by_path("Vehicle>Indestructible", 38), switch_for_godmode)
        menu.trigger_command(menu.ref_by_path("Self>Glued To Seats", 38), switch_for_godmode)
        menu.trigger_command(menu.ref_by_path("Stand>Lua Scripts>" .. SCRIPT_NAME .. ">Self>Clean Loop", 38),
            switch_for_godmode)
        announce("Godmode " .. switch_for_godmode)
    end
)

--Ghost
menu.toggle(self_tab, "Ghost", { "andyghostmode" },
    "Toggles several Stand features such as Invisibility and Off The Radar all at the same time to make you fully invisible.",
    function(state)
        menu.trigger_command(
            menu.ref_by_path("Self>Appearance>Invisibility>" .. (state and "Enabled" or "Disabled"), 38), "")
        menu.set_value(menu.ref_by_path("Online>Off The Radar", 38), state)
        announce("Ghostmode " .. (state and "On" or "Off"))
    end
)

--Heal
menu.action(self_tab, "Max Health", { "healself" }, "Heals your ped to its max health.",
    function()
        local max_health = ENTITY.GET_ENTITY_MAX_HEALTH(players.user_ped())
        ENTITY.SET_ENTITY_HEALTH(players.user_ped(), max_health, 0)
        announce("Health maxed.")
    end
)

--Semigodmode heal loop
local is_heal_loop_on = false
menu.toggle_loop(loops_in_self_tab, "Heal Loop", { "healloop" }, "",
    function()
        if not is_heal_loop_on then
            announce("Healing ped.")
            is_heal_loop_on = true
        end
        if ENTITY.GET_ENTITY_HEALTH(players.user_ped()) ~= 0 then
            local max_health = ENTITY.GET_ENTITY_MAX_HEALTH(players.user_ped())
            ENTITY.SET_ENTITY_HEALTH(players.user_ped(), max_health, 0)
        end
        util.yield()
    end, function() is_heal_loop_on = false end
)

--Clean
menu.action(self_tab, "Clean", { "cleanself" }, "Cleans your ped from all visible blood.",
    function()
        PED.CLEAR_PED_BLOOD_DAMAGE(players.user_ped())
        announce("Ped cleaned.")
    end
)

--Clean loop
menu.toggle(loops_in_self_tab, "Clean Loop", {}, "Kepes your ped clean at all costs.",
    function(state)
        local is_on = state
        if state then announce("Cleaning ped.") end
        while is_on do
            PED.CLEAR_PED_BLOOD_DAMAGE(players.user_ped())
            util.yield()
        end
    end)

--Max armor
menu.action(self_tab, "Max Armor", {}, "Maxes out your armor.",
    function()
        PED.SET_PED_ARMOUR(players.user_ped(), 100)
        announce("Armor filled.")
    end
)

--Armor loop
local is_armor_loop_on = false
menu.toggle_loop(loops_in_self_tab, "Armor Loop", {}, "Keeps your armor full at all costs.",
    function()
        if not is_armor_loop_on then
            announce("Filling ped's armor.")
            is_armor_loop_on = true
        end
        PED.SET_PED_ARMOUR(players.user_ped(), 100)
    end, function() is_armor_loop_on = false end)

--Revive ped
menu.action(self_tab, "Revive Ped", { "revive" }, "Revives your ped.",
    function()
        if ENTITY.GET_ENTITY_HEALTH(players.user_ped()) == 0 then
            local coordsv3 = ENTITY.GET_ENTITY_COORDS(players.user_ped())
            NETWORK.NETWORK_RESURRECT_LOCAL_PLAYER(coordsv3["x"], coordsv3["y"], coordsv3["z"],
                ENTITY.GET_ENTITY_HEADING(players.user_ped()), true, false, false, 0, 0)
            -- CAM.SET_CAM_DEATH_FAIL_EFFECT_STATE(0)
        end
    end
)

--Loop revive ped
menu.toggle_loop(loops_in_self_tab, "Revive Ped Loop", {}, "Constantly revives your ped if you die.",
    function()
        local ped = players.user_ped()
        if ENTITY.GET_ENTITY_HEALTH(ped) == 0 or PED.IS_PED_DEAD_OR_DYING(ped) then
            PED.SET_PED_CAN_RAGDOLL(ped, false)
            local coordsv3 = ENTITY.GET_ENTITY_COORDS(ped)
            NETWORK.NETWORK_RESURRECT_LOCAL_PLAYER(coordsv3["x"], coordsv3["y"], coordsv3["z"],
                ENTITY.GET_ENTITY_HEADING(ped), true, false, false, 0, 0)
        end
        -- util.yield() -- not necessary in menu.toggle_loop()
    end, function()
        PED.SET_PED_CAN_RAGDOLL(players.user_ped(), true)
    end
)

--Angry mode
menu.toggle_loop(self_tab, "Disable \"Angry Mode\"", {},
    "Disables the state where the ped is angry and moves quickly after getting shot nearby or directly.", function()
        PED.SET_MOVEMENT_MODE_OVERRIDE(players.user_ped(), "DEFAULT")
    end, function()
        PED.SET_MOVEMENT_MODE_OVERRIDE(players.user_ped(), 0)
    end)

--Online tab
--Weapons
menu.toggle(online_tab, "Give All Weapons After Joining A Session", {},
    "As soon as the transition is over, get all weapons.",
    function(state)
        give_weapons_after_transition = state
    end
)

--Popularity loop
local popularity_loop_command_ref = menu.ref_by_path("Online>Quick Progress>Set Nightclub Popularity", 38)
menu.toggle_loop(online_tab, "Nightclub Popularity Loop", { "ncpopularityloop" },
    "Toggles the Nightclub popularity loop to always keep it at 100%",
    function()
        menu.trigger_command(popularity_loop_command_ref, "100")
        util.toast("Popularity set")
        util.yield(2000)
    end
)

--Transition
menu.toggle(online_tab, "Notification When Transition Is Over", { "notifyontransitionend" },
    "Toasts a notification when the main transition is over.",
    function(state)
        announce_transition_end = state
    end
)

--Vehicles tab
--Include last vehicle
menu.toggle(vehicles_tab, "Include Last Vehicle For Vehicle Functions", {},
    "Option to include last vehicle if you're not in a vehicle at the time of running a function.",
    function(state) Include_last_vehicle_for_vehicle_functions = state end)

--Options divider
menu.divider(vehicles_tab, "Options")

--Radio off automatically
local last_vehicle_with_radio_off = 0
menu.toggle_loop(vehicles_tab, "Turn Off Radio Automatically", {}, "Turns off the radio each time you get in a vehicle.",
    function()
        local current_vehicle = get_vehicle_ped_is_in(players.user_ped())
        if current_vehicle ~= 0 then
            if last_vehicle_with_radio_off ~= current_vehicle and VEHICLE.GET_IS_VEHICLE_ENGINE_RUNNING(current_vehicle) then
                if AUDIO.IS_VEHICLE_RADIO_ON(current_vehicle) then
                    util.yield(1000)
                    AUDIO.SET_RADIO_TO_STATION_NAME("OFF")
                    announce("Radio off")
                end
                last_vehicle_with_radio_off = current_vehicle
            end
        else
            last_vehicle_with_radio_off = 0
        end
    end
)

--Auto-flip vehicle
menu.toggle_loop(vehicles_tab, "Auto-flip Vehicle", {},
    "Automatically flips your car the right way if you land upside-down or sideways.", function()
        local player_vehicle = get_vehicle_ped_is_in(players.user_ped(), false)
        local rotation = CAM.GET_GAMEPLAY_CAM_ROT(2)
        local heading = v3.getHeading(v3.new(rotation))
        local vehicle_distance_to_ground = ENTITY.GET_ENTITY_HEIGHT_ABOVE_GROUND(player_vehicle)
        local am_i_on_ground = vehicle_distance_to_ground < 2 --and true or false
        local speed = ENTITY.GET_ENTITY_SPEED(player_vehicle)
        if not VEHICLE.IS_VEHICLE_ON_ALL_WHEELS(player_vehicle) and ENTITY.IS_ENTITY_UPSIDEDOWN(player_vehicle) and am_i_on_ground then
            VEHICLE.SET_VEHICLE_ON_GROUND_PROPERLY(player_vehicle, 5.0)
            ENTITY.SET_ENTITY_HEADING(player_vehicle, heading)
            util.yield()
            VEHICLE.SET_VEHICLE_FORWARD_SPEED(player_vehicle, speed)
        end
    end)

--Vehicle accel
menu.text_input(vehicles_tab, "Alter Vehicle's Acceleration", { "vehiclespeed" },
    "Changes how fast the car goes. 0 = Default",
    function(string)
        local input = tonumber(string)
        if type(input) == "nil" then
            util.toast("Input must be a number. Try again!")
        else
            local vehicle = get_vehicle_ped_is_in(players.user_ped(), Include_last_vehicle_for_vehicle_functions)
            if vehicle == 0 then
                util.toast("Get in a car first.")
            else
                local number = tonumber(input) or 0
                request_control(vehicle)
                VEHICLE.MODIFY_VEHICLE_TOP_SPEED(vehicle, number)
                announce("Acceleration altered. Give it a try!")
            end
        end
    end, "0"
)

--Random tuning
menu.action(vehicles_tab, "Tune Vehicle Randomly", { "randomtune" }, "Applies random tuning to your vehicle.", function()
    local vehicle = get_vehicle_ped_is_in(players.user_ped(), Include_last_vehicle_for_vehicle_functions)
    if vehicle == 0 then
        util.toast("You are not in a vehicle.")
    else
        VEHICLE.SET_VEHICLE_MOD_KIT(vehicle, 0) -- needed for most modifications through SET_VEHICLE_MOD to take effect
        for mod_type = 0, 48 do
            local num_of_mods = VEHICLE.GET_NUM_VEHICLE_MODS(vehicle, mod_type)
            local random_tune = math.random(-1, num_of_mods - 1)
            VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, mod_type, math.random(0, 1) == 1)
            VEHICLE.SET_VEHICLE_MOD(vehicle, mod_type, random_tune, false)
        end
        VEHICLE.SET_VEHICLE_COLOURS(vehicle, math.random(0, 160), math.random(0, 160))
        VEHICLE.SET_VEHICLE_TYRE_SMOKE_COLOR(vehicle, math.random(0, 255), math.random(0, 255), math.random(0, 255))
        VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicle, math.random(0, 6))
        for index = 0, 3 do
            VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicle, index, math.random(0, 1) == 1)
        end
        VEHICLE.SET_VEHICLE_NEON_COLOUR(vehicle, math.random(0, 255), math.random(0, 255), math.random(0, 255))
        -- menu.trigger_command(menu.ref_by_path("Vehicle>Los Santos Customs>Appearance>Wheels>Wheels Colour", 42),
        -- tostring(math.random(0, 160)))
    end
end)
menu.text_input(vehicles_tab, "Loop Random Tune", { "randomtuneloop" },
    "Applies random tuning to your vehicle every \"x\" miliseconds. 0 is equal to off.", function(str)
        if tonumber(str) then
            Option = tonumber(str)
            while Option ~= 0 do
                local vehicle = get_vehicle_ped_is_in(players.user_ped(), Include_last_vehicle_for_vehicle_functions)
                if vehicle ~= 0 then
                    VEHICLE.SET_VEHICLE_MOD_KIT(vehicle, 0) -- needed for most modifications through SET_VEHICLE_MOD to take effect
                    for mod_type = 0, 48 do
                        local num_of_mods = VEHICLE.GET_NUM_VEHICLE_MODS(vehicle, mod_type)
                        local random_tune = math.random(-1, num_of_mods - 1)
                        VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, mod_type, math.random(0, 1) == 1)
                        VEHICLE.SET_VEHICLE_MOD(vehicle, mod_type, random_tune, false)
                    end
                    VEHICLE.SET_VEHICLE_COLOURS(vehicle, math.random(0, 160), math.random(0, 160))
                    VEHICLE.SET_VEHICLE_TYRE_SMOKE_COLOR(vehicle, math.random(0, 255), math.random(0, 255),
                        math.random(0, 255))
                    VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicle, math.random(0, 6))
                    for index = 0, 3 do
                        VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicle, index, math.random(0, 1) == 1)
                    end
                    VEHICLE.SET_VEHICLE_NEON_COLOUR(vehicle, math.random(0, 255), math.random(0, 255),
                        math.random(0, 255))
                    -- menu.trigger_command(
                    -- menu.ref_by_path("Vehicle>Los Santos Customs>Appearance>Wheels>Wheels Colour", 42),
                    -- tostring(math.random(0, 160)))
                end
                util.yield(Option)
            end
        else
            util.toast("Please enter a number.")
        end
    end, "0")

-- Measuring speed
local measuring_speed_list = menu.list(vehicles_tab, "Measure Speed", {}, "")
local unit = "km/h"
local function convert_speed(speed)
    if unit == "km/h" then
        return speed * 3.6
    elseif unit == "mph" then
        return speed * 2.236936
    end
end

menu.list_select(measuring_speed_list, "Unit for speed", {}, "", {
    { 1, "KM/H" },
    { 2, "MPH" },
}, 1, function(value)
    if value == 1 then
        unit = "km/h"
    elseif value == 2 then
        unit = "mph"
    end
end)

local send_speed_results_in_chat
measuring_speed_list:toggle("Send results in chat", {}, "Whether to send the results in team chat or not.",
    function(state)
        send_speed_results_in_chat = state
    end)

-- Top speed
menu.divider(measuring_speed_list, "Top Speed")
local topspeed_is_loop_on = false
local top_speed = 0
local last_topspeed_reported = 0
local function send_topspeed_to_chat_thread()
    util.create_thread(function()
        while topspeed_is_loop_on do
            if last_topspeed_reported < top_speed then
                local text = "New top speed: " .. convert_speed(top_speed) .. " " .. unit
                if send_speed_results_in_chat then
                    chat.send_message(text, true, true, true)
                end
                util.toast(text)
                last_topspeed_reported = top_speed
            end
            util.yield(2000)
        end
    end)
end
measuring_speed_list:toggle_loop("Measure Top Speed", { "topspeedcalc" },
    "Sends a message in chat every time a new top speed is found.", function()
        if not topspeed_is_loop_on then
            topspeed_is_loop_on = true
            send_topspeed_to_chat_thread()
        end
        local speed = ENTITY.GET_ENTITY_SPEED(PLAYER.PLAYER_PED_ID())
        if speed > top_speed then
            top_speed = speed
        end
    end, function()
        topspeed_is_loop_on = false
    end)
measuring_speed_list:action("Reset Top Speed", { "resettopspeedcalc" }, "Resets the top speed to 0.", function()
    top_speed = 0
    last_topspeed_reported = 0
end)

-- Acceleration
local speed = 0
local last_speed = 0
local time_to_acceleration = 0
local starting_acceleration_point = { x = 0, y = 0, z = 0, init = false }
local eighth_mile = false
local quarter_mile = false
measuring_speed_list:divider("Acceleration")
measuring_speed_list:toggle_loop("Measure Acceleration", { "measureacceleration" },
    "Measures your acceleration depending on the selected unit.", function()
        speed = ENTITY.GET_ENTITY_SPEED(PLAYER.PLAYER_PED_ID())
        while speed < 0.03 do -- wait for player to move
            speed = ENTITY.GET_ENTITY_SPEED(PLAYER.PLAYER_PED_ID())
            util.yield()
        end
        if time_to_acceleration == 0 or not starting_acceleration_point.init then -- start timer and distance
            time_to_acceleration = os.clock()
            local coords = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID(), true)
            starting_acceleration_point = { x = coords.x, y = coords.y, z = coords.z, init = true }
        end
        local coords = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID(), true)
        local distance = MISC.GET_DISTANCE_BETWEEN_COORDS(starting_acceleration_point.x, starting_acceleration_point.y,
            starting_acceleration_point.z, coords.x, coords.y, coords.z, true)
        if distance >= 201.168 and not eighth_mile then
            eighth_mile = true
            local result_time = os.clock() - time_to_acceleration
            local text = "Eighth mile: " .. result_time .. " seconds."
            if send_speed_results_in_chat then
                chat.send_message(text, true, true, true)
            end
            util.toast(text)
        end
        if distance >= 402.336 and not quarter_mile then
            quarter_mile = true
            local result_time = os.clock() - time_to_acceleration
            local text = "Quarter mile: " .. result_time .. " seconds."
            if send_speed_results_in_chat then
                chat.send_message(text, true, true, true)
            end
            util.toast(text)
        end
        if unit == "km/h" then
            if convert_speed(speed) >= 50 and convert_speed(last_speed) < 50 then
                local result_time = os.clock() - time_to_acceleration
                local text = "0-50 KM/H: " .. result_time .. " seconds."
                if send_speed_results_in_chat then
                    chat.send_message(text, true, true, true)
                end
                util.toast(text)
            end
            if convert_speed(speed) >= 100 and convert_speed(last_speed) < 100 then
                local result_time = os.clock() - time_to_acceleration
                local text = "0-100 KM/H: " .. result_time .. " seconds."
                if send_speed_results_in_chat then
                    chat.send_message(text, true, true, true)
                end
                util.toast(text)
            end
        elseif unit == "mph" then
            if convert_speed(speed) >= 30 and convert_speed(last_speed) < 30 then
                local result_time = os.clock() - time_to_acceleration
                local text = "0-30 MPH: " .. result_time .. " seconds."
                if send_speed_results_in_chat then
                    chat.send_message(text, true, true, true)
                end
                util.toast(text)
            end
            if convert_speed(speed) >= 60 and convert_speed(last_speed) < 60 then
                local result_time = os.clock() - time_to_acceleration
                local text = "0-60 MPH: " .. result_time .. " seconds."
                if send_speed_results_in_chat then
                    chat.send_message(text, true, true, true)
                end
                util.toast(text)
            end
        end
        last_speed = speed
    end, function()
        speed = 0
        last_speed = 0
        time_to_acceleration = 0
        starting_acceleration_point.init = false
        eighth_mile = false
        quarter_mile = false
    end)

--World tab
--Change local gravity
local function request_control_of_table_once(tbl)
    for index, entity in ipairs(tbl) do
        NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entity)
    end
end

local gravity_current_index
menu.list_select(world_tab, "World Gravity", { "worldgravity" },
    "Changes world's gravity. This option works best with other AndyScript users with the same mode. Can be really annoying/broken for other players (takes control of everything). Recommended to use only around friends to not ruin anyone elses fun. :)",
    {
        { "Default",    { "default" }, "" },
        { "Low",        { "low" },     "" },
        { "Very low",   { "verylow" }, "" },
        { "No gravity", { "none" },    "" },
    }, 1,
    function(option_index, menu_name, previous_option, click_type)
        gravity_current_index = option_index
        if click_type ~= CLICK_BULK then --[[this so that way the user does not get a notification when stand resets the option at script stop]]
            toast_formatted("Set the world's gravity to %s.", string.lower(menu_name))
        end
        if option_index ~= 1 then
            while gravity_current_index == option_index do
                request_control_of_table_once(entities.get_all_vehicles_as_handles())
                request_control_of_table_once(entities.get_all_objects_as_handles())
                request_control_of_table_once(entities.get_all_peds_as_handles())
                request_control_of_table_once(entities.get_all_pickups_as_handles())
                MISC.SET_GRAVITY_LEVEL(option_index - 1)
                util.yield()
            end
        else
            MISC.SET_GRAVITY_LEVEL(option_index - 1)
        end
    end)

menu.toggle_loop(world_tab, "Chaos", {},
    "Makes nearby cars go goblin-goblin mode. Can be really annoying/broken for other players (takes control of everything). Recommended to use only around friends to not ruin anyone elses fun. :)",
    function()
        for i, veh in ipairs(entities.get_all_vehicles_as_handles()) do
            NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(veh)
            ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(veh, 1, 0.0, 10.0, 0.0, true, true, true, true) --[[ alternatively, ]] --VEHICLE.SET_VEHICLE_FORWARD_SPEED(...) -- not tested
        end
    end
)

--spooner
local spooner_divider = 0
local spooner_all_entities = 0
local spooner_main_list = menu.list(world_tab, "Andy's Spooner", {}, "")
local spooned = {} -- {{list_handle, entity_handle}, {list_handle, entity_handle}, {list_handle, entity_handle}}

local function generate_entity_spooner_features(list, handle)
    local teleport = menu.action(list, "Teleport To Me", {}, "", function()
        request_control(handle)
        local coords = ENTITY.GET_ENTITY_COORDS(players.user_ped())
        ENTITY.SET_ENTITY_COORDS(handle, coords.x, coords.y, coords.z, 0, 0, 0, 0)
        ENTITY.SET_ENTITY_ROTATION(handle, 0, 0, 0, 1, true)
    end)
    menu.action(list, "Delete", {}, "", function()
        local function where_is()
            for i, tbl in ipairs(spooned) do
                if tbl[1] == list then
                    return i
                end
            end
        end
        request_control(handle)
        entities.delete_by_handle(handle)
        menu.delete(list)
        table.remove(spooned, where_is())
        announce("Entity removed.")
        if #spooned == 0 then
            menu.delete(spooner_divider)
            menu.delete(spooner_all_entities)
        end
    end)
end

local function add_spooner_list(list_handle, entity_handle)
    table.insert(spooned, { list_handle, entity_handle })
end

local function delete_every_entity_from_spooner()
    if #spooned > 0 then
        local entries = 0
        for number, tbl in ipairs(spooned) do
            for i, value in ipairs(tbl) do
                if i == 1 then
                    menu.delete(value)
                elseif i == 2 then
                    request_control(value)
                    entities.delete_by_handle(value)
                end
            end
            entries += 1
        end
        for i = 1, entries do
            table.remove(spooned) -- alternatively, spooned = {}
        end
        menu.delete(spooner_divider)
        menu.delete(spooner_all_entities)
        local message = entries > 1 and "Deleted " .. entries .. " entities." or "Deleted " .. entries .. " entity."
        util.toast(message)
    else
        util.toast("There are no entities to delete.")
    end
end

local function tp_every_entity_from_spooner()
    if #spooned > 0 then
        local entries = 0
        local coords = ENTITY.GET_ENTITY_COORDS(players.user_ped())
        for number, tbl in ipairs(spooned) do
            for i, value in ipairs(tbl) do
                if i == 2 then
                    ENTITY.SET_ENTITY_COORDS(value, coords.x, coords.y, coords.z, 0, 0, 0, 0)
                end
            end
            entries += 1
        end

        local message = entries > 1 and "Teleported " .. entries .. " entities." or "Teleported " .. entries ..
            " entity."
        util.toast(message)
    else
        util.toast("There are no entities to teleport.")
    end
end

local function entity_spooner(input)
    local coords = ENTITY.GET_ENTITY_COORDS(players.user_ped())
    local hash = util.joaat(input)
    local entity_handle = 0
    if request_model(hash) then
        if #spooned == 0 then
            spooner_all_entities = menu.list(spooner_main_list, "All Entities", {}, "Options for every entity spawned.",
                function() end)
            menu.action(spooner_all_entities, "TP All To Me", {},
                "Teleports every spawned entity from the list and in-game to you.",
                function() tp_every_entity_from_spooner() end)
            menu.action(spooner_all_entities, "Delete All", {},
                "Deletes every spawned entity from the list and in-game (if not manually deleted yet).",
                function() delete_every_entity_from_spooner() end)
            spooner_divider = menu.divider(spooner_main_list, "Spawned Entities")
        end
        if STREAMING.IS_MODEL_A_PED(hash) then
            entity_handle = entities.create_ped(4, hash, coords, 0)
        elseif STREAMING.IS_MODEL_A_VEHICLE(hash) then
            entity_handle = entities.create_vehicle(hash, coords, 0)
        else -- must be an object
            entity_handle = entities.create_object(hash, coords)
        end
        -- local is_user_in_list = false
        local list = menu.list(spooner_main_list, input, {}, ""
        -- , function()
        --     is_user_in_list = true
        --     local thing_coords = ENTITY.GET_ENTITY_COORDS(entity_handle)
        --     while is_user_in_list do
        --         GRAPHICS.DRAW_MARKER(1, thing_coords.x, thing_coords.y, thing_coords.z + 5, 0, 0, 0, 0, 0, 0, 1, 1, 1,
        --             255,
        --             255,
        --             255, true, true, 2, true, 0, 0, false)
        --         util.yield(0)
        --     end
        -- end, function()
        --     is_user_in_list = false
        -- end
        )
        add_spooner_list(list, entity_handle)
        generate_entity_spooner_features(list, entity_handle)
    else
        toast_formatted("Couldn't load given hash \"%s\". Are you sure you typed a valid entity?", input)
    end
end

local input_model_ref = menu.text_input(spooner_main_list, "Enter A Model Name", { "spawnentity" },
    "Given a model name, spawns the proper entity.",
    function(input, click_type)
        ---@diagnostic disable-next-line: undefined-field
        if string.strip(input, " ") == "" then
            if click_type ~= CLICK_BULK then
                util.toast(
                    "Input can't be empty.")
            end
        else
            entity_spooner(tostring(input))
        end
    end) ---@diagnostic disable-line

--consistent freeze clock
local function read_time(file_path)
    local filehandle = io.open(file_path, "r")
    if filehandle then
        local time = filehandle:read()
        filehandle:close()
        return tostring(time)
    else
        return false
    end
end

local function save_current_time(file_path, time)
    Filehandle = io.open(file_path, "w")
    Filehandle:write(time)
    Filehandle:flush()
    Filehandle:close()
end

local function get_clock()
    return tostring(CLOCK.GET_CLOCK_HOURS() .. ":" .. CLOCK.GET_CLOCK_MINUTES() .. ":" .. CLOCK.GET_CLOCK_SECONDS())
end

local time_path = filesystem.store_dir() .. format("%s\\time.txt", SCRIPT_NAME)
local is_freeze_clock_on = false
menu.toggle(world_tab, "Consistent Freeze Clock", {},
    "Freezes the clock using Stand's function, then saves the time for next execution. Change the current time using the \"time\" command, or in \"World > Atmosphere > Clock > Time\".",
    function(state)
        is_freeze_clock_on = state
        if state then
            if filesystem.exists(time_path) then
                local time = read_time(time_path)
                menu.trigger_command(menu.ref_by_path("World>Atmosphere>Clock>Time", 38), tostring(time))
            else
                save_current_time(time_path, get_clock())
            end
        else
            menu.trigger_command(menu.ref_by_path("World>Atmosphere>Clock>Lock Time", 38), "false")
        end
        while is_freeze_clock_on do
            menu.trigger_command(menu.ref_by_path("World>Atmosphere>Clock>Lock Time", 38), "true")
            save_current_time(time_path, get_clock())
            util.yield(1000)
        end
    end)
-- end of freeze clock

--clear world
menu.action(world_tab, "Clear World", { "clearworld" }, "Deletes every entity it can find from the face of the earth.",
    function()
        for i, entity in pairs(entities.get_all_vehicles_as_handles()) do
            request_control(entity)
            entities.delete_by_handle(entity)
        end

        for i, entity in pairs(entities.get_all_peds_as_handles()) do
            request_control(entity)
            entities.delete_by_handle(entity)
        end

        for i, entity in pairs(entities.get_all_objects_as_handles()) do
            request_control(entity)
            entities.delete_by_handle(entity)
        end

        announce("Cleared world.")
    end)

--Fun tab
--Ride cow
local function set_ped_apathy(ped, value)
    PED.SET_PED_CONFIG_FLAG(ped, 208, value)
    PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, value)
    ENTITY.SET_ENTITY_INVINCIBLE(ped, value)
end
menu.toggle(fun_tab, "Ride Cow", {},
    "Spawns a fucking cow for some reason, then rides it. Your ped becomes invisible (for other players) but the cow doesn't. Compatible with \"Vehicles > Auto Flip Vehicle\".",
    function(state)
        local player_heading = ENTITY.GET_ENTITY_HEADING(players.user_ped())
        local player_coords = ENTITY.GET_ENTITY_COORDS(players.user_ped())
        if state then
            request_model(util.joaat("TRACTOR")) -- util.joaat("TRACTOR") == 1641462412 (tractor hash)
            Vehicle_for_cow_rider = VEHICLE.CREATE_VEHICLE(util.joaat("TRACTOR"), player_coords.x, player_coords.y,
                player_coords.z, player_heading, true, true, false)
            request_model(util.joaat("A_C_Cow")) -- util.joaat("A_C_Cow") == 4244282910 (cow hash)
            ENTITY.SET_ENTITY_VISIBLE(Vehicle_for_cow_rider, false, 0)
            PED.SET_PED_INTO_VEHICLE(players.user_ped(), Vehicle_for_cow_rider, -1)
            Cow_for_cow_rider = PED.CREATE_PED(29, 4244282910, player_coords.x, player_coords.y, player_coords.z,
                player_heading, true, true)
            local bone = PED.GET_PED_BONE_INDEX(Cow_for_cow_rider, 0x796e)
            ENTITY.ATTACH_ENTITY_TO_ENTITY(Cow_for_cow_rider, Vehicle_for_cow_rider, bone, 0, -1, 0.5, 0, 0, 0, true,
                false, false, false, 1, false, false)
            ENTITY.SET_ENTITY_INVINCIBLE(Vehicle_for_cow_rider, true)
            set_ped_apathy(Cow_for_cow_rider, true)
            if not menu.get_value(menu.ref_by_path("Self>Glued To Seats")) then
                menu.trigger_command(menu.ref_by_path("Self>Glued To Seats", 38), "on")
                Altered_seatbelt_state = true
            end
        else
            if Altered_seatbelt_state then
                menu.trigger_command(menu.ref_by_path("Self>Glued To Seats", 38), "off")
            end
            entities.delete_by_handle(Vehicle_for_cow_rider)
            entities.delete_by_handle(Cow_for_cow_rider)
        end
    end
)

--Settings

--Shortcuts
local shortcuts = {}
-- {{new_button, shortcut_new, shortcut_title, shortcut_old}, {new_button, shortcut_new, shortcut_title, shortcut_old}}

local shortcut_menu = menu.list(settings_tab, "Andy's Shortcuts", {}, "")

local function write_to_shortcut_file(file_path)
    local filehandle = io.open(file_path, "w")
    if filehandle then
        for index, value in ipairs(shortcuts) do
            if value[1] ~= -1 then
                filehandle:write(value[2] .. "," .. value[3] .. "," .. value[4] .. "\n")
            end
        end
        filehandle:flush()
        io.close(filehandle)
    else
        util.toast("Error while writing to shortcut file.")
    end
end

local function create_shortcut_commands(shortcut_title, shortcut_new, shortcut_old)
    return menu.action(shortcut_menu, shortcut_title, { shortcut_new }, "",
        function()
            menu.trigger_commands(shortcut_old)
            announce('Shortcut "' .. shortcut_title .. '" activated.')
        end)
end

local function create_shortcut(shortcut_title, shortcut_new, shortcut_old)
    local new_button = create_shortcut_commands(shortcut_title, shortcut_new, shortcut_old)
    table.insert(shortcuts, { new_button, shortcut_new, shortcut_title, shortcut_old })
    write_to_shortcut_file(shortcut_path)
end

local function delete_shortcut(shortcut, is_editing)
    local function where_is_shortcut_to_delete(input)
        local c = 1
        for k, v in shortcuts do
            if v[2] == input then
                return c
            end
            c += 1
        end
        return false
    end
    local table_which_includes_shortcut = where_is_shortcut_to_delete(shortcut)
    if shortcuts[1] then
        if table_which_includes_shortcut then
            if shortcuts[table_which_includes_shortcut][2] == shortcut then
                menu.delete(shortcuts[table_which_includes_shortcut][1])
                shortcuts[table_which_includes_shortcut][1] = 0
                table.remove(shortcuts, table_which_includes_shortcut)
                write_to_shortcut_file(shortcut_path)
                if not is_editing then
                    util.toast('Shortcut "' .. shortcut .. '" removed.')
                end
            else
                util.toast("Shortcut not found.")
            end
        else
            util.toast("Shortcut doesn't exist.")
        end
    else
        util.toast("There are no shortcuts. Try creating one before deleting!")
    end
    write_to_shortcut_file(shortcut_path)
end

local function import_shortcuts_from_file(shortcut_new, shortcut_name, shortcut_old)
    table.insert(shortcuts, { 0, shortcut_new, shortcut_name, shortcut_old })
end

local function read_shortcut_file(file_path)
    local filehandle = io.open(shortcut_path, "r") -- Open file in read-only mode
    if filehandle then
        local what_line_am_i_reading = 0
        local imported_shortcut_count = 0
        for line in filehandle:lines() do
            what_line_am_i_reading += 1
            local data = string.split(line, ",") ---@diagnostic disable-line
            if data[2] ~= "" and data[3] ~= "" then
                import_shortcuts_from_file(data[1], data[2], data[3])
                imported_shortcut_count += 1
            else
                util.toast("Error reading from shortcuts file at line " .. what_line_am_i_reading .. ".")
            end
        end
        local message_for_importing
        if imported_shortcut_count >= 2 or imported_shortcut_count == 0 then
            message_for_importing = "Imported " .. imported_shortcut_count .. " previous shortcuts."
        else
            message_for_importing = "Imported " .. imported_shortcut_count .. " previous shortcut."
        end
        util.toast(message_for_importing)
        io.close(filehandle)
    else
        util.toast("Failed to open file.")
    end
end


local function convert_shortcuts(shortcut)
    if not string.find(shortcut, ",") then
        return shortcut
    else
        local new_shortcut = ""
        local new_shortcut_table = string.split(shortcut, ",") ---@diagnostic disable-line
        for i, value in new_shortcut_table do
            new_shortcut = new_shortcut .. value .. ";"
        end
        new_shortcut = string.rstrip(new_shortcut, ";") ---@diagnostic disable-line
        return new_shortcut
    end
end

local function does_shortcut_command_exist(shortcut)
    if not string.find(shortcut, ";") then
        if not pcall(menu.ref_by_command_name, tostring(string.split(shortcut, " ")[1])) then ---@diagnostic disable-line
            return false
        else
            return true
        end
    else -- if it's multiple commands
        local temp_shortcuts_table = string.split(shortcut, ";") ---@diagnostic disable-line
        for i, command in temp_shortcuts_table do
            if not pcall(menu.ref_by_command_name, tostring(string.split(command, " ")[1])) then ---@diagnostic disable-line
                return false
            else
                return true
            end
        end
    end
end

local function generate_editor_features(editor_menu)
    local c = 1
    for i, shortcut in shortcuts do
        local list = menu.list(editor_menu, shortcut[3], {}, "")
        menu.action(list, "Delete Shortcut", {}, "Deletes the selected shortcut.",
            function()
                delete_shortcut(shortcut[2])
                list:delete()
            end)
        menu.divider(list, "Alternatively, fill these in:")
        local new_name = menu.text_input(list, "New Shortcut Name", { "newshortcutname" .. c },
            "This will be the new shortcut name used to identify it.", function() end, shortcut[3])
        local new_shortcut = menu.text_input(list, "New Shortcut", { "newshortcut" .. c },
            "This will be the new command used to activate the shortcut.", function() end, shortcut[2])
        local new_command = menu.text_input(list, "New Shortcut Command", { "newshortcutcommand" .. c },
            "This will be the new command that the shortcut runs.", function() end, shortcut[4])
        menu.divider(list, "Once you're done, press this:")
        menu.action(list, "Edit Shortcut", {}, "Uses the given values to edit the selected shortcut and updates it.",
            function()
                delete_shortcut(shortcut[2], true)
                create_shortcut(menu.get_value(new_name), menu.get_value(new_shortcut), menu.get_value(new_command))
                menu.set_menu_name(list, tostring(menu.get_value(new_name)))
                util.toast("Edited shortcut.")
            end)
        c += 1
    end
end

local function is_shortcut_name_taken(name)
    for i, shortcut in shortcuts do
        if string.lower(shortcut[3]) == string.lower(name) then
            return true
        end
    end
    return false
end

local function is_shortcut_taken(command)
    for i, shortcut in shortcuts do
        if string.lower(shortcut[2]) == string.lower(command) then
            return true
        end
    end
    return false
end

local have_shortcuts_been_enabled = false
local have_shortcuts_been_generated_for_editor = false
-- defining main lists
local add_a_shortcut
local edit_a_shortcut
--toggle on or off
menu.toggle(shortcut_menu, "Enable", { "andyshortcuts" },
    "Enable \"Andy's Shortcuts\", which are command box shortcuts such as using \"dv\" instead of \"deletevehicle\".",
    function(state)
        Shortcut_status = state
        if not have_shortcuts_been_enabled then
            read_shortcut_file(shortcut_path)
            have_shortcuts_been_enabled = true
        end
        --To hide the buttons before you enable it
        if Shortcut_status then
            add_a_shortcut = menu.list(shortcut_menu, "Add A Shortcut", {}, "Allows you to add custom shortcuts.")
            edit_a_shortcut = menu.list(shortcut_menu, "Edit/Remove Shortcuts", {},
                "Allows you to edit previously created shortcuts.",
                function()
                    if not have_shortcuts_been_generated_for_editor then generate_editor_features(edit_a_shortcut) end
                    have_shortcuts_been_generated_for_editor = true
                end)
            --maker
            local normal_create = menu.list(add_a_shortcut, "Normal Mode", {},
                "Uses the normal mode to create a shortcut. Recommended for beginners.")
            local advanced_create = menu.list(add_a_shortcut, "Advanced Mode (Faster)", {},
                "Create the shortcut using a single command. Not recommended if you're not too sure of what you're doing.")
            menu.text_input(advanced_create, "Create Shortcut", { "shortcutadvancedmode" },
                "Create a command using the advanced mode. Use \",\" to separate the \"input\" commands (if more than one) that the shortcut will trigger, and use \"&\" to separate the parameters. The parameters are Title, Shortcut and Command(s).",
                function(str)
                    local parameters = string.split(str, "&") ---@diagnostic disable-line
                    if #parameters ~= 3 then
                        util.toast("The command needs exactly 3 parameters. Please try again.")
                    else
                        local title = parameters[1]
                        local shortcut = parameters[2]
                        local command = parameters[3]
                        local command_new = convert_shortcuts(command)
                        if not does_shortcut_command_exist(command_new) then
                            if not string.find(command_new, ";") then -- just a single command
                                util.toast("Error creating shortcut. Does the given command exist?")
                            else                                      -- multiple commands
                                util.toast("Error creating shortcut. Do the given commands exist?")
                            end
                        elseif parameters[1] == "" then
                            util.toast("Error creating shortcut. Does it have a name?")
                        elseif is_shortcut_name_taken(title) then
                            util.toast("Shortcut name is taken. Try again!")
                        elseif is_shortcut_taken(command_new) then
                            util.toast("Shortcut is taken. Try again!")
                        else
                            create_shortcut(title, shortcut, command_new)
                            util.toast('New shortcut "' .. parameters[1] .. '" created!')
                            edit_a_shortcut:delete()
                            have_shortcuts_been_generated_for_editor = false
                            --[[everything editor-related]]
                            edit_a_shortcut = menu.attach_after(add_a_shortcut,
                                menu.list(
                                    menu.shadow_root() --[[shadow root  is used to create a "detached command" which can then be used in attach_after. more in stand lua api]],
                                    "Edit/Remove Shortcuts", {}, "Allows you to edit previously created shortcuts.",
                                    function()
                                        if not have_shortcuts_been_generated_for_editor then
                                            generate_editor_features(edit_a_shortcut)
                                            have_shortcuts_been_generated_for_editor = true
                                        end
                                    end))
                        end
                    end
                end)
            --[[Maker title]]
            menu.divider(normal_create, "Fill these in:")
            local new_shortcut_title = menu.text_input(normal_create, "Title", { "customshortcuttitle" },
                "Title to identify custom shortcut.", function() end)
            local new_shortcut_shortcut = menu.text_input(normal_create, "Shortcut", { "customshortcut" },
                "Command that, when typed into the command box, will trigger the original command(s) you want to shorten.",
                function() end)
            local new_shortcut_command_temp = menu.text_input(normal_create, "Command", { "customshortcutcommand" },
                "Original command(s) that you want to shorten. Use \",\" to separate multiple commands.", function() end)
            --[[Maker button title]]
            menu.divider(normal_create, "Once you're done, press this:")
            --[[Maker button]]
            menu.action(normal_create, "Create", {}, "Creates the custom shortcut with the given specifications.",
                function()
                    New_shortcut_temp = menu.get_value(new_shortcut_command_temp)
                    Command_new = convert_shortcuts(New_shortcut_temp)
                    if not does_shortcut_command_exist(Command_new) then
                        if not string.find(Command_new, ";") then -- just a single command
                            util.toast("Error creating shortcut. Does the given command exist?")
                        else                                      -- multiple commands
                            util.toast("Error creating shortcut. Do the given commands exist?")
                        end
                    elseif menu.get_value(new_shortcut_title) == "" then
                        util.toast("Error creating shortcut. Does it have a name?")
                    elseif is_shortcut_name_taken(menu.get_value(new_shortcut_title)) then
                        util.toast("Shortcut name is taken. Try again!")
                    elseif is_shortcut_taken(menu.get_value(new_shortcut_shortcut)) then
                        util.toast("Shortcut is taken. Try again!")
                    else
                        create_shortcut(menu.get_value(new_shortcut_title), menu.get_value(new_shortcut_shortcut),
                            Command_new)
                        util.toast('New shortcut "' .. menu.get_value(new_shortcut_title) .. '" created!')
                        edit_a_shortcut:delete()
                        have_shortcuts_been_generated_for_editor = false
                        --[[everything editor-related]]
                        edit_a_shortcut = menu.attach_after(add_a_shortcut,
                            menu.list(
                                menu.shadow_root() --[[shadow root is used to create a "detached command" which can then be used in attach_after. more in stand lua api]],
                                "Edit/Remove Shortcuts", {}, "Allows you to edit previously created shortcuts.",
                                function()
                                    if not have_shortcuts_been_generated_for_editor then
                                        generate_editor_features(edit_a_shortcut)
                                        have_shortcuts_been_generated_for_editor = true
                                    end
                                end))
                    end
                end)
        else --clear everything, then restart when toggle is enabled (when deleting a list, everything inside of it goes too)
            menu.delete(add_a_shortcut)
            add_a_shortcut = 0
            menu.delete(edit_a_shortcut)
            edit_a_shortcut = 0
            have_shortcuts_been_generated_for_editor = false -- reset editor for next run
        end
        -- Showing shortcuts at trigger
        if Shortcut_status then --showing shortcut
            Shortcut_title = menu.divider(shortcut_menu, "Available Shortcuts")
        else                    --deleting
            menu.delete(Shortcut_title)
            Shortcut_title = 0
        end
        for k, v in ipairs(shortcuts) do                          -- creating existing shortcuts in the table "shortcuts"
            if Shortcut_status then
                v[1] = create_shortcut_commands(v[3], v[2], v[4]) --Restore shortcuts
            else
                menu.delete(v[1])
                v[1] = 0
            end
        end
    end, false
)

--Announce actions
menu.toggle(settings_tab, "Announce Actions", {},
    'Announces every action done by the script, i.e. "Health maxed". This could also be called "Debug mode" (?',
    function(state, click_type)
        if click_type ~= CLICK_BULK then
            settings.announce_actions = state
            save_settings_to_file()
        end
    end, settings.announce_actions)

-- Hide name on script startup
menu.toggle(settings_tab, "Hide Username On Startup", {}, "Hides your username that would show in the welcome phrase.",
    function(state, click_type)
        if click_type ~= CLICK_BULK then
            settings.hide_name_on_script_startup = state
            save_settings_to_file()
        end
    end, settings.hide_name_on_script_startup)

-- About tab
local function make_auto_updating_read_only_command(root_id, menu_title, value_func)
    local command = menu.readonly(root_id, menu_title, value_func())
    local handler = menu.on_tick_in_viewport(command, function()
        menu.set_value(command, value_func())
    end)
    return command, handler
end
make_auto_updating_read_only_command(info_tab, "Playtime", function() return format_time(script_playtime, true) end)
local credits_under_info_tab = menu.list(info_tab, "Credits", {}, "")
menu.readonly(info_tab, "Made by Andy <3", "@lancito01")
menu.readonly(info_tab, "Version", script_version)
menu.hyperlink(info_tab, "AndyScript Discord", "https://discord.gg/9vzATnaM9c",
    "The one and only official AndyScript Discord server, where you can find the script's changelog, support and a suggestions channel (they are greatly appreciated), and a good community to chat with. :D")
menu.hyperlink(info_tab, "GitHub", "https://github.com/Lancito01/AndyScript")
menu.readonly(credits_under_info_tab, "Ren", "For helping me with majority of the code and with stupid questions. <3")
menu.readonly(credits_under_info_tab, "gabito", "Chupada y polvo 350$, pero sin cola.")
credits_under_info_tab:readonly("hexarobi",
    "Created the original Lua script auto-updater that was the modified and added to AndyScript.")
credits_under_info_tab:readonly("Stand", "For being the best mod menu in the whole world. <3")
credits_under_info_tab:readonly("Stand Community", "Inspired me to make this script.")

--Player root
--Check for modder
local function is_player_modder(pid)
    local suffix = players.is_marked_as_modder(pid) and " has set off modder detections." or
        " hasn't set off modder detections."
    chat.send_message(players.get_name(pid) .. suffix,
        true, -- is team chat
        true, -- is in local history
        false -- is networked
    )
end

--Spawn ped in car
local function spawn_ped_in_vehicle(car, playerped, isclone)
    if car == 0 then
        util.toast("Player is not in a car.")
    elseif VEHICLE.ARE_ANY_VEHICLE_SEATS_FREE(car) then
        if isclone then
            local ped_created = PED.CLONE_PED(playerped, true, false, true)
            local seat = VEHICLE.IS_VEHICLE_SEAT_FREE(car, -1, false) and -1 or -2
            PED.SET_PED_INTO_VEHICLE(ped_created, car, seat)
            announce("Ped cloned.")
        else
            local coords = ENTITY.GET_ENTITY_COORDS(car, false)
            local random_ped = some_ped_list[math.random(#some_ped_list)]
            local random_ped_hash = util.joaat(random_ped)
            request_model(random_ped_hash) -- Ped is now loaded in memory, so i don't care about what it returns. Point of this is to load ped before i spawn it (otherwise ped won't spawn)
            local ped_created = entities.create_ped(4, random_ped_hash, coords, 0)
            local seat = VEHICLE.IS_VEHICLE_SEAT_FREE(car, -1, false) and -1 or -2
            PED.SET_PED_INTO_VEHICLE(ped_created, car, seat)
            announce("Ped spawned.")
        end
    else
        util.toast("There are no free seats in their vehicle.")
    end
end

local function fill_vehicle_with_peds(vehicle, playerped, isclone)
    if vehicle == 0 then
        util.toast("Player is not in a car.")
    elseif VEHICLE.ARE_ANY_VEHICLE_SEATS_FREE(vehicle) then
        while VEHICLE.ARE_ANY_VEHICLE_SEATS_FREE(vehicle) do
            spawn_ped_in_vehicle(vehicle, playerped, isclone)
        end
        announce("Car filled.")
    else
        util.toast("There are no free seats in their vehicle.")
    end
end

local function is_player_andy(pid)
    if players.get_rockstar_id(pid) == 35827130 then
        util.toast("'" .. players.get_name(pid) .. "'" .. " (AndyScript dev) is joining. Say hi!")
    end
end

local function repair_player_vehicle(pid)
    local player_ped = PLAYER.GET_PLAYER_PED(pid)
    local player_vehicle = get_vehicle_ped_is_in(player_ped, Include_last_vehicle_for_player_functions)
    if player_vehicle == 0 then
        util.toast(players.get_name(pid) .. " is not in any vehicle.")
    else
        if request_control(player_vehicle) then
            VEHICLE.SET_VEHICLE_FIXED(player_vehicle)
            announce(players.get_name(pid) .. "'s vehicle fixed!")
        else
            util.toast("Couldn't get control of their vehicle.")
        end
    end
end

local function toggle_player_vehicle_engine(pid)
    local player_ped = PLAYER.GET_PLAYER_PED(pid)
    local player_vehicle = get_vehicle_ped_is_in(player_ped, Include_last_vehicle_for_player_functions)
    if player_vehicle == 0 then
        util.toast(players.get_name(pid) .. " is not in any vehicle.")
    else
        local is_running = VEHICLE.GET_IS_VEHICLE_ENGINE_RUNNING(player_vehicle)
        if request_control(player_vehicle) then
            VEHICLE.SET_VEHICLE_ENGINE_ON(player_vehicle, not is_running, true, true)
            announce(players.get_name(pid) .. "'s engine toggled!")
        else
            util.toast("Couldn't get control of their vehicle.")
        end
    end
end

local function break_player_vehicle_engine(pid)
    local player_ped = PLAYER.GET_PLAYER_PED(pid)
    local player_vehicle = get_vehicle_ped_is_in(player_ped, Include_last_vehicle_for_player_functions)
    if player_vehicle == 0 then
        util.toast(players.get_name(pid) .. " is not in any vehicle.")
    else
        if request_control(player_vehicle) then
            VEHICLE.SET_VEHICLE_ENGINE_HEALTH(player_vehicle, -10.0)
            announce(players.get_name(pid) .. "'s engine broken!")
        else
            util.toast("Couldn't get control of their vehicle.")
        end
    end
end

local function launch_up_player_vehicle(pid)
    local player_ped = PLAYER.GET_PLAYER_PED(pid)
    local player_vehicle = get_vehicle_ped_is_in(player_ped, Include_last_vehicle_for_player_functions)
    if player_vehicle == 0 then
        util.toast(players.get_name(pid) .. " is not in any vehicle.")
    else
        if request_control(player_vehicle) then
            ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(player_vehicle, 1, 0.0, 0.0, 1000.0, true, true, true, true)
            announce(players.get_name(pid) .. "'s launched.")
        else
            util.toast("Couldn't get control of their vehicle.")
        end
    end
end

local function boost_player_vehicle_forward(pid)
    local player_ped = PLAYER.GET_PLAYER_PED(pid)
    local player_vehicle = get_vehicle_ped_is_in(player_ped, Include_last_vehicle_for_player_functions)
    if player_vehicle == 0 then
        util.toast(players.get_name(pid) .. " is not in any vehicle.")
    else
        request_control(player_vehicle)
        ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(player_vehicle, 1, 0.0, 1000.0, 0.0, true, true, true, true)
        announce(players.get_name(pid) .. "'s vehicle boosted.")
    end
end

local function stop_player_vehicle(pid)
    local player_ped = PLAYER.GET_PLAYER_PED(pid)
    local player_vehicle = get_vehicle_ped_is_in(player_ped, Include_last_vehicle_for_player_functions)
    if player_vehicle == 0 then
        util.toast(players.get_name(pid) .. " is not in any vehicle.")
    else
        request_control(player_vehicle)
        VEHICLE.BRING_VEHICLE_TO_HALT(player_vehicle, 0.0, 1, false)
        announce(players.get_name(pid) .. "'s vehicle stopped.")
    end
end

local function flip_player_vehicle(pid)
    local player_ped = PLAYER.GET_PLAYER_PED(pid)
    local player_vehicle = get_vehicle_ped_is_in(player_ped, Include_last_vehicle_for_player_functions)
    if player_vehicle == 0 then
        util.toast(players.get_name(pid) .. " is not in any vehicle.")
    else
        request_control(player_vehicle)
        local heading = ENTITY.GET_ENTITY_HEADING(player_vehicle)
        ENTITY.SET_ENTITY_ROTATION(player_vehicle, 0, 180, -heading, 1, true)
        announce(players.get_name(pid) .. "'s vehicle flipped.")
    end
end

local function turn_player_vehicle(pid)
    local player_ped = PLAYER.GET_PLAYER_PED(pid)
    local player_vehicle = get_vehicle_ped_is_in(player_ped, Include_last_vehicle_for_player_functions)
    if player_vehicle == 0 then
        util.toast(players.get_name(pid) .. " is not in any vehicle.")
    else
        request_control(player_vehicle)
        local heading = ENTITY.GET_ENTITY_HEADING(player_vehicle)
        local alter_heading = heading >= 180 and heading - 180 or heading + 180
        ENTITY.SET_ENTITY_ROTATION(player_vehicle, 0, 0, alter_heading, 2, true)
        announce(players.get_name(pid) .. "'s vehicle turned.")
    end
end

local function generate_features(pid)
    menu.divider(menu.player_root(pid), "AndyScript-dev")

    local weapons_player_root = menu.list(menu.player_root(pid), "Weapons", {}, "")
    local vehicles_player_root = menu.list(menu.player_root(pid), "Vehicles", {}, "")
    local online_player_root = menu.list(menu.player_root(pid), "Online", {}, "")
    --Explosive bullets
    local current_exp_chosen
    local coords_exp = v3.new()
    menu.list_select(weapons_player_root, "Give Explosive Ammo", {}, "", explosion_names, 0,
        function(index, menu_name, click_type)
            current_exp_chosen = index - 1
            local explosion_id =
                current_exp_chosen -- this SHOULD have a -1 because lua starts indexes at 1, not 0 BUT! if you look at the table definition, ma boy the sus man told me how to make it 0 based to my brain can rest easy
            if current_exp_chosen ~= -1 then
                while current_exp_chosen + 1 == index and players.exists(pid) do
                    current_exp_chosen = index - 1
                    if WEAPON.GET_PED_LAST_WEAPON_IMPACT_COORD(PLAYER.GET_PLAYER_PED(pid), coords_exp) then
                        local x, y, z = v3.get(coords_exp)
                        FIRE.ADD_OWNED_EXPLOSION(PLAYER.GET_PLAYER_PED(pid), x, y, z, explosion_id, 1.0, true, false, 0)
                    end
                    util.yield()
                end
            else
                announce("Explosive Ammo for " .. players.get_name(pid) .. " off.")
            end
        end)
    menu.toggle(vehicles_player_root, "Include Player's Last Vehicle", {},
        "Option to use last vehicle in case the player is not in a vehicle when running a function.",
        function(state) Include_last_vehicle_for_player_functions = state end)
    menu.divider(vehicles_player_root, "Options")
    menu.list_action(vehicles_player_root, "Clone Ped Inside Their Car", {},
        "Clones the player's ped and places it in the first free seat it finds.", {
            { 1, "Once" },
            { 2, "Fill vehicle" }
        },
        function(index)
            local player_ped = PLAYER.GET_PLAYER_PED(pid)
            local car = get_vehicle_ped_is_in(player_ped, Include_last_vehicle_for_player_functions) -- alternatively: local car = use_last_vehicle_toggle and PED.GET_VEHICLE_PED_IS_IN(ped) or get_vehicle_ped_is_in(pid, false)
            if index == 1 then
                spawn_ped_in_vehicle(car, player_ped, true)
            elseif index == 2 then
                fill_vehicle_with_peds(car, player_ped, true)
            end
        end)
    menu.list_action(vehicles_player_root, "Spawn Random Ped Inside Their Car", {},
        "Spawns a random ped from our (not very) extensive list and places it on the first available seat it finds.",
        { "Once", "Fill vehicle" },
        function(index)
            local player_ped = PLAYER.GET_PLAYER_PED(pid)
            local car = get_vehicle_ped_is_in(player_ped, Include_last_vehicle_for_player_functions) -- alternatively: local car = use_last_vehicle_toggle and PED.GET_VEHICLE_PED_IS_IN(ped) or get_vehicle_ped_is_in(pid, false)
            if index == 1 then
                spawn_ped_in_vehicle(car, player_ped, false)
            elseif index == 2 then
                fill_vehicle_with_peds(car, player_ped, false)
            end
        end)
    do
        local strength, current_option
        menu.list_select(vehicles_player_root, "Remote Horn Boost", {},
            "Boosts their vehicle forward when they honk the horn. Can be combined with \"Remote Car Jump\".",
            { { "Off",         {}, "Default." }, { "Low Boost", {}, "Too slow." },
                { "Neutral Boost", {}, "Recommended." },
                { "High Boost",    {}, "Quite fast, maybe not enough." },
                { "Extreme Boost", {}, "This one is not lineal, it's 50x the Neutral option." } }, 1, function(index)
                local player_ped = PLAYER.GET_PLAYER_PED(pid)
                local player_vehicle = get_vehicle_ped_is_in(player_ped, false)
                strength = index == 5 and 50 or index / 3
                current_option = index
                if current_option ~= 1 then
                    while index == current_option do
                        if AUDIO.IS_HORN_ACTIVE(player_vehicle) then
                            NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(player_vehicle)
                            ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(player_vehicle, 1, 0.0, strength, 0.0, true, true,
                                true, true) -- alternatively, VEHICLE.SET_VEHICLE_FORWARD_SPEED(...) -- not tested
                        end
                        util.yield()
                    end
                end
            end)
    end
    do
        local strength, current_option
        menu.list_select(vehicles_player_root, "Remote Car Jump", {},
            "Makes their vehicle jump when they honk the horn. Can be combined with \"Remote Horn Boost\".",
            { { "Off",         {}, "Default." }, { "Low Boost", {}, "Too low." },
                { "Neutral Boost", {}, "Recommended." },
                { "High Boost",    {}, "Quite high, maybe not enough." },
                { "Extreme Boost", {}, "This one is not lineal, it's 50x the Neutral option." } }, 1, function(index)
                local player_ped = PLAYER.GET_PLAYER_PED(pid)
                local player_vehicle = get_vehicle_ped_is_in(player_ped, false)
                strength = index == 5 and 50 or index / 3
                current_option = index
                if current_option ~= 1 then
                    while index == current_option do
                        if AUDIO.IS_HORN_ACTIVE(player_vehicle) then
                            NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(player_vehicle)
                            ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(player_vehicle, 1, 0.0, 0.0, strength, true, true,
                                true, true)
                        end
                        util.yield()
                    end
                end
            end)
    end
    menu.action(vehicles_player_root, "Repair", {}, "Repairs their vehicle to full health.",
        function() repair_player_vehicle(pid) end)
    menu.action(vehicles_player_root, "Toggle Engine", {}, "If their engine is on, it toggles it off and viceversa.",
        function() toggle_player_vehicle_engine(pid) end)
    menu.action(vehicles_player_root, "Break Engine", {}, "Makes their engine catch on fire.",
        function() break_player_vehicle_engine(pid) end)
    menu.action(vehicles_player_root, "Boost Forward", {}, "Boosts their vehicle forward with great force.",
        function() boost_player_vehicle_forward(pid) end)
    menu.action(vehicles_player_root, "Launch Up", {},
        "Launches their vehicle into the stratosphere. Okay, maybe not that high but still pretty funny.",
        function() launch_up_player_vehicle(pid) end)
    menu.action(vehicles_player_root, "Stop Vehicle", {},
        "Stops their vehicle in the exact spot they're at. Doesn't freeze it, just stops it.",
        function() stop_player_vehicle(pid) end)
    menu.action(vehicles_player_root, "Flip Vehicle Upside Down", {}, "Flips their car in its Y axis.",
        function() flip_player_vehicle(pid) end)
    menu.action(vehicles_player_root, "Turn Vehicle 180 Degrees", {}, "Flips their car in its Z axis.",
        function() turn_player_vehicle(pid) end)
    menu.action(online_player_root, "Check If Player Is Modder", { "isplayermodder" },
        "Checks if the selected player is a modder, then displays the result in local chat. Other players can't see this message.",
        function() is_player_modder(pid) end)
end

local function on_player_join(pid)
    generate_features(pid)
    is_player_andy(pid)
end

players.on_join(on_player_join)
players.dispatch_on_join()

util.create_tick_handler(function()
    if was_in_transition and not util.is_session_transition_active() then
        on_transition_exit()
    end
    was_in_transition = util.is_session_transition_active()
end)

--On script end
util.on_stop(function()
    write_to_shortcut_file(shortcut_path)
    save_settings_to_file()
    save_playtime_to_file(script_playtime)
    if #spooned > 0 then
        delete_every_entity_from_spooner()
    end
    util.toast("See you later!")
end)
