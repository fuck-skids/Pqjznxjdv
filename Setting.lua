local httpService = game:GetService('HttpService')

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings'
	SaveManager.Ignore = {}
	-- Community configs (empty by default; fill from main script)
	SaveManager.CommunityConfigs = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = 'Toggle', idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if Toggles[idx] then 
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue({ data.key, data.mode })
				end
			end,
		},
		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if not name then
			return false, 'no config file is selected'
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'

		local data = {
			objects = {}
		}

		for idx, toggle in next, Toggles do
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
		end

		for idx, option in next, Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if not name then
			return false, 'no config file is selected'
		end
		
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, 'decode error' end

		for idx, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() self.Parser[option.type].Load(option.idx, option) end) -- task.spawn() so the config loading wont get stuck.
			end
		end

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. '/themes',
			self.Folder .. '/settings'
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. '/settings')

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				-- i hate this but it has to be done ...

				local pos = file:find('.json', 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1))
				end
			end
		end
		
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load autoload config: ' .. err)
			end

			self.Library:Notify(string.format('Auto loaded config %q', name))
		end
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local section = tab:AddRightGroupbox('Configuration')

		section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })
		section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

		section:AddDivider()

		section:AddButton('Create config', function()
			local name = Options.SaveManager_ConfigName.Value

			if name:gsub(' ', '') == '' then 
				return self.Library:Notify('Invalid config name (empty)', 2)
			end

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save config: ' .. err)
			end

			self.Library:Notify(string.format('Created config %q', name))

			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end):AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load config: ' .. err)
			end

			self.Library:Notify(string.format('Loaded config %q', name))
		end)

		section:AddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite config: ' .. err)
			end

			self.Library:Notify(string.format('Overwrote config %q', name))
		end)

		section:AddButton('Refresh list', function()
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		section:AddButton('Set as autoload', function()
			local name = Options.SaveManager_ConfigList.Value
			writefile(self.Folder .. '/settings/autoload.txt', name)
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			self.Library:Notify(string.format('Set %q to auto load', name))
		end)

		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
		end

		-- Build Cloud Upload section directly below Configuration on the right side
		self:BuildUploadSection(tab)
		-- community configs (empty until RegisterCommunityConfig from main script)
		pcall(function() self:BuildCommunitySection(tab) end)

		SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
	end

	-- ── Cloud / Store Config Upload System ────────────────────────
	local STORE_URL = "https://config-hub--z1bje.replit.app/api"
	local RATE_FILE = "creepcc/entities/zone_last_upload.txt"
	local HWID_FILE = "creepcc/entities/zone_hwid.txt"

	local function ensureDirectories()
		if not isfolder("creepcc") then pcall(makefolder, "creepcc") end
		if not isfolder("creepcc/entities") then pcall(makefolder, "creepcc/entities") end
	end

	local function execRequest(options)
		local fn = (syn and syn.request) or (http and http.request) or (type(request) == "function" and request) or nil
		if not fn then return nil end
		local ok, res = pcall(fn, options)
		return (ok and res) or nil
	end

	local function storePost(path, body)
		local res = execRequest({
			Url = STORE_URL .. path,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = httpService:JSONEncode(body),
		})
		if res then return res.StatusCode, res.Body end
		return nil, nil
	end

	local function getHWID()
		ensureDirectories()
		if isfile(HWID_FILE) then
			local cached = readfile(HWID_FILE)
			if cached and #cached > 4 then return cached end
		end
		local id = (type(syn) == "table" and type(syn.get_hwid) == "function" and syn.get_hwid())
			or (type(get_hwid) == "function" and get_hwid())
			or tostring(game:GetService("Players").LocalPlayer.UserId)
		pcall(function() writefile(HWID_FILE, tostring(id)) end)
		return tostring(id)
	end

	local HOUR = 3600
	local function getSecondsUntilNextUpload()
		ensureDirectories()
		if not isfile(RATE_FILE) then return 0 end
		local lastTime = tonumber(readfile(RATE_FILE))
		if not lastTime then return 0 end
		local elapsed = os.time() - lastTime
		return elapsed >= HOUR and 0 or (HOUR - elapsed)
	end

	local function markUploadTime()
		ensureDirectories()
		pcall(function() writefile(RATE_FILE, tostring(os.time())) end)
	end

	function SaveManager:BuildUploadSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local UploadGroup = tab:AddRightGroupbox("Upload")

		UploadGroup:AddInput("UploadName", {
			Text = "Config Name",
			Default = "",
			Placeholder = "e.g. my_rage_config",
		})
		UploadGroup:AddInput("UploadAuthor", {
			Text = "Your Name",
			Default = "",
			Placeholder = "your username",
		})
		UploadGroup:AddInput("UploadDesc", {
			Text = "Description",
			Default = "",
			Placeholder = "optional",
		})

		local localCfgDropdown = nil
		local function refreshLocalConfigs()
			local cfgs = self:RefreshConfigList() or {}
			if localCfgDropdown then
				localCfgDropdown:SetValues(cfgs)
				if #cfgs > 0 then
					localCfgDropdown:SetValue(cfgs[1])
				end
			end
		end

		localCfgDropdown = UploadGroup:AddDropdown("UploadLocalDropdown", {
			Text = "Select Config",
			Default = 1,
			Values = self:RefreshConfigList() or { "" },
		})

		UploadGroup:AddButton("Refresh Configs", function()
			refreshLocalConfigs()
			self.Library:Notify("Local config list refreshed")
		end)

		UploadGroup:AddButton("Upload to Store", function()
			local selectedCfg = Options.UploadLocalDropdown.Value or ""
			local name = Options.UploadName.Value or ""
			local author = Options.UploadAuthor.Value or ""
			local desc = Options.UploadDesc.Value or ""

			if selectedCfg == "" then
				self.Library:Notify("Select a local config first")
				return
			end
			if name == "" then
				self.Library:Notify("Enter a config name")
				return
			end
			if author == "" then
				self.Library:Notify("Enter your name")
				return
			end

			local wait = getSecondsUntilNextUpload()
			if wait > 0 then
				local mins = math.ceil(wait / 60)
				self.Library:Notify(string.format("Rate limited — wait %d more minute%s", mins, mins == 1 and "" or "s"))
				return
			end

			local filePath = self.Folder .. "/settings/" .. selectedCfg .. ".json"
			if not isfile(filePath) then
				self.Library:Notify("Config file not found: " .. selectedCfg)
				return
			end

			local ok2, configData = pcall(function() return httpService:JSONDecode(readfile(filePath)) end)
			if not ok2 or not configData then
				self.Library:Notify("Failed to read config file")
				return
			end

			local status, raw = storePost("/configs", {
				name = name,
				author = author,
				description = desc,
				hwid = getHWID(),
				data = configData,
			})

			if not raw then
				self.Library:Notify("Upload failed — no response")
				return
			end

			local ok3, decoded = pcall(function() return httpService:JSONDecode(raw) end)
			if status == 429 then
				self.Library:Notify((ok3 and decoded and decoded.error) or "Rate limited")
				return
			end

			if status == 201 and ok3 and decoded and decoded.id then
				markUploadTime()
				self.Library:Notify(string.format("Uploaded! ID %d — share with friends", decoded.id))
			else
				self.Library:Notify((ok3 and decoded and decoded.error) or "Upload failed")
			end
		end)

		UploadGroup:AddButton("Copy Config Hub URL", function()
			local fn = setclipboard or toclipboard
			if fn then
				fn("https://config-hub--z1bje.replit.app")
				self.Library:Notify("Copied Config Hub URL to clipboard!")
			else
				self.Library:Notify("Your executor does not support clipboard copying.")
			end
		end)

		SaveManager:SetIgnoreIndexes({ 'UploadName', 'UploadAuthor', 'UploadDesc', 'UploadLocalDropdown' })

		task.spawn(function()
			task.wait(0.5)
			pcall(refreshLocalConfigs)
		end)
	end

	-- Optional helper to build both Upload (left) and Config (right) tabs at once
	function SaveManager:BuildFullConfigTab(window)
		local ConfigsTab = window:AddTab("Configs")
		self:BuildUploadSection(ConfigsTab)
		self:BuildConfigSection(ConfigsTab)
		return ConfigsTab
	end

	SaveManager:BuildFolderTree()
end


	function SaveManager:RegisterCommunityConfig(name, url)
		assert(type(name) == 'string' and name ~= '', 'name required')
		assert(type(url) == 'string' and url ~= '', 'url required')
		self.CommunityConfigs = self.CommunityConfigs or {}
		-- replace if same name
		for i, cfg in ipairs(self.CommunityConfigs) do
			if cfg.Name == name then
				self.CommunityConfigs[i] = { Name = name, Url = url }
				self:_mfRefreshCommunityDropdown()
				return
			end
		end
		table.insert(self.CommunityConfigs, { Name = name, Url = url })
		self:_mfRefreshCommunityDropdown()
	end

	function SaveManager:ClearCommunityConfigs()
		self.CommunityConfigs = {}
		self:_mfRefreshCommunityDropdown()
	end

	function SaveManager:_mfRefreshCommunityDropdown()
		if not Options or not Options.CommunityConfigList then return end
		local names = {}
		for _, cfg in ipairs(self.CommunityConfigs or {}) do
			table.insert(names, cfg.Name)
		end
		pcall(function()
			Options.CommunityConfigList:SetValues(names)
			Options.CommunityConfigList:SetValue(nil)
		end)
	end

	function SaveManager:BuildCommunitySection(tab)
		assert(self.Library, 'Must set SaveManager.Library')
		self.CommunityConfigs = self.CommunityConfigs or {}

		local section = tab:AddLeftGroupbox('community configs')
		local names = {}
		for _, cfg in ipairs(self.CommunityConfigs) do
			table.insert(names, cfg.Name)
		end

		section:AddDropdown('CommunityConfigList', {
			Text = 'config',
			Values = names, -- empty until RegisterCommunityConfig
			AllowNull = true,
		})

		section:AddButton('Load community config', function()
			local selected = Options.CommunityConfigList and Options.CommunityConfigList.Value
			if not selected or selected == '' then
				return self.Library:Notify('No community config selected', 2)
			end
			local url = nil
			for _, cfg in ipairs(self.CommunityConfigs) do
				if cfg.Name == selected then
					url = cfg.Url
					break
				end
			end
			if not url then
				return self.Library:Notify('Config URL not found', 2)
			end
			local ok, body = pcall(function()
				return game:HttpGet(url)
			end)
			if not ok or not body or body == '' then
				return self.Library:Notify(string.format('Failed to load community config: %q', selected), 3)
			end
			-- body may be JSON config data or a name pointing to local — try decode + apply
			local httpService = game:GetService('HttpService')
			local ok2, data = pcall(function() return httpService:JSONDecode(body) end)
			if not ok2 or type(data) ~= 'table' then
				return self.Library:Notify(string.format('Failed to parse community config: %q', selected), 3)
			end
			-- Apply like SaveManager:Load but from table
			local applied = 0
			if data.objects then
				for _, option in ipairs(data.objects) do
					if option.type and self.Parser[option.type] then
						pcall(function()
							self.Parser[option.type].Load(option.idx, option)
							applied = applied + 1
						end)
					end
				end
			else
				-- raw { idx = {type, value}, ... } fallback
				for idx, option in pairs(data) do
					if type(option) == 'table' and option.type and self.Parser[option.type] then
						pcall(function()
							self.Parser[option.type].Load(option.idx or idx, option)
							applied = applied + 1
						end)
					end
				end
			end
			self.Library:Notify(string.format('Loaded community config %q (%d settings)', selected, applied), 3)
		end)

		section:AddButton('Refresh list', function()
			self:_mfRefreshCommunityDropdown()
		end)

		SaveManager:SetIgnoreIndexes({ 'CommunityConfigList' })
	end



	-- ============================================================
	-- Full UE-style Settings tab (Menu / Notifications / Background)
	-- Call: SaveManager:BuildUESettings(Tabs.Settings)
	-- ============================================================
	function SaveManager:BuildUESettings(tab)
		assert(self.Library, 'Must set SaveManager.Library')
		local Library = self.Library

		-- ---------- Menu ----------
		local MenuGroup = tab:AddLeftGroupbox('Menu')

		MenuGroup:AddLabel('Menu keybind'):AddKeyPicker('MenuKeybind', {
			Default = 'RightShift',
			NoUI = true,
			Text = 'Menu keybind',
			Modes = { 'Toggle' },
		})

		MenuGroup:AddToggle('KeybindMenu', {
			Text = 'Keybind Menu',
			Default = true,
			Tooltip = 'Shows Keybinds',
			Callback = function(v)
				Library.KeypickerListVisible = v and true or false
				if Library.KeybindFrame then
					-- visibility also driven by RefreshKeybinds content
					if Library.RefreshKeybinds then
						pcall(function() Library:RefreshKeybinds() end)
					end
					if not v then
						Library.KeybindFrame.Visible = false
					end
				end
			end,
		})

		MenuGroup:AddSlider('KeybindMenuTransparency', {
			Text = 'Menu Transparency',
			Default = 100,
			Min = 0,
			Max = 100,
			Suffix = '%',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				if Library.SetKeybindMenuTransparency then
					Library:SetKeybindMenuTransparency(v)
				else
					local t = 1 - ((tonumber(v) or 100) / 100)
					if Library.KeybindFrame then
						pcall(function() Library.KeybindFrame.BackgroundTransparency = t end)
					end
					if Library.KeybindInner then
						pcall(function() Library.KeybindInner.BackgroundTransparency = t end)
					end
				end
			end,
		})

		MenuGroup:AddDropdown('KeybindMenuValue', {
			Text = 'Keybind Menu Mode',
			Values = { 'All', 'Active', 'Toggled' },
			Default = 1,
			Multi = false,
			Callback = function(v)
				if Library.SetKeybindMode then
					pcall(function() Library:SetKeybindMode(v) end)
				else
					Library.KeybindMode = v
					if Library.RefreshKeybinds then
						pcall(function() Library:RefreshKeybinds() end)
					end
				end
			end,
		})

		MenuGroup:AddButton('Unload', function()
			if Library.Unload then
				pcall(function() Library:Unload() end)
			elseif getgenv().Library and getgenv().Library.Unload then
				pcall(function() getgenv().Library:Unload() end)
			end
		end)

		-- ---------- Notifications ----------
		local NotifGroup = tab:AddLeftGroupbox('Notifications')

		NotifGroup:AddToggle('NotificationClips', {
			Text = 'Clip Descendants',
			Default = true,
			Tooltip = 'if enabled, will hide notifications past a certain point',
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.ClipDescendants = v and true or false
				if Library.UpdateNotifAlignment then
					Library.UpdateNotifAlignment()
				end
			end,
		})

		local clipDep = NotifGroup:AddDependencyBox()
		clipDep:SetupDependencies({ { Toggles.NotificationClips, true } })
		clipDep:AddSlider('NotificationClipsDistance', {
			Text = 'Clip Past Distance',
			Default = 200,
			Min = 100,
			Max = 1000,
			Suffix = 'px',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.ClipDistance = v
				if Library.NotificationArea then
					if Library.NotifyConfig.ClipDescendants then
						Library.NotificationArea.Size = UDim2.fromOffset(300, v)
					end
				end
				if Library.UpdateNotifAlignment then
					Library.UpdateNotifAlignment()
				end
			end,
		})

		NotifGroup:AddToggle('NotificationColors', {
			Text = 'Force Color',
			Default = false,
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.ForceColor = v and true or false
			end,
		})

		-- color pickers (optional force palette)
		NotifGroup:AddLabel('Main Color'):AddColorPicker('NotificationColorsMain', {
			Default = Library.MainColor or Color3.fromRGB(30, 30, 30),
		})
		NotifGroup:AddLabel('Accent Color'):AddColorPicker('NotificationColorsAccent', {
			Default = Library.AccentColor or Color3.fromRGB(0, 150, 255),
		})
		NotifGroup:AddLabel('Outline Color'):AddColorPicker('NotificationColorsOutline', {
			Default = Library.OutlineColor or Color3.fromRGB(60, 60, 60),
		})
		NotifGroup:AddLabel('Font Color'):AddColorPicker('NotificationColorsFont', {
			Default = Library.FontColor or Color3.fromRGB(255, 255, 255),
		})

		NotifGroup:AddButton('copy colors', function()
			if Options.NotificationColorsMain and Library.MainColor then
				Options.NotificationColorsMain:SetValueRGB(Library.MainColor)
			end
			if Options.NotificationColorsAccent and Library.AccentColor then
				Options.NotificationColorsAccent:SetValueRGB(Library.AccentColor)
			end
			if Options.NotificationColorsOutline and Library.OutlineColor then
				Options.NotificationColorsOutline:SetValueRGB(Library.OutlineColor)
			end
			if Options.NotificationColorsFont and Library.FontColor then
				Options.NotificationColorsFont:SetValueRGB(Library.FontColor)
			end
			Library:Notify('Copied theme colors to notification colors', 2)
		end)

		NotifGroup:AddSlider('NotificationPositionX', {
			Text = 'Position X',
			Default = 0,
			Min = 0,
			Max = 100,
			Suffix = '%',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.PositionXPct = v
				if Library.UpdateNotifAlignment then Library.UpdateNotifAlignment() end
			end,
		})

		NotifGroup:AddSlider('NotificationPositionY', {
			Text = 'Position Y',
			Default = 60,
			Min = 0,
			Max = 100,
			Suffix = '%',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.PositionYPct = v
				if Library.UpdateNotifAlignment then Library.UpdateNotifAlignment() end
			end,
		})

		NotifGroup:AddSlider('NotificationTransparency', {
			Text = 'Transparency',
			Default = 25,
			Min = 0,
			Max = 100,
			Suffix = '%',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.Transparency = v
				if Library.SetNotifyTransparency then
					Library:SetNotifyTransparency(v)
				end
			end,
		})

		NotifGroup:AddDropdown('NotificationAnchorStyle', {
			Text = 'Alignment',
			Values = { 'Left', 'Right', 'Center' },
			Default = 3,
			Multi = false,
			Tooltip = 'how the text is positioned',
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.Alignment = v
				if Library.UpdateNotifAlignment then Library.UpdateNotifAlignment() end
			end,
		})

		NotifGroup:AddDropdown('NotificationBarStyle', {
			Text = 'Bar Side',
			Values = { 'Left', 'Right', 'Top', 'Bottom' },
			Default = 4,
			Multi = false,
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.BarSide = v
			end,
		})

		NotifGroup:AddDropdown('NotificationStyleSortOrder', {
			Text = 'Sort Order',
			Values = { 'Text Length', 'Default' },
			Default = 2,
			Multi = false,
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.SortOrder = v
			end,
		})

		NotifGroup:AddSlider('NotifyDuration', {
			Text = 'Duration',
			Default = 5,
			Min = 1,
			Max = 15,
			Suffix = 's',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.Duration = v
				if Library.SetNotifyDuration then Library:SetNotifyDuration(v) end
			end,
		})

		NotifGroup:AddButton('Send Notification', function()
			Library:Notify('Test notification', Library.NotifyConfig and Library.NotifyConfig.Duration or 5)
		end)

		NotifGroup:AddButton('Send Center Notification', function()
			if Library.NotifyBottomCenter then
				Library:NotifyBottomCenter('Test center notification', Library.NotifyCenterConfig and Library.NotifyCenterConfig.Duration or 5)
			else
				Library:Notify('Center notify not available', 3)
			end
		end)

		-- Center-specific transparency / duration
		NotifGroup:AddSlider('NotificationCenterTransparency', {
			Text = 'Center Transparency',
			Default = 25,
			Min = 0,
			Max = 100,
			Suffix = '%',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				Library.NotifyCenterConfig = Library.NotifyCenterConfig or {}
				Library.NotifyCenterConfig.Transparency = v
				if Library.SetNotifyCenterTransparency then
					Library:SetNotifyCenterTransparency(v)
				end
			end,
		})

		NotifGroup:AddSlider('NotificationCenterPositionY', {
			Text = 'Center Position Y',
			Default = 85,
			Min = 0,
			Max = 100,
			Suffix = '%',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				Library.NotifyCenterConfig = Library.NotifyCenterConfig or {}
				Library.NotifyCenterConfig.PositionYPct = v
				if Library.SetNotifyCenterPositionPct then
					Library:SetNotifyCenterPositionPct(v)
				elseif Library.UpdateNotifCenterArea then
					Library:UpdateNotifCenterArea()
				end
			end,
		})

		-- ---------- Background (3D rotating item) ----------
		local BgGroup = tab:AddRightGroupbox('Background')

		BgGroup:AddToggle('MenuBackgroundEnabled', {
			Text = 'Enable Background',
			Default = true,
			Callback = function(v)
				if Library.SetMenuBackgroundEnabled then
					Library:SetMenuBackgroundEnabled(v)
				end
			end,
		})

		BgGroup:AddDropdown('ItemType', {
			Text = 'Background Item',
			Values = { 'None', 'Unnamed Enhancements' },
			Default = 1,
			Multi = false,
			Callback = function(v)
				Library.ItemType = v
				if Library.SetMenuBackgroundItem then
					Library:SetMenuBackgroundItem(v)
				end
			end,
		})

		BgGroup:AddInput('ItemTypeCustom', {
			Text = 'Custom item name',
			Default = '',
			Placeholder = 'Model name in ReplicatedStorage...',
			Callback = function(v)
				if v and v ~= '' then
					Library.ItemType = v
					if Library.SetMenuBackgroundItem then
						Library:SetMenuBackgroundItem(v)
					end
				end
			end,
		})

		BgGroup:AddSlider('SwordSpeed', {
			Text = 'Rotate Speed',
			Default = 0.15,
			Min = 0,
			Max = 2,
			Rounding = 2,
			Compact = true,
			Callback = function(v)
				if Library.SetSwordSpeed then
					Library:SetSwordSpeed(v)
				else
					Library.SwordSpeed = v
				end
			end,
		})

		BgGroup:AddSlider('BackTransparency', {
			Text = 'Back Transparency',
			Default = 70,
			Min = 0,
			Max = 100,
			Suffix = '%',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				local t = (tonumber(v) or 70) / 100
				if Library.SetBackTransparency then
					Library:SetBackTransparency(t)
				else
					Library.BackTransparency = t
					if Library.MenuViewport then
						Library.MenuViewport.BackgroundTransparency = t
					end
				end
			end,
		})

		BgGroup:AddLabel('Sword Color'):AddColorPicker('SwordColor', {
			Default = Library.SwordColor or Color3.fromRGB(255, 255, 255),
			Callback = function(val)
				Library.SwordColor = val
				if Library.RefreshMenuBackgroundStyle then
					Library:RefreshMenuBackgroundStyle()
				end
			end,
		})

		BgGroup:AddLabel('Back Color'):AddColorPicker('BackColor', {
			Default = Library.BackColor or Color3.fromRGB(0, 0, 0),
			Callback = function(val)
				Library.BackColor = val
				if Library.MenuViewport then
					Library.MenuViewport.BackgroundColor3 = val
				end
				if Library.RefreshMenuBackgroundStyle then
					Library:RefreshMenuBackgroundStyle()
				end
			end,
		})

		BgGroup:AddDropdown('SwordMaterial', {
			Text = 'Sword Material',
			Values = { 'Neon', 'ForceField', 'Glass', 'SmoothPlastic', 'Metal' },
			Default = 1,
			Multi = false,
			Callback = function(v)
				local ok, mat = pcall(function() return Enum.Material[v] end)
				if ok and mat then
					Library.SwordMaterial = mat
					if Library.RefreshMenuBackgroundStyle then
						Library:RefreshMenuBackgroundStyle()
					end
				end
			end,
		})

		BgGroup:AddSlider('SwordTransparency', {
			Text = 'Sword Transparency',
			Default = 0,
			Min = 0,
			Max = 100,
			Suffix = '%',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				Library.SwordTransparency = (tonumber(v) or 0) / 100
				if Library.RefreshMenuBackgroundStyle then
					Library:RefreshMenuBackgroundStyle()
				end
			end,
		})

		-- ignore transient UI indexes from save
		self:SetIgnoreIndexes({
			'MenuKeybind', -- usually handled by Library toggle bind
			'Send Notification',
		})
	end


	return SaveManager
