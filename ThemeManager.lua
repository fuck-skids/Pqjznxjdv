local httpService = game:GetService('HttpService')
local ThemeManager = {} do
	ThemeManager.Folder = 'LinoriaLibSettings'
	-- if not isfolder(ThemeManager.Folder) then makefolder(ThemeManager.Folder) end

	ThemeManager.Library = nil
	ThemeManager.BuiltInThemes = {
		['Default']         = { 1, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"181818","AccentColor":"4777b6","BackgroundColor":"141414","OutlineColor":"2a2a2a"}') },
		['BBot'] 			= { 2, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1e1e","AccentColor":"7e48a3","BackgroundColor":"232323","OutlineColor":"141414"}') },
		['Fatality']		= { 3, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1842","AccentColor":"c50754","BackgroundColor":"191335","OutlineColor":"3c355d"}') },
		['Jester'] 			= { 4, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"db4467","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') },
		['Mint'] 			= { 5, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"3db488","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') },
		['Tokyo Night'] 	= { 6, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"191925","AccentColor":"6759b3","BackgroundColor":"16161f","OutlineColor":"323232"}') },
		['Ubuntu'] 			= { 7, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"3e3e3e","AccentColor":"e2581e","BackgroundColor":"323232","OutlineColor":"191919"}') },
		['Quartz'] 			= { 8, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"232330","AccentColor":"426e87","BackgroundColor":"1d1b26","OutlineColor":"27232f"}') },
        ['Inkwell']         = { 9, httpService:JSONDecode('{"FontColor":"c5c3c3","MainColor":"000000","AccentColor":"ffffff","BackgroundColor":"000000","OutlineColor":"27232f"}') },
	}

	function ThemeManager:ApplyTheme(theme)
		local customThemeData = self:GetCustomTheme(theme)
		local data = customThemeData or self.BuiltInThemes[theme]

		if not data then return end

		-- custom themes are just regular dictionaries instead of an array with { index, dictionary }

		local scheme = data[2] or data
		-- support both {idx, scheme} builtin and flat custom dict
		if data[2] then scheme = data[2] end
		if customThemeData then scheme = customThemeData end

		local colorKeys = {
			FontColor = true, MainColor = true, AccentColor = true,
			BackgroundColor = true, OutlineColor = true, RiskColor = true,
			SwordColor = true, BackColor = true,
		}
		for idx, col in next, scheme do
			if colorKeys[idx] and type(col) == 'string' then
				local ok, rgb = pcall(function() return Color3.fromHex(col) end)
				if ok and rgb then
					self.Library[idx] = rgb
					if Options[idx] and Options[idx].SetValueRGB then
						Options[idx]:SetValueRGB(rgb)
					end
				end
			elseif idx == 'SwordSpeed' or idx == 'BlurSize' or idx == 'BackTransparency'
				or idx == 'SwordTransparency' or idx == 'SwordReflectance' then
				local num = tonumber(col)
				if num then
					self.Library[idx] = num
					if Options[idx] and Options[idx].SetValue then
						-- BackTransparency in themes is 0-1; slider is 0-100
						if idx == 'BackTransparency' and Options[idx].Max == 100 then
							Options[idx]:SetValue(num * 100)
						elseif idx == 'SwordTransparency' and Options[idx].Max == 100 then
							Options[idx]:SetValue(num * 100)
						else
							Options[idx]:SetValue(num)
						end
					end
				end
			elseif idx == 'ItemType' or idx == 'SwordMaterial' then
				self.Library[idx] = col
				if Options[idx] and Options[idx].SetValue then
					Options[idx]:SetValue(col)
				end
			end
		end

		if self.Library.RefreshMenuBackgroundStyle then
			pcall(function() self.Library:RefreshMenuBackgroundStyle() end)
		end
		if self.Library.SetMenuBackgroundItem and self.Library.ItemType then
			pcall(function() self.Library:SetMenuBackgroundItem(self.Library.ItemType) end)
		end

		self:ThemeUpdate()
	end

	function ThemeManager:ThemeUpdate()
		-- This allows us to force apply themes without loading the themes tab :)
		local options = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor", "RiskColor", "SwordColor", "BackColor" }
		for i, field in next, options do
			if Options and Options[field] then
				self.Library[field] = Options[field].Value
			end
		end

		self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor);
		self.Library:UpdateColorsUsingRegistry()
	end

	function ThemeManager:LoadDefault()		
		local theme = 'Default'
		local content = isfile(self.Folder .. '/themes/default.txt') and readfile(self.Folder .. '/themes/default.txt')

		local isDefault = true
		if content then
			if self.BuiltInThemes[content] then
				theme = content
			elseif self:GetCustomTheme(content) then
				theme = content
				isDefault = false;
			end
		elseif self.BuiltInThemes[self.DefaultTheme] then
		 	theme = self.DefaultTheme
		end

		if isDefault then
			Options.ThemeManager_ThemeList:SetValue(theme)
		else
			self:ApplyTheme(theme)
		end
	end

	function ThemeManager:SaveDefault(theme)
		writefile(self.Folder .. '/themes/default.txt', theme)
	end

	function ThemeManager:CreateThemeManager(parent)
		-- UE: Themes + Background as tabs in a left tabbox
		local tabbox = parent
		-- parent may already be a groupbox OR a tab; prefer tabbox
		if parent.AddTab and not parent.AddLabel then
			tabbox = parent
		elseif parent.AddLeftTabbox then
			tabbox = parent:AddLeftTabbox('ThemeBox')
		elseif self.Library and self._ApplyTab then
			tabbox = self._ApplyTab:AddLeftTabbox('ThemeBox')
		else
			-- groupbox path from ApplyToGroupbox - just use groupbox for themes only
			tabbox = nil
		end

		local themesTab
		local backgroundTab
		if tabbox and tabbox.AddTab then
			themesTab = tabbox:AddTab('Themes')
			backgroundTab = tabbox:AddTab('Background')
		else
			themesTab = parent
			backgroundTab = parent
		end

		if not self.Library.RiskColor then
			self.Library.RiskColor = Color3.fromRGB(255, 50, 50)
		end
		if not self.Library.SwordColor then
			self.Library.SwordColor = Color3.new(1,1,1)
		end
		if not self.Library.BackColor then
			self.Library.BackColor = Color3.new(0,0,0)
		end
		if self.Library.SwordTransparency == nil then
			self.Library.SwordTransparency = 0
		end
		if self.Library.SwordReflectance == nil then
			self.Library.SwordReflectance = 0
		end
		if not self.Library.SwordMaterial then
			self.Library.SwordMaterial = Enum.Material.Neon
		end
		if not self.Library.SwordSpeed then
			self.Library.SwordSpeed = 0.15
		end
		if self.Library.BackTransparency == nil then
			self.Library.BackTransparency = 0.7
		end
		if not self.Library.ItemType then
			self.Library.ItemType = 'Unnamed Enhancements'
		end
		if self.Library.Contrast == nil then self.Library.Contrast = 0 end
		if self.Library.Saturation == nil then self.Library.Saturation = 0 end
		if self.Library.Brightness == nil then self.Library.Brightness = 0 end
		if self.Library.BlurSize == nil then self.Library.BlurSize = 15 end

		-- ========== THEMES ==========
		themesTab:AddLabel('Main Color'):AddColorPicker('MainColor', {
			Default = self.Library.MainColor,
		})
		themesTab:AddLabel('Accent Color'):AddColorPicker('AccentColor', {
			Default = self.Library.AccentColor,
		})
		themesTab:AddLabel('Background Color'):AddColorPicker('BackgroundColor', {
			Default = self.Library.BackgroundColor,
		})
		themesTab:AddLabel('Outline Color'):AddColorPicker('OutlineColor', {
			Default = self.Library.OutlineColor,
		})
		themesTab:AddLabel('Text Color'):AddColorPicker('FontColor', {
			Default = self.Library.FontColor,
		})
		themesTab:AddLabel('Risk Text Color'):AddColorPicker('RiskColor', {
			Default = self.Library.RiskColor,
		})

		local ThemesArray = {}
		for Name, Theme in next, self.BuiltInThemes do
			table.insert(ThemesArray, Name)
		end
		table.sort(ThemesArray, function(a, b)
			return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1]
		end)

		themesTab:AddDropdown('ThemeManager_ThemeList', {
			Text = 'Theme list',
			Values = ThemesArray,
			Default = 1,
		})
		themesTab:AddButton('Set Default', function()
			self:SaveDefault(Options.ThemeManager_ThemeList.Value)
			self.Library:Notify(string.format('Set default theme to %q', Options.ThemeManager_ThemeList.Value))
		end)
		Options.ThemeManager_ThemeList:OnChanged(function()
			self:ApplyTheme(Options.ThemeManager_ThemeList.Value)
		end)

		themesTab:AddInput('ThemeManager_CustomThemeName', {
			Text = 'Custom theme name',
		})
		themesTab:AddButton('Create theme', function()
			local themeName = Options.ThemeManager_CustomThemeName.Value
			if not themeName or themeName == '' then
				self.Library:Notify('Failed to create theme: invalid name')
				return
			end
			self:SaveCustomTheme(themeName .. '.json')
			Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Options.ThemeManager_CustomThemeList:SetValue(nil)
			self.Library:Notify(string.format('Created theme %q', themeName))
		end)
		themesTab:AddDropdown('ThemeManager_CustomThemeList', {
			Text = 'Custom themes',
			Values = self:ReloadCustomThemes(),
			AllowNull = true,
			Default = 1,
		})
		themesTab:AddButton('Load theme', function()
			self:ApplyTheme(Options.ThemeManager_CustomThemeList.Value)
		end)
		themesTab:AddButton('Overwrite Theme', function()
			local name = Options.ThemeManager_CustomThemeList.Value
			if not name or name == '' then
				self.Library:Notify('No custom theme selected')
				return
			end
			self:SaveCustomTheme(name)
			self.Library:Notify(string.format('Overwrote theme %q', name))
		end):AddButton('Delete Theme', function()
			local themeName = Options.ThemeManager_CustomThemeList.Value
			if not themeName or themeName == '' then
				self.Library:Notify('No custom theme selected')
				return
			end
			local ok, err = self:Delete(themeName)
			if not ok then
				self.Library:Notify('Failed to delete theme: ' .. tostring(err))
				return
			end
			Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Options.ThemeManager_CustomThemeList:SetValue(nil)
			self.Library:Notify(string.format('Deleted theme %q', themeName))
		end)
		themesTab:AddButton('Set Default', function()
			local themeName = Options.ThemeManager_CustomThemeList.Value
			if not themeName or themeName == '' then return end
			self:SaveDefault(themeName)
			self.Library:Notify(string.format('Set default theme to %q', themeName))
		end):AddButton('Reset Default', function()
			local ok = pcall(function()
				if delfile then delfile(self.Folder .. '/themes/default.txt') end
			end)
			self.Library:Notify(ok and 'Removed default theme' or 'Failed to reset default')
		end)
		themesTab:AddButton('Refresh', function()
			Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Options.ThemeManager_CustomThemeList:SetValue(nil)
		end)

		-- ========== BACKGROUND (UE exact tabbox) ==========
		if backgroundTab then
			backgroundTab:AddLabel('Item Color'):AddColorPicker('SwordColor', {
				Default = self.Library.SwordColor,
			})
			backgroundTab:AddDropdown('ItemType', {
				Values = {
					'None',
					'Sword',
					'Cross',
					'Heart',
					'Catholic Cross',
					'Orthodox Cross',
					'Unnamed Enhancements',
				},
				Default = 'Unnamed Enhancements',
				Multi = false,
				Text = 'Item',
			})
			backgroundTab:AddSlider('SwordTransparency', {
				Text = 'Transparency',
				Default = 0,
				Min = 0,
				Max = 1,
				Rounding = 2,
			})
			backgroundTab:AddSlider('SwordReflectance', {
				Text = 'Reflectance',
				Default = 0,
				Min = 0,
				Max = 1,
				Rounding = 2,
			})
			backgroundTab:AddSlider('SwordSpeed', {
				Text = 'Speed',
				Default = 0.15,
				Min = 0.1,
				Max = 1,
				Rounding = 2,
			})
			backgroundTab:AddDropdown('SwordMaterial', {
				Values = {
					'ForceField', 'Neon', 'Plastic', 'SmoothPlastic', 'Wood',
					'WoodPlanks', 'Marble', 'Slate', 'Concrete', 'Granite',
					'Brick', 'Pebble', 'Cobblestone', 'Rock', 'Sandstone',
					'Basalt', 'CrackedLava', 'Limestone', 'Pavement',
					'CorrodedMetal', 'DiamondPlate', 'Foil', 'Metal', 'Grass',
					'LeafyGrass', 'Sand', 'Fabric', 'Snow', 'Mud', 'Ground',
					'Asphalt', 'Salt', 'Ice', 'Glacier', 'Glass',
				},
				Default = 'Neon',
				Multi = false,
				Text = 'Material',
			})
			backgroundTab:AddDivider()
			backgroundTab:AddLabel('Background Color'):AddColorPicker('BackColor', {
				Default = self.Library.BackColor,
			})
			backgroundTab:AddSlider('BackTransparency', {
				Text = 'Transparency',
				Default = 0.7,
				Min = 0,
				Max = 1,
				Rounding = 2,
			})
			backgroundTab:AddSlider('BlurSize', {
				Text = 'Blur',
				Default = 15,
				Min = 0,
				Max = 50,
				Rounding = 0,
			})
			backgroundTab:AddSlider('Contrast', {
				Text = 'Contrast',
				Default = 0,
				Min = -10,
				Max = 10,
				Rounding = 1,
			})
			backgroundTab:AddSlider('Saturation', {
				Text = 'Saturation',
				Default = 0,
				Min = -10,
				Max = 10,
				Rounding = 1,
			})
			backgroundTab:AddSlider('Brightness', {
				Text = 'Brightness',
				Default = 0,
				Min = -1,
				Max = 1,
				Rounding = 1,
			})
		end

		ThemeManager:LoadDefault()

		local function UpdateTheme()
			self:ThemeUpdate()
			local L = self.Library
			if not L then return end

			if Options.SwordColor then L.SwordColor = Options.SwordColor.Value end
			if Options.BackColor then L.BackColor = Options.BackColor.Value end
			if Options.SwordTransparency then L.SwordTransparency = Options.SwordTransparency.Value end
			if Options.SwordReflectance then L.SwordReflectance = Options.SwordReflectance.Value end
			if Options.SwordSpeed then
				L.SwordSpeed = Options.SwordSpeed.Value
				if type(L.SetSwordSpeed) == 'function' then
					pcall(function() L:SetSwordSpeed(Options.SwordSpeed.Value) end)
				end
			end
			if Options.SwordMaterial then
				local matName = Options.SwordMaterial.Value
				pcall(function() L.SwordMaterial = Enum.Material[matName] end)
			end
			if Options.BackTransparency then
				local v = Options.BackTransparency.Value
				L.BackTransparency = v
				if type(L.SetBackTransparency) == 'function' then
					pcall(function() L:SetBackTransparency(v) end)
				end
			end
			if Options.ItemType then
				L.ItemType = Options.ItemType.Value
				if type(L.SetMenuBackgroundItem) == 'function' then
					pcall(function() L:SetMenuBackgroundItem(Options.ItemType.Value) end)
				end
			end
			if Options.BlurSize then
				L.BlurSize = Options.BlurSize.Value
				if L.BlurEffect then
					pcall(function()
						if L.Toggled then
							L.BlurEffect.Enabled = true
							L.BlurEffect.Size = L.BlurSize
						end
					end)
				end
			end
			if Options.Contrast then L.Contrast = Options.Contrast.Value end
			if Options.Saturation then L.Saturation = Options.Saturation.Value end
			if Options.Brightness then L.Brightness = Options.Brightness.Value end
			if type(L.UpdateColorCorrection) == 'function' then
				pcall(function() L:UpdateColorCorrection() end)
			elseif L.ColorCorrection then
				pcall(function()
					L.ColorCorrection.Contrast = L.Contrast or 0
					L.ColorCorrection.Saturation = L.Saturation or 0
					L.ColorCorrection.Brightness = L.Brightness or 0
				end)
			end
			if type(L.RefreshMenuBackgroundStyle) == 'function' then
				pcall(function() L:RefreshMenuBackgroundStyle() end)
			end
		end

		for _, id in ipairs({
			'BackgroundColor','MainColor','AccentColor','OutlineColor','FontColor','RiskColor',
			'SwordColor','ItemType','SwordTransparency','SwordReflectance','SwordSpeed',
			'SwordMaterial','BackColor','BackTransparency','BlurSize','Contrast','Saturation','Brightness',
		}) do
			if Options[id] and Options[id].OnChanged then
				Options[id]:OnChanged(UpdateTheme)
			end
		end

		-- initial background apply
		task.defer(function()
			pcall(UpdateTheme)
		end)
	end

function ThemeManager:Delete(themeName)
		if not themeName or themeName == '' then
			return false, 'invalid name'
		end
		local path = self.Folder .. '/themes/' .. themeName
		if not path:find('%.json$') then
			path = path .. '.json'
		end
		local ok = false
		pcall(function()
			if isfile and isfile(path) then
				if delfile then delfile(path); ok = true
				elseif type(removefile) == 'function' then removefile(path); ok = true end
			end
		end)
		if not ok then
			return false, 'file not found or cannot delete'
		end
		return true
	end

function ThemeManager:GetCustomTheme(file)
		local path = self.Folder .. '/themes/' .. file
		if not isfile(path) then
			return nil
		end

		local data = readfile(path)
		local success, decoded = pcall(httpService.JSONDecode, httpService, data)
		
		if not success then
			return nil
		end

		return decoded
	end

	function ThemeManager:SaveCustomTheme(file)
		if file:gsub(' ', '') == '' then
			return self.Library:Notify('Invalid file name for theme (empty)', 3)
		end

		local theme = {}
		local fields = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }

		for _, field in next, fields do
			theme[field] = Options[field].Value:ToHex()
		end

		writefile(self.Folder .. '/themes/' .. file .. '.json', httpService:JSONEncode(theme))
	end

	function ThemeManager:ReloadCustomThemes()
		local list = listfiles(self.Folder .. '/themes')

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				-- i hate this but it has to be done ...

				local pos = file:find('.json', 1, true)
				local char = file:sub(pos, pos)

				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1))
				end
			end
		end

		return out
	end

	function ThemeManager:SetLibrary(lib)
		self.Library = lib
	end

	function ThemeManager:BuildFolderTree()
		local paths = {}

		-- build the entire tree if a path is like some-hub/phantom-forces
		-- makefolder builds the entire tree on Synapse X but not other exploits

		local parts = self.Folder:split('/')
		for idx = 1, #parts do
			paths[#paths + 1] = table.concat(parts, '/', 1, idx)
		end

		table.insert(paths, self.Folder .. '/themes')
		table.insert(paths, self.Folder .. '/settings')

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function ThemeManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function ThemeManager:CreateGroupBox(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		return tab:AddLeftGroupbox('Themes')
	end

	function ThemeManager:ApplyToTab(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		self._ApplyTab = tab
		-- UE: Themes + Background live in a left tabbox
		local tabbox = tab:AddLeftTabbox('ThemeBox')
		self:CreateThemeManager(tabbox)
	end

	function ThemeManager:ApplyToGroupbox(groupbox)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		self:CreateThemeManager(groupbox)
	end

	ThemeManager:BuildFolderTree()
end

return ThemeManager
