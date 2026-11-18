on run argv
    -- Reopen a completed or dropped task (mark it as not completed and not dropped)
    -- Usage: reopen_task.applescript "task name or id:<id>"
    -- A name must match exactly one completed or dropped task; otherwise the matches are listed.

    if (count of argv) = 0 then
        return "❌ Task name is required."
    end if
    set searchTerm to my trimItem(item 1 of argv)
    if searchTerm is "" then
        return "❌ Task name cannot be empty."
    end if

    tell application "OmniFocus"
        tell default document
            -- "id:<id>" addresses exactly one task; otherwise search completed and dropped tasks by name
            -- The hidden root task of a project has the ID of its project. It is no task: the project IDs are left out of the
            -- search, and an ID that belongs to a project is refused
            set projectIDs to {}
            try
                set projectIDs to id of every flattened project
            end try
            set skippedProjects to 0

            if searchTerm starts with "id:" and (length of searchTerm) > 3 then
                set wantedID to my trimItem(text 4 thru -1 of searchTerm)
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
                set completedMatches to every flattened task whose name contains searchTerm and completed is true
                set droppedMatches to every flattened task whose name contains searchTerm and dropped is true
                set foundTasks to completedMatches
                set knownIDs to {}
                repeat with aTask in completedMatches
                    set end of knownIDs to id of aTask
                end repeat
                repeat with aTask in droppedMatches
                    if knownIDs does not contain (id of aTask) then set end of foundTasks to contents of aTask
                end repeat

                -- Root tasks of projects are no tasks
                if (count of foundTasks) > 0 and (count of projectIDs) > 0 then
                    set keptTasks to {}
                    repeat with aTask in foundTasks
                        set isProjectID to false
                        considering case
                            if projectIDs contains (id of aTask) then set isProjectID to true
                        end considering
                        if isProjectID then
                            set skippedProjects to skippedProjects + 1
                        else
                            set end of keptTasks to contents of aTask
                        end if
                    end repeat
                    set foundTasks to keptTasks
                end if

                -- An exact name wins over longer names that contain it
                if (count of foundTasks) > 1 then
                    set exactTasks to {}
                    repeat with aTask in foundTasks
                        ignoring case
                            if (name of aTask) is searchTerm then set end of exactTasks to contents of aTask
                        end ignoring
                    end repeat
                    if (count of exactTasks) = 1 then set foundTasks to exactTasks
                end if
            end if

            if (count of foundTasks) = 0 then
                set notFoundText to "❌ No completed or dropped task found for: " & searchTerm
                if skippedProjects > 0 then set notFoundText to notFoundText & return & "ℹ️ " & skippedProjects & " project(s) match this name. Projects are handled by the project tools (get_project, edit_project)."
                return notFoundText
            else if (count of foundTasks) > 1 then
                set taskList to "🔍 Multiple completed or dropped tasks found (" & (count of foundTasks) & "):" & return
                set shownCount to 0
                repeat with aTask in foundTasks
                    if shownCount ≥ 20 then
                        set taskList to taskList & "… more not shown" & return
                        exit repeat
                    end if
                    set stateMark to "✓"
                    set stateDate to missing value
                    try
                        if completed of aTask then
                            set stateDate to completion date of aTask
                        else
                            set stateMark to "🚫"
                            set stateDate to dropped date of aTask
                        end if
                    end try
                    set dateText to ""
                    if stateDate is not missing value then set dateText to " " & (date string of stateDate)
                    set taskList to taskList & "• " & name of aTask & " " & stateMark & dateText & " [id:" & (id of aTask) & "]" & return
                    set shownCount to shownCount + 1
                end repeat
                set taskList to taskList & return & "Please be more specific or use id:<id>."
                return taskList
            end if

            set targetTask to item 1 of foundTasks
            set originalName to name of targetTask

            if (completed of targetTask) is false and (dropped of targetTask) is false then
                return "ℹ️ Task is already open: " & originalName
            end if

            try
                mark incomplete targetTask
            on error errMsg
                return "❌ Error reopening task: " & errMsg
            end try

            -- Check the result; a task below a completed or dropped project or task stays inactive
            if (completed of targetTask) or (dropped of targetTask) then
                return "❌ The task could not be reopened: " & originalName
            end if
            set noteText to ""
            try
                if effectively completed of targetTask then
                    set noteText to return & "⚠️ It is still inside a completed task or project."
                else if effectively dropped of targetTask then
                    set noteText to return & "⚠️ It is still inside a dropped task or project."
                end if
            end try
            return "↩️ Reopened: " & originalName & noteText
        end tell
    end tell
end run

on trimItem(theText)
    set whitespaceChars to {" ", tab, return, linefeed}
    set textLength to length of theText
    if textLength is 0 then return ""
    set textStart to 1
    repeat while textStart ≤ textLength and character textStart of theText is in whitespaceChars
        set textStart to textStart + 1
    end repeat
    if textStart > textLength then return ""
    set textEnd to textLength
    repeat while textEnd ≥ textStart and character textEnd of theText is in whitespaceChars
        set textEnd to textEnd - 1
    end repeat
    return text textStart thru textEnd of theText
end trimItem
