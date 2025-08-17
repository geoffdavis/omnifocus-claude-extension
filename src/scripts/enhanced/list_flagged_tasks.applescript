on run argv
    -- List all flagged tasks across all projects
    -- Usage: list_flagged_tasks.applescript
    
    tell application "OmniFocus"
        tell default document
            set flaggedTasks to every flattened task whose flagged is true and completed is false
            
            if (count of flaggedTasks) = 0 then
                return "🚩 No flagged tasks - inbox zero for priorities!"
            end if
            
            -- Group tasks by urgency
            set currentTime to current date
            set overdueTasks to {}
            set todayTasks to {}
            set thisWeekTasks to {}
            set laterTasks to {}
            set noDueTasks to {}
            
            set todayEnd to currentTime
            set hours of todayEnd to 23
            set minutes of todayEnd to 59
            set thisWeekEnd to todayEnd + 7 * days
            
            repeat with aTask in flaggedTasks
                try
                    set taskDue to due date of aTask
                    if taskDue is missing value then
                        set end of noDueTasks to aTask
                    else if taskDue < currentTime then
                        set end of overdueTasks to aTask
                    else if taskDue ≤ todayEnd then
                        set end of todayTasks to aTask
                    else if taskDue ≤ thisWeekEnd then
                        set end of thisWeekTasks to aTask
                    else
                        set end of laterTasks to aTask
                    end if
                on error
                    set end of noDueTasks to aTask
                end try
            end repeat
            
            -- Build output
            set taskList to "🚩 Flagged Tasks (" & (count of flaggedTasks) & " items)" & return
            set taskList to taskList & "════════════════════════════" & return & return
            
            -- Overdue flagged tasks (highest priority)
            if (count of overdueTasks) > 0 then
                set taskList to taskList & "🔴 OVERDUE (" & (count of overdueTasks) & "):" & return
                repeat with aTask in overdueTasks
                    set taskList to taskList & my formatFlaggedTask(aTask, true) & return
                end repeat
                set taskList to taskList & return
            end if
            
            -- Due today
            if (count of todayTasks) > 0 then
                set taskList to taskList & "🟠 Due Today (" & (count of todayTasks) & "):" & return
                repeat with aTask in todayTasks
                    set taskList to taskList & my formatFlaggedTask(aTask, false) & return
                end repeat
                set taskList to taskList & return
            end if
            
            -- Due this week
            if (count of thisWeekTasks) > 0 then
                set taskList to taskList & "🟡 Due This Week (" & (count of thisWeekTasks) & "):" & return
                repeat with aTask in thisWeekTasks
                    set taskList to taskList & my formatFlaggedTask(aTask, false) & return
                end repeat
                set taskList to taskList & return
            end if
            
            -- Due later
            if (count of laterTasks) > 0 then
                set taskList to taskList & "🟢 Due Later (" & (count of laterTasks) & "):" & return
                repeat with aTask in laterTasks
                    set taskList to taskList & my formatFlaggedTask(aTask, false) & return
                end repeat
                set taskList to taskList & return
            end if
            
            -- No due date
            if (count of noDueTasks) > 0 then
                set taskList to taskList & "⚪ No Due Date (" & (count of noDueTasks) & "):" & return
                repeat with aTask in noDueTasks
                    set taskList to taskList & my formatFlaggedTask(aTask, false) & return
                end repeat
            end if
            
            -- Add summary
            set taskList to taskList & return & "💡 Summary:" & return
            if (count of overdueTasks) > 0 then
                set taskList to taskList & "• " & (count of overdueTasks) & " overdue tasks need immediate attention" & return
            end if
            if (count of todayTasks) > 0 then
                set taskList to taskList & "• " & (count of todayTasks) & " tasks due today" & return
            end if
            set taskList to taskList & "• " & (count of flaggedTasks) & " total flagged tasks to review"
            
            return taskList
        end tell
    end tell
end run

on formatFlaggedTask(aTask, isOverdue)
    tell application "OmniFocus"
        set taskName to name of aTask
        
        -- Get project info
        set projectInfo to ""
        try
            set projName to name of containing project of aTask
            set projectInfo to " [" & projName & "]"
        on error
            set projectInfo to " [Inbox]"
        end try
        
        -- Get due date info
        set dueInfo to ""
        try
            set dueDate to due date of aTask
            if dueDate is not missing value then
                if isOverdue then
                    set daysPast to ((current date) - dueDate) / days as integer
                    if daysPast = 0 then
                        set dueInfo to " (due earlier today)"
                    else if daysPast = 1 then
                        set dueInfo to " (1 day overdue)"
                    else
                        set dueInfo to " (" & daysPast & " days overdue)"
                    end if
                else
                    -- Format the due date nicely
                    set dueInfo to " (due " & (date string of dueDate) & ")"
                end if
            end if
        end try
        
        -- Check if task is blocked
        set availabilityInfo to ""
        try
            set deferDate to defer date of aTask
            if deferDate is not missing value and deferDate > (current date) then
                set availabilityInfo to " ⏸"
            end if
        end try
        
        return "• " & taskName & projectInfo & dueInfo & availabilityInfo
    end tell
end formatFlaggedTask
