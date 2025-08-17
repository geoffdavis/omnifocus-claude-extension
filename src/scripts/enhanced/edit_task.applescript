on run argv
    -- Edit an existing task
    -- Usage: edit_task.applescript "task name" "property" "new value"
    -- Properties: name, note, due_date, defer_date, flagged, project, context, estimated_minutes
    
    set searchTerm to item 1 of argv
    set propertyName to item 2 of argv
    set newValue to item 3 of argv
    
    tell application "OmniFocus"
        tell default document
            -- Find the task
            set foundTasks to every flattened task whose name contains searchTerm and completed is false
            
            if (count of foundTasks) = 0 then
                return "❌ No matching tasks found for: " & searchTerm
            else if (count of foundTasks) > 1 then
                -- Multiple matches - show them
                set taskList to "🔍 Multiple tasks found (" & (count of foundTasks) & "):" & return
                repeat with aTask in foundTasks
                    set taskList to taskList & "• " & name of aTask & return
                end repeat
                set taskList to taskList & return & "Please be more specific."
                return taskList
            end if
            
            -- Single task found - edit it
            set targetTask to item 1 of foundTasks
            set originalName to name of targetTask
            
            try
                if propertyName is "name" then
                    set name of targetTask to newValue
                    return "✏️ Renamed task: \"" & originalName & "\" → \"" & newValue & "\""
                    
                else if propertyName is "note" then
                    set note of targetTask to newValue
                    return "✏️ Updated note for: " & originalName
                    
                else if propertyName is "due_date" or propertyName is "due" then
                    if newValue is "none" or newValue is "clear" then
                        set due date of targetTask to missing value
                        return "✏️ Cleared due date for: " & originalName
                    else
                        -- Parse date string (basic parsing)
                        set parsedDate to my parseDate(newValue)
                        set due date of targetTask to parsedDate
                        return "✏️ Set due date to " & (parsedDate as string) & " for: " & originalName
                    end if
                    
                else if propertyName is "defer_date" or propertyName is "defer" then
                    if newValue is "none" or newValue is "clear" then
                        set defer date of targetTask to missing value
                        return "✏️ Cleared defer date for: " & originalName
                    else
                        set parsedDate to my parseDate(newValue)
                        set defer date of targetTask to parsedDate
                        return "✏️ Set defer date to " & (parsedDate as string) & " for: " & originalName
                    end if
                    
                else if propertyName is "flagged" or propertyName is "flag" then
                    if newValue is "true" or newValue is "yes" or newValue is "1" then
                        set flagged of targetTask to true
                        return "🚩 Flagged: " & originalName
                    else
                        set flagged of targetTask to false
                        return "🏳️ Unflagged: " & originalName
                    end if
                    
                else if propertyName is "project" then
                    if newValue is "inbox" or newValue is "none" then
                        set containing project of targetTask to missing value
                        return "📥 Moved to inbox: " & originalName
                    else
                        set matchingProjects to every project whose name contains newValue
                        if (count of matchingProjects) > 0 then
                            set containing project of targetTask to item 1 of matchingProjects
                            return "📁 Moved to project \"" & name of item 1 of matchingProjects & "\": " & originalName
                        else
                            return "❌ Project not found: " & newValue
                        end if
                    end if
                    
                else if propertyName is "estimated_minutes" or propertyName is "estimate" then
                    set estimated minutes of targetTask to (newValue as integer)
                    return "⏱️ Set estimate to " & newValue & " minutes for: " & originalName
                    
                else
                    return "❌ Unknown property: " & propertyName & ". Valid properties: name, note, due_date, defer_date, flagged, project, estimated_minutes"
                end if
                
            on error errMsg
                return "❌ Error updating task: " & errMsg
            end try
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
        -- Try to parse as date directly
        try
            return date dateString
        on error
            return todayDate
        end try
    end if
end parseDate
