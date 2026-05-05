local CRYSTAL_ITEM_NAMES = {
	"mcl_end:crystal",
	"mcl_end_crystal:end_crystal",
}

local OBSIDIAN_ITEM_NAMES = {
	"mcl_core:obsidian",
	"default:obsidian",
}

local CRYSTAL_ENTITY_NAMES = {
	["mcl_end:crystal"] = true,
	["mcl_end_crystal:end_crystal"] = true,
}

core.register_cheat_with_infotext("CrystalSpam", "Combat", "crystalspam", "")

local spam_state = {
	cooldown = 0,
}

local function switch_to_item(names)
	for _, item_name in ipairs(names) do
		if core.switch_to_item(item_name) then
			return true
		end
	end
	return false
end

local function is_elytra(stack)
	if not stack or stack:is_empty() then
		return false
	end

	local def = core.get_item_def(stack:get_name())
	local groups = def and def.groups or nil
	return groups and (groups.elytra or 0) > 0 or false
end

local function equip_best_torso_armor()
	local inv = core.get_inventory("current_player")
	if not inv or not inv.main or not inv.armor then
		return false
	end

	local current = inv.armor[3] or ItemStack("")
	if not current:is_empty() and not is_elytra(current) then
		local current_def = core.get_item_def(current:get_name())
		local current_groups = current_def and current_def.groups or nil
		if current_groups and (current_groups.armor_torso or 0) > 0 then
			-- Already wearing chest armor.
			return false
		end
	end

	local best_index
	local best_score = -1
	for i, stack in ipairs(inv.main) do
		if not stack:is_empty() then
			local def = core.get_item_def(stack:get_name())
			local groups = def and def.groups or nil
			if groups and (groups.armor_torso or 0) > 0 and (groups.elytra or 0) == 0 then
				local score = tonumber(groups.mcl_armor_points) or 0
				score = score * 100000000 + (tonumber(groups.mcl_armor_toughness) or 0) * 1000000
				score = score + math.floor((math.max(1, (tonumber(groups.mcl_armor_uses) or 1) - 1) * (65535 - stack:get_wear())) / 65535)
				if score > best_score then
					best_score = score
					best_index = i
				end
			end
		end
	end

	if not best_index then
		return false
	end

	local action = InventoryAction("move")
	action:from("current_player", "main", best_index)
	action:to("current_player", "armor", 3)
	action:set_count(1)
	action:apply()
	return true
end

local function is_support_block(name)
	return name == "mcl_core:obsidian" or name == "mcl_core:crying_obsidian" or
		name == "mcl_core:bedrock" or name == "default:obsidian"
end

local function is_buildable(node)
	if not node then
		return false
	end

	local def = core.get_node_def(node.name)
	return def and def.buildable_to
end

local function get_object_center(obj)
	if not obj or not obj.get_pos then
		return nil
	end

	local pos = obj:get_pos()
	if not pos then
		return nil
	end

	return vector.add(pos, {x = 0, y = 1.0, z = 0})
end

local function get_target_mode()
	local mode = core.settings:get("crystalspam.target_mode")
	if mode == "Entities" or mode == "Both" then
		return mode
	end
	return "Players"
end

local function get_infotext_mode()
	if core.settings:get_bool("crystalspam.safe") then
		return "SAFE"
	end
	return get_target_mode()
end

local function target_matches_mode(obj)
	local mode = get_target_mode()
	if mode == "Both" then
		return true
	end

	local is_player = obj.is_player and obj:is_player() or false
	if mode == "Entities" then
		return not is_player
	end

	return is_player
end

local function is_attackable_target(obj)
	if not obj or not obj.get_id then
		return false
	end

	local attackable = core.can_attack(obj:get_id())
	return attackable == true
end

local function get_nearest_target(max_distance)
	local player = core.localplayer
	if not player then
		return nil
	end

	local player_pos = player:get_pos()
	if not player_pos then
		return nil
	end

	local best_target = nil
	local best_distance = max_distance

	for _, obj in ipairs(core.get_nearby_objects(max_distance)) do
		if obj and not (obj.is_local_player and obj:is_local_player()) then
			if target_matches_mode(obj) and obj:get_hp() > 0 and is_attackable_target(obj) then
				local obj_pos = obj:get_pos()
				if obj_pos then
					local distance = vector.distance(player_pos, obj_pos)
					if distance <= best_distance then
						best_distance = distance
						best_target = obj
					end
				end
			end
		end
	end

	return best_target
end

local function get_target_search_radius()
	if not core.settings:get_bool("reach") then
		return 8
	end
	local reach_bonus = tonumber(core.settings:get("reach.range")) or 2
	return 8 + reach_bonus
end

local function get_crystals_near(center, radius)
	local crystals = {}
	if not center then
		return crystals
	end

	for _, obj in ipairs(core.get_objects_inside_radius(center, radius)) do
		local name = obj.get_name and obj:get_name() or nil
		if name and CRYSTAL_ENTITY_NAMES[name] then
			crystals[#crystals + 1] = obj
		end
	end

	return crystals
end

local function get_target_support_pos(target)
	local target_pos = target and target:get_pos() or nil
	if not target_pos then
		return nil
	end

	return vector.round({x = target_pos.x, y = target_pos.y - 1, z = target_pos.z})
end

local function punch_crystals_near(target_pos, radius)
	local crystals = get_crystals_near(target_pos, radius or 1.25)
	if #crystals == 0 then
		return false
	end

	local punched = false
	for _, crystal in ipairs(crystals) do
		local id = nil
		if crystal.get_id then
			id = crystal:get_id()
		end
		if id and core.localplayer then
			core.localplayer:punch(id)
		else
			crystal:punch()
		end
		punched = true
	end

	return punched
end

local function clear_dodge_controls()
	return
end

local function has_nearby_support_block(center_pos, radius)
	if not center_pos then
		return false
	end

	local search_radius = radius or 1
	for dx = -search_radius, search_radius do
		for dy = -search_radius, search_radius do
			for dz = -search_radius, search_radius do
				if not (dx == 0 and dy == 0 and dz == 0) then
					local node_pos = {
						x = center_pos.x + dx,
						y = center_pos.y + dy,
						z = center_pos.z + dz,
					}
					local node = core.get_node_or_nil(node_pos)
					if node and is_support_block(node.name) then
						return true
					end
				end
			end
		end
	end

	return false
end

local function try_place_spam(target)
	local support_pos = get_target_support_pos(target)
	if not support_pos then
		return false
	end

	local crystal_pos = vector.add(support_pos, {x = 0, y = 1, z = 0})
	local support_node = core.get_node_or_nil(support_pos)
	local crystal_node = core.get_node_or_nil(crystal_pos)

	if not crystal_node or not is_buildable(crystal_node) then
		return false
	end

	punch_crystals_near(crystal_pos, 1.25)

	if support_node and not is_support_block(support_node.name) then
		if has_nearby_support_block(support_pos, 1) then
			return false
		end
		if is_buildable(support_node) then
			if switch_to_item(OBSIDIAN_ITEM_NAMES) then
				equip_best_torso_armor()
				core.settings:set_bool("placing_node", true)
				core.place_node(support_pos)
				support_node = core.get_node_or_nil(support_pos)
			else
				return false
			end
		else
			core.dig_node(support_pos)
			spam_state.cooldown = 0.25
			return false
		end
	end

	support_node = core.get_node_or_nil(support_pos)
	crystal_node = core.get_node_or_nil(crystal_pos)
	if not support_node or not is_support_block(support_node.name) or not crystal_node or not is_buildable(crystal_node) then
		return false
	end

	if switch_to_item(CRYSTAL_ITEM_NAMES) then
		equip_best_torso_armor()
		core.settings:set_bool("placing_node", true)
		core.place_node(support_pos)
		punch_crystals_near(crystal_pos, 1.25)
		return true
	end

	return false
end

local function get_safe_hp_threshold()
	return 10
end

core.register_globalstep(function(dtime)
	if not core.settings:get_bool("crystalspam") then
		core.update_infotext("CrystalSpam", "Combat", "crystalspam", "")
		spam_state.cooldown = 0
		clear_dodge_controls()
		return
	end

	spam_state.cooldown = math.max(spam_state.cooldown - dtime, 0)
	local player = core.localplayer
	if not player then
		core.update_infotext("CrystalSpam", "Combat", "crystalspam", "")
		return
	end

	local hp = player:get_hp() or 0
	local safe = core.settings:get_bool("crystalspam.safe")

	if safe and hp <= get_safe_hp_threshold() then
		core.update_infotext("CrystalSpam", "Combat", "crystalspam", get_infotext_mode())
		return
	end

	local target = get_nearest_target(get_target_search_radius())
	if not target then
		core.update_infotext("CrystalSpam", "Combat", "crystalspam", get_infotext_mode())
		return
	end

	core.update_infotext("CrystalSpam", "Combat", "crystalspam", get_infotext_mode())

	local target_center = get_object_center(target)
	if target_center and punch_crystals_near(target_center, 1.25) then
		spam_state.cooldown = 0.05
		return
	end

	if spam_state.cooldown > 0 then
		return
	end

	if try_place_spam(target) then
		spam_state.cooldown = 0.05
		local refreshed_center = get_object_center(target)
		if refreshed_center then
			punch_crystals_near(refreshed_center, 1.25)
		end
	end
end)
