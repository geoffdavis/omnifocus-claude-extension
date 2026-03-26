on run argv
    -- Remove a tag from a task in OmniFocus
    -- Usage: remove_tag_from_task.applescript "task name" "tag name"

    if (count of argv) < 2 then
        return "❌ Both task name and tag name are required."
    end if

    set searchTerm to item 1 of argv
    set tagName to item 2 of argv

    if searchTerm is "" then
        return "❌ Task name cannot be empty."
    end if
    if tagName is "" then
        return "❌ Tag name cannot be empty."
    end if

    tell application "OmniFocus"
        tell default document
            -- Find the tag
            set matchingTags to every tag whose name is tagName
            if (count of matchingTags) = 0 then
                return "❌ Tag not found: " & tagName
            end if
            set theTag to item 1 of matchingTags

            -- Find the task
            set foundTasks to every flattened task whose name contains searchTerm and completed is false

            if (count of foundTasks) = 0 then
                return "❌ No matching tasks found for: " & searchTerm
            else if (count of foundTasks) > 1 then
                set taskList to "🔍 Multiple tasks found (" & (count of foundTasks) & "):" & return
                repeat with aTask in foundTasks
                    set taskList to taskList & "• " & name of aTask & return
                end repeat
                set taskList to taskList & return & "Please be more specific."
                return taskList
            end if

            set targetTask to item 1 of foundTasks
            set originalName to name of targetTask

            try
                remove theTag from tags of targetTask
                return "🏷️ Removed tag \"" & tagName & "\" from: " & originalName
            on error errMsg
                return "❌ Error removing tag: " & errMsg
            end try
        end tell
    end tell
end run
