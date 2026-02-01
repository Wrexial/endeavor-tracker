-- EndeavorTracker/Sort.lua

local addon = EndeavorTracker
addon.Sort = {}

addon.Sort.currentSort = "Contribution"

addon.Sort.sortFunctions = {
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

function addon.Sort.SetSort(sortKey)
    addon.Sort.currentSort = sortKey
    addon.UpdateDisplay()
end