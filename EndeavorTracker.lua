-- Forward declarations for UI elements and state
local frame, debugFrame, editBox, title, progressBar, progressText, estimatedProgressBar, estimatedProgressText, contributionText, taskScrollChild
local taskBoxes = {}
local currentSort = "Contribution"
local sortFunctions = {}

-- Forward declarations for functions
local UpdateDisplay

-- Helper function to format a table into a string
local function FormatTableForDebug(tbl)
    local result = {}
    local function recurse(t, indent)
        indent = indent or 0
        local prefix = string.rep("  ", indent)
        for k, v in pairs(t) do
            if type(v) == "table" then
                table.insert(result, prefix .. k .. ":")
                recurse(v, indent + 1)
            else
                table.insert(result, prefix .. k .. ": " .. tostring(v))
            end
        end
    end
    recurse(tbl)
    return table.concat(result, "\n")
end

-- Helper function to round to a number of decimal places
local function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Sorting functions table
sortFunctions = {
    ["Default"] = function(a, b)
        if a.completed and not b.completed then return false end
        if not a.completed and b.completed then return true end
        return a.sortOrder < b.sortOrder
    end,
    ["Name"] = function(a, b)
        if a.completed and not b.completed then return false end
        if not a.completed and b.completed then return true end
        if a.taskName ~= b.taskName then return a.taskName < b.taskName else return a.sortOrder < b.sortOrder end
    end,
    ["Contribution"] = function(a, b)
        if a.completed and not b.completed then return false end
        if not a.completed and b.completed then return true end
        if a.progressContributionAmount ~= b.progressContributionAmount then
            return (a.progressContributionAmount or 0) > (b.progressContributionAmount or 0)
        else
            return a.sortOrder < b.sortOrder
        end
    end,
    ["Status"] = function(a, b)
        local function getStatusValue(task)
            if task.completed then return 3 end
            if task.inProgress then return 1 end
            return 2
        end
        local statusA = getStatusValue(a)
        local statusB = getStatusValue(b)
        if statusA ~= statusB then
            return statusA < statusB
        else
            return a.sortOrder < b.sortOrder
        end
    end,
}

-- Main display update function
UpdateDisplay = function()
    if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo then
        local initiativeInfo = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
        if initiativeInfo and initiativeInfo.isLoaded then
            -- Update debug frame
            local debugText = FormatTableForDebug(initiativeInfo)
            editBox:SetText(debugText)

            -- Update main frame
            title:SetText(initiativeInfo.title)
            progressBar:SetMinMaxValues(0, initiativeInfo.progressRequired)
            progressBar:SetValue(initiativeInfo.currentProgress)
            progressText:SetText(round(initiativeInfo.currentProgress, 2) .. " / " .. initiativeInfo.progressRequired)

            -- Update estimated progress bar
            local conversionRate = 0.0886874728733333
            local estimatedCurrent = round(initiativeInfo.currentProgress / conversionRate, 2)
            local calculatedMax = round(initiativeInfo.progressRequired / conversionRate, 2)
            estimatedProgressBar:SetMinMaxValues(0, calculatedMax)
            estimatedProgressBar:SetValue(estimatedCurrent)
            estimatedProgressText:SetText("Est: " .. estimatedCurrent .. " / " .. calculatedMax)
            
            local estimatedPlayerContribution = math.floor(initiativeInfo.playerTotalContribution / conversionRate)
            contributionText:SetText("Your Contribution: " .. round(initiativeInfo.playerTotalContribution, 2) .. " (Est: " .. estimatedPlayerContribution .. ")")

            -- Hide all existing task boxes before updating
            for _, box in ipairs(taskBoxes) do
                box:Hide()
            end

            if initiativeInfo.tasks then
                table.sort(initiativeInfo.tasks, sortFunctions[currentSort])
                
                local lastBox = nil
                local totalHeight = 0
                local boxSpacing = 10

                for i, task in ipairs(initiativeInfo.tasks) do
                    local box = taskBoxes[i]
                    if not box then
                        box = CreateFrame("Frame", nil, taskScrollChild, "BackdropTemplate")
                        box:SetWidth(taskScrollChild:GetWidth())
                        box:SetBackdrop({
                            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                            tile = true, tileSize = 16, edgeSize = 16,
                            insets = { left = 4, right = 4, top = 4, bottom = 4 }
                        })
                        box:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

                        box.taskName = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                        box.taskName:SetPoint("TOPLEFT", 5, -5)
                        box.taskName:SetJustifyH("LEFT")
                        box.taskName:SetNonSpaceWrap(true)
                        box.taskName:SetWidth(box:GetWidth() - 10)

                        box.requirements = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                        box.requirements:SetPoint("TOPLEFT", box.taskName, "BOTTOMLEFT", 0, -5)
                        box.requirements:SetJustifyH("LEFT")
                        box.requirements:SetNonSpaceWrap(true)
                        box.requirements:SetWidth(box:GetWidth() - 10)

                        box.status = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                        box.status:SetPoint("TOPLEFT", box.requirements, "BOTTOMLEFT", 0, -5)
                        box.status:SetJustifyH("LEFT")
                        
                        box.contribution = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                        box.contribution:SetPoint("TOPRIGHT", box.requirements, "BOTTOMRIGHT", 0, -5)
                        box.contribution:SetJustifyH("RIGHT")

                        taskBoxes[i] = box
                    end

                    -- Populate data
                    local taskName = task.taskName
                    if task.timesCompleted and task.timesCompleted > 0 then
                        taskName = taskName .. " |cff888888(Completed x" .. task.timesCompleted .. ")|r"
                    end
                    box.taskName:SetText(taskName)
                    
                    local reqText = {}
                    if task.requirementsList then
                        for _, req in ipairs(task.requirementsList) do
                           if req.requirementsText then
                                table.insert(reqText, req.requirementsText)
                           end
                        end
                    end
                    box.requirements:SetText(table.concat(reqText, "\n"))

                    if task.completed then
                        box.status:SetText("|cff00ff00Completed|r")
                    else
                        box.status:SetText("")
                    end
                    
                    box.contribution:SetText("Contribution: " .. task.progressContributionAmount)

                    -- Calculate height and position
                    local reqHeight = box.requirements:GetStringHeight()
                    local nameHeight = box.taskName:GetStringHeight()
                    local statusHeight = box.status:GetStringHeight()
                    local contributionHeight = box.contribution:GetStringHeight()
                    local bottomLineHeight = math.max(statusHeight, contributionHeight)
                    local requiredHeight = nameHeight + reqHeight + bottomLineHeight + 20 -- Padding
                    box:SetHeight(requiredHeight)

                    if i == 1 then
                        box:SetPoint("TOPLEFT", 0, 0)
                    else
                        box:SetPoint("TOP", lastBox, "BOTTOM", 0, -boxSpacing)
                    end
                    
                    box:Show()
                    lastBox = box
                    totalHeight = totalHeight + requiredHeight + boxSpacing
                end
                
                if #initiativeInfo.tasks > 0 then
                    totalHeight = totalHeight - boxSpacing
                end
                taskScrollChild:SetHeight(totalHeight)
            end
        end
    end
end

-- Main addon initialization function
local function Initialize()
    -- Create the main frame
    frame = CreateFrame("Frame", "EndeavorTrackerFrame", UIParent, "BackdropTemplate")
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
    
    -- Add a close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)

    -- Add a title
    title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Endeavor Leaderboards")

    -- Add progress bars and text
    progressBar = CreateFrame("StatusBar", nil, frame)
    progressBar:SetSize(310, 20)
    progressBar:SetPoint("TOP", 0, -50)
    progressBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    progressBar:SetStatusBarColor(0, 1, 0)
    progressText = progressBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    progressText:SetPoint("CENTER")
    progressText:SetText("0 / 0")

    estimatedProgressBar = CreateFrame("StatusBar", nil, frame)
    estimatedProgressBar:SetSize(310, 20)
    estimatedProgressBar:SetPoint("TOP", 0, -80)
    estimatedProgressBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    estimatedProgressBar:SetStatusBarColor(0, 0, 1)
    estimatedProgressText = estimatedProgressBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    estimatedProgressText:SetPoint("CENTER")
    estimatedProgressText:SetText("Est: 0 / 0")

    -- Add contribution text
    contributionText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    contributionText:SetPoint("TOP", 0, -110)
    contributionText:SetText("Your Contribution: 0")

    -- Add task list title
    local taskListTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    taskListTitle:SetPoint("TOP", contributionText, "BOTTOM", 0, -10)
    taskListTitle:SetText("Task List")

    -- Create sorting dropdown
    local sortDropdown = CreateFrame("Frame", "EndeavorTrackerSortDropdown", frame, "UIDropDownMenuTemplate")
    sortDropdown:SetPoint("TOPRIGHT", -30, -135)
    local function OnSortChanged(self)
        UIDropDownMenu_SetSelectedValue(sortDropdown, self.value)
        currentSort = self.value
        UpdateDisplay()
    end
    local function InitializeSortDropdown()
        for _, sortKey in ipairs({"Default", "Status", "Contribution", "Name"}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = sortKey
            info.value = sortKey
            info.func = OnSortChanged
            UIDropDownMenu_AddButton(info, 1)
        end
    end
    UIDropDownMenu_Initialize(sortDropdown, InitializeSortDropdown)
    UIDropDownMenu_SetSelectedValue(sortDropdown, currentSort)
    UIDropDownMenu_SetWidth(sortDropdown, 120)
    UIDropDownMenu_JustifyText(sortDropdown, "RIGHT")

    -- Create scroll frame for the task list
    local taskScrollFrame = CreateFrame("ScrollFrame", "EndeavorTrackerTaskScrollFrame", frame, "UIPanelScrollFrameTemplate")
    taskScrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -155)
    taskScrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    taskScrollChild = CreateFrame("Frame")
    taskScrollChild:SetWidth(taskScrollFrame:GetWidth())
    taskScrollFrame:SetScrollChild(taskScrollChild)

    -- Create the debug frame
    debugFrame = CreateFrame("Frame", "EndeavorTrackerDebugFrame", UIParent, "BackdropTemplate")
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
    
    local debugCloseButton = CreateFrame("Button", nil, debugFrame, "UIPanelCloseButton")
    debugCloseButton:SetPoint("TOPRIGHT", -4, -4)
    local debugTitle = debugFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    debugTitle:SetPoint("TOP", 0, -20)
    debugTitle:SetText("Debug Output")
    local scrollFrame = CreateFrame("ScrollFrame", "EndeavorTrackerDebugScrollFrame", debugFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)
    editBox:EnableMouse(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetHeight(scrollFrame:GetHeight())

    frame:Hide()
    debugFrame:Hide()
end

-- Main event handler frame
local mainEventFrame = CreateFrame("Frame")
mainEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        Initialize() -- Create all UI elements

        -- Create a separate event frame for updates
        local updateEventFrame = CreateFrame("Frame")
        updateEventFrame:RegisterEvent("NEIGHBORHOOD_INITIATIVE_UPDATED")
        updateEventFrame:SetScript("OnEvent", function(...)
            UpdateDisplay()
        end)

        -- Initial data request
        if C_NeighborhoodInitiative and C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo then
            C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
        end
    end
end)

-- Slash commands
SLASH_ENDEAVORTRACKER1 = "/endtr"
SlashCmdList["ENDEAVORTRACKER"] = function()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

SLASH_ENDEAVORTRACKERDEBUG1 = "/endebug"
SlashCmdList["ENDEAVORTRACKERDEBUG"] = function()
    if debugFrame:IsShown() then debugFrame:Hide() else debugFrame:Show() end
end