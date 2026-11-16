on run argv
    -- List all deferred tasks (tasks with defer dates in the future)
    -- Usage: list_deferred_tasks.applescript
    
    -- include_dropped: "true" also shows dropped items and items below dropped (hidden) folders
    set includeDropped to false
    if (count of argv) > 0 then set includeDropped to (item 1 of argv is "true")
    set hiddenIDs to {}
    if not includeDropped then set hiddenIDs to my hiddenFolderTaskIDs()
    
    tell application "OmniFocus"
        tell default document
            set currentTime to current date
            
            -- Get all tasks with defer dates
            if includeDropped then
                set allDeferredTasks to every flattened task whose defer date is not missing value and effectively completed is false
            else
                set allDeferredTasks to every flattened task whose defer date is not missing value and effectively completed is false and effectively dropped is false
            end if
            
            -- Filter for tasks actually deferred (defer date in future)
            set deferredTasks to {}
            repeat with aTask in allDeferredTasks
                if defer date of aTask > currentTime and not (my isHiddenItem(contents of aTask, hiddenIDs)) then
                    set end of deferredTasks to contents of aTask
                end if
            end repeat
            
            if (count of deferredTasks) = 0 then
                return "⏸️ No deferred tasks - all tasks are currently available!"
            end if
            
            -- Sort tasks by defer date (bubble sort for simplicity)
            repeat with i from 1 to (count of deferredTasks) - 1
                repeat with j from i + 1 to count of deferredTasks
                    if defer date of item j of deferredTasks < defer date of item i of deferredTasks then
                        set temp to item i of deferredTasks
                        set item i of deferredTasks to item j of deferredTasks
                        set item j of deferredTasks to temp
                    end if
                end repeat
            end repeat
            
            -- Build the output
            set taskList to "⏸️ Deferred Tasks (" & (count of deferredTasks) & " items)" & return
            set taskList to taskList & "════════════════════════════" & return & return
            
            -- Group by time periods
            set todayEnd to currentTime
            set hours of todayEnd to 23
            set minutes of todayEnd to 59
            set seconds of todayEnd to 59
            
            set tomorrowEnd to todayEnd + 1 * days
            set thisWeekEnd to todayEnd + 7 * days
            set thisMonthEnd to todayEnd + 30 * days
            
            set laterTodayTasks to {}
            set tomorrowTasks to {}
            set thisWeekTasks to {}
            set thisMonthTasks to {}
            set laterTasks to {}
            
            repeat with aTask in deferredTasks
                set deferDate to defer date of aTask
                
                if deferDate ≤ todayEnd then
                    set end of laterTodayTasks to aTask
                else if deferDate ≤ tomorrowEnd then
                    set end of tomorrowTasks to aTask
                else if deferDate ≤ thisWeekEnd then
                    set end of thisWeekTasks to aTask
                else if deferDate ≤ thisMonthEnd then
                    set end of thisMonthTasks to aTask
                else
                    set end of laterTasks to aTask
                end if
            end repeat
            
            -- Output tasks by group
            if (count of laterTodayTasks) > 0 then
                set taskList to taskList & "📅 Later Today:" & return
                repeat with aTask in laterTodayTasks
                    set taskList to taskList & my formatDeferredTask(aTask) & return
                end repeat
                set taskList to taskList & return
            end if
            
            if (count of tomorrowTasks) > 0 then
                set taskList to taskList & "📅 Tomorrow:" & return
                repeat with aTask in tomorrowTasks
                    set taskList to taskList & my formatDeferredTask(aTask) & return
                end repeat
                set taskList to taskList & return
            end if
            
            if (count of thisWeekTasks) > 0 then
                set taskList to taskList & "📅 This Week:" & return
                repeat with aTask in thisWeekTasks
                    set taskList to taskList & my formatDeferredTask(aTask) & return
                end repeat
                set taskList to taskList & return
            end if
            
            if (count of thisMonthTasks) > 0 then
                set taskList to taskList & "📅 This Month:" & return
                repeat with aTask in thisMonthTasks
                    set taskList to taskList & my formatDeferredTask(aTask) & return
                end repeat
                set taskList to taskList & return
            end if
            
            if (count of laterTasks) > 0 then
                set taskList to taskList & "📅 Later:" & return
                repeat with aTask in laterTasks
                    set taskList to taskList & my formatDeferredTask(aTask) & return
                end repeat
            end if
            
            return taskList
        end tell
    end tell
end run

on formatDeferredTask(aTask)
    tell application "OmniFocus"
        set taskName to name of aTask
        set deferDate to defer date of aTask
        
        -- Format the defer time
        set timeStr to (time string of deferDate)
        set dateStr to (date string of deferDate)
        
        -- Add project info if available
        set projectInfo to ""
        try
            set projName to name of containing project of aTask
            set projectInfo to " [" & projName & "]"
        end try
        
        -- Add flags
        set flags to ""
        if flagged of aTask then set flags to flags & " 🚩"
        
        try
            if due date of aTask is not missing value then
                set dueDate to due date of aTask
                set daysUntilDue to ((dueDate - (current date)) / days) as integer
                if daysUntilDue ≤ 7 then
                    set flags to flags & " 📅"
                end if
            end if
        end try
        
        return "• " & taskName & projectInfo & flags & return & "  ⏰ Available: " & dateStr & " at " & timeStr
    end tell
end formatDeferredTask

on hiddenFolderProjectIDs()
    -- IDs of all projects below a hidden (dropped) folder, at any depth
    set idList to {}
    tell application "OmniFocus"
        tell default document
            try
                set hiddenFolders to every flattened folder whose hidden is true
                repeat with aFolder in hiddenFolders
                    set idList to idList & (id of every flattened project of (contents of aFolder))
                end repeat
            end try
        end tell
    end tell
    return idList
end hiddenFolderProjectIDs

on hiddenFolderTaskIDs()
    -- IDs of all tasks in projects below a hidden (dropped) folder
    set idList to {}
    tell application "OmniFocus"
        tell default document
            try
                set hiddenFolders to every flattened folder whose hidden is true
                repeat with aFolder in hiddenFolders
                    set folderProjects to every flattened project of (contents of aFolder)
                    repeat with aProject in folderProjects
                        try
                            set idList to idList & (id of every flattened task of root task of (contents of aProject))
                        on error
                            set idList to idList & (id of every flattened task of (contents of aProject))
                        end try
                    end repeat
                end repeat
            end try
        end tell
    end tell
    return idList
end hiddenFolderTaskIDs

on isHiddenItem(anItem, hiddenIDs)
    -- True if the task or project is one of the items below a hidden folder
    if (count of hiddenIDs) = 0 then return false
    tell application "OmniFocus" to set itemID to id of anItem
    return (hiddenIDs contains itemID)
end isHiddenItem

on countVisible(idList, hiddenIDs)
    -- Number of IDs that are not below a hidden folder
    if (count of hiddenIDs) = 0 then return count of idList
    set visibleCount to 0
    repeat with anID in idList
        if hiddenIDs does not contain (contents of anID) then set visibleCount to visibleCount + 1
    end repeat
    return visibleCount
end countVisible
