core.cheats = {
	["Client"] = {
		["QuickMenu"] = { setting = "use_old_menu", order = 0 },
		["Client List"] = { setting = "clients", order = 1 },
		["Ping"] = { setting = "ping", order = 3 },
		["Welcome"] = { setting = "welcome", order = 5 },
		["CheatHUD"] = { setting = "cheat_hud", order = 6 },
		["HUD Color"] = { setting = "hud_color", order = 7 },
		["Coords"] = { setting = "coords", order = 8 },
		["EquipmentHUD"] = { setting = "equipment_hud", order = 9 },
		["LagOptimizer"] = { setting = "lag_optimizer", order = 11 },
	},
	["Render"] = {
		["FullBright"] = "fullbright",
		["BrightNight"] = "no_night",
		["NoClouds"] = "no_clouds",
		["NoFog"] = "no_fog",
		["Xray"] = "xray",
		["EntityESP"] = "enable_entity_esp",
		["EntityTracers"] = "enable_entity_tracers",
		["NoArmor"] = "no_armor",
		["PlayerESP"] = "enable_player_esp",
		["PlayerTracers"] = "enable_player_tracers",
		["NodeESP"] = "enable_node_esp",
		["NodeTracers"] = "enable_node_tracers",
		["TunnelESP"] = "enable_tunnel_esp",
		["TunnelTracers"] = "enable_tunnel_tracers",
	--	["HUDBypass"] = "hud_flags_bypass", dont wanna work, will fix later
		["HealthESP"] = "enable_health_esp",
		["NoHurtCam"] = "no_hurt_cam",
		["NoDrownCam"] = "no_drown_cam",
		["NoFire"] = "no_fire",
		["NoParticles"] = "norender.particles",
		["TaskTracers"] = "enable_task_tracers",
		["TaskNodes"] = "enable_task_nodes",
		["TargetHUD"] = "enable_combat_target_hud",
		["LeftHand"] = "left_hand",
		["HandView"] = "hand_view",
		["ContentPreviewer"] = "content_previewer",
		["Nametags"] = "nametags",
	["FOV"] = "fov_setting",
		["Skybox"] = "custom_skybox",
    },
	["Player"] = {
		["PrivBypass"] = "priv_bypass",
		["NoFallDamage"] = "prevent_natural_damage",
		["Reach"] = "reach",
		["AutoRespawn"] = "autorespawn",
	--	["LuaControl"] = "lua_control",
		["NoForceRotate"] = "no_force_rotate",
		["NoViewBob"] = "nobob",
    },
	["Movement"] = {
		["Freecam"] = "freecam",
		["InvMove"] = "invmove",
		["AutoForward"] = "continuous_forward",
		["PitchMove"] = "pitch_move",
		["AutoJump"] = "autojump",
		["Flight"] = "free_move",
		["Noclip"] = "noclip",
		["FastMove"] = "fast_move",
		["Jesus"] = "jesus",
		["NoSlow"] = "no_slow",
		["JetPack"] = "jetpack",
		["AntiSlip"] = "antislip",
		["AirJump"] = "airjump",
		["Spider"] = "spider",
		["AutoSneak"] = "autosneak",
		["Step"] = "step",
    },
	["Combat"] = {
		["AntiKnockback"] = "antiknockback",
		["AttachmentFloat"] = "float_above_parent",
		["ThroughWalls"] = "throughwalls",
    },
	["Interact"] = {
		["Blink"] = "blink",
		["FastHit"] = "spamclick",
		["AutoHit"] = "autohit",
		["FastPlace"] = "fastplace",
		["AutoPlace"] = "autoplace",
		["AutoDig"] = "autodig",
		["FastDig"] = "fastdig",
		["InstantBreak"] = "instant_break",
		["AutoTool"] = "autotool",
    },
	["Misc"] = {
		["AutoStaff"] = "autostaff",
		["AntiAFK"] = "anti_afk",
		["Greeter"] = "greeter",
		["Spammer+"] = "spammer_plus",
    }
}
-----------------------------------------------------------REGISTER CHEATS-----------------------------------------------------------
function core.register_cheat(cheatname, category, func)
	core.cheats[category] = core.cheats[category] or {}
	core.cheats[category][cheatname] = func
end
-----------------------------------------------------------CHEAT SETTINGS-----------------------------------------------------------
core.cheat_settings = {}

function core.register_cheat_setting(setting_name, parent_category, parent_setting, setting_id, setting_data)
	 --settingname is the formatted setting name, e.g "Assist Mode"
	 --parent_category is the category of the parent setting, e.g "Combat", 
	 --parent_setting is the cheat this setting is for, e.g "autoaim", 
	 --setting_id is the setting string, e.g "autoaim.mode", 
	 --setting_data is the setting table, e.g 
	 --if its a bool,         {type="bool"}
	 --if its an int slider,  {type="slider_int", min=0, max=10, steps=10}
	 --if its a float slider, {type="slider_float", min=0.0, max=10.0, steps=100}
     --if its a text field,   {type="text", size=10}
	 --if its a selectionbox, {type="selectionbox", options={"lock", "assist"}}
	core.cheat_settings[parent_category] = core.cheat_settings[parent_category] or {}
	core.cheat_settings[parent_category][parent_setting] = core.cheat_settings[parent_category][parent_setting] or {}

	core.cheat_settings[parent_category][parent_setting][setting_id] = {
        name = setting_name,
        type = setting_data.type,
        min = setting_data.min,
        max = setting_data.max,
        steps = setting_data.steps,
        size = setting_data.size,
		options = setting_data.options
    }
end
-----------------------------------------------------------CHEAT INFOTEXTS-----------------------------------------------------------
core.infotexts = {}
local infotext_cache = {}


function core.register_cheat_with_infotext(cheatname, category, func, infotext)
	core.infotexts[category] = core.infotexts[category] or {}	
	core.infotexts[category][cheatname] = infotext	
	core.register_cheat(cheatname, category, func)	
end
	
function core.update_infotext(cheatname, category, func, infotext)
	core.infotexts[category] = core.infotexts[category] or {}	
	local cache_key = category .. "\0" .. cheatname
	if infotext_cache[cache_key] == infotext then
		return
	end
	infotext_cache[cache_key] = infotext
	core.infotexts[category][cheatname] = infotext
	core.update_infotexts()
end
-----------------------------------------------------------CHEAT DESCRIPTIONS-----------------------------------------------------------
core.descriptions = {}

function core.register_cheat_with_description(cheatname, category, func, description)
	core.descriptions[category] = core.descriptions[category] or {}
	core.descriptions[category][cheatname] = description
	core.get_description()
end

function core.register_cheat_description(cheatname, category, func, description)
	core.descriptions[category] = core.descriptions[category] or {}
	core.descriptions[category][cheatname] = description
	core.get_description()
end
-----------------------------------------------------------PANIC-----------------------------------------------------------
function core.panic()
	for category_name, category in pairs(minetest.cheats) do
		for cheat_name, cheat in pairs(category) do
			local disable_cheats = minetest.cheats[category_name][cheat_name]
			if type(disable_cheats) == "string" then
				core.settings:set(disable_cheats, "false")
			elseif type(disable_cheats) == "table" and disable_cheats.setting then
				core.settings:set(disable_cheats.setting, "false")
			end
		end
	end
end
core.register_cheat("Panic", "Misc", core.panic)
-----------------------------------------------------------TESTS, PRESET VALUES, ETC-----------------------------------------------------------

--Combat
core.register_cheat_description("AntiKnockback", "Combat", "antiknockback", "Ignore knockback")
core.register_cheat_description("AttachmentFloat", "Combat", "float_above_parent", "Puts the camera one node higher when attached to an entity")
core.register_cheat_description("AutoTotem", "Combat", "autototem", "Automatically puts a totem in your offhand")
core.register_cheat_description("AutoAim", "Combat", "autoaim", "Aims at a specified target")
core.register_cheat_description("CombatLog", "Combat", "be_a_bitch", "Logs off when certain HP is reached")
core.register_cheat_description("Criticals", "Combat", "critical_hits", "Does critical hits in mcl2/mcla")
core.register_cheat_description("CrystalSpam", "Combat", "crystalspam", "Puts end crystals under nearby players or entities")
core.register_cheat_description("AutoWither", "Combat", "autowither", "Completes a wither structure and places the skulls")
core.register_cheat_setting("Nametag", "Combat", "autowither", "autowither.nametag", {type="bool"})
core.register_cheat_description("Killaura", "Combat", "killaura", "Attacks a specified target. Silent mode is recommended in PVP servers, as it makes Killaura undetectable")
core.register_cheat_description("Orbit", "Combat", "orbit", "Moves around a specified target")
core.register_cheat_description("TriggerBot", "Combat", "tbot", "Automatically punch when aiming at an entity")
core.register_cheat_description("ThroughWalls", "Combat", "throughwalls", "Lets you hit players or entities through walls")
--Interact
core.register_cheat_description("FastDig", "Interact", "fastdig", "No block break cooldown")
core.register_cheat_with_infotext("Blink", "Interact", "blink", "0ms")
core.register_cheat_description("Blink", "Interact", "blink", "Delay sending of packets until this cheat is disabled.")
core.register_cheat_description("FastPlace", "Interact", "fastplace", "No block placement cooldown")
core.register_cheat_description("AutoDig", "Interact", "autodig", "Player can dig blocks without mouse press")
core.register_cheat_description("AutoPlace", "Interact", "autoplace", "Auto place blocks")
core.register_cheat_description("InstantBreak","Interact", "instant_break", "Instantly break blocks regardless of tool used")
core.register_cheat_description("FastHit", "Interact", "spamclick", "Hit faster while holding")
core.register_cheat_description("AutoHit","Interact", "autohit", "Auto hit when looking at entity")
core.register_cheat_description("AutoTool", "Interact", "autotool", "Selects the best tool for an action")
--Inventory
core.register_cheat_description("Enderchest", "Misc", minetest.open_enderchest, "Preview enderchest content in mcl/mcla")
core.register_cheat_description("Hand", "Misc", minetest.open_handslot, "Open hand formspec in mcl/mcla")
--Misc
core.register_cheat_description("AntiAFK", "Misc", "anti_afk", "Prevent afk by moving")
core.register_cheat_description("AutoStaff", "Misc", "autostaff", "Automatically check player privs and assign them as a staff. WARNING: can be detected easily")
core.register_cheat_setting("Warn Staff", "Misc", "autostaff", "autostaff.warn_staff", {type="bool"})
core.register_cheat_description("AutoTeam", "Misc", "autoteam", "Sets allied players to your team in ctf. It might require you to run /team in some servers")
core.register_cheat_description("Panic", "Misc", "panic", "Disables all cheats")
core.register_cheat_description("Greeter", "Misc", "greeter", "Sends welcome and goodbye messages for joined or leaving clients")
core.register_cheat_description("Spammer+", "Misc", "spammer_plus", "Loops through chat messages, including multiline text")
--Movement
core.register_cheat_description("AirJump", "Movement", "airjump", "Jump on air")
core.register_cheat_description("AntiSlip", "Movement", "antislip", "Walk on slippery blocks without slipping")
core.register_cheat_description("AutoForward", "Movement", "continuous_forward", "Walk forward automatically")
core.register_cheat_description("AutoJump", "Movement", "autojump", "Jump automatically")
core.register_cheat_description("AutoSneak", "Movement", "autosneak", "Always sneak")
core.register_cheat_description("FastMove", "Movement", "fast_move", "Toggle fast (req. PrivBypass)")
core.register_cheat_with_infotext("Flight", "Movement", "free_move", "")
core.register_cheat_description("Flight", "Movement", "free_move", "Toggle flight (req. PrivBypass)")
core.register_cheat_description("Freecam", "Movement", "freecam", "Spectator mode")
core.register_cheat_description("InvMove", "Movement", "invmove", "Move while a formspec is open")
core.register_cheat_description("Jesus", "Movement", "jesus", "Walk on liquids")
core.register_cheat_with_infotext("JetPack", "Movement", "jetpack", "")
core.register_cheat_description("JetPack", "Movement", "jetpack", "AirJump with adjustable speed")
core.register_cheat_description("NoSlow", "Movement", "noslow", "Sneaking doesn't slow you down")
core.register_cheat_description("Noclip", "Movement", "noclip", "Walk through walls (req. PrivBypass)")
core.register_cheat_description("Overrides", "Movement", "overrides", "Movement overrides")
core.register_cheat_description("PitchMove", "Movement", "pitch_move", "While flying, you move where you're pointing")
core.register_cheat_description("Spider", "Movement", "spider", "Climb walls")
core.register_cheat_description("Step", "Movement", "step", "Climbs the block you're facing")
core.register_cheat_description("Velocity", "Movement", "velocity", "Various velocity overrides")
--Player
core.register_cheat_description("AutoRespawn", "Player", "autorespawn", "Respawn after dying. Singleplayer only")
core.register_cheat_description("NoFallDamage", "Player", "prevent_natural_damage", "Receive no fall damage")
core.register_cheat_description("NoForceRotate", "Player", "noforcerotate", "Prevent server from changing the player's view direction")
core.register_cheat_description("NoViewBob", "Player", "nobob", "Disable view bobbing")
core.register_cheat_description("PrivBypass", "Player", "priv_bypass", "Bypass fly, noclip, fast and wireframe rendering")
core.register_cheat_with_infotext("Reach", "Player", "reach", "")
core.register_cheat_description("Reach", "Player", "reach", "Increase reach")
-- core.register_cheat_description("LuaControl", "Player", "luacontrol", "The player moves regardless of the received input")
core.register_cheat_description("QuickMenu", "Client", "use_old_menu", "Add a menu for quicker access to cheats")
core.register_cheat_description("Client List", "Client", "clients", "Show online and nearby players")
core.register_cheat_description("Ping", "Client", "ping", "Show client RTT in milliseconds")
core.register_cheat_description("Welcome", "Client", "welcome", "Shows a customizable welcome message in the HUD")
core.register_cheat_description("CheatHUD", "Client", "cheat_hud", "List enabled cheats")
core.register_cheat_setting("Order", "Client", "cheat_hud", "cheat_hud.order", {type="selectionbox", options={"Ascending", "Descending"}})
core.register_cheat_setting("By Length", "Client", "cheat_hud", "cheat_hud.by_length", {type="bool"})
core.register_cheat_setting("Y Offset", "Client", "cheat_hud", "cheat_hud.offset", {type="slider_int", min=0, max=200, steps=41})
core.register_cheat_setting("Text Align", "Client", "cheat_hud", "cheat_hud.align", {type="selectionbox", options={"Left", "Center", "Right"}})
core.register_cheat_description("HUD Color", "Client", "hud_color", "Colorize HUD and menu accents")
core.register_cheat_description("Coords", "Client", "coords", "Render coordinates in the bottom left corner")
core.register_cheat_description("EquipmentHUD", "Client", "equipment_hud", "Shows armor and held item durability")
core.register_cheat_description("LagOptimizer", "Client", "lag_optimizer", "Reduce visual lag, first-person motion, inventory animations, and item motion")
--Render
core.register_cheat_description("BrightNight", "Render", "no_night", "Always daytime")
core.register_cheat_description("EntityESP", "Render", "enable_entity_esp", "See entities through walls")
core.register_cheat_description("EntityTracers", "Render", "enable_entity_tracers", "Draw tracers to entities")
core.register_cheat_description("FullBright", "Render", "fullbright", "No darkness")
core.register_cheat_description("Left hand", "Render", "left_hand", "Switch to left hand")
core.register_cheat_description("Skybox", "Render", "custom_skybox", "Render custom skybox")
core.register_cheat_with_infotext("FOV", "Render", "fov_setting", "FOV")
core.register_cheat_description("FOV", "Render", "fov_setting", "Have your FOV set to a custom value")
--core.register_cheat_description("HUDBypass", "Render", "hudbypass", "Allows player to toggle hud elements disabled by the game")
core.register_cheat_description("HealthESP", "Render", "show_players_hp", "Shows player and entity HP")
core.register_cheat_description("NoDrownCam", "Render", "no_drown_cam", "Disables drowning camera effect")
core.register_cheat_description("NoClouds", "Render", "no_clouds", "Disables cloud rendering")
core.register_cheat_description("NoFog", "Render", "no_fog", "Disables fog rendering")
core.register_cheat_description("NoFire", "Render", "no_fire", "Disables the burning fire HUD")
core.register_cheat_description("NoArmor", "Render", "no_armor", "Hide armor on player models and nametags")
core.register_cheat_description("NoHurtCam", "Render", "no_hurt_cam", "Disables hurt camera effect")
core.register_cheat_description("NoParticles", "Render", "norender.particles", "Don't render particles")
core.register_cheat_description("NodeESP", "Render", "enable_node_esp", "See specified nodes through walls")
core.register_cheat_description("NodeTracers", "Render", "enable_node_tracers", "Draw tracers to specified nodes")
core.register_cheat_description("PlayerESP", "Render", "enable_player_esp", "See players through walls")
core.register_cheat_description("PlayerTracers", "Render", "enable_player_tracers", "Draw tracers to players")
core.register_cheat_description("TunnelESP", "Render", "enable_tunnel_esp", "See tunnels through walls")
core.register_cheat_description("TunnelTracers", "Render", "enable_tunnel_tracers", "Draw tracers to tunnels")
core.register_cheat_description("Xray", "Render", "xray", "Don't render specific nodes")
core.register_cheat_description("TargetHUD", "Render", "enable_combat_target_hud", "Shows best target on a HUD (depends on your combat settings)")
core.register_cheat_description("Nametags", "Render", "nametags", "Customize players nametags, equipment, wielded items, and item names. Doesn't work well in CTF")
core.register_cheat_description("LeftHand", "Render", "left_hand", "Switch to left hand")
core.register_cheat_description("HandView", "Render", "hand_view", "Adjust the wielded hand position and scale")
--World
core.register_cheat_description("AutoTNT", "World", "autotnt", "Puts TNT on the ground")
core.register_cheat_description("BlockLava", "World", "blocklava", "Replace lava with the block you're holding")
core.register_cheat_description("BlockWater", "World", "blockwater", "Replace water with the block you're holding")
core.register_cheat_description("Replace", "World", "replace", "When you break a block it gets replaced by the block you're holding")
core.register_cheat_description("Scaffold", "World", "scaffold", "Puts blocks below you")
core.register_cheat_description("ScaffoldPlus", "World", "scaffoldplus", "Puts even more blocks under you")


--SOME SETTINGS

core.register_cheat_setting("Nodelist", "Render", "xray", "xray.nodes", {type="text", size=10})
core.register_cheat_setting("Nodelist", "Render", "enable_node_esp", "enable_node_esp.nodes", {type="text", size=10})
core.register_cheat_setting("Multiplier", "Movement", "step", "step.mult", {type="slider_float", min=1.0, max=3.5, steps=6})
core.register_cheat_setting("Range", "Player", "reach", "reach.range",
	{type="slider_float", min=1.0, max=6.0, steps=100})
core.register_cheat_setting("Flight Speed", "Movement", "free_move", "free_move.speed",
	{type="slider_float", min=0.25, max=8.00, steps=155})
core.register_cheat_setting("JetPack Speed", "Movement", "jetpack", "jetpack.speed",
	{type="slider_float", min=0.25, max=8.00, steps=155})
core.register_cheat_setting("HUD Color", "Client", "hud_color", "globalcolor", {type="text", size=18})
core.register_cheat_setting("Background", "Client", "cheat_hud", "cheat_hud.background", {type="bool"})
core.register_cheat_setting("Reset", "Client", "cheat_hud", "cheat_hud.reset", {type="bool"})
core.register_cheat_setting("HandView", "Render", "hand_view", "hand_view", {type="bool"})
core.register_cheat_setting("X Offset", "Render", "hand_view", "hand_view.x", {type="slider_float", min=-100.0, max=100.0, steps=200})
core.register_cheat_setting("Y Offset", "Render", "hand_view", "hand_view.y", {type="slider_float", min=-100.0, max=100.0, steps=200})
core.register_cheat_setting("Z Offset", "Render", "hand_view", "hand_view.z", {type="slider_float", min=-100.0, max=100.0, steps=200})
core.register_cheat_setting("Scale", "Render", "hand_view", "hand_view.scale", {type="slider_float", min=0.10, max=3.00, steps=58})
core.register_cheat_setting("Type", "Render", "enable_health_esp", "enable_health_esp.type", {type="selectionbox", options={"Health Bar", "Above Head"}})
core.register_cheat_setting("Players Only", "Render", "enable_health_esp", "enable_health_esp.players_only", {type="bool"})
core.register_cheat_setting("Target highlight", "Render", "enable_combat_target_hud", "enable_combat_target_hud.target_highlight", {type="bool"})
core.register_cheat_setting("Target Mode", "Combat", "crystalspam", "crystalspam.target_mode", {type="selectionbox", options={"Players", "Entities", "Both"}})
core.register_cheat_setting("Safe", "Combat", "crystalspam", "crystalspam.safe", {type="bool"})
core.register_cheat_setting("HP", "Render", "nametags", "nametags.hp", {type="bool"})
core.register_cheat_setting("Status Marker", "Render", "nametags", "nametags.status", {type="bool"})
core.register_cheat_setting("Distance", "Render", "nametags", "nametags.distance", {type="bool"})
core.register_cheat_setting("Self", "Render", "nametags", "nametags.self", {type="bool"})
core.register_cheat_setting("Icon Scale", "Render", "nametags", "nametags.icon_scale", {type="slider_float", min=0.50, max=4.00, steps=70})
core.register_cheat_setting("Item names", "Render", "nametags", "nametags.item_names", {type="bool"})
core.register_cheat_setting("Equipment", "Render", "nametags", "nametags.armor", {type="bool"})
core.register_cheat_setting("Wielded Items", "Render", "nametags", "nametags.wielded_items", {type="bool"})
core.register_cheat_setting("Background", "Render", "nametags", "show_nametag_backgrounds", {type="bool"})
core.register_cheat_setting("Height", "Render", "nametags", "nametags.height", {type="slider_int", min=1, max=9, steps = 9});
core.register_cheat_setting("Field Of View", "Render", "fov_setting", "fov.step", {type="slider_int", min=72, max=160, steps = 89});
core.register_cheat_setting("Background", "Client", "equipment_hud", "equipment_hud.background", {type="bool"})
core.register_cheat_setting("Background", "Client", "coords", "coords.background", {type="bool"})
core.register_cheat_setting("Message", "Client", "welcome", "welcome.message", {type="text", size=80})
core.register_cheat_setting("Text Align", "Client", "welcome", "welcome.align", {type="selectionbox", options={"Left", "Center", "Right"}})
core.register_cheat_setting("Text Color", "Client", "welcome", "welcome.color", {type="text", size=18})
core.register_cheat_setting("Background", "Client", "welcome", "welcome.background", {type="bool"})
core.register_cheat_setting("Background", "Client", "ping", "ping.background", {type="bool"})
core.register_cheat_setting("Background", "Client", "clients", "clients.background", {type="bool"})
core.register_cheat_setting("Nether Coords", "Client", "coords", "coords.nether_coords", {type="bool"})
core.register_cheat_setting("Durability", "Client", "equipment_hud", "equipment_hud.durability_mode", {type="selectionbox", options={"Percent", "Dur/Max", "Both"}})
core.register_cheat_setting("Enderchest", "Render", "content_previewer", "content_previewer.enderchest", {type="bool"})
core.register_cheat_setting("Shulker", "Render", "content_previewer", "content_previewer.shulker", {type="bool"})
core.register_cheat_setting("Maps", "Render", "content_previewer", "content_previewer.maps", {type="bool"})
core.register_cheat_setting("No Item Spin", "Client", "lag_optimizer", "lag_optimizer.no_item_spin", {type="bool"})
core.register_cheat_setting("No Hand Animation", "Client", "lag_optimizer",
	"lag_optimizer.no_hand_animation", {type="bool"})

core.register_cheat_setting("Display sunrise", "Render", "custom_skybox", "display_sunrise", {type="bool"})
core.register_cheat_setting("Force custom sky", "Render", "custom_skybox", "force_custom_skybox", {type="bool"})
core.register_cheat_setting("Force render sky", "Render", "custom_skybox", "force_render_skybox", {type="bool"})

core.register_cheat_setting("Min Length", "Render", "enable_tunnel_esp", "tunnel_esp_min_length", {type="slider_int", min=1, max=10, steps=10})
core.register_cheat_setting("Max Width", "Render", "enable_tunnel_esp", "tunnel_esp_max_width", {type="slider_int", min=1, max=5, steps=5})
core.register_cheat_setting("Max Height", "Render", "enable_tunnel_esp", "tunnel_esp_max_height", {type="slider_int", min=1, max=5, steps=5})

local update_interval = 0.25
local timer = 0
local blinktime = 0

local function reset_cheat_hud()
	core.settings:set_bool("cheat_hud", true)
	core.settings:set_bool("cheat_hud.reset", false)
	core.settings:remove("HudElement_Position1_cheathud")
	core.settings:remove("HudElement_Position2_cheathud")
	core.settings:remove("cheat_hud.offset")
	core.settings:remove("cheat_hud.align")
	core.settings:remove("cheat_hud.position")
	core.settings:remove("cheat_hud.mode")
end

local function make_lua_control(control, jump_override)
	return {
		up = control.up or false,
		down = control.down or false,
		left = control.left or false,
		right = control.right or false,
		jump = jump_override ~= nil and jump_override or (control.jump or false),
		aux1 = control.aux1 or false,
		sneak = control.sneak or false,
		zoom = control.zoom or false,
		dig = control.dig or false,
		place = control.place or false,
	}
end

minetest.register_globalstep(function(dtime)
    timer = timer + dtime

	if core.settings:get_bool("blink") then
		blinktime = blinktime + dtime
		core.update_infotext("Blink", "Interact", "blink", math.floor(blinktime * 1000) .. "ms")
		if blinktime > 10 then
			core.settings:set_bool("blink", false)
		end
	else
		blinktime = 0
	end

	if core.settings:get_bool("cheat_hud.reset") then
		reset_cheat_hud()
	end

    if timer >= update_interval then
        timer = 0

        local function format_amount(value)
            local text = string.format("%.2f", tonumber(value) or 0)
            text = text:gsub("0+$", "")
            text = text:gsub("%.$", "")
            return text
        end

        -- Step infotext
        core.update_infotext("Step", "Movement", "step", "Mult: " .. core.settings:get("step.mult"))
        core.update_infotext("Reach", "Player", "reach",
            core.settings:get_bool("reach") and format_amount(core.settings:get("reach.range")) or "")
        core.update_infotext("Flight", "Movement", "free_move",
            core.settings:get_bool("free_move") and format_amount(core.settings:get("free_move.speed")) or "")
        core.update_infotext("JetPack", "Movement", "jetpack",
            core.settings:get_bool("jetpack") and format_amount(core.settings:get("jetpack.speed")) or "")

        -- CombatLog infotext
        core.update_infotext("CombatLog", "Combat", "combatlog", "Min HP: " .. core.settings:get("combatlog.hp"))

        -- FOV infotext
        if core.settings:get_bool("fov_setting") then
            core.update_infotext("FOV", "Render", "fov_setting", core.settings:get("fov.step"))
        else
            core.update_infotext("FOV", "Render", "fov_setting", "")
        end

        -- Nametags infotext
        local nametags_enabled = core.settings:get_bool("nametags")
        local nametags_hp = core.settings:get_bool("nametags.hp")
        local nametags_status = core.settings:get_bool("nametags.status")
        local nametags_distance = core.settings:get_bool("nametags.distance")
        if nametags_enabled then
            core.update_infotext("Nametags", "Render", "nametags", "")
        end

		--Scaffold infotext
		if core.settings:get_bool("scaffold") then
			if core.settings:get("scaffold.mode") == "Silent" then
				core.update_infotext("Scaffold", "World", "scaffold", "Silent")
			else
				core.update_infotext("Scaffold", "World", "scaffold", "Blatant")
			end
		end
		--ScaffoldPlus infotext
		if core.settings:get_bool("scaffold_plus") then
			if core.settings:get("scaffold_plus.mode") == "Silent" then
				core.update_infotext("ScaffoldPlus", "World", "scaffold_plus", "Silent")
			else
				core.update_infotext("ScaffoldPlus", "World", "scaffold_plus", "Blatant")
			end
		end
    end
end)
