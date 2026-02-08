-- EndeavorTracker/EndeavorTracker.lua

EndeavorTracker = {}
local addon = EndeavorTracker

local taskBoxes = {}
addon.searchFilter = ""

function addon.FilterTasks(text)
    addon.searchFilter = text or ""
    addon.UpdateDisplay()
end

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

-- Main display update function
function addon.UpdateDisplay()
    if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo then
        local initiativeInfo = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
        if initiativeInfo and initiativeInfo.isLoaded then
            -- Update debug frame
            local debugText = FormatTableForDebug(initiativeInfo)
            addon.UI.editBox:SetText(debugText)

            -- Update main frame
            addon.UI.title:SetText(initiativeInfo.title)
            addon.UI.progressBar:SetMinMaxValues(0, initiativeInfo.progressRequired)
            addon.UI.progressBar:SetValue(initiativeInfo.currentProgress)
            addon.UI.progressText:SetText(round(initiativeInfo.currentProgress, 2) .. " / " .. initiativeInfo.progressRequired)

            -- Update estimated progress bar
            local conversionRate = 0.0886874728733333
            local estimatedCurrent = round(initiativeInfo.currentProgress / conversionRate, 2)
            local calculatedMax = round(initiativeInfo.progressRequired / conversionRate, 2)
            addon.UI.estimatedProgressBar:SetMinMaxValues(0, calculatedMax)
            addon.UI.estimatedProgressBar:SetValue(estimatedCurrent)
            addon.UI.estimatedProgressText:SetText("Est: " .. estimatedCurrent .. " / " .. calculatedMax)
            
            local estimatedPlayerContribution = math.floor(initiativeInfo.playerTotalContribution / conversionRate)
            addon.UI.contributionText:SetText("Your Contribution: " .. round(initiativeInfo.playerTotalContribution, 2) .. " (Est: " .. estimatedPlayerContribution .. ")")

            -- Hide all existing task boxes before updating
            for _, box in ipairs(taskBoxes) do
                box:Hide()
            end

            if initiativeInfo.tasks then
                local filteredTasks = {}
                if addon.searchFilter and addon.searchFilter ~= "" then
                    for _, task in ipairs(initiativeInfo.tasks) do
                        if task.taskName and string.find(string.lower(task.taskName), string.lower(addon.searchFilter), 1, true) then
                            table.insert(filteredTasks, task)
                        end
                    end
                else
                    filteredTasks = initiativeInfo.tasks
                end

                table.sort(filteredTasks, addon.Sort.sortFunctions[addon.Sort.currentSort])
                
                local lastBox = nil
                local totalHeight = 0
                local boxSpacing = 10

                for i, task in ipairs(filteredTasks) do
                    local box = taskBoxes[i]
                    if not box then
                        box = CreateFrame("Frame", nil, addon.UI.taskScrollChild, "BackdropTemplate")
                        box:SetWidth(addon.UI.taskScrollChild:GetWidth())
                        box:SetBackdrop({
                            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                            tile = true, tileSize = 16, edgeSize = 16,
                            insets = { left = 4, right = 4, top = 4, bottom = 4 }
                        })
                        box:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

                        box.trackedPip = box:CreateTexture(nil, "ARTWORK")
                        box.trackedPip:SetSize(24, 24)
                        box.trackedPip:SetPoint("TOPLEFT", 10, -10)

                        box.taskName = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                        box.taskName:SetPoint("TOPLEFT", box.trackedPip, "TOPRIGHT", 5, 0)
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
                        box.status:SetWidth(box:GetWidth() - 70)
                        box.status:SetJustifyH("LEFT")
                        
                        box.contributionBanner = box:CreateTexture(nil, "ARTWORK")
                        box.contributionBanner:SetAtlas("housing-dashboard-tasks-listitem-flag")
                        box.contributionBanner:SetSize(64, 32)
                        box.contributionBanner:SetPoint("RIGHT", box, "RIGHT", 0, 0)

                        box.contribution = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        box.contribution:SetPoint("CENTER", box.contributionBanner, "CENTER", 0, 0)
                        box.contribution:SetJustifyH("CENTER")
                        box.contribution:SetTextColor(1, 1, 0) -- Yellow

                        box.rewardIcon = box:CreateTexture(nil, "ARTWORK")
                        box.rewardIcon:SetSize(18, 18)
                        box.rewardText = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")

                        box:EnableMouse(true)

                        box:SetScript("OnEnter", function(self)
                            self:SetBackdropColor(0.25, 0.25, 0.25, 0.8)
                        end)

                        box:SetScript("OnLeave", function(self)
                            self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                        end)

                        box:SetScript("OnMouseUp", function(self, button)
                            if button == "RightButton" and self.taskID and self.taskID > 0 and not self.isCompleted then
                                if self.isTracked then
                                    pcall(C_NeighborhoodInitiative.RemoveTrackedInitiativeTask, self.taskID)
                                else
                                    pcall(C_NeighborhoodInitiative.AddTrackedInitiativeTask, self.taskID)
                                end
                            end
                        end)

                        taskBoxes[i] = box
                    end

                    -- Populate data
                    box.taskID = task.ID
                    box.isTracked = task.tracked
                    box.isCompleted = task.completed
                    local taskName = task.taskName
                    if task.timesCompleted and task.timesCompleted > 0 then
                        taskName = taskName .. " |cff888888(Completed x" .. task.timesCompleted .. ")|r"
                    end
                    box.taskName:SetText(taskName)

                    if box.isCompleted then
                        box.trackedPip:SetAtlas("housing-dashboard-fillbar-pip-incomplete")
                        box.trackedPip:SetVertexColor(0.5, 0.5, 0.5, 1) -- Grey tint
                        box:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5) -- Grey
                    else
                        box.trackedPip:SetVertexColor(1, 1, 1, 1) -- Remove tint
                        if box.isTracked then
                            box.trackedPip:SetAtlas("housing-dashboard-fillbar-pip-complete")
                            box:SetBackdropBorderColor(1, 0.84, 0, 1) -- Gold
                        else
                            box.trackedPip:SetAtlas("housing-dashboard-fillbar-pip-incomplete")
                            box:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5) -- Grey
                        end
                    end

                    if task.rewardQuestID and task.rewardQuestID > 0 then
                        local currencies = C_QuestLog.GetQuestRewardCurrencies(task.rewardQuestID)
                        if currencies and #currencies > 0 and currencies[1] then
                            local reward = currencies[1]
                            box.rewardIcon:SetTexture(reward.texture)
                            box.rewardText:SetText(reward.totalRewardAmount)
                            box.rewardText:SetPoint("RIGHT", box.contributionBanner, "LEFT", -5, 0)
                            box.rewardIcon:SetPoint("RIGHT", box.rewardText, "LEFT", -2, 0)
                            box.rewardIcon:Show()
                            box.rewardText:Show()
                        else
                            box.rewardIcon:Hide()
                            box.rewardText:Hide()
                        end
                    else
                        box.rewardIcon:Hide()
                        box.rewardText:Hide()
                    end
                    
                    local reqText = {}
                    if task.requirementsList then
                        for _, req in ipairs(task.requirementsList) do
                           if req.requirementText then
                                table.insert(reqText, req.requirementText)
                           end
                        end
                    end
                    box.requirements:SetText(table.concat(reqText, "\n"))

                    if task.completed then
                        box.status:SetText("|cff00ff00Completed|r")
                    elseif task.inProgress then
                        box.status:SetText("")
                    else
                        box.status:SetText("")
                    end
                    
                    box.contribution:SetText(task.progressContributionAmount)

                    -- Set fixed height and position
                    local fixedHeight = 64
                    box:SetHeight(fixedHeight)
                    box.contributionBanner:SetSize(64, fixedHeight + 8)

                    if i == 1 then
                        box:SetPoint("TOPLEFT", 0, -10) -- Add padding
                    else
                        box:SetPoint("TOP", lastBox, "BOTTOM", 0, -boxSpacing)
                    end
                    
                    box:Show()
                    lastBox = box
                    totalHeight = totalHeight + fixedHeight + boxSpacing
                end
                
                if #filteredTasks > 0 then
                    totalHeight = totalHeight - boxSpacing
                end
                addon.UI.taskScrollChild:SetHeight(totalHeight)
            end
        end
    end
end

-- Main event handler frame
local mainEventFrame = CreateFrame("Frame")
mainEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        EndeavorTrackerDB = EndeavorTrackerDB or {}
        EndeavorTrackerDB.minimap = EndeavorTrackerDB.minimap or {}

        addon.UI.CreateFrames() -- Create all UI elements
        
        local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
        if ldb then
            local dataobj = ldb:NewDataObject("EndeavorTracker", {
                type = "launcher",
                icon = "Interface\\AddOns\\EndeavorTracker\\Media\\minimap-icon.tga",
                label = "Endeavor Tracker",
                OnClick = function(_, button)
                    if button == "LeftButton" then
                        if addon.UI.frame:IsShown() then addon.UI.frame:Hide() else addon.UI.frame:Show() end
                    end
                end,
                OnTooltipShow = function(tooltip)
                    if not tooltip or not tooltip.AddLine then return end
                    tooltip:AddLine("Endeavor Tracker")
                    tooltip:AddLine("|cffeda55fClick|r to toggle the main window.")
                end
            })

            local icon = LibStub("LibDBIcon-1.0", true)
            if icon then
                icon:Register("EndeavorTracker", dataobj, EndeavorTrackerDB.minimap)
            end
        end

        -- Create a separate event frame for updates
        local updateEventFrame = CreateFrame("Frame")
        updateEventFrame:RegisterEvent("NEIGHBORHOOD_INITIATIVE_UPDATED")
        updateEventFrame:RegisterEvent("INITIATIVE_TASKS_TRACKED_UPDATED")
        updateEventFrame:RegisterEvent("INITIATIVE_TASKS_TRACKED_LIST_CHANGED")
        updateEventFrame:SetScript("OnEvent", function(...)
            addon.UpdateDisplay()
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
    if addon.UI.frame:IsShown() then addon.UI.frame:Hide() else addon.UI.frame:Show() end
end

SLASH_ENDEAVORTRACKERDEBUG1 = "/endebug"
SlashCmdList["ENDEAVORTRACKERDEBUG"] = function()
    if addon.UI.debugFrame:IsShown() then addon.UI.debugFrame:Hide() else addon.UI.debugFrame:Show() end
end