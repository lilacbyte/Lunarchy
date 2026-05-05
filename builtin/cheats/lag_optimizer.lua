local lag_optimizer_state = {
	old_inventory_items_animations = nil,
	old_no_item_spin = nil,
	was_enabled = nil,
	last_no_item_spin = nil,
	last_no_inventory_animations = nil,
	last_no_hand_animation = nil,
}

core.register_cheat_description("LagOptimizer", "Client", "lag_optimizer",
	"Reduce visual lag, first-person motion, inventory animations, and item motion")
core.register_cheat_with_infotext("LagOptimizer", "Client", "lag_optimizer", "")
core.register_cheat_setting("No Inventory Animations", "Client", "lag_optimizer",
	"lag_optimizer.no_inventory_animations", {type="bool"})
core.register_cheat_setting("No Item Spin", "Client", "lag_optimizer", "lag_optimizer.no_item_spin", {type="bool"})
core.register_cheat_setting("No Hand Animation", "Client", "lag_optimizer",
	"lag_optimizer.no_hand_animation", {type="bool"})

core.register_globalstep(function(dtime)
	local ok, err = pcall(function()
		local enabled = core.settings:get_bool("lag_optimizer")

		if enabled ~= lag_optimizer_state.was_enabled then
			lag_optimizer_state.was_enabled = enabled
			if enabled then
				lag_optimizer_state.old_inventory_items_animations =
					core.settings:get_bool("inventory_items_animations")
				lag_optimizer_state.old_no_item_spin =
					core.settings:get_bool("lag_optimizer.no_item_spin")
				lag_optimizer_state.last_no_inventory_animations =
					core.settings:get_bool("lag_optimizer.no_inventory_animations")
				lag_optimizer_state.last_no_item_spin =
					core.settings:get_bool("lag_optimizer.no_item_spin")
				lag_optimizer_state.last_no_hand_animation =
					core.settings:get_bool("lag_optimizer.no_hand_animation")

				if core.settings:get_bool("lag_optimizer.no_inventory_animations") then
					core.settings:set_bool("inventory_items_animations", false)
				end
				if core.settings:get_bool("lag_optimizer.no_item_spin") then
					core.settings:set_bool("lag_optimizer.no_item_spin", true)
				end
				core.update_infotext("LagOptimizer", "Client", "lag_optimizer", "")
			else
				if lag_optimizer_state.old_inventory_items_animations ~= nil then
					core.settings:set_bool("inventory_items_animations", lag_optimizer_state.old_inventory_items_animations)
					lag_optimizer_state.old_inventory_items_animations = nil
				end
				if lag_optimizer_state.old_no_item_spin ~= nil then
					core.settings:set_bool("lag_optimizer.no_item_spin", lag_optimizer_state.old_no_item_spin)
					lag_optimizer_state.old_no_item_spin = nil
				end
				lag_optimizer_state.last_no_inventory_animations = nil
				lag_optimizer_state.last_no_item_spin = nil
				lag_optimizer_state.last_no_hand_animation = nil
				core.update_infotext("LagOptimizer", "Client", "lag_optimizer", "")
			end
		elseif enabled then
			local no_inventory_animations = core.settings:get_bool("lag_optimizer.no_inventory_animations")
			if no_inventory_animations ~= lag_optimizer_state.last_no_inventory_animations then
				lag_optimizer_state.last_no_inventory_animations = no_inventory_animations
				core.settings:set_bool("inventory_items_animations", not no_inventory_animations)
			end

			local no_item_spin = core.settings:get_bool("lag_optimizer.no_item_spin")
			if no_item_spin ~= lag_optimizer_state.last_no_item_spin then
				lag_optimizer_state.last_no_item_spin = no_item_spin
				core.settings:set_bool("lag_optimizer.no_item_spin", no_item_spin)
			end

			local no_hand_animation = core.settings:get_bool("lag_optimizer.no_hand_animation")
			if no_hand_animation ~= lag_optimizer_state.last_no_hand_animation then
				lag_optimizer_state.last_no_hand_animation = no_hand_animation
			end
		end
	end)

	if not ok then
		core.log("error", "LagOptimizer error: " .. tostring(err))
		core.settings:set_bool("lag_optimizer", false)
		lag_optimizer_state.old_inventory_items_animations = nil
		lag_optimizer_state.old_no_item_spin = nil
		lag_optimizer_state.was_enabled = nil
		lag_optimizer_state.last_no_inventory_animations = nil
		lag_optimizer_state.last_no_item_spin = nil
		lag_optimizer_state.last_no_hand_animation = nil
	end
end)
