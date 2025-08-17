on run argv
    -- Search for tasks across all projects and contexts
    -- Usage: search_tasks.applescript "search term" ["all"|"available"|"remaining"] [limit]
    
    set searchTerm to item 1 of argv
    set taskFilter to "all"
    set resultLimit to 50
    
    if (count of argv) > 1 then
        set taskFilter to item 2 of argv
    end if
    
    if (count of argv) > 2 then
        set resultLimit to item 3 of argv as integer
    end if
    
    tell application "OmniFocus"
        tell default document
            -- Determine which tasks to search based on filter
            if taskFilter is "available" then
                set searchableTasks to every available task of every project
            else if taskFilter is "remaining" then
                set searchableTasks to every remaining task of every project
            else
                set searchableTasks to every flattened task
            end if
            
            -- Filter tasks by search term
            set matchingTasks to {}
            set taskCount to 0
            
            repeat with aTask in searchableTasks
                if taskCount ≥ resultLimit then exit repeat
                
                set taskName to name of aTask
                set taskNote to note of aTask
                
                -- Search in both name and note
                if (taskName contains searchTerm) or (taskNote contains searchTerm) then
                    set taskCount to taskCount + 1
                    
                    -- Build task info
                    set taskInfo to "• " & taskName
                    
                    -- Add project info if available
                    try
                        set projName to name of containing project of aTask
                        set taskInfo to taskInfo & " [" & projName & "]"
                    end try
                    
                    -- Add status indicators
                    if completed of aTask then
                        set taskInfo to taskInfo & " ✓"
                    else if flagged of aTask then
                        set taskInfo to taskInfo & " 🚩"
                    end if
                    
                    -- Add due date if present
                    try
                        set dueDate to due date of aTask
                        if dueDate is not missing value then
                            set taskInfo to taskInfo & " 📅 " & (dueDate as string)
                        end if
                    end try
                    
                    set end of matchingTasks to taskInfo
                end if
            end repeat
            
            -- Format results
            if (count of matchingTasks) = 0 then
                return "🔍 No tasks found matching: " & searchTerm
            else
                set resultText to "🔍 Found " & (count of matchingTasks) & " tasks matching \"" & searchTerm & "\":"
                repeat with taskLine in matchingTasks
                    set resultText to resultText & return & taskLine
                end repeat
                
                if taskCount = resultLimit then
                    set resultText to resultText & return & return & "... (results limited to " & resultLimit & " items)"
                end if
                
                return resultText
            end if
        end tell
    end tell
end run
