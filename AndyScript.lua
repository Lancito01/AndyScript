script_version = "v0.0.12"
util.require_natives(1660775568)
util.keep_running()

local store = filesystem.store_dir()
local shortcut_path = store .. "/shortcuts.txt"

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
util.toast("Welcome back, friend. :D")

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

--Semigodmode
menu.toggle_loop(self_tab, "Heal Loop", {"healloop"}, "",
function()
    if ENTITY.GET_ENTITY_HEALTH(players.user_ped()) ~= 0 then
        local max_health = ENTITY.GET_ENTITY_MAX_HEALTH(players.user_ped())
        ENTITY.SET_ENTITY_HEALTH(players.user_ped(), max_health, 0)
    end
end
)

--Heal
menu.action(self_tab, "Max Health", {"healself"}, "Heals your ped to its max health.",
function()
    local max_health = ENTITY.GET_ENTITY_MAX_HEALTH(players.user_ped())
    ENTITY.SET_ENTITY_HEALTH(players.user_ped(), max_health, 0)
    announce("Health maxed")
end
)

--Max armor
menu.action(self_tab, "Max Armor", {}, "Maxes out your armor.",
function()
    PED.SET_PED_ARMOUR(players.user_ped(), 100)
end
)

--Clean
menu.action(self_tab, "Clean", {"cleanself"}, "Cleans your ped from all visible blood.",
function()
    PED.CLEAR_PED_BLOOD_DAMAGE(players.user_ped())
    announce("Ped cleaned")
end
)

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
--Radio off automatically
local last_vehicle_with_radio_off = 0
menu.toggle_loop(vehicles_tab, "Turn Off Radio Automatically", {}, "Turns off the radio each time you get in a vehicle",
function()
    local current_vehicle = get_vehicle_ped_is_in(players.user_ped())
    if current_vehicle ~= 0 then
        if last_vehicle_with_radio_off ~= current_vehicle and VEHICLE.GET_IS_VEHICLE_ENGINE_RUNNING(current_vehicle) then
            if AUDIO._IS_VEHICLE_RADIO_ENABLED(current_vehicle) then
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
    if not VEHICLE.IS_VEHICLE_ON_ALL_WHEELS(player_vehicle) and ENTITY.IS_ENTITY_UPSIDEDOWN(player_vehicle) and am_i_on_ground then
        local speed = ENTITY.GET_ENTITY_SPEED_VECTOR(player_vehicle, true)
        VEHICLE.SET_VEHICLE_ON_GROUND_PROPERLY(player_vehicle, 5.0)
        VEHICLE.SET_VEHICLE_FORWARD_SPEED(player_vehicle, speed.y)
        ENTITY.SET_ENTITY_HEADING(player_vehicle, heading)
    end
end)

--World
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
    write_to_shortcut_file(io.open(shortcut_path, "w"))
end

local function import_shortcuts_from_file(shortcut_new, shortcut_name, shortcut_old)
    table.insert(shortcuts, {0, shortcut_new, shortcut_name, shortcut_old})
end

local function read_shortcut_file(filehandle)
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
    util.toast("Imported " .. imported_shortcut_count .. " previous shortcuts.")
end

function write_to_shortcut_file(filehandle)
    for index, value in ipairs(shortcuts) do
        if value[1] ~= -1 then
            if type(value[4]) ~= "table" then
                filehandle:write(value[2])
                filehandle:write(",")
                filehandle:write(value[3])
                filehandle:write(",")
                filehandle:write(value[4])
                filehandle:write("\n")
            else
                filehandle:write(value[2])
                filehandle:write(",")
                filehandle:write(value[3])
                filehandle:write(",")
                filehandle:write(table.concat(value[4]))
                filehandle:write("\n")
            end
        end
    end
    filehandle:flush()
end

shortcut_menu = menu.list(settings_tab, "Andy's Shortcuts")

local have_shortcuts_been_enabled = false
-- defining main lists
local add_a_shortcut
local remove_a_shortcut
--toggle on or off
menu.toggle(shortcut_menu, "Enable", {"andyshortcuts"}, "Enable " .. '"' .. "Andy's Shortcuts" .. '"' .. ", which are command box shortcuts such as using 'dv' instead of 'deletevehicle'.",
function(state)
    shortcut_status = state
    if not have_shortcuts_been_enabled then
        local shortcut_open_file_read = io.open(shortcut_path, "r") -- Open file in read-only mode
        read_shortcut_file(shortcut_open_file_read)
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
            if not pcall(menu.ref_by_command_name, menu.get_value(new_shortcut_command)) then
                util.toast("Error creating shortcut. Is the original command given correct?")
            elseif menu.get_value(new_shortcut_title) == "" then
                util.toast("Error creating shortcut. Does it have a name?")
            else
                create_shortcut(menu.get_value(new_shortcut_title), menu.get_value(new_shortcut), menu.get_value(new_shortcut_command))
                util.toast('New shortcut "' .. menu.get_value(new_shortcut_title) .. '" created!')
            end
        end)

        local multiple_custom_shortcut_menu = menu.list(add_a_shortcut, "Shorten Multiple Commands", {}, "Shortcut creator to shorten many commands in one shortcut, such as 'rapidfire; godmode'. Nesting commands is allowed and encouraged. Go wild!")
        local multiple_shortcut_maker_title = menu.divider(multiple_custom_shortcut_menu, "Fill these in:")
        local multiple_new_shortcut_title = menu.text_input(multiple_custom_shortcut_menu, "Title", {"multiplecustomshortcuttitle"}, "Title to identify custom shortcut.", function() end)
        local multiple_new_shortcut = menu.text_input(multiple_custom_shortcut_menu, "Shortcut", {"multiplecustomshortcut"}, "Command that, when typed into the command box, will trigger the original command you want to shorten.", function() end)
        local multiple_custom_command1 = menu.text_input(multiple_custom_shortcut_menu, "Command 1", {"multiplecustomshortcutcommand1"}, "Original command(s) that you want to shorten.", function() end)
        local multiple_custom_command2 = menu.text_input(multiple_custom_shortcut_menu, "Command 2", {"multiplecustomshortcutcommand2"}, "Original command(s) that you want to shorten.", function() end)
        local multiple_shortcut_maker_subtitle = menu.divider(multiple_custom_shortcut_menu, "Once you're done, press this:")
        local multiple_create_shortcut_command = menu.action(multiple_custom_shortcut_menu, "Create", {}, "Creates the custom shortcut with the given specifications.",
        function()
            if not pcall(menu.ref_by_command_name, menu.get_value(multiple_custom_command1)) and pcall(menu.ref_by_command_name, menu.get_value(multiple_custom_command2)) then
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
        --[[Remover button]] menu.action(remove_a_shortcut, "Remove", {}, "Removes the inputted shortcut from the entry and your shortcut file.", 
            function()
                if shortcuts[1] then
                    for k, v in shortcuts do
                        if v[2] == menu.get_value(remover_shortcut) then
                            menu.delete(v[1])
                            v[1] = 0
                            table.remove(shortcuts, k)
                            write_to_shortcut_file(io.open(shortcut_path, "w"))
                            util.toast('Shortcut "' .. menu.get_value(remover_shortcut) .. '" removed.')
                        else
                            util.toast("Shortcut not found.")
                        end
                    end
                else
                    util.toast("There are no shortcuts. Try creating one before deleting!")
                end
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
menu.hyperlink(info_tab, "GitHub", "https://gist.github.com/Lancito01/aa79a2d964e2409094578fd6cdabf0d8")
menu.readonly(credits_under_info_tab, "Ren", "For helping me with majority of the code and with stupid questions. <3")

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

--local function pipe_bomb(pid)
--    menu.action(menu.player_root(pid), "Sends A Pipebomb Directly To Their Mailbox", {}, "Tracks their house based on their IP and geolocation data and sends an untraceable pipebomb to their home and places it stealthily inside their mailbox for a funny surprise.", function()
--    util.toast("We're out of pipebombs. The fuck are you doin anyways") end)
--end

--Spawn ped in car
local function spawn_ped_in_car(car, playerped, isclone)
    if car == 0 then
        util.toast("Player is not in a car.")
    elseif VEHICLE.ARE_ANY_VEHICLE_SEATS_FREE(car) then
        if isclone then
            local ped_created = PED.CLONE_PED(playerped, true, false, true)
            local seat = VEHICLE.IS_VEHICLE_SEAT_FREE(car, -1, false) and -1 or -2
            PED.SET_PED_INTO_VEHICLE(ped_created, car, seat)
        else
            local coords = ENTITY.GET_ENTITY_COORDS(car, false)
            local random_ped = some_ped_list[math.random(#some_ped_list)]
            local random_ped_hash = util.joaat(random_ped)
            request_model(random_ped_hash) -- Ped is now loaded in memory, so i don't care about what it returns. Point of this is to load ped before i spawn it (otherwise ped won't spawn)
            local ped_created = entities.create_ped(4, random_ped_hash, coords, 0)
            local seat = VEHICLE.IS_VEHICLE_SEAT_FREE(car, -1, false) and -1 or -2
            PED.SET_PED_INTO_VEHICLE(ped_created, car, seat)
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
    else
        util.toast("There are no available seats free in their car.")
    end
end

local function is_player_andy(pid)
    if players.get_rockstar_id(pid) == 35827130 then
        util.toast("'" .. players.get_name(pid) .. "'" .. " (AndyScript dev) is joining. Say hi!")
    end
end

local function generate_features(pid)
    menu.divider(menu.player_root(pid), "AndyScript")
    local vehicles_player_root = menu.list(menu.player_root(pid), "Vehicles")
    local online_player_root = menu.list(menu.player_root(pid), "Online")
    menu.toggle(vehicles_player_root, "Include Player's Last Vehicle", {}, "Include the selected player's last vehicle in the vehicle-related functions.", function(state) include_last_vehicle_for_player_functions = state end)
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
    menu.action(online_player_root, "Check If Player Is Modder", {"isplayermodder"}, "Checks if the selected player is a modder, then displays the result in local chat. Other players can't see this message.", function() is_player_modder(pid) end)
    --pipe_bomb(pid)
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
    write_to_shortcut_file(io.open(shortcut_path, "w"))
    util.toast("See you later!")
end)
