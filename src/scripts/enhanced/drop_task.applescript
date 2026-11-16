on run argv
    -- Drop a task, or delete it permanently when explicitly confirmed
    -- Usage: drop_task.applescript "task name" ["true"|"false"]
    -- The second argument must be exactly "true" to delete instead of drop.

    if (count of argv) = 0 then
        return "❌ Task name is required."
    end if

    set searchTerm to item 1 of argv
    set confirmDelete to false
    if (count of argv) > 1 then set confirmDelete to (item 2 of argv is "true")

    if searchTerm is "" then
        return "❌ Task name cannot be empty."
    end if

    tell application "OmniFocus"
        tell default document
            -- Find the task
            set foundTasks to every flattened task whose name contains searchTerm and completed is false

            if (count of foundTasks) = 0 then
                return "❌ No matching tasks found for: " & searchTerm
            else if (count of foundTasks) > 1 then
                set taskList to "🔍 Multiple tasks found (" & (count of foundTasks) & "):" & return
                repeat with aTask in foundTasks
                    set taskList to taskList & "• " & name of aTask & return
                end repeat
                set taskList to taskList & return & "Nothing was changed. Please be more specific."
                return taskList
            end if

            set targetTask to item 1 of foundTasks
            set originalName to name of targetTask

            try
                if confirmDelete then
                    delete targetTask
                    return "🗑️ Permanently deleted: " & originalName
                else
                    mark dropped targetTask
                    return "🚫 Dropped: " & originalName
                end if
            on error errMsg
                return "❌ Error: " & errMsg
            end try
        end tell
    end tell
end run
