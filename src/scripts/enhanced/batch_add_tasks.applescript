on run argv
    -- Create multiple tasks at once
    -- Usage: batch_add_tasks.applescript "task1|task2|task3" "project_name" "due_date" "flagged"
    
    set taskNames to item 1 of argv
    set projectName to ""
    set dueDate to ""
    set isFlagged to false
    
    if (count of argv) > 1 then
        set projectName to item 2 of argv
    end if
    
    if (count of argv) > 2 then
        set dueDate to item 3 of argv
    end if
    
    if (count of argv) > 3 then
        set isFlagged to (item 4 of argv is "true")
    end if
    
    -- Parse pipe-separated task names
    set AppleScript's text item delimiters to "|"
    set taskList to text items of taskNames
    set AppleScript's text item delimiters to ""
    
    tell application "OmniFocus"
        tell default document
            set createdTasks to {}
            set targetProject to missing value
            
            -- Find target project if specified
            if projectName is not "" and projectName is not "inbox" then
                try
                    set matchingProjects to every project whose name contains projectName
                    if (count of matchingProjects) > 0 then
                        set targetProject to item 1 of matchingProjects
                    end if
                end try
            end if
            
            -- Parse due date if specified
            set parsedDueDate to missing value
            if dueDate is not "" then
                set parsedDueDate to my parseDate(dueDate)
            end if
            
            -- Create each task
            repeat with taskName in taskList
                set taskName to taskName as string
                
                -- Check for subtask indicator (starts with -)
                set isSubtask to false
                set parentTask to missing value
                if taskName starts with "-" then
                    set isSubtask to true
                    set taskName to text 2 thru -1 of taskName -- Remove leading dash
                    
                    -- Get the last non-subtask as parent
                    if (count of createdTasks) > 0 then
                        repeat with i from (count of createdTasks) to 1 by -1
                            set potentialParent to item i of createdTasks
                            if class of potentialParent is not missing value then
                                set parentTask to potentialParent
                                exit repeat
                            end if
                        end repeat
                    end if
                end if
                
                -- Trim whitespace
                set taskName to my trimText(taskName)
                
                if taskName is not "" then
                    try
                        if targetProject is not missing value then
                            -- Create in project
                            if isSubtask and parentTask is not missing value then
                                tell parentTask
                                    set newTask to make new task with properties {name:taskName, flagged:isFlagged}
                                end tell
                            else
                                tell targetProject
                                    set newTask to make new task with properties {name:taskName, flagged:isFlagged}
                                end tell
                            end if
                        else
                            -- Create in inbox
                            set newTask to make new inbox task with properties {name:taskName, flagged:isFlagged}
                        end if
                        
                        -- Set due date if specified
                        if parsedDueDate is not missing value then
                            set due date of newTask to parsedDueDate
                        end if
                        
                        set end of createdTasks to newTask
                    on error
                        set end of createdTasks to missing value
                    end try
                end if
            end repeat
            
            -- Return summary
            set successCount to 0
            repeat with aTask in createdTasks
                if aTask is not missing value then
                    set successCount to successCount + 1
                end if
            end repeat
            
            if successCount = 0 then
                return "❌ Failed to create any tasks"
            else
                set resultText to "✅ Created " & successCount & " task"
                if successCount > 1 then set resultText to resultText & "s"
                
                if targetProject is not missing value then
                    set resultText to resultText & " in project: " & name of targetProject
                else
                    set resultText to resultText & " in inbox"
                end if
                
                if parsedDueDate is not missing value then
                    set resultText to resultText & return & "📅 Due: " & (parsedDueDate as string)
                end if
                
                if isFlagged then
                    set resultText to resultText & return & "🚩 All tasks flagged"
                end if
                
                return resultText
            end if
        end tell
    end tell
end run

on parseDate(dateString)
    set todayDate to current date
    
    if dateString is "today" then
        return todayDate
    else if dateString is "tomorrow" then
        return todayDate + 1 * days
    else if dateString is "next week" then
        return todayDate + 7 * days
    else if dateString contains "days" then
        try
            set dayCount to word 1 of dateString as integer
            return todayDate + dayCount * days
        on error
            return todayDate
        end try
    else
        try
            return date dateString
        on error
            return todayDate
        end try
    end if
end parseDate

on trimText(txt)
    set txt to txt as string
    repeat while txt begins with " "
        set txt to text 2 thru -1 of txt
    end repeat
    repeat while txt ends with " "
        set txt to text 1 thru -2 of txt
    end repeat
    return txt
end trimText
