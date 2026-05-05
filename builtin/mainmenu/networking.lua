local API_SERVER_ADDRESS = "http://teamacedia.baselinux.net:22222/"
--local API_SERVER_ADDRESS = "http://127.0.0.1:22222/"

SESSION_TOKEN_SETTING_NAME = "session_token"
TEAMACEDIA_USERNAME_SETTING_NAME = "teamacedia_username"

networking = {}

networking.Capes = {}
networking.SelectedCape = ""

function verify_login_credentials(username, password)
	local http = core.get_http_api()
	if not http then
		return false
	end

	local handle = http.fetch_async({
		url = API_SERVER_ADDRESS .. "api/login/",
		timeout = 15,
		post_data = core.write_json({
			username = username,
			password = password
		}),
		extra_headers = {
			"Content-Type: application/json"
		}
	})

	local result = http.fetch_async_get(handle)
	while not result.completed do
		result = http.fetch_async_get(handle)
	end

	if result.succeeded and result.code == 200 then
		-- Parse JSON response to get the session token
		local ok, data = pcall(core.parse_json, result.data)
		if ok and data.session_token then
			core.settings:set(SESSION_TOKEN_SETTING_NAME, data.session_token)
			core.settings:set(TEAMACEDIA_USERNAME_SETTING_NAME, username)
			fetch_capes()
			return true
		end
	end

	-- Failed login
	return false
end

function register_account(login_username, password)
	local http = core.get_http_api()
	if not http then
		return "HTTP API not available."
	end

	local handle = http.fetch_async({
		url = API_SERVER_ADDRESS .. "api/register/",
		timeout = 5,
		post_data = core.write_json({
			username = login_username,
			password = password
		}),
		extra_headers = {
			"Content-Type: application/json"
		}
	})

	local result = http.fetch_async_get(handle)
	while not result.completed do
		result = http.fetch_async_get(handle)
	end

	if result.succeeded and result.code == 201 then
		return true
	else
		
		return result and result.data or "Network error: Failed to contact login server."
	end
end

function login_account(login_username, password)
	local http = core.get_http_api()
	if not http then
		return "HTTP API not available."
	end

	local handle = http.fetch_async({
		url = API_SERVER_ADDRESS .. "api/login/",
		timeout = 5,
		post_data = core.write_json({
			username = login_username,
			password = password
		}),
		extra_headers = {
			"Content-Type: application/json"
		}
	})
	-- Poll until request completes
	local result = http.fetch_async_get(handle)
	while not result.completed do
		result = http.fetch_async_get(handle)
	end

	-- Process result

	if result.succeeded and result.code == 200 then
		-- Parse JSON response to get the session token
		local ok, data = pcall(core.parse_json, result.data)
		if ok and data.session_token then
			core.settings:set(SESSION_TOKEN_SETTING_NAME, data.session_token)
			core.settings:set(TEAMACEDIA_USERNAME_SETTING_NAME, login_username)
		end
		cache_settings:set(LOGIN_PASSWORD_SETTING_NAME, password)
		cache_settings:set(LOGIN_USERNAME_SETTING_NAME, login_username)
		fetch_capes()
		return true
	else
		return result and result.data or "Network error: Failed to contact login server."
	end
end

function fetch_capes()
	networking.Capes = {}
	local session_token = core.settings:get(SESSION_TOKEN_SETTING_NAME)

	local http = core.get_http_api()
	if not http then
		return
	end

	local handle = http.fetch_async({
		url = API_SERVER_ADDRESS .. "api/users/capes/",
		timeout = 15,
		post_data = core.write_json({
			token = session_token
		}),
		extra_headers = {
			"Content-Type: application/json"
		}
	})

	-- Poll until request completes
	local result = http.fetch_async_get(handle)
	while not result.completed do
		result = http.fetch_async_get(handle)
	end

	if result.succeeded and result.code == 200 then
		local ok, data = pcall(core.parse_json, result.data)
		if ok and type(data) == "table" then
			networking.Capes = {}

			for _, c in ipairs(data) do
				table.insert(networking.Capes, {
					CapeID      	= c.CapeID,
					CapeTexture 	= c.CapeTexture,
					CapePreview 	= c.CapePreview,
					CapeAnimLength 	= c.CapeAnimLength
				})
			end
		end
	end

	core.log("error", dump(networking.Capes))
	get_selected_cape()
end

function get_selected_cape()
	local session_token = core.settings:get(SESSION_TOKEN_SETTING_NAME)

	local http = core.get_http_api()
	if not http then
		return
	end

	local handle = http.fetch_async({
		url = API_SERVER_ADDRESS .. "api/users/capes/get_selected/",
		timeout = 15,
		post_data = core.write_json({
			token = session_token
		}),
		extra_headers = {
			"Content-Type: application/json"
		}
	})

	-- Poll until request completes
	local result = http.fetch_async_get(handle)
	while not result.completed do
		result = http.fetch_async_get(handle)
	end

	if result.succeeded and result.code == 200 then
		local ok, data = pcall(core.parse_json, result.data)
		if ok and type(data) == "table" then
			networking.SelectedCape = data.selected_cape
		end
	end
end

function set_selected_cape(cape_id)

	local session_token = core.settings:get(SESSION_TOKEN_SETTING_NAME)

	local http = core.get_http_api()
	if not http then
		return
	end

	local handle = http.fetch_async({
		url = API_SERVER_ADDRESS .. "api/users/capes/set_selected/",
		timeout = 15,
		post_data = core.write_json({
			token = session_token,
			cape = cape_id
		}),
		extra_headers = {
			"Content-Type: application/json"
		}
	})

	-- Poll until request completes
	local result = http.fetch_async_get(handle)
	while not result.completed do
		result = http.fetch_async_get(handle)
	end

	if result.succeeded and result.code == 200 then
		local ok, data = pcall(core.parse_json, result.data)
		if ok then
			networking.SelectedCape = cape_id
			return true
		end
	end
	return false
end
