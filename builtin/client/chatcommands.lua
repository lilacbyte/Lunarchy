core.register_on_sending_chat_message(function(message)
	if message:sub(1,2) == ".." then
		return false
	end

	local first_char = message:sub(1,1)
	if first_char == "/" or first_char == "." then
		core.display_chat_message(core.gettext("Issued command: ") .. message)
	end

	if first_char ~= "." then
		return false
	end

	local cmd, param = string.match(message, "^%.([^ ]+) *(.*)")
	param = param or ""

	if not cmd then
		core.display_chat_message("-!- " .. core.gettext("Empty command."))
		return true
	end

	-- Run core.registered_on_chatcommand callbacks.
	if core.run_callbacks(core.registered_on_chatcommand, 5, cmd, param) then
		return true
	end

	local cmd_def = core.registered_chatcommands[cmd]
	if cmd_def then
		core.set_last_run_mod(cmd_def.mod_origin)
		local _, result = cmd_def.func(param)
		if result then
			core.display_chat_message(result)
		end
	else
		core.display_chat_message("-!- " .. core.gettext("Invalid command: ") .. cmd)
	end

	return true
end)

core.register_chatcommand("list_players", {
	description = core.gettext("List online players"),
	func = function(param)
		local player_names = core.get_player_names()
		if not player_names then
			return false, core.gettext("This command is disabled by server.")
		end

		local players = table.concat(player_names, ", ")
		return true, core.gettext("Online players: ") .. players
	end
})
core.register_chatcommand("kill", {
	description = "Kill yourself",
	func = function()
		core.send_damage(10000)
	end,
})

core.register_chatcommand("speed", {
	params = "<speed>",
	description = "Set speed.",
	func = function(param)
		local success, newspeed = core.parse_num(param)
		if success then
			core.set_fast_speed(newspeed)
			return true, "Speed set to " .. newspeed
		end
		return false, "Invalid speed input (" .. param .. ")"
	end,
})

core.register_chatcommand("place", {
	params = "<X>,<Y>,<Z>",
	description = "Place wielded item",
	func = function(param)
		local success, pos = core.parse_pos(param)
		if success then
			core.place_node(pos)
			return true, "Node placed at " .. core.pos_to_string(pos)
		end
		return false, pos
	end,
})

core.register_chatcommand("dig", {
	params = "<X>,<Y>,<Z>",
	description = "Dig node",
	func = function(param)
		local success, pos = core.parse_pos(param)
		if success then
			core.dig_node(pos)
			return true, "Node at " .. core.pos_to_string(pos) .. " dug"
		end
		return false, pos
	end,
})

core.register_chatcommand("break", {
	description = "Toggle instant break on/off",
	func = function()
		local instant_break = core.settings:get_bool("instant_break")
		core.settings:set_bool("instant_break", not instant_break)
	end,
})



core.register_chatcommand("disconnect", {
	description = core.gettext("Exit to main menu"),
	func = function(param)
		core.disconnect()
	end,
})
core.register_chatcommand("clear_chat_queue", {
	description = core.gettext("Clear the out chat queue"),
	func = function(param)
		core.clear_out_chat_queue()
		return true, core.gettext("The out chat queue is now empty.")
	end,
})

core.register_chatcommand("setyaw", {
	params = "<yaw>",
	description = "Set your yaw",
	func = function(param)
		local yaw = tonumber(param)
		if yaw then
			core.localplayer:set_yaw(yaw)
			return true, "Yaw set to " .. yaw
		else
			return false, "Invalid usage (See .help setyaw)"
		end
	end
})

core.register_chatcommand("setpitch", {
	params = "<pitch>",
	description = "Set your pitch",
	func = function(param)
		local pitch = tonumber(param)
		if pitch then
			core.localplayer:set_pitch(pitch)
			return true, "Pitch set to " .. pitch
		else
			return false, "Invalid usage (See .help setpitch)"
		end
	end
})


function core.run_server_chatcommand(cmd, param)
	core.send_chat_message("/" .. cmd .. " " .. param)
end

local function forward_server_chatcommand(command, param)
	core.run_server_chatcommand(command, param)
	return true
end

core.register_chatcommand("waypoint", {
	params = "[list | set <name> <color> | death clear]",
	description = "Forward waypoint management to the server",
	func = function(param)
		return forward_server_chatcommand("waypoint", param)
	end,
})

core.register_chatcommand("waypoints", {
	params = "[list | set <name> <color> | death clear]",
	description = "Forward waypoint management to the server",
	func = function(param)
		return forward_server_chatcommand("waypoints", param)
	end,
})

core.register_list_command("xray", "Configure X-Ray", "xray.nodes")
core.register_list_command("search", "Configure NodeESP", "enable_node_esp.nodes")
core.register_player_list_command("friend", "Configure Friends.", "friends")
core.register_player_list_command("enemy", "Configure Enemies.", "enemies")
core.register_player_list_command("ally", "Configure Allies.", "allies")
core.register_player_list_command("staff", "Configure Staff.", "staff")

warp = {}

local storage = core.get_mod_storage()

function warp.set(warp, pos)
	if warp == "" or not pos then return false, "Missing parameter." end
	local posstr = core.pos_to_string(pos)
	storage:set_string(warp, posstr)
	return true, "Warp " .. warp .. " set to " .. posstr .. "."
end

function warp.set_here(param)
	local success, message = warp.set(param, vector.round(core.localplayer:get_pos()))
	return success, message
end

function warp.get(param)
	if param == "" then return false, "Missing parameter." end
	local pos = storage:get_string(param)
	if pos == "" then return false, "Warp " .. param .. " not set." end
	return true, "Warp " .. param .. " is set to " .. pos .. ".", core.string_to_pos(pos)
end

function warp.delete(param)
	if param == "" then return false, "Missing parameter." end
	storage:set_string(param, "")
	return true, "Deleted warp " .. param .. "."
end

core.register_chatcommand("setwarp", {
	params = "<warp>",
	description = "Set a warp to your current position.",
	func = warp.set_here,
})

core.register_chatcommand("readwarp", {
	params = "<warp>",
	description = "Print the coordinates of a warp.",
	func = warp.get,
})

core.register_chatcommand("deletewarp", {
	params = "<warp>",
	description = "Delete a warp.",
	func = warp.delete,
})

core.register_chatcommand("listwarps", {
	description = "List all warps.",
	func = function()
		local warps = storage:to_table().fields
		local warplist = {}
		for warp in pairs(warps) do
			table.insert(warplist, warp)
		end
		if #warplist > 0 then
			return true, table.concat(warplist, ", ")
		else
			return false, "No warps set."
		end
	end,
})

local function do_warp(param)
	if param == "" then return false, "Missing parameter." end
	local success, pos = core.parse_pos(param)
	if not success then
		local msg
		success, msg, pos = warp.get(param)
		if not success then
			return false, msg
		end
	end
	core.localplayer:set_pos(pos)
	return true, "Warped to " .. core.pos_to_string(pos)
end

core.register_chatcommand("warp", {
	params = "<pos>|<warp>",
	description = "Warp to a set warp or a position.",
	func = do_warp
})

core.register_chatcommand("warpandexit", {
	params = "<pos>|<warp>",
	description = "Warp to a set warp or a position and exit.",
	func = function(param)
		local s, m = do_warp(param)
		if s then
			core.disconnect()
		end
		return s,m 
	end
})
