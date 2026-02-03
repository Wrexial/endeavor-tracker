-- EndeavorTracker/UI.lua

local addon = EndeavorTracker
addon.UI = {}

function addon.UI.CreateFrames()
    -- Create the main frame
    local frame = CreateFrame("Frame", "EndeavorTrackerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(500, 600)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetToplevel(true)
    frame:SetScript("OnShow", function(self) table.insert(UIPanelWindows, self) end)
    frame:SetScript("OnHide", function(self)
        for i, v in ipairs(UIPanelWindows) do
            if v == self then table.remove(UIPanelWindows, i) return end
        end
    end)
    addon.UI.frame = frame
    
    -- Add a close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)

    -- Add a title
    addon.UI.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    addon.UI.title:SetPoint("TOP", 0, -20)
    addon.UI.title:SetText("Endeavor Leaderboards")

    -- Add progress bars and text
    addon.UI.progressBar = CreateFrame("StatusBar", nil, frame)
    addon.UI.progressBar:SetSize(310, 20)
    addon.UI.progressBar:SetPoint("TOP", 0, -50)
    addon.UI.progressBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    addon.UI.progressBar:SetStatusBarColor(0, 1, 0)
    addon.UI.progressText = addon.UI.progressBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    addon.UI.progressText:SetPoint("CENTER")
    addon.UI.progressText:SetText("0 / 0")

    addon.UI.estimatedProgressBar = CreateFrame("StatusBar", nil, frame)
    addon.UI.estimatedProgressBar:SetSize(310, 20)
    addon.UI.estimatedProgressBar:SetPoint("TOP", 0, -80)
    addon.UI.estimatedProgressBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    addon.UI.estimatedProgressBar:SetStatusBarColor(0, 0, 1)
    addon.UI.estimatedProgressText = addon.UI.estimatedProgressBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    addon.UI.estimatedProgressText:SetPoint("CENTER")
    addon.UI.estimatedProgressText:SetText("Est: 0 / 0")

    -- Add contribution text
    addon.UI.contributionText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    addon.UI.contributionText:SetPoint("TOP", 0, -110)
    addon.UI.contributionText:SetText("Your Contribution: 0")

    -- Add task list title
    local taskListTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    taskListTitle:SetPoint("TOP", addon.UI.contributionText, "BOTTOM", 0, -10)
    taskListTitle:SetText("Task List")

    -- Create sorting dropdown
    local sortDropdown = CreateFrame("Frame", "EndeavorTrackerSortDropdown", frame, "UIDropDownMenuTemplate")
    sortDropdown:SetPoint("TOPRIGHT", -30, -135)
    local function OnSortChanged(self)
        UIDropDownMenu_SetSelectedValue(sortDropdown, self.value)
        addon.Sort.SetSort(self.value)
    end
    local function InitializeSortDropdown()
        for _, sortKey in ipairs({"Default", "Status", "Contribution", "Name", "Coupons"}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = sortKey
            info.value = sortKey
            info.func = OnSortChanged
            UIDropDownMenu_AddButton(info, 1)
        end
    end
    UIDropDownMenu_Initialize(sortDropdown, InitializeSortDropdown)
    UIDropDownMenu_SetSelectedValue(sortDropdown, addon.Sort.currentSort)
    UIDropDownMenu_SetWidth(sortDropdown, 120)
    UIDropDownMenu_JustifyText(sortDropdown, "RIGHT")

    -- Create scroll frame for the task list
    local taskScrollFrame = CreateFrame("ScrollFrame", "EndeavorTrackerTaskScrollFrame", frame, "UIPanelScrollFrameTemplate")
    taskScrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -155)
    taskScrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    addon.UI.taskScrollChild = CreateFrame("Frame")
    addon.UI.taskScrollChild:SetWidth(taskScrollFrame:GetWidth())
    taskScrollFrame:SetScrollChild(addon.UI.taskScrollChild)

    -- Create the debug frame
    local debugFrame = CreateFrame("Frame", "EndeavorTrackerDebugFrame", UIParent, "BackdropTemplate")
    debugFrame:SetSize(500, 600)
    debugFrame:SetPoint("CENTER", 0, 0)
    debugFrame:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    debugFrame:SetMovable(true)
    debugFrame:EnableMouse(true)
    debugFrame:RegisterForDrag("LeftButton")
    debugFrame:SetScript("OnDragStart", debugFrame.StartMoving)
    debugFrame:SetScript("OnDragStop", debugFrame.StopMovingOrSizing)
    debugFrame:SetClampedToScreen(true)
    debugFrame:SetToplevel(true)
    debugFrame:SetScript("OnShow", function(self) table.insert(UIPanelWindows, self) end)
    debugFrame:SetScript("OnHide", function(self)
        for i, v in ipairs(UIPanelWindows) do
            if v == self then table.remove(UIPanelWindows, i) return end
        end
    end)
    addon.UI.debugFrame = debugFrame
    
    local debugCloseButton = CreateFrame("Button", nil, debugFrame, "UIPanelCloseButton")
    debugCloseButton:SetPoint("TOPRIGHT", -4, -4)
    local debugTitle = debugFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    debugTitle:SetPoint("TOP", 0, -20)
    debugTitle:SetText("Debug Output")
    local scrollFrame = CreateFrame("ScrollFrame", "EndeavorTrackerDebugScrollFrame", debugFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    addon.UI.editBox = CreateFrame("EditBox", nil, scrollFrame)
    addon.UI.editBox:SetMultiLine(true)
    addon.UI.editBox:SetMaxLetters(0)
    addon.UI.editBox:EnableMouse(true)
    addon.UI.editBox:SetAutoFocus(false)
    addon.UI.editBox:SetFontObject("ChatFontNormal")
    addon.UI.editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(addon.UI.editBox)
    addon.UI.editBox:SetWidth(scrollFrame:GetWidth())
    addon.UI.editBox:SetHeight(scrollFrame:GetHeight())

    frame:Hide()
    debugFrame:Hide()
end