-- Do this first so you can update infontext later
minetest.register_cheat_with_infotext("FlagAura", "Misc", "flagaura", "")
minetest.register_cheat_setting("Radius", "Misc", "flagaura", "flagaura.range", {type="slider_float", min=1, max=6, steps=6})
core.register_cheat_description("FlagAura", "Misc", "flagaura", "Automatically picks up flags in CTF.")

local heal_cooldown = 0

local function destroy_apple(pos)
    minetest.dig_node(pos)
end

local greeter_initialized = false
local greeter_last_online_players = {}
local greeter_timer = 0
local spammer_plus_timer = 0
local spammer_plus_index = 1
local spammer_plus_file_warned = false

local function normalize_message_lines(value)
    value = tostring(value or "")
    value = value:gsub("\r\n", "\n"):gsub("\\n", "\n")

    local lines = {}
    for _, line in ipairs(string.split(value, "\n", true)) do
        if line ~= nil and line ~= "" then
            lines[#lines + 1] = line
        end
    end

    return lines
end

local function get_spammer_plus_messages()
    local file_path = core.settings:get("spammer_plus.file_path") or ""
    if file_path ~= "" and not spammer_plus_file_warned then
        spammer_plus_file_warned = true
        minetest.log("warning", "Spammer+: file path input is unsupported in client Lua; using the Messages field instead.")
    end

    local raw_messages = core.settings:get("spammer_plus.messages") or "message"
    local messages = normalize_message_lines(raw_messages)
    if #messages == 0 then
        messages = {"message"}
    end
    return messages
end

local function format_player_message(template, name)
    template = template or ""
    template = template:gsub("%%player%%", function()
        return name
    end)
    template = template:gsub("%%name%%", function()
        return name
    end)
    template = template:gsub("%$1", function()
        return name
    end)
    return template
end

local function apply_color_tags(message)
    message = tostring(message or "")
    local used_color = false

    message = message:gsub("<#([%x]+)>", function(color)
        used_color = true
        return core.get_color_escape_sequence("#" .. color)
    end)

    if used_color then
        message = message .. core.get_color_escape_sequence("#ffffff")
    end

    return message
end

local function send_greeter_message(setting_name, fallback, name)
    local template = core.settings:get(setting_name)
    if template == nil or template == "" then
        template = fallback
    end
    minetest.send_chat_message(apply_color_tags(format_player_message(template, name)))
end

local message_sent_combat_target_hud = false
local message_sent_coords

local timer = 0

local function getOtherColors(excludedColor)
    local teamColors = {"red", "blue", "green", "orange", "purple"}
    local otherColors = {}
    for _, color in ipairs(teamColors) do
        if color ~= excludedColor then
            table.insert(otherColors, color)
        end
    end

    return otherColors
end

local function findFlags()
	local player = minetest.localplayer
    if not player then return end
    local tcolor = player:get_teamcolor()
    if not tcolor then return end
    local availableColors = getOtherColors(tcolor)
    local nodeNames = {}

    -- Add the flag nodes for each available color
    for _, color in ipairs(availableColors) do
        table.insert(nodeNames, "ctf_modebase:flag_top_" .. color)
    end
    local foundNodes = {}
    for _, nodeName in ipairs(nodeNames) do
        local nodes = minetest.find_nodes_near(player:get_pos(), tonumber(minetest.settings:get("flagaura.range")), {nodeName})
        for _, pos in ipairs(nodes) do
            table.insert(foundNodes, pos) 
        end
    end

    return foundNodes
end

core.register_globalstep(function(dtime)

    -- AutoHeal
	if core.localplayer then
		if heal_cooldown > 0 then
			heal_cooldown = heal_cooldown - dtime
		end

		if heal_cooldown <= 0 and core.localplayer:get_hp() < tonumber(core.settings:get("auto_heal.hp")) and core.settings:get_bool("auto_heal") then
			local current_wield_index = core.localplayer:get_wield_index() + 1
			local food_index = nil

			for index, stack in ipairs(core.get_inventory("current_player").main) do
				if stack and stack:get_name() ~= "" then
					for group_name, _ in pairs(core.get_item_def(stack:get_name()).groups) do
						if group_name:sub(1, 5) == "food_" then
							food_index = index
							break
						end
					end
				end
				if food_index then break end
			end

			if food_index then
				core.localplayer:set_wield_index(food_index)
				heal_cooldown = tonumber(core.settings:get("auto_heal.cooldown"))

				core.after(tonumber(core.settings:get("auto_heal.delay")), function()
					core.interact("use", {type="nothing"})
					core.localplayer:set_wield_index(current_wield_index)
				end)
			end
		end
	end
    local player = minetest.localplayer
    if not player then
        return
    end
    --AppleAura
    if minetest.settings:get_bool("appleaura") then
        local player_pos = player:get_pos()
        local apple_nodes = minetest.find_nodes_near(player_pos, tonumber(minetest.settings:get("appleaura.range")), {"default:apple"}) -- Find apples within specified range

        if apple_nodes then
            for _, apple_pos in ipairs(apple_nodes) do
                destroy_apple(apple_pos)
            end
        end
    end
    --Spammer+
    if core.settings:get_bool("spammer_plus") then
        spammer_plus_timer = spammer_plus_timer + dtime
        local cooldown = tonumber(core.settings:get("spammer_plus.cooldown")) or 5
        cooldown = math.max(cooldown, 0.1)

        if spammer_plus_timer >= cooldown then
            spammer_plus_timer = spammer_plus_timer - cooldown

            local messages = get_spammer_plus_messages()
            if #messages > 0 then
                if spammer_plus_index > #messages then
                    spammer_plus_index = 1
                end
                minetest.send_chat_message(messages[spammer_plus_index])
                spammer_plus_index = spammer_plus_index + 1
            end
        end
    else
        spammer_plus_timer = 0
        spammer_plus_index = 1
    end

    --Greeter
    greeter_timer = greeter_timer + dtime
    if greeter_timer >= 1 then
        greeter_timer = 0

        local current_players = core.get_player_names() or {}
        local current_set = {}
        local local_name = core.localplayer and core.localplayer:get_name() or nil
        for _, name in ipairs(current_players) do
            if name ~= local_name then
                current_set[name] = true
            end
        end

		if not greeter_initialized then
			greeter_last_online_players = current_set
			greeter_initialized = true
		else
			local greeter_enabled = core.settings:get_bool("greeter")
			local welcome_enabled = core.settings:get_bool("greeter.welcome")
			local goodbye_enabled = core.settings:get_bool("greeter.goodbye")

			if greeter_enabled then
				for name, _ in pairs(current_set) do
					if welcome_enabled and not greeter_last_online_players[name] then
							send_greeter_message(
								"greeter.welcome_message",
								"welcome, <%player%> :^)",
								name
							)
					end
				end

				for name, _ in pairs(greeter_last_online_players) do
					if goodbye_enabled and not current_set[name] then
						send_greeter_message(
							"greeter.goodbye_message",
							"goodbye, <%player%> :^(",
							name
						)
                    end
                end
			else
				greeter_initialized = false
            end
        end

        greeter_last_online_players = current_set
    end
    --HUD elements advice thing
    if minetest.settings:get_bool("enable_combat_target_hud") and minetest.settings:get_bool("hud_elements_advice") then
        if not message_sent_combat_target_hud then
            local message = minetest.colorize("#3250af", "[Advice]: To modify this HUD element's (and some others) position and size, open the Click GUI (F8 by default), press 'Edit HUD' button and then you can modify them. You can hide this message with the command .hide_hud_elements_advice")
            ws.dcm(message)
            message_sent_combat_target_hud = true
        end
    else
		message_sent_combat_target_hud = false
	end
    --Anti AFK
    timer = timer + dtime

    if core.settings:get_bool("anti_afk") then
        if timer >= 0 and timer < 0.25 then
            Strata.clear_controls()
            Strata.set_controls({left = true})
        elseif timer >= 0.25 and timer < 0.5 then
            Strata.clear_controls()
            Strata.set_controls({up = true})
        elseif timer >= 0.5 and timer < 0.75 then
            Strata.clear_controls()
            Strata.set_controls({right = true})
        elseif timer >= 0.75 and timer < 1 then
            Strata.clear_controls()
            Strata.set_controls({down = true})
        elseif timer >= 1 then
            Strata.clear_controls()
            timer = 0
        end
    end
    --FlagAura
    if not minetest.settings:get_bool("flagaura") then return end
    if core.get_server_game() == "not_initialized" then return end
    if core.get_server_game() ~= "capturetheflag" then
        core.update_infotext("FlagAura", "Misc", "flagaura", "Invalid Game")
        return
    end
	local positions = findFlags()
    if not positions then return end
	for _, pos in ipairs(positions) do
    	minetest.dig_node(pos)
	end
end)
--AutoHeal
core.register_cheat_with_infotext("AutoHeal", "Misc", "auto_heal", "CTF")
core.register_cheat_description("AutoHeal", "Misc", "auto_heal", "Automatically eat food if health is below a set value.")

core.register_cheat_setting("Delay", "Misc", "auto_heal", "auto_heal.delay", {type="slider_float", min=0.0, max=1.5, steps=16})
core.register_cheat_setting("Cooldown", "Misc", "auto_heal", "auto_heal.cooldown", {type="slider_float", min=0.0, max=1.5, steps=16})
core.register_cheat_setting("HP", "Misc", "auto_heal", "auto_heal.hp", {type="slider_int", min=1, max=30, steps=30})
--AppleAura
minetest.register_cheat_with_infotext("AppleAura", "Misc", "appleaura", "CTF")
minetest.register_cheat_setting("Radius", "Misc", "appleaura", "appleaura.range", {type="slider_float", min=1, max=6, steps=6})
core.register_cheat_description("AppleAura", "Misc", "appleaura", "Automatically digs all apples within a specific radius.")
--Greeter
minetest.register_cheat("Greeter", "Misc", "greeter")
core.register_cheat_setting("Welcome", "Misc", "greeter", "greeter.welcome", {type="bool", order=1})
core.register_cheat_setting("Welcome Message", "Misc", "greeter", "greeter.welcome_message", {type="text", size=80, order=2})
core.register_cheat_setting("Goodbye", "Misc", "greeter", "greeter.goodbye", {type="bool", order=3})
core.register_cheat_setting("Goodbye Message", "Misc", "greeter", "greeter.goodbye_message", {type="text", size=80, order=4})
--Spammer+
minetest.register_cheat("Spammer+", "Misc", "spammer_plus")
core.register_cheat_setting("Cooldown", "Misc", "spammer_plus", "spammer_plus.cooldown", {type="slider_int", min=1, max=50, steps=50})
core.register_cheat_setting("Messages", "Misc", "spammer_plus", "spammer_plus.messages", {type="text", size=120})


--Commands

minetest.register_chatcommand("hide_hud_elements_advice", {
    func = function()
        core.settings:set_bool("hud_elements_advice", false)
    end,
})

-- I don't know why you'd wanna use this
minetest.register_chatcommand("show_hud_elements_advice", {
    func = function()
        core.settings:set_bool("hud_elements_advice", true)
    end,
})
minetest.register_chatcommand("lenny", {
    func = function()
        core.send_chat_message("( ͡° ͜ʖ ͡°)")
    end,
})
