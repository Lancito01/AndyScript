local script_version = "v0.0.18"

-- Auto-Updater by Hexarobi, modified by Ren, tysm to the both of u <3
local wait_for_restart = false
local please_wait_while_updating_menu = menu.divider(menu.my_root(), "Please wait...")

local function convert_backslashes_to_forwardslashes(str)
    return str:gsub("\\", "/")
end

local function parse_url_host_and_path(url)
    return url:match("://(.-)/"), "/"..url:match("://.-/(.*)")
end

local toast = util.toast
local format = string.format

local SCRIPTS_DIR       = convert_backslashes_to_forwardslashes(filesystem.scripts_dir())
local SCRIPT_RELPATH    = convert_backslashes_to_forwardslashes(SCRIPT_RELPATH)
local STORE_DIR         = convert_backslashes_to_forwardslashes(filesystem.store_dir())
local SCRIPT_PATH       = SCRIPTS_DIR .. SCRIPT_RELPATH
local VERSION_DIR       = STORE_DIR .. SCRIPT_NAME .. "/"
local VERSION_PATH      = VERSION_DIR .. "version.txt"

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
        toast("Error updating "..SCRIPT_PATH..". Could not open file for writing.")
        return false
    end
    file:write(result.."\n")
    file:close()
    return true
end

local function update_script(url)

    local url_host, url_path = parse_url_host_and_path(url)

    local function http_success(result, headers, status_code)
        WAITING_FOR_HTTP_RESULT = false
        if status_code == 304 then
            -- No update found
            toast_formatted("%s is up to date! (%s)", SCRIPT_NAME, script_version)
            return
        end

        if not result or result == "" then
            toast_formatted("Error updating %s. Found empty script file.", SCRIPT_NAME)
            return
        end

        replace_current_script(result)

        if headers then
            for header_key, header_value in pairs(headers) do
                if header_key == "ETag" then
                    write_version_id(VERSION_PATH, header_value)
                end
            end
        end

        toast_formatted("Updated %s. Restarting...", SCRIPT_NAME)
        wait_for_restart = true
        util.yield(2900)    -- Avoid restart loops by giving time for any other scripts to also complete updates
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
    http_add_cache_header_if_cached()
    async_http.dispatch()
end

update_script("https://raw.githubusercontent.com/Lancito01/AndyScript/main/AndyScript.lua")
while WAITING_FOR_HTTP_RESULT or wait_for_restart do
    util.yield()
end
menu.delete(please_wait_while_updating_menu)

-- End of auto-updater

util.require_natives(1663599433)
util.keep_running()

local store = filesystem.store_dir()
local AndyScript_store = store .. "/AndyScript"
local shortcut_path = AndyScript_store .. "/shortcuts.txt"

local notif_prefix = "[AndyScript] "
local og_toast = util.toast
local og_log = util.log
util.toast = function(str, flag)
    assert(str ~= nil, "No string given")
    if flag ~= nil then
        og_toast(notif_prefix .. tostring(str), flag)
    else
        og_toast(notif_prefix .. tostring(str))
    end
end
util.log = function(str) 
    assert(str ~= nil, "No string given.")
    og_log(notif_prefix .. tostring(str))
end

--On Script Start
local user_name = players.get_name(players.user())
local possible_welcome_phrases = { -- 12 normal, 1 rare
    "Glad you're here, " .. user_name .. ".",
    "Welcome, " .. user_name ..". We hope you brought pizza.",
    user_name .. " just slid into the script.",
    "Welcome, " .. user_name .. ". Hi!",
    user_name .. " joined the party.",
    "Glad you're here, " .. user_name .. ".",
    "Yay you made it, " .. user_name .. "!",
    user_name .. " just landed.",
    "Good to see you, " .. user_name .. ".",
    user_name .. " just showed up!",
    user_name .. " is here.",
    user_name .. " hopped into the script.",
    "You found the rare welcome phrase! Feel free to flex it in AndyScript Discord. :D"
}

local chosen_welcome_phrase_index = math.random(1,100) == 1 and #possible_welcome_phrases or math.random(#possible_welcome_phrases - 1)

util.toast("Loaded AndyScript " .. script_version .. "\n\n" .. possible_welcome_phrases[chosen_welcome_phrase_index])

--Functions
local function announce(string)
    if announce_actions then
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
    "a_m_m_bevhills_02",    --1
    "a_m_m_business_01",    --2
    "a_m_m_bevhills_01",    --3
    "a_m_m_farmer_01",      --4
    "a_m_m_paparazzi_01",   --5
    "a_m_m_prolhost_01",    --6
    "a_m_m_stlat_02"        --7
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
        menu.trigger_command(menu.ref_by_path("Self>Weapons>Get Weapons>All Weapons", 38))
        announce("All weapons  given.")
    end
end

--Main Menu
menu.divider(menu.my_root(), "Main")
local self_tab = menu.list(menu.my_root(), "Self")
local online_tab = menu.list(menu.my_root(), "Online")
menu.action(menu.my_root(), "Players shortcut", {}, 'Takes you to "Players" list.', function() menu.trigger_command(menu.ref_by_path('Players')) end)
local vehicles_tab = menu.list(menu.my_root(), "Vehicles")
local world_tab = menu.list(menu.my_root(), "World")
local fun_tab = menu.list(menu.my_root(), "Fun", {}, "Most of these are suggestions on my Discord. You should join! Link is in \"About\" tab.")
local settings_tab = menu.list(menu.my_root(), "Settings")
menu.divider(menu.my_root(), "Information")
local info_tab = menu.list(menu.my_root(), "About")

--Self tab
--Godmode
menu.toggle(self_tab, "Godmode", {"andygodmode"}, "Toggles several Stand features such as Godmode, Gracefulness, and Vehicle Godmode all at the same time to make you invincible against mortals.", 
function(state)
    local switch_for_godmode = state and "On" or "Off"
    menu.trigger_command(menu.ref_by_path("Self>Immortality", 38), switch_for_godmode)
    menu.trigger_command(menu.ref_by_path("Self>Gracefulness", 38), switch_for_godmode)
    menu.trigger_command(menu.ref_by_path("Self>Auto Heal", 38), switch_for_godmode)
    menu.trigger_command(menu.ref_by_path("Vehicle>Indestructible", 38), switch_for_godmode)
    menu.trigger_command(menu.ref_by_path("Self>Glued To Seats", 38), switch_for_godmode)
    menu.trigger_command(menu.ref_by_path("Stand>Lua Scripts>AndyScript>Self>Clean Loop",38), switch_for_godmode)
    announce("Godmode " .. switch_for_godmode)
end
)

--Ghost
menu.toggle(self_tab, "Ghost", {"andyghostmode"}, "Toggles several Stand features such as Invisibility and Off The Radar all at the same time to make you fully invisible.",
function(state)
    menu.trigger_command(menu.ref_by_path("Self>Appearance>Invisibility>" .. (state and "Enabled" or "Disabled"), 38))
    menu.set_value(menu.ref_by_path("Online>Off The Radar", 38), state)
    announce("Ghostmode " .. (state and "On" or "Off"))
end
)

--Heal
menu.action(self_tab, "Max Health", {"healself"}, "Heals your ped to its max health.",
function()
    local max_health = ENTITY.GET_ENTITY_MAX_HEALTH(players.user_ped())
    ENTITY.SET_ENTITY_HEALTH(players.user_ped(), max_health, 0)
    announce("Health maxed.")
end
)

--Semigodmode heal loop
local is_heal_loop_on = false
menu.toggle_loop(self_tab, "Heal Loop", {"healloop"}, "",
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
menu.action(self_tab, "Clean", {"cleanself"}, "Cleans your ped from all visible blood.",
function()
    PED.CLEAR_PED_BLOOD_DAMAGE(players.user_ped())
    announce("Ped cleaned.")
end
)

--Clean loop
menu.toggle(self_tab, "Clean Loop", {}, "Kepes your ped clean at all costs.", function(state) local is_on = state if state then announce("Cleaning ped.") end while is_on do PED.CLEAR_PED_BLOOD_DAMAGE(players.user_ped()) util.yield() end end)

--Max armor
menu.action(self_tab, "Max Armor", {}, "Maxes out your armor.",
function()
    PED.SET_PED_ARMOUR(players.user_ped(), 100)
    announce("Armor filled.")
end
)

--Armor loop
local is_armor_loop_on = false
menu.toggle_loop(self_tab, "Armor Loop", {}, "Keeps your armor full at all costs.", function() if not is_armor_loop_on then announce("Filling ped's armor.") is_armor_loop_on = true end PED.SET_PED_ARMOUR(players.user_ped(), 100) end, function() is_armor_loop_on = false end)

--Angry mode
menu.toggle_loop(self_tab, "Disable \"Angry Mode\"", {}, "Disables the state where the ped is angry and moves quickly after shooting.",function()
    PED.SET_MOVEMENT_MODE_OVERRIDE(players.user_ped(), "DEFAULT")
end, function()
    PED.SET_MOVEMENT_MODE_OVERRIDE(players.user_ped(), 0)
end)

--Online tab
--Weapons
menu.toggle(online_tab, "Give All Weapons After Joining A Session", {}, "As soon as the transition is over, get all weapons.",
function(state)
    give_weapons_after_transition = state
end
)

--Popularity loop
local popularity_loop_command_ref = menu.ref_by_path("Online>Quick Progress>Set Nightclub Popularity", 38)
menu.toggle_loop(online_tab, "Nightclub Popularity Loop", {"ncpopularityloop"}, "Toggles the Nightclub popularity loop to always keep it at 100%",
function()
    menu.trigger_command(popularity_loop_command_ref, 100)
    util.toast("Popularity set")
    util.yield(2000)
end
)

--Transition
menu.toggle(online_tab, "Notification When Transition Is Over", {"notifyontransitionend"}, "Toasts a notification when the main transition is over.",
function(state)
    announce_transition_end = state
end
)

--Vehicles tab
--Include last vehicle
menu.toggle(vehicles_tab, "Include Last Vehicle For Vehicle Functions", {}, "Option to include last vehicle if you're not in a vehicle at the time of running a function.", function(state) include_last_vehicle_for_vehicle_functions = state end)

--Options divider
menu.divider(vehicles_tab, "Options")

--Radio off automatically
local last_vehicle_with_radio_off = 0
menu.toggle_loop(vehicles_tab, "Turn Off Radio Automatically", {}, "Turns off the radio each time you get in a vehicle",
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
menu.toggle_loop(vehicles_tab, "Auto-flip Vehicle", {}, "Automatically flips your car the right way if you land upside-down or sideways.", function()
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
menu.text_input(vehicles_tab, "Alter Vehicle's Acceleration", {"vehiclespeed"}, "Changes how fast the car goes. 0 = Default",
    function(input)
        if vehicle_accel_button ~= 0 and vehicle_accel_button then
            menu.delete(vehicle_accel_button)
            vehicle_accel_button = 0
        end
        vehicle_accel_button = menu.action(vehicles_tab, "Apply Acceleration", {}, "",
        function()
            local vehicle = get_vehicle_ped_is_in(players.user_ped(), include_last_vehicle_for_vehicle_functions)
            if vehicle == 0 then
                util.toast("Get in a car first.")
            else
                local number = tonumber(input) or 0
                VEHICLE.MODIFY_VEHICLE_TOP_SPEED(vehicle, number)
                announce("Acceleration altered. Give it a try!")
            end
        end
        )
    end, "0"
)

--World tab
--Change local gravity
local gravity_tab_under_world = menu.list(world_tab, "Gravity", {}, "Changes world's gravity.")
menu.toggle_loop(gravity_tab_under_world, "Toggle", {}, "Can be really annoying to other players. Recommended to use with friends to not ruin anyone elses fun. :)",
    function()
        local coords = ENTITY.GET_ENTITY_COORDS(players.user_ped())
        if not is_gravity_toggled then
            announce("Gravity set.")
            is_gravity_toggled = true
        end
        if ENTITY.IS_ENTITY_AT_COORD(players.user_ped(), coords.x, coords.y, coords.z, 5.0, 5.0, 5.0, 0, 1, 0) then
            NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entities.get_all_vehicles_as_handles())
            NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entities.get_all_peds_as_handles())
            NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entities.get_all_objects_as_handles())
            MISC.SET_GRAVITY_LEVEL(set_gravity_level)
        end
    end,
    function()
        is_gravity_toggled = false
        NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entities.get_all_vehicles_as_handles())
        NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entities.get_all_peds_as_handles())
        NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entities.get_all_objects_as_handles())
        MISC.SET_GRAVITY_LEVEL(0)
    end)
menu.action_slider(gravity_tab_under_world, "Gravity Level", {}, "Changes gravity's intensity for objects around you. Toggle on with button above. (:", {"Low", "Very low", "Off"},
function(int)
    set_gravity_level = int
end)

menu.toggle_loop(world_tab, "Chaos", {}, "Makes nearby cars go goblin-goblin mode. Can be really annoying to other players. Recommended to use with friends to not ruin anyone elses fun. :)",
    function()
        for i, veh in ipairs(entities.get_all_vehicles_as_handles()) do
            NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(veh)
            ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(veh, 1, 0.0, 10.0, 0.0, true, true, true, true) -- alternatively, VEHICLE.SET_VEHICLE_FORWARD_SPEED(...) -- not tested
        end
    end
)

--spooner
local spooner_main_list = menu.list(world_tab, "Andy's Spooner")
local spooned = {} -- {{list_handle, entity_handle}, {list_handle, entity_handle}, {list_handle, entity_handle}}

local function generate_entity_spooner_features(list, handle)
    local teleport = menu.action(list, "Teleport To Me", {}, "",
    function()
        request_control(handle)
        local coords = ENTITY.GET_ENTITY_COORDS(players.user_ped())
        ENTITY.SET_ENTITY_COORDS(handle, coords.x, coords.y, coords.z, 0, 0, 0, 0)
    end)
    menu.action(list, "Delete", {}, "",
    function()
        local function where_is()
            local counter = 0
            for i,table in spooned do
                counter += 1
                for index, value in table do
                    if value == list then
                        return counter
                    end
                end
            end
        end
        request_control(handle)
        entities.delete_by_handle(handle)
        menu.delete(list)
        table.remove(spooned, where_is())
        announce("Entity removed.")
    end)
end

local function add_spooner_list(list_handle, handle)
    table.insert(spooned, {list_handle, handle})
end

local function entity_spooner(input)
    local coords = ENTITY.GET_ENTITY_COORDS(players.user_ped())
    local hash = util.joaat(input)
    local entity_handle = 0
    if request_model(hash) then
        if STREAMING.IS_MODEL_A_PED(hash) then
            entity_handle = entities.create_ped(4, hash, coords, 0)
        elseif STREAMING.IS_MODEL_A_VEHICLE(hash) then
            entity_handle = entities.create_vehicle(hash, coords, 0)
        else -- must be an object
            entity_handle = entities.create_object(hash, coords)
        end
    local list = menu.list(spooner_main_list, input)
        add_spooner_list(list, entity_handle)
        generate_entity_spooner_features(list, entity_handle)
    else
        toast_formatted("Couldn't load given hash \"%s\". Are you sure you typed a valid entity?", input)
    end
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
        for i=1, entries do
            table.remove(spooned)
        end
        local message = entries > 1 and "Deleted "..entries.." entities." or "Deleted "..entries.." entity."
        util.toast(message)
    else
        util.toast("There are no entities to delete.")
    end
end
local input_model_ref = menu.text_input(spooner_main_list, "Enter An Entity Name", {"spawnentity"}, "Given a hash, spanws the entity and then shows it below.", function(input) if input ~= string.strip(input, " ") then util.toast("Input can't be empty.") else entity_spooner(tostring(input)) end end) ---@diagnostic disable-line
menu.action(spooner_main_list, "Delete All", {}, "Deletes every spawned entity from the list and in-game (if not manually deleted yet).", function() delete_every_entity_from_spooner() end)
--[[Spooner divider]] menu.divider(spooner_main_list, "Spawned Entities will appear here:")

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
    filehandle = io.open(file_path, "w")
    filehandle:write(time)
    filehandle:flush()
    filehandle:close()
end

local function get_clock()
    return tostring(CLOCK.GET_CLOCK_HOURS() .. ":" .. CLOCK.GET_CLOCK_MINUTES() .. ":".. CLOCK.GET_CLOCK_SECONDS())
end

local time_path = filesystem.store_dir() .. "AndyScript\\time.txt"
local is_freeze_clock_on = false
menu.toggle(world_tab, "Consistent Freeze Clock", {}, "Freezes the clock using Stand's function, then saves the time for next execution. Change the current time using the \"time\" command, or in \"World > Atmosphere > Clock > Time\".",
function(state)
    is_freeze_clock_on = state
    if state then
        if filesystem.exists(time_path) then
            local time = read_time(time_path)
            menu.trigger_command(menu.ref_by_path("World>Atmosphere>Clock>Time", 38), time)
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

--Fun tab
--Ride cow
local function set_ped_apathy(ped, value)
    PED.SET_PED_CONFIG_FLAG(ped, 208, value)
    PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, value)
    ENTITY.SET_ENTITY_INVINCIBLE(ped, value)
end
menu.toggle(fun_tab, "Ride Cow", {}, "Spawns a fucking cow for some reason, then rides it. Your ped becomes invisible (for other players) but the cow doesn't. Compatible with \"Vehicles > Auto Flip Vehicle\".",
    function(state)
        local player_heading = ENTITY.GET_ENTITY_HEADING(players.user_ped())
        local player_coords = ENTITY.GET_ENTITY_COORDS(players.user_ped())
        if state then
            request_model(util.joaat("TRACTOR")) -- util.joaat("TRACTOR") == 1641462412 (tractor hash)
            vehicle_for_cow_rider = VEHICLE.CREATE_VEHICLE(util.joaat("TRACTOR"), player_coords.x, player_coords.y, player_coords.z, player_heading, true, true, false)
            request_model(util.joaat("A_C_Cow")) -- util.joaat("A_C_Cow") == 4244282910 (cow hash)
            ENTITY.SET_ENTITY_VISIBLE(vehicle_for_cow_rider, false, 0)
            PED.SET_PED_INTO_VEHICLE(players.user_ped(), vehicle_for_cow_rider, -1)
            cow_for_cow_rider = PED.CREATE_PED(29, 4244282910, player_coords.x, player_coords.y, player_coords.z, player_heading, true, true)
            local bone = PED.GET_PED_BONE_INDEX(cow_for_cow_rider, 0x796e)
            ENTITY.ATTACH_ENTITY_TO_ENTITY(cow_for_cow_rider, vehicle_for_cow_rider, bone, 0, -1, 0.5, 0, 0, 0, true, false, false, false, 1, false, false)
            ENTITY.SET_ENTITY_INVINCIBLE(vehicle_for_cow_rider, true)
            set_ped_apathy(cow_for_cow_rider, true)
            if not menu.get_value(menu.ref_by_path("Self>Glued To Seats")) then
                menu.trigger_command(menu.ref_by_path("Self>Glued To Seats", 38), "on")
                altered_seatbelt_state = true
            end
        else
            if altered_seatbelt_state then
                menu.trigger_command(menu.ref_by_path("Self>Glued To Seats", 38), "off")
            end
            entities.delete_by_handle(vehicle_for_cow_rider)
            entities.delete_by_handle(cow_for_cow_rider)
        end
    end
)

--Settings
--Announce actions
menu.toggle(settings_tab, "Announce Actions", {}, 'Announces every action done by the script, i.e. "Health maxed". This could also be called "Debug mode" (?',
function(state)
    announce_actions = state
end
)

--Shortcuts
local shortcuts = {}
-- {{new_button, shortcut_new, shortcut_title, shortcut_old}, {new_button, shortcut_new, shortcut_title, shortcut_old}}

local shortcut_menu = menu.list(settings_tab, "Andy's Shortcuts")

local function read_multiple_commands(shortcut_title, shortcut_new, shortcut_old)
    if string.find(shortcut_old, ";") then
        local commands = string.split(shortcut_old, ";") ---@diagnostic disable-line
        return menu.action(shortcut_menu, shortcut_title, {shortcut_new}, "", function() menu.trigger_commands(commands[1]) menu.trigger_commands(commands[2]) announce('Shortcut "' .. shortcut_title .. '" activated.') end)
    else
        return menu.action(shortcut_menu, shortcut_title, {shortcut_new}, "", function() menu.trigger_commands(shortcut_old) announce('Shortcut "' .. shortcut_title .. '" activated.') end)
    end
end

local function create_shortcut(shortcut_title, shortcut_new, shortcut_old)
    local new_button = read_multiple_commands(shortcut_title, shortcut_new, shortcut_old)
    if string.find(shortcut_old, ";") then
        table.insert(shortcuts, {new_button, shortcut_new, shortcut_title, {shortcut_old}})
    else
        table.insert(shortcuts, {new_button, shortcut_new, shortcut_title, shortcut_old})
    end
    write_to_shortcut_file(shortcut_path)
end

local function delete_shortcut(shortcut)
    local function where_is_shortcut_to_delete(input)
        c = 1
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
                util.toast('Shortcut "' .. shortcut .. '" removed.')
            else
                util.toast("Shortcut not found.")
            end
        else
            util.toast("Shortcut doens't exist.")
        end
    else
        util.toast("There are no shortcuts. Try creating one before deleting!")
    end
    write_to_shortcut_file(shortcut_path)
end

local function import_shortcuts_from_file(shortcut_new, shortcut_name, shortcut_old)
    table.insert(shortcuts, {0, shortcut_new, shortcut_name, shortcut_old})
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
        local message_for_importing = imported_shortcut_count > 1 and "Imported " .. imported_shortcut_count .. " previous shortcuts." or "Imported " .. imported_shortcut_count .. " previous shortcut."
        util.toast(message_for_importing)
        io.close(filehandle)
    else
        util.toast("Failed to open file.")
    end
end


function write_to_shortcut_file(file_path)
    local filehandle = io.open(file_path, "w")
    if filehandle then
        for index, value in ipairs(shortcuts) do
            if value[1] ~= -1 then
                if type(value[4]) ~= "table" then
                    filehandle:write(value[2] .. "," .. value[3] .. "," .. value[4] .. "\n")
                else
                    filehandle:write(value[2] .. "," .. value[3] .. "," .. table.concat(value[4]) .. "\n")
                end
            end
        end
        filehandle:flush()
        io.close(filehandle)
    else
        util.toast("Error while writing to shortcut file.")
    end
end

local have_shortcuts_been_enabled = false
-- defining main lists
local add_a_shortcut
local remove_a_shortcut
--toggle on or off
menu.toggle(shortcut_menu, "Enable", {"andyshortcuts"}, "Enable " .. '"' .. "Andy's Shortcuts" .. '"' .. ", which are command box shortcuts such as using 'dv' instead of 'deletevehicle'.",
function(state)
    shortcut_status = state
    if not have_shortcuts_been_enabled then
        read_shortcut_file(shortcut_path)
        have_shortcuts_been_enabled = true
    end
    --To hide the buttons before you enable it
    if shortcut_status then
        add_a_shortcut = menu.list(shortcut_menu, "Add A Shortcut", {}, "Allows you to add custom shortcuts.")
        remove_a_shortcut = menu.list(shortcut_menu, "Remove A Shortcut", {}, "Allows you to remove previously created shortcuts.")

        --maker
        local single_custom_shortcut_menu = menu.list(add_a_shortcut, "Shorten A Single Command", {}, "Shortcut creator to shorten a single command, such as 'deletevehicle'.")
        --[[Maker title]] menu.divider(single_custom_shortcut_menu, "Fill these in:")
        local new_shortcut_title = menu.text_input(single_custom_shortcut_menu, "Title", {"customshortcuttitle"}, "Title to identify custom shortcut.", function() end)
        local new_shortcut = menu.text_input(single_custom_shortcut_menu, "Shortcut", {"customshortcut"}, "Command that, when typed into the command box, will trigger the original command you want to shorten.", function() end)
        local new_shortcut_command = menu.text_input(single_custom_shortcut_menu, "Command", {"customshortcutcommand"}, "Original command that you want to shorten.", function() end)
        --[[Maker button title]] menu.divider(single_custom_shortcut_menu, "Once you're done, press this:")
        --[[Maker button]] menu.action(single_custom_shortcut_menu, "Create", {}, "Creates the custom shortcut with the given specifications.",
        function()
            local new_shortcut_test = menu.get_value(new_shortcut_command)
            if not pcall(menu.ref_by_command_name, string.split(new_shortcut_test, " ")[1]) then --[[string.split ALWAYS returns a table]] ---@diagnostic disable-line
                util.toast("Error creating shortcut. Is the original command given correct?")
            elseif menu.get_value(new_shortcut_title) == "" then
                util.toast("Error creating shortcut. Does it have a name?")
            else
                create_shortcut(menu.get_value(new_shortcut_title), menu.get_value(new_shortcut), new_shortcut_test)
                util.toast('New shortcut "' .. menu.get_value(new_shortcut_title) .. '" created!')
            end
        end)

        local multiple_custom_shortcut_menu = menu.list(add_a_shortcut, "Shorten Multiple Commands", {}, "Shortcut creator to shorten many commands in one shortcut, such as 'rapidfire; godmode'. Nesting commands is allowed and encouraged. Go wild!")
        --[[Multiple-shortcuts title]] menu.divider(multiple_custom_shortcut_menu, "Fill these in:")
        local multiple_new_shortcut_title = menu.text_input(multiple_custom_shortcut_menu, "Title", {"multiplecustomshortcuttitle"}, "Title to identify custom shortcut.", function() end)
        local multiple_new_shortcut = menu.text_input(multiple_custom_shortcut_menu, "Shortcut", {"multiplecustomshortcut"}, "Command that, when typed into the command box, will trigger the original command you want to shorten.", function() end)
        local multiple_custom_command1 = menu.text_input(multiple_custom_shortcut_menu, "Command 1", {"multiplecustomshortcutcommand1"}, "Original command(s) that you want to shorten.", function() end)
        local multiple_custom_command2 = menu.text_input(multiple_custom_shortcut_menu, "Command 2", {"multiplecustomshortcutcommand2"}, "Original command(s) that you want to shorten.", function() end)
        --[[Multiple-shortcuts maker divider]] menu.divider(multiple_custom_shortcut_menu, "Once you're done, press this:")
        --[[Multiple-shortcuts maker button]] menu.action(multiple_custom_shortcut_menu, "Create", {}, "Creates the custom shortcut with the given specifications.",
        function()
            local new_shortcut_test1 = menu.get_value(multiple_custom_command1)
            local new_shortcut_test2 = menu.get_value(multiple_custom_command2)
            if not pcall(menu.ref_by_command_name, string.split(new_shortcut_test1, " ")[1]) and pcall(menu.ref_by_command_name, string.split(new_shortcut_test2, " ")[1]) then --[[string.split ALWAYS returns a table]] ---@diagnostic disable-line
                util.toast("Error creating shortcut. Are the original commands given correct?")
            elseif multiple_new_shortcut_title == "" then
                util.toast("Error creating shortcut. Does it have a name?")
            else
                local multiple_og_commands = menu.get_value(multiple_custom_command1) .. ";" .. menu.get_value(multiple_custom_command2)
                create_shortcut(menu.get_value(multiple_new_shortcut_title), menu.get_value(multiple_new_shortcut), multiple_og_commands)
                util.toast('New shortcut "' .. menu.get_value(multiple_new_shortcut_title) .. '" created!')
            end
        end)

        --remover
        --[[Remover title]] menu.divider(remove_a_shortcut, "Fill this in:")
        local remover_shortcut = menu.text_input(remove_a_shortcut, "Shortcut", {"removershortcut"}, "Removes the entry belonging to the shortcut you input.", function() end)
        --[[Remover subtitle]] menu.divider(remove_a_shortcut, "Once you're done, press this:")
        --[[Remover button]] menu.action(remove_a_shortcut, "Remove", {}, "Looks for the first match with your given input and deletes it from the shortcut list.",
            function()
                delete_shortcut(menu.get_value(remover_shortcut))
            end)

    else --clear everything, then restart when toggle is enabled
        menu.delete(add_a_shortcut)
        add_a_shortcut = 0
        menu.delete(remove_a_shortcut)
        remove_a_shortcut = 0
        --delete remover menu and all that
    end

    if shortcut_status then --showing shortcuts
        shortcut_title = menu.divider(shortcut_menu, "Available Shortcuts")
    else --cleanup
        menu.delete(shortcut_title)
        shortcut_title = 0
    end
    -- v are shortcuts
    for k, v in ipairs(shortcuts) do
        if shortcut_status then
            v[4] = tostring(v[4])
            if string.find(v[4], ";") then
                local multiple_commands_action = string.split(v[4], ";") ---@diagnostic disable-line
                v[1] = menu.action(shortcut_menu, v[3], {v[2]}, "", function() menu.trigger_commands(multiple_commands_action[1]) menu.trigger_commands(multiple_commands_action[2]) end)
            else
                v[1] = menu.action(shortcut_menu, v[3], {v[2]}, "", function() menu.trigger_commands(v[4]) end) --Restore shortcuts
            end
        else
            menu.delete(v[1])
            v[1] = 0
        end
    end
end, false
)

-- About tab
local credits_under_info_tab = menu.list(info_tab, "Credits")
menu.readonly(info_tab, "Made by Andy <3", "Lancito01#0001")
menu.readonly(info_tab, "Version", script_version)
menu.hyperlink(info_tab, "AndyScript Discord", "https://discord.gg/9vzATnaM9c", "The one and only official AndyScript Discord server, where you can find the script's changelog, support and a suggestions channel (they are greatly appreciated), and a good community to chat with. :D")
menu.hyperlink(info_tab, "GitHub", "https://github.com/Lancito01/AndyScript")
menu.readonly(credits_under_info_tab, "Ren", "For helping me with majority of the code and with stupid questions. <3")
menu.readonly(credits_under_info_tab, "Gabeeh", "For existing.")

--Player root
--Remote horn boost
local function remote_horn_boost(pid)
    local player_ped = PLAYER.GET_PLAYER_PED(pid)
    local player_vehicle = get_vehicle_ped_is_in(player_ped, false)
    if AUDIO.IS_HORN_ACTIVE(player_vehicle) then
        NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(player_vehicle)
        ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(player_vehicle, 1, 0.0, 1.0, 0.0, true, true, true, true) -- alternatively, VEHICLE.SET_VEHICLE_FORWARD_SPEED(...) -- not tested
    end
end

local function remote_car_jump(pid)
    local player_ped = PLAYER.GET_PLAYER_PED(pid)
    local player_vehicle = get_vehicle_ped_is_in(player_ped, false)
    if AUDIO.IS_HORN_ACTIVE(player_vehicle) then
        NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(player_vehicle)
        ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(player_vehicle, 1, 0.0, 0.0, 0.7, true, true, true, true) -- alternatively, VEHICLE.SET_VEHICLE_FORWARD_SPEED(...) -- not tested
    end
end

--Check for modder
local function is_player_modder(pid)
    local suffix = players.is_marked_as_modder(pid) and " has set off modder detections." or " hasn't set off modder detections."
    chat.send_message(players.get_name(pid) .. suffix,
    true, -- is team chat
    true, -- is in local history
    false -- is networked
    )
end

--Spawn ped in car
local function spawn_ped_in_car(car, playerped, isclone)
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
        util.toast("There are no available seats free in their car.")
    end
end

local function fill_car_with_peds(vehicle, playerped, isclone)
    if vehicle == 0 then
        util.toast("Player is not in a car.")
    elseif VEHICLE.ARE_ANY_VEHICLE_SEATS_FREE(vehicle) then
        while VEHICLE.ARE_ANY_VEHICLE_SEATS_FREE(vehicle) do
            spawn_ped_in_car(vehicle, playerped, isclone)
        end
        announce("Car filled.")
    else
        util.toast("There are no available seats free in their car.")
    end
end

local function is_player_andy(pid)
    if players.get_rockstar_id(pid) == 35827130 then
        util.toast("'" .. players.get_name(pid) .. "'" .. " (AndyScript dev) is joining. Say hi!")
    end
end

local function repair_player_vehicle(pid)
    local player_ped = PLAYER.GET_PLAYER_PED(pid)
    local player_vehicle = get_vehicle_ped_is_in(player_ped, include_last_vehicle_for_player_functions)
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
    local player_vehicle = get_vehicle_ped_is_in(player_ped, include_last_vehicle_for_player_functions)
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
    local player_vehicle = get_vehicle_ped_is_in(player_ped, include_last_vehicle_for_player_functions)
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
    local player_vehicle = get_vehicle_ped_is_in(player_ped, include_last_vehicle_for_player_functions)
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
    local player_vehicle = get_vehicle_ped_is_in(player_ped, include_last_vehicle_for_player_functions)
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
    local player_vehicle = get_vehicle_ped_is_in(player_ped, include_last_vehicle_for_player_functions)
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
    local player_vehicle = get_vehicle_ped_is_in(player_ped, include_last_vehicle_for_player_functions)
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
    local player_vehicle = get_vehicle_ped_is_in(player_ped, include_last_vehicle_for_player_functions)
    if player_vehicle == 0 then
        util.toast(players.get_name(pid) .. " is not in any vehicle.")
    else
        request_control(player_vehicle)
        local heading = ENTITY.GET_ENTITY_HEADING(player_vehicle)
        local alter_heading = heading >= 180 and heading-180 or heading+180
        ENTITY.SET_ENTITY_ROTATION(player_vehicle, 0, 0, alter_heading, 2, true)
        announce(players.get_name(pid) .. "'s vehicle turned.")
    end
end

local function generate_features(pid)
    menu.divider(menu.player_root(pid), "AndyScript")
    local vehicles_player_root = menu.list(menu.player_root(pid), "Vehicles")
    local online_player_root = menu.list(menu.player_root(pid), "Online")
    menu.toggle(vehicles_player_root, "Include Player's Last Vehicle", {}, "Option to use last vehicle in case the player is not in a vehicle when running a function.", function(state) include_last_vehicle_for_player_functions = state end)
    menu.divider(vehicles_player_root, "Options")
    menu.action_slider(vehicles_player_root, "Clone Ped Inside Their Car", {}, "Clones the player's ped and places it in the first free seat it finds.", {"Once", "Fill vehicle"},
        function(index)
            local player_ped = PLAYER.GET_PLAYER_PED(pid)
            local car = get_vehicle_ped_is_in(player_ped, include_last_vehicle_for_player_functions) -- alternatively: local car = use_last_vehicle_toggle and PED.GET_VEHICLE_PED_IS_IN(ped) or get_vehicle_ped_is_in(pid, false)        
            if index == 1 then
                spawn_ped_in_car(car, player_ped, true)
            elseif index == 2 then
                fill_car_with_peds(car, player_ped, true)
            end
        end)
        menu.action_slider(vehicles_player_root, "Spawn Random Ped Inside Their Car", {}, "Spawns a random ped from our (not very) extensive list and places it on the first available seat it finds.", {"Once", "Fill vehicle"},
        function(index)
            local player_ped = PLAYER.GET_PLAYER_PED(pid)
            local car = get_vehicle_ped_is_in(player_ped, include_last_vehicle_for_player_functions) -- alternatively: local car = use_last_vehicle_toggle and PED.GET_VEHICLE_PED_IS_IN(ped) or get_vehicle_ped_is_in(pid, false)        
            if index == 1 then
                spawn_ped_in_car(car, player_ped, false)
            elseif index == 2 then
                fill_car_with_peds(car, player_ped, false)
            end
        end)
    menu.toggle_loop(vehicles_player_root, "Remote Horn Boost", {}, "Boosts their car forward when they honk the horn. Can be combined with \"Remote Car Jump\".", function() remote_horn_boost(pid) end)
    menu.toggle_loop(vehicles_player_root, "Remote Car Jump", {}, "Makes their car jump when they honk the horn. Can be combined with \"Remote Horn Boost\".", function() remote_car_jump(pid) end)
    menu.action(vehicles_player_root, "Repair", {}, "Repairs their vehicle to full health.", function() repair_player_vehicle(pid) end)
    menu.action(vehicles_player_root, "Toggle Engine", {}, "If their engine is on, it toggles it off and viceversa.", function() toggle_player_vehicle_engine(pid) end)
    menu.action(vehicles_player_root, "Break Engine", {}, "Makes their engine catch on fire.", function() break_player_vehicle_engine(pid) end)
    menu.action(vehicles_player_root, "Boost Forward", {}, "Boosts their vehicle forward with great force.", function() boost_player_vehicle_forward(pid) end)
    menu.action(vehicles_player_root, "Launch Up", {}, "Launches their vehicle into the stratosphere. Okay, maybe not that high but still pretty funny.", function() launch_up_player_vehicle(pid) end)
    menu.action(vehicles_player_root, "Stop Vehicle", {}, "Stops their vehicle in the exact spot they're at. Doesn't freeze it, just stops it.", function() stop_player_vehicle(pid) end) 
    menu.action(vehicles_player_root, "Flip Vehicle Upside Down", {}, "Flips their car in its Y axis.", function() flip_player_vehicle(pid) end)
    menu.action(vehicles_player_root, "Turn Vehicle 180 Degrees", {}, "Flips their car in its Z axis.", function() turn_player_vehicle(pid) end)
    menu.action(online_player_root, "Check If Player Is Modder", {"isplayermodder"}, "Checks if the selected player is a modder, then displays the result in local chat. Other players can't see this message.", function() is_player_modder(pid) end)
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
    util.toast("See you later!")
end)
