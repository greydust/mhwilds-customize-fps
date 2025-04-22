local setting = require('customize_fps.setting')
local util = require('customize_fps.util')

setting.LoadSettings()

local function buildOptions(weapon, ammo, option)
    local key = weapon .. ammo

    if ammo == '' then
        imgui.text(weapon)
    else
        imgui.text(ammo)
    end

    if weapon ~= 'Default' then
        imgui.same_line()
        changed, value = imgui.checkbox('Default##' .. key, option.Default)
        if changed then
            option.Default = value
            setting.SaveSettings()
        end
    end
    if option.Default then
        return
    end

    imgui.same_line()
    changed, value = imgui.checkbox('Unchanged##' .. key, option.Unchanged)
    if changed then
        option.Unchanged = value
        setting.SaveSettings()
    end
    if option.Unchanged then
        return
    end

    imgui.same_line()
    changed, value = imgui.checkbox('Capped Max FPS##' .. key, option.CappedFPS)
    if changed then
        option.CappedFPS = value
        setting.SaveSettings()
    end

--[[
    changed, value = imgui.combo('Frame Generation##' .. key, option.FrameGeneration, {'Off', 'On', 'Unchanged'})
    if changed then
        option.FrameGeneration = value
        setting.SaveSettings()
    end
]]--
    if not option.CappedFPS then
        return
    end

    changed, value = imgui.drag_int('Max FPS##' .. key, option.MaxFPS, 1, 30, 240)
    if changed then
        option.MaxFps = value
        setting.SaveSettings()
    end
end

re.on_draw_ui(function()
    if imgui.tree_node('Customize FPS') then
        changed, value = imgui.checkbox('Enabled', setting.Settings.Enabled)
        if changed then
            setting.Settings.Enabled = value
            setting.SaveSettings()
        end

        for _, k in pairs(util.SettingOrder) do
            v = setting.Settings.FPS[k]

            imgui.begin_group()
            if v.Ammo then
                if imgui.tree_node(k) then
                    for _, a in pairs(util.AmmoOrder) do
                        imgui.begin_group()
                        buildOptions(k, a, v.Ammo[a])
                        imgui.end_group()
                    end
                    imgui.tree_pop()                    
                end
            else
                buildOptions(k, '', v)
            end
            imgui.end_group()
        end
        
        imgui.tree_pop()
    end
end)

local function getCharacter()
    local masterPlayer = sdk.get_managed_singleton('app.PlayerManager'):getMasterPlayer() -- app.cPlayerManageInfo
    if masterPlayer then
        return masterPlayer:get_Character() -- app.HunterCharacter
    end
    return nil
end

--[[
Frame generation On: Set 233 to 0, 216 to 0
Frame generation Off: Set 233 to 1
Currently not working. Need to find the correct method to set the value.
Also chaning Frame generation could stutter the game.
]]--
local function setFrameGeneration(value)
    optionParam = sdk.get_managed_singleton('app.GUIManager'):get_Option()._OptionParam
    if optionParam == nil then
        log.debug('OptionParam is nil')
        return false
    end

    if value == util.FrameGeneration.Off then
        optionParam:setOptionValue(233, 1)
    elseif value == util.FrameGeneration.On then
        optionParam:setOptionValue(233, 0)
        optionParam:setOptionValue(216, 0)
    end
end

-- Max FPS: Set 210 to number
local function setMaxFPS(value)
    optionParam = sdk.get_managed_singleton('app.GUIManager'):get_Option()._OptionParam
    if optionParam == nil then
        log.debug('OptionParam is nil')
        return false
    end

    optionParam:setOptionValue(210, value)
end

--[[
Capped FPS: set 219 to 1
Uncapped FPS: set 219 to 0
]]--
local function setCappedFPS(value)
    optionParam = sdk.get_managed_singleton('app.GUIManager'):get_Option()._OptionParam
    if optionParam == nil then
        log.debug('OptionParam is nil')
        return false
    end

    if value then
        optionParam:setOptionValue(219, 1)
    else
        optionParam:setOptionValue(219, 0)
    end
end

local lastWeaponType = -1
local lastShellType = -1
re.on_frame(function()
    if not setting.Settings.Enabled then
        return
    end

    local character = getCharacter()
    if character then
        local weaponType = character:get_WeaponType() -- app.WeaponDef.TYPE
        local shellType = -1

        local weaponName = util.WeaponType[weaponType]
        local ammoName = ''
        if weaponType == 12 or weaponType == 13 then
            local wpHandling = character:get_WeaponHandling() -- app.cHunterWpGunHandling
            if not wpHandling then
                log.debug('Using bowguns but get_WeaponHandling is nil') 
                return false
            end
            shellType = wpHandling:get_ShellType() -- System.Int32
            ammoName = util.ShellType[shellType]
        end

        if weaponType ~= lastWeaponType or shellType ~= lastShellType then
            local option = nil
            if shellType == -1 then
                option = setting.Settings.FPS[weaponName]
            else
                option = setting.Settings.FPS[weaponName].Ammo[ammoName]
            end
            if option == nil then
                log.debug('Option not found for weapon: ' .. weaponName .. ' ammo: ' .. ammoName) 
                return false
            end

            if option.Default then
                option = setting.Settings.FPS.Default
            end

            if not option.Unchanged then
                if option.FrameGeneration ~= util.FrameGeneration.Unchanged then
                    setFrameGeneration(option.FrameGeneration)
                end
                setCappedFPS(option.CappedFPS)
                if option.CappedFPS then
                    setMaxFPS(option.MaxFPS)
                end
            end
        end

        lastShellType = shellType
        lastWeaponType = weaponType
    end
end)
