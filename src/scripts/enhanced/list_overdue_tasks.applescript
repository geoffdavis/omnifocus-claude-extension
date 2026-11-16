on run argv
    -- List all overdue tasks
    -- Usage: list_overdue_tasks.applescript
    
    tell application "OmniFocus"
        tell default document
            set currentTime to current date
            -- Open tasks only: not completed and not dropped, also not through their project or parent task
            try
                set overdueTasks to every flattened task whose due date < currentTime and effectively completed is false and effectively dropped is false
            on error
                set overdueTasks to every flattened task whose due date < currentTime and completed is false
            end try
            
            if (count of overdueTasks) = 0 then
                return "✅ No overdue tasks! You're all caught up!"
            end if
            
            -- Sort tasks by how overdue they are (most overdue first)
            repeat with i from 1 to (count of overdueTasks) - 1
                repeat with j from i + 1 to count of overdueTasks
                    if due date of item j of overdueTasks < due date of item i of overdueTasks then
                        set temp to item i of overdueTasks
                        set item i of overdueTasks to item j of overdueTasks
                        set item j of overdueTasks to temp
                    end if
                end repeat
            end repeat
            
            -- Group by overdue period
            set todayOverdue to {}
            set yesterdayOverdue to {}
            set thisWeekOverdue to {}
            set lastWeekOverdue to {}
            set olderOverdue to {}
            
            set todayStart to currentTime
            set hours of todayStart to 0
            set minutes of todayStart to 0
            set seconds of todayStart to 0
            
            set yesterdayStart to todayStart - 1 * days
            set weekAgoStart to todayStart - 7 * days
            set twoWeeksAgoStart to todayStart - 14 * days
            
            repeat with aTask in overdueTasks
                set dueDate to due date of aTask
                
                if dueDate ≥ todayStart then
                    set end of todayOverdue to aTask
                else if dueDate ≥ yesterdayStart then
                    set end of yesterdayOverdue to aTask
                else if dueDate ≥ weekAgoStart then
                    set end of thisWeekOverdue to aTask
                else if dueDate ≥ twoWeeksAgoStart then
                    set end of lastWeekOverdue to aTask
                else
                    set end of olderOverdue to aTask
                end if
            end repeat
            
            -- Build output
            set taskList to "⚠️ Overdue Tasks (" & (count of overdueTasks) & " items)" & return
            set taskList to taskList & "════════════════════════════" & return & return
            
            -- Earlier today
            if (count of todayOverdue) > 0 then
                set taskList to taskList & "🔴 Earlier Today (" & (count of todayOverdue) & "):" & return
                repeat with aTask in todayOverdue
                    set taskList to taskList & my formatOverdueTask(aTask) & return
                end repeat
                set taskList to taskList & return
            end if
            
            -- Yesterday
            if (count of yesterdayOverdue) > 0 then
                set taskList to taskList & "🟠 Yesterday (" & (count of yesterdayOverdue) & "):" & return
                repeat with aTask in yesterdayOverdue
                    set taskList to taskList & my formatOverdueTask(aTask) & return
                end repeat
                set taskList to taskList & return
            end if
            
            -- This week
            if (count of thisWeekOverdue) > 0 then
                set taskList to taskList & "🟡 This Week (" & (count of thisWeekOverdue) & "):" & return
                repeat with aTask in thisWeekOverdue
                    set taskList to taskList & my formatOverdueTask(aTask) & return
                end repeat
                set taskList to taskList & return
            end if
            
            -- Last week
            if (count of lastWeekOverdue) > 0 then
                set taskList to taskList & "📅 Last Week (" & (count of lastWeekOverdue) & "):" & return
                repeat with aTask in lastWeekOverdue
                    set taskList to taskList & my formatOverdueTask(aTask) & return
                end repeat
                set taskList to taskList & return
            end if
            
            -- Older
            if (count of olderOverdue) > 0 then
                set taskList to taskList & "📆 Older (" & (count of olderOverdue) & "):" & return
                repeat with aTask in olderOverdue
                    set taskList to taskList & my formatOverdueTask(aTask) & return
                end repeat
                set taskList to taskList & return
            end if
            
            -- Add action summary
            set taskList to taskList & return & "💡 Recommended Actions:" & return
            
            -- Count flagged overdue
            set flaggedOverdue to 0
            repeat with aTask in overdueTasks
                if flagged of aTask then set flaggedOverdue to flaggedOverdue + 1
            end repeat
            
            if flaggedOverdue > 0 then
                set taskList to taskList & "• " & flaggedOverdue & " flagged tasks are overdue - prioritize these first" & return
            end if
            
            if (count of olderOverdue) > 0 then
                set taskList to taskList & "• " & (count of olderOverdue) & " tasks are significantly overdue - consider rescheduling or dropping" & return
            end if
            
            if (count of overdueTasks) > 10 then
                set taskList to taskList & "• Large backlog detected - consider a focused catch-up session" & return
            end if
            
            set taskList to taskList & "• Review and either complete, reschedule, or drop each overdue task"
            
            return taskList
        end tell
    end tell
end run

on formatOverdueTask(aTask)
    tell application "OmniFocus"
        set taskName to name of aTask
        set dueDate to due date of aTask
        set currentTime to current date
        
        -- Calculate how overdue
        set hoursOverdue to (currentTime - dueDate) / hours as integer
        set daysOverdue to (currentTime - dueDate) / days as integer
        
        set overdueText to ""
        if hoursOverdue < 24 then
            if hoursOverdue = 1 then
                set overdueText to "1 hour ago"
            else
                set overdueText to hoursOverdue & " hours ago"
            end if
        else if daysOverdue = 1 then
            set overdueText to "1 day ago"
        else
            set overdueText to daysOverdue & " days ago"
        end if
        
        -- Get project info
        set projectInfo to ""
        try
            set projName to name of containing project of aTask
            set projectInfo to " [" & projName & "]"
        on error
            set projectInfo to " [Inbox]"
        end try
        
        -- Check flags
        set flags to ""
        if flagged of aTask then set flags to " 🚩"
        
        -- Check if blocked by defer date
        try
            set deferDate to defer date of aTask
            if deferDate is not missing value and deferDate > currentTime then
                set flags to flags & " ⏸"
            end if
        end try
        
        return "• " & taskName & projectInfo & flags & return & "  ⏰ Was due: " & overdueText & " (" & (date string of dueDate) & ")"
    end tell
end formatOverdueTask
