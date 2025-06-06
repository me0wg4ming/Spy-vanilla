SpyStats = Spy:NewModule("SpyStats", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Spy", true)
local AceCore = LibStub("AceCore-3.0")

local wipe = AceCore.wipe
local Spy = Spy
local Data = SpyData

local getn = table.getn
local _G = getfenv()
local GUI = {}
local units = {
    recent = {},
    display = {},
}

--local PAGE_SIZE = 32
local PAGE_SIZE = 34
local TAB_PLAYER = 1
local VIEW_PLAYER_HISTORY = 1
local COLOR_NORMAL = { 1, 1, 1 }
local COLOR_KOS = { 1, 0, 0 }

GUI.ListFrameLines = {
    [VIEW_PLAYER_HISTORY] = {},
}
GUI.ListFrameFields = {
    [VIEW_PLAYER_HISTORY] = {},
}

local SORT = {
    ["SpyStatsPlayersNameSort"] = "name",
    ["SpyStatsPlayersLevelSort"] = "level",
    ["SpyStatsPlayersClassSort"] = "class",
    ["SpyStatsPlayersGuildSort"] = "guild",
    ["SpyStatsPlayersWinsSort"] = "wins",
    ["SpyStatsPlayersLosesSort"] = "loses",
    ["SpyStatsTimeSort"] = "time",
}

function SpyStats:OnInitialize()
    -- create lookup tables for all GUI list lines and buttons
    local views = {
        [VIEW_PLAYER_HISTORY] = "SpyStatsPlayerHistoryFrameListFrame",
    }

    for view, frame in pairs(views) do
        local v = view
        GUI.ListFrameLines[v] = {}
        setmetatable(GUI.ListFrameLines[v], {
            __index = function(t, k)

                local b = _G[views[v] .. "Line" .. k]
                if b then
                    rawset(t, k, b)
                    return b
                end
            end,
        })

        for line = 1, PAGE_SIZE do
            local l = line
            GUI.ListFrameFields[v][l] = {}
            setmetatable(GUI.ListFrameFields[v][l], {
                __index = function(t, k)
                    local f = _G[views[v] .. "Line" .. l .. k]
                    if f then
                        rawset(t, k, f)
                        return f
                    end
                end,
            })
        end
    end

    -- set initial view
    self.sortBy = "time"
    self.view = VIEW_PLAYER_HISTORY

    -- localization
    SpyStatsKosCheckboxText:SetText(L["KOS"])
    SpyStatsWinsLosesCheckboxText:SetText(L["Won/Lost"])
    SpyStatsReasonCheckboxText:SetText(L["Reason"])

    table.insert(UISpecialFrames, "SpyStatsFrame")
end

function SpyStats:OnDisable()
    self:Hide()
end

function SpyStats:Show()
    SpyStatsFilterBox:SetText("")
    SpyStatsKosCheckbox:SetChecked(false)
    SpyStatsWinsLosesCheckbox:SetChecked(false)
    SpyStatsReasonCheckbox:SetChecked(false)
    SpyStatsFrame:Show()
    self:Recalulate()
    self:ScheduleRepeatingTimer("Refresh", 1)
end

function SpyStats:Hide()
    self:CancelAllTimers()
    SpyStatsFrame:Hide()
    self:Cleanup()
end

function SpyStats:Toggle()
    if SpyStatsFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function SpyStats:IsShown()
    return SpyStatsFrame:IsShown()
end

function SpyStats:UpdateView()
    local tab = PanelTemplates_GetSelectedTab(SpyStatsTabFrame)

    if tab == TAB_PLAYER then
        self.view = VIEW_PLAYER_HISTORY

        SpyStatsWinsLosesCheckbox:ClearAllPoints()
        SpyStatsWinsLosesCheckbox:SetPoint("LEFT", SpyStatsKosCheckboxText, "RIGHT", 12, -1)

        if (self.sortBy == "name") or (self.sortBy == "level") or (self.sortBy == "class") then
            self.sortBy = "time"
        end
    end
    self:Refresh()
end

function SpyStats:OnNewEvent(unit)
    self.newevents = true
end

function SpyStats:SetSortColumn(name)
    name = SORT[name]
    if name then
        self.sortBy = name
        self:Recalulate()
    end
end

function SpyStats:Recalulate()
    if not self:IsShown() or not self:IsEnabled() then return end

    self.newevents = false
    SpyStatsRefreshButton:UnlockHighlight()

    local tab = PanelTemplates_GetSelectedTab(SpyStatsTabFrame)

    local i = 1

    if tab == TAB_PLAYER then
        for _, unit in SpyData:GetPlayers(self.sortBy) do
            units.recent[i] = unit
            i = i + 1
        end
    end

    for j = i, getn(units.recent) do units.recent[j] = nil end

    self:Filter()
end

function SpyStats:Filter()
    if not self:IsShown() or not self:IsEnabled() then return end

    local tab = PanelTemplates_GetSelectedTab(SpyStatsTabFrame)

    local filter = SpyStatsFilterBox:GetText() or ""
    local filterkos = SpyStatsKosCheckbox:GetChecked()
    local filterpvp = SpyStatsWinsLosesCheckbox:GetChecked()
    local filterreason = SpyStatsReasonCheckbox:GetChecked()

    local i = 1
    for _, unit in ipairs(units.recent) do
        local session = SpyData:GetUnitSession(unit)

        if (filter == ""
            or (unit.name and unit.name:sub(1, string.len(filter)):lower() == filter:lower())
            or (unit.guild and unit.guild:sub(1, string.len(filter)):lower() == filter:lower()))
            and (not filterkos or unit.kos)
            and (not filterpvp or ((unit.wins and unit.wins > 0) or (unit.loses and unit.loses > 0)))
            and (not filterreason or unit.reason)
        then
            units.display[i] = unit
            i = i + 1
        end
    end

    for j = i, getn(units.display) do units.display[j] = nil end

    self:Refresh()
end

function SpyStats:Refresh()
    local self = SpyStats
    if self.refreshing then return end
    self.refreshing = true

    local tab = PanelTemplates_GetSelectedTab(SpyStatsTabFrame)
    local view = SpyStats.view

    -- set offest location to current scroll position
    local Scroll = SpyStatsTabFrameTabContentFrameScrollFrame
    FauxScrollFrame_Update(Scroll, getn(units.display), PAGE_SIZE, 15)
    local offset = FauxScrollFrame_GetOffset(Scroll)
    Scroll:Show()

    local now = time()

    -- loop through all frame lines
    for row = 1, PAGE_SIZE do
        local line = GUI.ListFrameLines[view][row]

        -- use offset to locate where to start displaying records
        local i = row + offset

        if i <= getn(units.display) then
            local unit = units.display[i]
            local session = SpyData:GetUnitSession(unit)

            line.unit = unit

            local age = now - unit.time

            local r, g, b
            if unit.kos and (age < 60) then
                r, g, b = unpack(COLOR_KOS)
            else
                r, g, b = unpack(COLOR_NORMAL)
            end

            if tab == TAB_PLAYER then
                local name = GUI.ListFrameFields[view][row]["Name"]
                name:SetText(unit.name)
                name:SetTextColor(r, g, b)

                local level = GUI.ListFrameFields[view][row]["Level"]
                level:SetText(unit.level)
                level:SetTextColor(r, g, b)

                local class = GUI.ListFrameFields[view][row]["Class"]
                local classtext = unit.class
                if classtext then
                    classtext = (L[classtext])
                else
                    classtext = "?"
                end
                class:SetText(classtext)
                class:SetTextColor(r, g, b)

                local guild = GUI.ListFrameFields[view][row]["Guild"]
                guild:SetText(unit.guild or "?")
                guild:SetTextColor(r, g, b)

                local wins = GUI.ListFrameFields[view][row]["Wins"]
                wins:SetText(unit.wins or 0)
                wins:SetTextColor(r, g, b)

                local loses = GUI.ListFrameFields[view][row]["Loses"]
                loses:SetText(unit.loses or 0)
                loses:SetTextColor(r, g, b)

                local reason = GUI.ListFrameFields[view][row]["Reason"]
                local reasonText = ""
                if unit.reason then
                    for reason in pairs(unit.reason) do
                        if reasonText ~= "" then reasonText = reasonText .. ", " end
                        if reason == L["KOSReasonOther"] then
                            reasonText = reasonText .. unit.reason[reason]
                        else
                            reasonText = reasonText .. reason
                        end
                    end
                end
                reason:SetText(reasonText or "")
                reason:SetTextColor(r, g, b)

                local zone = GUI.ListFrameFields[view][row]["Zone"]
                local location = unit.zone
                if location and unit.subZone and unit.subZone ~= "" and unit.subZone ~= location then
                    location = unit.subZone .. ", " .. location
                end
                zone:SetText(location or "?")
                zone:SetTextColor(r, g, b)

                local time = GUI.ListFrameFields[view][row]["Time"]
                time:SetText((unit.time and unit.time > 0) and Spy:FormatTime(unit.time) or "?")
                time:SetTextColor(r, g, b)

                local tList = GUI.ListFrameFields[view][row]["List"]
                local f = ""
                for key, value in pairs(SpyPerCharDB.KOSData) do
                    -- find units that match
                    local KoSname = key
                    if unit.name == KoSname then f = f .. "x" end
                end
                tList:SetText(f)
                tList:SetTextColor(r, g, b)
            end
            line:Show()
        else
            line:Hide()
        end
    end

    self.refreshing = false
end

function SpyStats:OnRefreshButtonUpdate(frame, elapsed)
    if not self.newevents then return end

    local timer = frame.timer + elapsed

    if (timer < .5) then
        frame.timer = timer
        return
    end

    while (timer >= .5) do
        timer = timer - .5
    end
    frame.timer = timer

    if (frame.state) then
        frame:UnlockHighlight()
        frame.state = nil
    else
        frame:LockHighlight()
        frame.state = true
    end
end

-- remove all references to units
function SpyStats:Cleanup()
    for _, lines in pairs(GUI.ListFrameLines) do
        for _, line in pairs(lines) do
            line.unit = nil
        end
    end

    for i in ipairs(units.recent) do units.recent[i] = nil end
    for i in ipairs(units.display) do units.display[i] = nil end
end

local info = {}
function Spy_CreateStatsDropdown(level)
    level = level or 1
    
    local unit = _G["StatsDropDownMenu"].unit
    local session = SpyData:GetUnitSession(unit)
    if level == 1 then
        wipe(info)
        info.isTitle = true
        info.text = unit.name
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    
        if not unit.kos then
            wipe(info)
            info.isTitle = nil
            info.notCheckable = true
            info.hasArrow = false
            info.disabled = nil
            info.text = L["AddToKOSList"]
            info.func = function() Spy:ToggleKOSPlayer(true, unit.name) end
            info.value = nil
            UIDropDownMenu_AddButton(info, level)
    
            info.isTitle = nil
            info.notCheckable = true
            info.hasArrow = false
            info.disabled = nil
            info.text = L["RemoveFromStatsList"]
            info.func = function()
                Spy:RemovePlayerData(unit.name)
                SpyStats:Recalulate()
            end
            info.value = nil
            UIDropDownMenu_AddButton(info, level)
    
        else
            wipe(info)
            info.notCheckable = true
            info.text = L["KOSReasonDropDownMenu"]
            info.value = unit
            info.func = function(player) Spy:SetKOSReason(player, L["KOSReasonOther"], other) end
            info.checked = false
            info.arg1 = unit.name
            UIDropDownMenu_AddButton(info, level)
    
            info.isTitle = nil
            info.notCheckable = true
            info.hasArrow = false
            info.disabled = nil
            info.text = L["RemoveFromKOSList"]
            info.func = function() Spy:ToggleKOSPlayer(false, unit.name) end
            info.value = nil
            UIDropDownMenu_AddButton(info, level)
    
        end

    elseif level == 2 then
    end
end

function Spy:ShowStatsDropDown(node)

    if arg1 ~= "RightButton" then return end
    StatsDropDownMenu = CreateFrame("Frame", "StatsDropDownMenu", node, "UIDropDownMenuTemplate")
    GameTooltip:Hide()
    StatsDropDownMenu.unit = node.unit
    local cursor = GetCursorPosition() / UIParent:GetEffectiveScale()
    local center = node:GetLeft() + (node:GetWidth() / 2)

    UIDropDownMenu_Initialize(StatsDropDownMenu, Spy_CreateStatsDropdown, "MENU")
    UIDropDownMenu_SetAnchor(cursor - center, 0, StatsDropDownMenu, "TOPRIGHT", node, "TOP")
    CloseDropDownMenus(1)
    ToggleDropDownMenu(1, nil, StatsDropDownMenu)
end
