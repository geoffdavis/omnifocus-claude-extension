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
            -- The hidden root task of a project has the ID of its project. It is no task: the project IDs are left out of the
            -- search, and an ID that belongs to a project is refused
            set projectIDs to {}
            try
                set projectIDs to id of every flattened project
            end try

            -- "id:<id>" addresses exactly one task; otherwise search open tasks by name
            set skippedProjects to 0
            if searchTerm starts with "id:" and (length of searchTerm) > 3 then
                set wantedID to text 4 thru -1 of searchTerm
                set isProjectID to false
                considering case
                    if projectIDs contains wantedID then set isProjectID to true
                end considering
                if isProjectID then
                    set projectMatches to every flattened project whose id is wantedID
                    set projectNameText to wantedID
                    if (count of projectMatches) > 0 then set projectNameText to name of item 1 of projectMatches
                    return "❌ id:" & wantedID & " is a project, not a task: " & projectNameText & return & "Nothing was changed. Projects are handled by the project tools (get_project, edit_project)."
                end if
                set foundTasks to every flattened task whose id is wantedID
            else
                set foundTasks to every flattened task whose name contains searchTerm and completed is false
                if (count of foundTasks) > 0 and (count of projectIDs) > 0 then
                    -- Same condition, same order: the IDs tell which hits are root tasks of projects
                    set foundIDs to id of every flattened task whose name contains searchTerm and completed is false
                    set keptTasks to {}
                    repeat with i from 1 to count of foundTasks
                        set isProjectID to false
                        considering case
                            if projectIDs contains (item i of foundIDs) then set isProjectID to true
                        end considering
                        if isProjectID then
                            set skippedProjects to skippedProjects + 1
                        else
                            set end of keptTasks to item i of foundTasks
                        end if
                    end repeat
                    set foundTasks to keptTasks
                end if
            end if

            if (count of foundTasks) = 0 then
                set notFoundText to "❌ No matching tasks found for: " & searchTerm
                if skippedProjects > 0 then set notFoundText to notFoundText & return & "ℹ️ " & skippedProjects & " project(s) match this name. Projects are handled by the project tools (get_project, edit_project)."
                return notFoundText
            else if (count of foundTasks) > 1 then
                set taskList to "🔍 Multiple tasks found (" & (count of foundTasks) & "):" & return
                repeat with aTask in foundTasks
                    set taskList to taskList & "• " & name of aTask & " [id:" & (id of aTask) & "]" & return
                end repeat
                set taskList to taskList & return & "Nothing was changed. Please be more specific or use id:<id>."
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
