-- globals
local capes_list, selected_cape_idx, selected_idx
local useless_placeholder_setting = 0

selected_idx = tonumber(core.settings:get("cosmetics_dropdown_idx")) or 3

local cape_cache_dir = core.get_cache_path() .. DIR_DELIM .. "capes"
assert(core.create_dir(cape_cache_dir))

local function get_cape_preview(cape_id, base64_data)
    local filepath = cape_cache_dir .. DIR_DELIM .. cape_id .. ".png"

    -- Return cached file if it exists
    local f = io.open(filepath, "r")
    if f then f:close() return filepath end

    -- Write PNG from base64
    local data = core.decode_base64(base64_data)
    local file, err = io.open(filepath, "wb")
    if not file then
        core.log("error", "Failed to write cape preview: " .. err)
        return defaulttexturedir .. "no_screenshot.png"
    end
    file:write(data)
    file:close()

    return filepath
end


-- Constants
local CAPE_WIDTH = 2        -- width of each cape image
local CAPE_HEIGHT = 3.2     -- height of each cape image (includes space for label)
local GRID_COLUMNS = 3      -- number of columns in the grid
local GRID_PADDING = 0.7  -- spacing between items
local SCROLL_HEIGHT = 7   -- height of scrollable area
local VISIBLE_CAPES = 3 -- Number of capes to show at once


local start_index = 1
local last_capes
-- Returns the formspec for displaying capes in a scrollable 3-column grid
local function get_formspec(dlgview, scroll_offset)
    scroll_offset = scroll_offset or 0

    -- Load capes if not already loaded
    if capes_list == nil or last_capes ~= networking.Capes then
        useless_placeholder_setting = 0
        last_capes = networking.Capes
        if networking.Capes == nil then networking.Capes = {} end
        capes_list = {}
        for id, data in pairs(networking.Capes) do
            table.insert(capes_list, {
                id = id,
                full_id = data.CapeID,
                texture = data.CapeTexture,
                preview = data.CapePreview,
            })
            if data.CapeID == networking.SelectedCape then
                selected_cape_idx = id
            end
        end
        table.sort(capes_list, function(a, b) return a.id < b.id end)
    end

    local retval = "size[8.5,8.5,true]"

    local start_x = 0.5
    local start_y = 2
    local x, y = start_x, start_y

    local dropdown_options = {"Public","Private"}

    local escaped_options = {}
    for _, opt in ipairs(dropdown_options) do
        table.insert(escaped_options, core.formspec_escape(opt))
    end

    -- Only show a slice of the capes_list based on start_index
    local end_index = math.min(start_index + VISIBLE_CAPES - 1, #capes_list)
    for i = start_index, end_index do
        local cape = capes_list[i]
        local is_selected = (i == selected_cape_idx)

        local bg_color = is_selected and "gray" or "black"

        -- Background box behind image + button
        local box_w = CAPE_WIDTH
        local box_h = CAPE_HEIGHT + 1.0
        retval = retval .. "box[" .. x .. "," .. y .. ";" .. box_w .. "," .. box_h .. ";" .. bg_color .. "]"

        -- Cape preview image
        local preview_path = get_cape_preview(cape.full_id, cape.preview)
        retval = retval .. "image[" .. (x + 0.2) .. "," .. (y + 0.2) ..
                            ";" .. CAPE_WIDTH .. "," .. CAPE_HEIGHT .. ";" ..
                            core.formspec_escape(preview_path) .. "]"

        local text = is_selected and "Selected" or "Select"
        retval = retval .. "button[" .. (x + 0.1) .. "," .. (y + CAPE_HEIGHT + 0.15) ..
                            ";" .. CAPE_WIDTH .. ",0.8;" ..
                            "select_" .. cape.id .. ";" .. text .. "]"

        -- Advance x for next cape
        x = x + CAPE_WIDTH + GRID_PADDING

        useless_placeholder_setting = 1
    end

    -- Navigation buttons
    if start_index > 1 then
        retval = retval .. "button[0.2,6.5;2,1;prev;← Prev]"
    end
    if end_index < #capes_list then
        retval = retval .. "button[6.2,6.5;2,1;next;Next →]"
    end


    -- Disable/Enable dropdown
    retval = retval .. "dropdown[5.7,0.7;2.5;enable_cosmetics;" ..
    table.concat(escaped_options, ",") .. ";" .. selected_idx .. "]"

    retval = retval ..
		"container[0,4.5]" ..
		"box[0,3;8.3,1;#cc5801]" ..
		"textarea[0.5,3.1;8.3,1;;;It is recommended to set cosmetics to private in servers where you shouldn't be cheating, since other Lunarchy users may spot you]" ..
		"container_end[]"

    retval = retval .. "label[0.25,0.15;Select a Cape]"
    
    retval = retval .. "label[5.9,0.15;Cosmetic Visibilty]"

    -- Back button
    retval = retval .. "button[2.25,6.5;4,1;back;Back]"
    if useless_placeholder_setting == 0 then
        retval = retval ..
	    	"container[0,-0.5]" ..
	    	"box[2.1,3;4,2;#cc5801]" ..
	    	"textarea[2.5,3.1;4,2.2;;;In order to use cosmetics, please log in. In case you're already logged in, you may have to close and open the client again to refresh this menu]" ..
	    	"container_end[]"
    end

    return retval
end

-- Handle double-click on a cape
local function handle_cape_doubleclick(cape)
    -- Set the selected cape globally
	if set_selected_cape(cape.full_id) then
		selected_cape_idx = cape.id
	end
end

-- Handle formspec buttons/events
local function handle_buttons(dlgview, fields)
    for i, cape in ipairs(capes_list) do
        if fields["select_" .. i] then
            handle_cape_doubleclick(cape)
            return true
        end
    end

    if fields.back then
        dlgview:delete()
        return true
    end

    if fields.prev then
        start_index = math.max(1, start_index - 1)
        return true
    elseif fields.next then
        start_index = math.min(#capes_list - VISIBLE_CAPES + 1, start_index + 1)
        return true
    end

    if fields.enable_cosmetics then
            if fields.enable_cosmetics == "Public" then
                selected_idx = 1
                core.settings:set_bool("announce_join", true)
            elseif fields.enable_cosmetics == "Private" then
                selected_idx = 2
                core.settings:set_bool("announce_join", false)
            end

            core.settings:set("cosmetics_dropdown_idx", tostring(selected_idx))
        end



    return false
end



function create_cosmetics_dlg()
	mm_game_theme.set_engine()
	local retval = dialog_create("cosmetics",
					get_formspec,
					handle_buttons,
					nil)
	return retval
end
