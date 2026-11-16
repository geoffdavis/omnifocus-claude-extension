on run argv
    -- Search for tasks across all projects and contexts
    -- Usage: search_tasks.applescript "search term" ["all"|"available"|"remaining"] [limit] [include_dropped]
    
    set searchTerm to item 1 of argv
    set taskFilter to "all"
    set resultLimit to 50
    
    if (count of argv) > 1 then
        set taskFilter to item 2 of argv
    end if
    
    if (count of argv) > 2 then
        set resultLimit to item 3 of argv as integer
    end if
    
    -- include_dropped: "true" also shows dropped items and items below dropped (hidden) folders
    set includeDropped to false
    if (count of argv) > 3 then set includeDropped to (item 4 of argv is "true")
    set hiddenIDs to {}
    if not includeDropped then set hiddenIDs to my hiddenFolderTaskIDs()
    
    tell application "OmniFocus"
        tell default document
            -- Determine which tasks to search based on filter
            -- "remaining" and "available": open tasks only; "all" also includes completed tasks.
            -- Dropped tasks are left out unless include_dropped is set.
            if taskFilter is "available" or taskFilter is "remaining" then
                if includeDropped then
                    set searchableTasks to every flattened task whose effectively completed is false
                else
                    set searchableTasks to every flattened task whose effectively completed is false and effectively dropped is false
                end if
            else
                if includeDropped then
                    set searchableTasks to every flattened task
                else
                    set searchableTasks to every flattened task whose effectively dropped is false
                end if
            end if
            
            -- Filter tasks by search term
            set matchingTasks to {}
            set taskCount to 0
            
            repeat with aTask in searchableTasks
                if taskCount ≥ resultLimit then exit repeat
                
                set taskName to name of aTask
                set taskNote to note of aTask
                
                -- Search in both name and note
                set taskMatches to (taskName contains searchTerm) or (taskNote contains searchTerm)

                -- "available" additionally excludes blocked tasks and tasks deferred to the future
                if taskMatches and taskFilter is "available" then
                    try
                        if blocked of aTask then set taskMatches to false
                    end try
                    try
                        set taskDefer to defer date of aTask
                        if taskDefer is not missing value and taskDefer > (current date) then set taskMatches to false
                    end try
                end if

                -- Leave out tasks of projects below hidden (dropped) folders
                if taskMatches and my isHiddenItem(contents of aTask, hiddenIDs) then set taskMatches to false
                
                if taskMatches then
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
                    
                    set taskInfo to taskInfo & " [id:" & (id of aTask) & "]"
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
