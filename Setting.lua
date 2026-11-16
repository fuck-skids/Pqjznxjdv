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

	
	function SaveManager:Delete(name)
		if (not name) then
			return false, 'no config file is selected'
		end
		local fullPath = self.Folder .. '/settings/' .. name .. '.json'
		local ok = false
		local err = 'file not found or cannot delete'
		pcall(function()
			if isfile and isfile(fullPath) then
				if delfile then
					delfile(fullPath)
					ok = true
				elseif type(removefile) == 'function' then
					removefile(fullPath)
					ok = true
				end
			end
		end)
		if not ok then
			return false, err
		end
		return true
	end


	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local section = tab:AddRightGroupbox('Configuration')

		section:AddInput('SaveManager_ConfigName', { Text = 'Config name' })
		section:AddDropdown('SaveManager_ConfigList', {
			Text = 'Config list',
			Values = self:RefreshConfigList(),
			AllowNull = true,
		})

		section:AddButton('Create config', function()
			local name = Options.SaveManager_ConfigName.Value
			if not name or name:gsub(' ', '') == '' then
				return self.Library:Notify('Invalid config name (empty)', 2)
			end
			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save config: ' .. tostring(err))
			end
			self.Library:Notify(string.format('Created config %q', name))
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end):AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value
			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load config: ' .. tostring(err))
			end
			self.Library:Notify(string.format('Loaded config %q', name))
		end)

		-- Overwrite + Delete (UE: DoubleClick)
		section:AddButton({
			Text = 'Overwrite config',
			DoubleClick = true,
			Func = function()
				local name = Options.SaveManager_ConfigList.Value
				local success, err = self:Save(name)
				if not success then
					return self.Library:Notify('Failed to overwrite config: ' .. tostring(err))
				end
				self.Library:Notify(string.format('Overwrote config %q', name))
			end,
		}):AddButton({
			Text = 'Delete config',
			DoubleClick = true,
			Func = function()
				local name = Options.SaveManager_ConfigList.Value
				if not name or name == '' then
					return self.Library:Notify('No config selected', 2)
				end
				local success, err = self:Delete(name)
				if not success then
					return self.Library:Notify('Failed to delete config: ' .. tostring(err))
				end
				self.Library:Notify(string.format('Deleted config %q', name))
				Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
				Options.SaveManager_ConfigList:SetValue(nil)
			end,
		})

		section:AddButton('Refresh list', function()
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		section:AddButton('Set autoload', function()
			local name = Options.SaveManager_ConfigList.Value
			if not name then return end
			writefile(self.Folder .. '/settings/autoload.txt', name)
			if SaveManager.AutoloadLabel then
				SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			end
			self.Library:Notify(string.format('Set %q to auto load', name))
		end):AddButton('Remove autoload', function()
			local autoloadPath = self.Folder .. '/settings/autoload.txt'
			pcall(function()
				if isfile and isfile(autoloadPath) and delfile then
					delfile(autoloadPath)
				elseif writefile then
					writefile(autoloadPath, '')
				end
			end)
			if SaveManager.AutoloadLabel then
				SaveManager.AutoloadLabel:SetText('Current autoload config: none')
			end
			self.Library:Notify('Removed autoload config')
		end)

		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

		pcall(function()
			local path = self.Folder .. '/settings/autoload.txt'
			if isfile and isfile(path) then
				local name = readfile(path)
				if name and name ~= '' then
					SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
				end
			end
		end)

		SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
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

		local section = tab:AddRightGroupbox('community configs')
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


	-- ============================================================
	-- UE Settings — exact structure: LeftTabbox → Menu + Notifications
	-- ============================================================
	function SaveManager:BuildUESettings(tab)
		assert(self.Library, 'Must set SaveManager.Library')
		local Library = self.Library

		-- UE uses a left tabbox with two tabs (not groupboxes)
		local tabbox = tab:AddLeftTabbox('UESettings')
		local Menu = tabbox:AddTab('Menu')
		local Notif = tabbox:AddTab('Notifications')

		-- ========== MENU TAB ==========
		Menu:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
			Default = 'RightShift',
			NoUI = true,
			Text = 'Menu keybind',
			Modes = { 'Toggle' },
		})

		Menu:AddToggle('KeybindMenu', {
			Text = 'Keybind Menu',
			Default = true,
			Tooltip = 'Shows Keybinds',
			Callback = function(v)
				Library.KeypickerListVisible = v and true or false
				if Library.KeybindFrame then
					Library.KeybindFrame.Visible = v and true or false
				end
				if Library.RefreshKeybinds then
					pcall(function() Library:RefreshKeybinds() end)
				end
			end,
		})

		Menu:AddSlider('KeybindMenuTransparency', {
			Text = 'Menu Transparency',
			Default = 100,
			Min = 0,
			Max = 100,
			Suffix = '%',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				local t = 1 - ((tonumber(v) or 100) / 100)
				if Library.SetKeybindMenuTransparency then
					Library:SetKeybindMenuTransparency(v)
				else
					if Library.KeybindFrame then
						pcall(function() Library.KeybindFrame.BackgroundTransparency = t end)
					end
					if Library.KeybindInner then
						pcall(function() Library.KeybindInner.BackgroundTransparency = t end)
					end
				end
			end,
		})

		Menu:AddDropdown('KeybindMenuValue', {
			Text = 'Keybind Menu Mode',
			Values = { 'Active', 'Toggled', 'All' },
			Default = 2, -- Toggled
			Multi = false,
			Callback = function(v)
				Library.KeypickerListMode = v
				Library.KeybindMode = v
				if Library.SetKeybindMode then
					pcall(function() Library:SetKeybindMode(v) end)
				elseif Library.RefreshKeybinds then
					pcall(function() Library:RefreshKeybinds() end)
				end
			end,
		})

		-- ========== NOTIFICATIONS TAB ==========
		Notif:AddToggle('NotificationClips', {
			Text = 'Clip Descendants',
			Default = true,
			Tooltip = 'if enabled, will hide notifications past a certain point',
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.ClipDescendants = v and true or false
				if Library.NotificationArea then
					Library.NotificationArea.ClipsDescendants = v and true or false
				end
				if Library.UpdateNotifAlignment then
					Library.UpdateNotifAlignment()
				end
			end,
		})

		local clipDep = Notif:AddDependencyBox()
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
				if Library.NotificationArea and Library.NotifyConfig.ClipDescendants then
					-- UE sets Size = UDim2.new(0, 2560, 0, distance)
					Library.NotificationArea.Size = UDim2.new(0, 2560, 0, v)
				end
				if Library.UpdateNotifAlignment then
					Library.UpdateNotifAlignment()
				end
			end,
		})

		Notif:AddToggle('NotificationColors', {
			Text = 'Force Color',
			Default = false,
			Tooltip = 'forces the notification colors based on the config, not the theme',
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.ForceColor = v and true or false
			end,
		})

		-- Color pickers attached to Force Color toggle (UE loops Main/Accent/Outline/Font)
		local forceToggle = Toggles.NotificationColors
		if forceToggle and forceToggle.AddColorPicker then
			forceToggle:AddColorPicker('NotificationColorsMain', {
				Default = Library.MainColor or Color3.fromRGB(30, 30, 30),
				Title = 'Main Color',
			})
			forceToggle:AddColorPicker('NotificationColorsAccent', {
				Default = Library.AccentColor or Color3.fromRGB(0, 150, 255),
				Title = 'Accent Color',
			})
			forceToggle:AddColorPicker('NotificationColorsOutline', {
				Default = Library.OutlineColor or Color3.fromRGB(60, 60, 60),
				Title = 'Outline Color',
			})
			forceToggle:AddColorPicker('NotificationColorsFont', {
				Default = Library.FontColor or Color3.fromRGB(255, 255, 255),
				Title = 'Font Color',
			})
		else
			Notif:AddLabel('Main Color'):AddColorPicker('NotificationColorsMain', {
				Default = Library.MainColor or Color3.fromRGB(30, 30, 30),
			})
			Notif:AddLabel('Accent Color'):AddColorPicker('NotificationColorsAccent', {
				Default = Library.AccentColor or Color3.fromRGB(0, 150, 255),
			})
			Notif:AddLabel('Outline Color'):AddColorPicker('NotificationColorsOutline', {
				Default = Library.OutlineColor or Color3.fromRGB(60, 60, 60),
			})
			Notif:AddLabel('Font Color'):AddColorPicker('NotificationColorsFont', {
				Default = Library.FontColor or Color3.fromRGB(255, 255, 255),
			})
		end

		local colorDep = Notif:AddDependencyBox()
		colorDep:SetupDependencies({ { Toggles.NotificationColors, true } })
		colorDep:AddButton('copy colors', function()
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
			Library:Notify('copied notification colors', 2)
		end)

		Notif:AddSlider('NotificationPositionX', {
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

		Notif:AddSlider('NotificationPositionY', {
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

		Notif:AddSlider('NotificationTransparency', {
			Text = 'Transparency',
			Default = 25,
			Min = 0,
			Max = 100,
			Suffix = '%',
			Rounding = 0,
			Compact = true,
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyCenterConfig = Library.NotifyCenterConfig or {}
				Library.NotifyConfig.Transparency = v
				Library.NotifyCenterConfig.Transparency = v
				if Library.SetNotifyTransparency then Library:SetNotifyTransparency(v) end
				if Library.SetNotifyCenterTransparency then Library:SetNotifyCenterTransparency(v) end
			end,
		})

		Notif:AddDropdown('NotificationAnchorStyle', {
			Text = 'Alignment',
			Values = { 'Left', 'Right', 'Center' },
			Default = 3, -- Center
			Multi = false,
			Tooltip = 'how the text is positioned',
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyCenterConfig = Library.NotifyCenterConfig or {}
				Library.NotifyConfig.Alignment = v
				Library.NotifyCenterConfig.Alignment = v
				if Library.UpdateNotifAlignment then Library.UpdateNotifAlignment() end
			end,
		})

		Notif:AddDropdown('NotificationBarStyle', {
			Text = 'Bar Side',
			Values = { 'Left', 'Right', 'Top', 'Bottom' },
			Default = 3, -- Top (UE-style default for monoflux)
			Multi = false,
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyCenterConfig = Library.NotifyCenterConfig or {}
				Library.NotifyConfig.BarSide = v
				Library.NotifyCenterConfig.BarSide = v
				if Library.SetNotifyBarSide then
					Library:SetNotifyBarSide(v)
				end
			end,
		})

		Notif:AddDropdown('NotificationStyleSortOrder', {
			Text = 'Sort Order',
			Values = { 'Text Length', 'Default' },
			Default = 2,
			Multi = false,
			Callback = function(v)
				Library.NotifyConfig = Library.NotifyConfig or {}
				Library.NotifyConfig.SortOrder = v
				if Library.NotifLayout then
					Library.NotifLayout.SortOrder = (v == 'Text Length')
						and Enum.SortOrder.Name
						or Enum.SortOrder.LayoutOrder
				end
			end,
		})

		Notif:AddButton('Send Notification', function()
			Library:Notify('test notification (' .. tostring(math.random(1000, 9999)) .. ')', 3)
		end)



		self:SetIgnoreIndexes({ 'MenuKeybind' })

		-- Apply initial keybind visibility
		Library.KeypickerListVisible = true
		if Library.KeybindFrame then
			Library.KeybindFrame.Visible = true
		end
		if Library.RefreshKeybinds then
			task.defer(function()
				pcall(function() Library:RefreshKeybinds() end)
			end)
		end
	end


	return SaveManager
