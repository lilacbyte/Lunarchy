local CHEAT_NAME = "bow_autoaim"
local DISPLAY_NAME = "BowAutoAim"
local BOW_SPEED = 35
local CHARGE_TIME_US = 1000000

local bow_state = {
	enabled = false,
	draw_started_us = 0,
	last_release_us = 0,
	lua_control_was_enabled = false,
}

local function is_bow_item(item_name)
	if not item_name or item_name == "" then
		return false
	end

	local lower = item_name:lower()
	return lower:find("bow", 1, true) ~= nil
end

local function is_target_candidate(obj, player)
	if not obj or obj == player then
		return false
	end
	if obj.is_local_player and obj:is_local_player() then
		return false
	end
	if obj.get_hp and obj:get_hp() <= 0 then
		return false
	end
	if obj.get_id and core.can_attack and not core.can_attack(obj:get_id()) then
		return false
	end
	return obj.get_pos ~= nil
end

local function get_best_target(player, radius)
	local player_pos = player:get_pos()
	if not player_pos then
		return nil
	end

	local best_target
	local best_score = -1

	for _, obj in ipairs(core.get_objects_inside_radius(player_pos, radius) or {}) do
		if is_target_candidate(obj, player) then
			local target_pos = obj:get_pos()
			if target_pos then
				local dist = vector.distance(player_pos, target_pos)
				local score = 1000 / (dist + 1)
				if score > best_score then
					best_score = score
					best_target = obj
				end
			end
		end
	end

	return best_target
end

local function aim_at_target(player, target, prediction, smoothness)
	local player_pos = player:get_pos()
	local target_pos = target:get_pos()
	if not player_pos or not target_pos then
		return
	end

	local target_vel = target.get_velocity and target:get_velocity() or { x = 0, y = 0, z = 0 }
	local dist = vector.distance(player_pos, target_pos)
	local travel_time = dist / BOW_SPEED
	local predicted = {
		x = target_pos.x + target_vel.x * travel_time * prediction,
		y = target_pos.y + target_vel.y * travel_time * 0.8 + (dist * 0.018),
		z = target_pos.z + target_vel.z * travel_time * prediction,
	}

	local dir = vector.direction(player_pos, predicted)
	if not dir then
		return
	end

	local target_yaw = core.dir_to_yaw(dir)
	local target_pitch = math.asin(math.max(-1, math.min(1, -dir.y)))

	local current_yaw = player:get_look_horizontal()
	local current_pitch = player:get_look_vertical()

	player:set_look_horizontal(current_yaw * (1 - smoothness) + target_yaw * smoothness)
	player:set_look_vertical(current_pitch * (1 - smoothness) + target_pitch * smoothness)
end

local function set_lua_control(player, control)
	if not player then
		return
	end

	player:set_lua_control(control)
end

local function clear_lua_control()
	if bow_state.lua_control_was_enabled then
		core.settings:set_bool("lua_control", true)
	else
		core.settings:set_bool("lua_control", false)
	end
end

local function disable_bow_autoaim()
	bow_state.enabled = false
	bow_state.draw_started_us = 0
	bow_state.last_release_us = 0
	clear_lua_control()
	bow_state.lua_control_was_enabled = false
end

core.register_cheat_with_infotext(DISPLAY_NAME, "Combat", CHEAT_NAME, "")
core.register_cheat_description(
	DISPLAY_NAME,
	"Combat",
	CHEAT_NAME,
	"Automatically aims bows at nearby targets and assists release timing."
)
core.register_cheat_setting("Target Radius", "Combat", CHEAT_NAME, CHEAT_NAME .. ".radius", {
	type = "slider_int",
	min = 1,
	max = 140,
	steps = 140,
})
core.register_cheat_setting("Prediction", "Combat", CHEAT_NAME, CHEAT_NAME .. ".prediction", {
	type = "slider_float",
	min = 0.5,
	max = 2.0,
	steps = 30,
})
core.register_cheat_setting("Smoothness", "Combat", CHEAT_NAME, CHEAT_NAME .. ".smoothness", {
	type = "slider_float",
	min = 0.1,
	max = 1.0,
	steps = 18,
})
core.register_cheat_setting("Auto Release", "Combat", CHEAT_NAME, CHEAT_NAME .. ".auto_release", {
	type = "bool",
})

core.register_globalstep(function(dtime)
	local player = core.localplayer
	if not player then
		disable_bow_autoaim()
		return
	end

	if not core.settings:get_bool(CHEAT_NAME) then
		disable_bow_autoaim()
		return
	end

	if not bow_state.enabled then
		bow_state.lua_control_was_enabled = core.settings:get_bool("lua_control")
	end
	bow_state.enabled = true

	local wielded = player:get_wielded_item()
	local wield_name = wielded and wielded:get_name() or ""
	if not is_bow_item(wield_name) then
		bow_state.draw_started_us = 0
		bow_state.last_release_us = 0
		clear_lua_control()
		core.update_infotext(DISPLAY_NAME, "Combat", CHEAT_NAME, "Hold bow")
		return
	end

	local radius = tonumber(core.settings:get(CHEAT_NAME .. ".radius")) or 140
	local prediction = tonumber(core.settings:get(CHEAT_NAME .. ".prediction")) or 1.35
	local smoothness = tonumber(core.settings:get(CHEAT_NAME .. ".smoothness")) or 0.45
	local auto_release = core.settings:get_bool(CHEAT_NAME .. ".auto_release")

	local target = get_best_target(player, radius)
	if target then
		aim_at_target(player, target, prediction, smoothness)
	else
		core.update_infotext(DISPLAY_NAME, "Combat", CHEAT_NAME, "No target")
		return
	end

	local control = player:get_control() or {}
	local now = core.get_us_time()

	if control.dig then
		if bow_state.draw_started_us == 0 then
			bow_state.draw_started_us = now
		end
	else
		bow_state.draw_started_us = 0
	end

	if auto_release and bow_state.draw_started_us > 0 and now - bow_state.draw_started_us >= CHARGE_TIME_US then
		if now - bow_state.last_release_us >= 200000 then
			bow_state.last_release_us = now
			bow_state.draw_started_us = 0
			if not bow_state.lua_control_was_enabled then
				bow_state.lua_control_was_enabled = core.settings:get_bool("lua_control")
			end
			core.settings:set_bool("lua_control", true)
			set_lua_control(player, {
				up = control.up,
				down = control.down,
				left = control.left,
				right = control.right,
				jump = control.jump,
				aux1 = control.aux1,
				sneak = control.sneak,
				zoom = control.zoom,
				dig = false,
				place = control.place,
			})
		end
	elseif core.settings:get_bool("lua_control") and bow_state.draw_started_us > 0 then
		set_lua_control(player, {
			up = control.up,
			down = control.down,
			left = control.left,
			right = control.right,
			jump = control.jump,
			aux1 = control.aux1,
			sneak = control.sneak,
			zoom = control.zoom,
			dig = control.dig,
			place = control.place,
		})
	end

	core.update_infotext(DISPLAY_NAME, "Combat", CHEAT_NAME, ("Aim %.0fm"):format(radius))
end)

core.register_on_death(function()
	disable_bow_autoaim()
end)
