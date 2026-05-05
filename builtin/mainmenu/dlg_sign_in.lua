LOGIN_USERNAME_SETTING_NAME = "login_username"
LOGIN_PASSWORD_SETTING_NAME = "login_password"

local function get_formspec(dialogdata)
	return table.concat({
		"formspec_version[6]",
		"size[5,6]",
		"bgcolor[;neither;]",
		"box[0,0;5,6;#1f2328]",
		
        "image[0,0;5,1;" .. core.formspec_escape(defaulttexturedir .. "menu_header.png") .. "]",

		"style_type[image_button;border=false;textcolor=white;font_size=*2;padding=0;font=bold;" ..
		"bgimg=" .. core.formspec_escape(defaulttexturedir .. "menu_button.png") .. ";" ..
		"bgimg_hovered=" .. core.formspec_escape(defaulttexturedir .. "menu_button_hovered.png") .. "]",

		"image_button[0,1.6;5,0.8;;login;" .. fgettext("Log In") .. "]",
		"image_button[0,2.5;5,0.8;;create;" .. fgettext("Create Account") .. "]",
		"image_button[0,3.4;5,0.8;;guest;" .. fgettext("Continue as Guest") .. "]",
		"image_button[0,4.3;5,0.8;;exit;" .. fgettext("Exit") .. "]"
	}, "\n")
end

local function buttonhandler(this, fields)
	if fields.login then
		this:delete()
		local mainmenu = ui.find_by_name("mainmenu")
		local dlg = create_login_dialog()
		dlg:set_parent(mainmenu)
		mainmenu:hide()
		dlg:show()
		ui.update()
		return true

	elseif fields.create then
		this:delete()
		local mainmenu = ui.find_by_name("mainmenu")
		local dlg = create_register_account_dialog()
		dlg:set_parent(mainmenu)
		mainmenu:hide()
		dlg:show()
		ui.update()
		return true
	elseif fields.guest then
		cache_settings:set(LOGIN_PASSWORD_SETTING_NAME, "")
		cache_settings:set(LOGIN_USERNAME_SETTING_NAME, "Guest")
		core.settings:set(SESSION_TOKEN_SETTING_NAME, "")
		fetch_capes()
		this:delete()
		return true
	elseif fields.exit then
		core.close()
		return true
	end
end

local function eventhandler(event)
	if event == "DialogShow" then
		mm_game_theme.set_engine()
		mm_game_theme.clear_single("header")
		return true
	elseif event == "MenuQuit" then
		core.close()
		return true
	end
	return false
end

function create_sign_in_dialog()
	local dlg = dialog_create("dlg_sign_in", get_formspec, buttonhandler, eventhandler)
	return dlg
end


function show_sign_in_screen()
	local username = cache_settings:get(LOGIN_USERNAME_SETTING_NAME)
	local password = cache_settings:get(LOGIN_PASSWORD_SETTING_NAME)
	if username == "Guest" then
		core.settings:set(SESSION_TOKEN_SETTING_NAME, "")
		return
	end
	if username and username ~= "" and password and password ~= "" then
		if not verify_login_credentials(username, password) then
			local mainmenu = ui.find_by_name("mainmenu")
			local dlg = create_sign_in_dialog()
			dlg:set_parent(mainmenu)
			mainmenu:hide()
			dlg:show()
			ui.update()
		end
	else
		local mainmenu = ui.find_by_name("mainmenu")
		local dlg = create_sign_in_dialog()
		dlg:set_parent(mainmenu)
		mainmenu:hide()
		dlg:show()
		ui.update()
	end
end
