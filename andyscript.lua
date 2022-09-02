script_version = "v0.0.9"
util.require_natives(1651208000)
util.keep_running()

local store = filesystem.store_dir()
local shortcut_path = store .. "/shortcuts.txt"
local shortcut_open_file = io.open(shortcut_path, "r")

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
        local max_health = ENTITY.GET_ENTITY_MAX_HEALTH(players.user_ped())
        ENTITY.SET_ENTITY_HEALTH(players.user_ped(), max_health, 0)
    end
)

--Heal
menu.action(self_tab, "Heal", {"healself"}, "Heals your ped to its max health.",
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
local function create_shortcut(shortcut_title, shortcut_new, shortcut_old)
    local new_button = menu.action(shortcut_menu, shortcut_title, {shortcut_new}, "", function() menu.trigger_command(menu.ref_by_command_name(shortcut_old)) end)
    table.insert(shortcuts, {new_button, shortcut_new, shortcut_title, shortcut_old})
end

local function import_shortcuts_from_file(shortcut_new, shortcut_name, shortcut_old)
    table.insert(shortcuts, {0, shortcut_new, shortcut_name, shortcut_old})
end

local function read_shortcut_file(filehandle)
    local what_line_am_i_reading = 0
    for line in filehandle:lines() do
        what_line_am_i_reading += 1
        local data = string.split(line, ",") ---@diagnostic disable-line
        if data[1] ~= "" and data[2] ~= "" and data[3] ~= "" then
            import_shortcuts_from_file(data[1], data[2], data[3])
        else
            util.toast("Error reading from shortcuts file at line " .. what_line_am_i_reading .. ".")
        end
    end
    util.toast("Imported " .. what_line_am_i_reading .. " previous shortcuts.")
end

local function write_to_shortcut_file(filehandle)
    for index, value in ipairs(shortcuts) do
        if value[1] ~= -1 then
            filehandle:write(value[2])
            filehandle:write(",")
            filehandle:write(value[3])
            filehandle:write(",")
            filehandle:write(value[4])
            filehandle:write("\n")
        end
    end
end

shortcut_menu = menu.list(settings_tab, "Andy's Shortcuts")

local have_shortcuts_been_enabled = false
--toggle on or off
menu.toggle(shortcut_menu, "Enable", {"andyshortcuts"}, "Enable " .. '"' .. "Andy's Shortcuts" .. '"' .. ", which are command box shortcuts such as using 'dv' instead of 'deletevehicle'.",
function(state)
    shortcut_status = state
    if not have_shortcuts_been_enabled then
        read_shortcut_file(shortcut_open_file)
        have_shortcuts_been_enabled = true
    end
    --To hide the buttons before you enable it
    if shortcut_status then
        custom_shortcut_menu = menu.list(shortcut_menu, "Add A Shortcut", {}, "Allows you to add custom shortcuts.")
        remove_shortcut_menu = menu.list(shortcut_menu, "Remove A Shortcut", {}, "Allows you to remove previously created shortcuts.")

        --maker
        local shortcut_maker_title = menu.divider(custom_shortcut_menu, "Fill these in:")
        local new_shortcut_title = menu.text_input(custom_shortcut_menu, "Title", {"customshortcuttitle"}, "Title to identify custom shortcut.", function() end)
        local new_shortcut = menu.text_input(custom_shortcut_menu, "Shortcut", {"customshortcut"}, "Command that, when typed into the command box, will trigger the original command you want to shorten.", function() end)
        local new_shortcut_command = menu.text_input(custom_shortcut_menu, "Command", {"customshortcutcommand"}, "Original command that you want to shorten.", function() end)
        local shortcut_maker_subtitle = menu.divider(custom_shortcut_menu, "Once you're done, press this:")
        local create_shortcut_command = menu.action(custom_shortcut_menu, "Create", {}, "Creates the custom shortcut with the given specifications.",
        function()
            if pcall(menu.ref_by_command_name, menu.get_value(new_shortcut_command)) then
                create_shortcut(menu.get_value(new_shortcut_title), menu.get_value(new_shortcut), menu.get_value(new_shortcut_command))
                util.toast('New shortcut "' .. menu.get_value(new_shortcut_title) .. '" created!')
            else
                util.toast("Error creating shortcut. Is the original command given correct?")
            end
        end)
        --remover
        local remover_title = menu.divider(remove_shortcut_menu, "Fill this in:")
        local remover_shortcut = menu.text_input(remove_shortcut_menu, "Shortcut", {"removershortcut"}, "Removes the entry for the shortcut you input.", function() end)
        local remover_subtitle = menu.divider(remove_shortcut_menu, "Once you're done, press this:")
        local remove_button = menu.action(remove_shortcut_menu, "Remove", {}, "Removes the inputted shortcut from the entry and your shortcut file.", 
            function()
                for k, v in shortcuts do
                    if v[2] == menu.get_value(remover_shortcut) then
                        menu.delete(v[1])
                        v[1] = 0
                        table.remove(shortcuts, k)
                        util.toast('Shortcut "' .. menu.get_value(remover_shortcut) .. '" removed.')
                    end
                end
            end)

    else --clear everything, then restart when toggle is enabled
        menu.delete(custom_shortcut_menu)
        custom_shortcut_menu = 0
        menu.delete(remove_shortcut_menu)
        remove_shortcut_menu = 0
        new_shortcut_title = 0
        new_shortcut = 0
        shortcut_maker_title = 0
        new_shortcut_command = 0
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
            v[1] = menu.action(shortcut_menu, v[3], {v[2]}, "", function() menu.trigger_command(menu.ref_by_command_name(v[4])) end) --Restore shortcuts
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
--Check for modder
local function is_player_modder(pid)
    local suffix
    menu.divider(menu.player_root(pid), "AndyScript")
    menu.action(menu.player_root(pid), "Check If Player Is Modder", {"isplayermodder"}, "Checks if the selected player is a modder, then displays the result in local chat. Other players can't see this message.",
        function()
            suffix = players.is_marked_as_modder(pid) and " is a modder" or " is not a modder"
            chat.send_message(players.get_name(pid) .. suffix, 
            true, -- is team chat
            true, -- is in local history
            false) -- is networked
        end
    )
end

local function is_player_andy(pid)
    if players.get_rockstar_id(pid) == 99063679 or players.get_rockstar_id(pid) == 183828684 or players.get_rockstar_id(pid) == 181860426 or players.get_rockstar_id(pid) == 114010022 then
        util.toast("'" .. players.get_name(pid) .. "'" .. " (AndyScript dev) is joining. Say hi!")
    end
end

local function on_player_join(pid)
    is_player_modder(pid)
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
util.on_stop(
    function()
        write_to_shortcut_file(io.open(shortcut_path, "w"))
        util.toast(
            "See you later!"
        )
    end
)
