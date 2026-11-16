on run argv
    -- Show the details of one task
    -- Usage: get_task.applescript "task name or id:<id>"
    
    if (count of argv) = 0 then
        return "❌ Task name is required."
    end if
    set searchTerm to item 1 of argv
    if searchTerm is "" then
        return "❌ Task name cannot be empty."
    end if
    
    tell application "OmniFocus"
        tell default document
            -- "id:<id>" addresses exactly one task; otherwise search open tasks by name
            if searchTerm starts with "id:" and (length of searchTerm) > 3 then
                set wantedID to text 4 thru -1 of searchTerm
                set foundTasks to every flattened task whose id is wantedID
            else
                set foundTasks to every flattened task whose name contains searchTerm and completed is false
            end if
            
            if (count of foundTasks) = 0 then
                return "❌ No matching tasks found for: " & searchTerm
            else if (count of foundTasks) > 1 then
                set taskList to "🔍 Multiple tasks found (" & (count of foundTasks) & "):" & return
                repeat with aTask in foundTasks
                    set taskList to taskList & "• " & name of aTask & " [id:" & (id of aTask) & "]" & return
                end repeat
                set taskList to taskList & return & "Please be more specific or use id:<id>."
                return taskList
            end if
            
            set targetTask to item 1 of foundTasks
            set taskInfo to "📝 " & (name of targetTask) & return
            set taskInfo to taskInfo & "ID: " & (id of targetTask) & return
            
            -- State
            set stateText to "open"
            if effectively dropped of targetTask then set stateText to "dropped"
            if effectively completed of targetTask then set stateText to "completed"
            if flagged of targetTask then set stateText to stateText & ", flagged"
            try
                if stateText starts with "open" and blocked of targetTask then set stateText to stateText & ", blocked"
            end try
            set taskInfo to taskInfo & "State: " & stateText & return
            
            -- Location
            set locationText to "Inbox"
            try
                set taskProject to containing project of targetTask
                if taskProject is not missing value then set locationText to my projectLabel(taskProject)
            end try
            set taskInfo to taskInfo & "Project: " & locationText & return
            try
                set taskParent to parent task of targetTask
                if taskParent is not missing value then
                    set parentName to name of taskParent
                    if parentName is not locationText and locationText does not end with parentName then
                        set taskInfo to taskInfo & "Parent task: " & parentName & return
                    end if
                end if
            end try
            
            -- Tags
            set tagNames to name of every tag of targetTask
            if (count of tagNames) > 0 then
                set oldDelims to AppleScript's text item delimiters
                set AppleScript's text item delimiters to ", "
                set taskInfo to taskInfo & "Tags: " & (tagNames as string) & return
                set AppleScript's text item delimiters to oldDelims
            end if
            
            -- Dates and estimate
            set deferValue to defer date of targetTask
            if deferValue is not missing value then set taskInfo to taskInfo & "Deferred until: " & (deferValue as string) & return
            try
                set plannedValue to planned date of targetTask
                if plannedValue is not missing value then set taskInfo to taskInfo & "Planned: " & (plannedValue as string) & return
            end try
            set dueValue to due date of targetTask
            if dueValue is not missing value then set taskInfo to taskInfo & "Due: " & (dueValue as string) & return
            set estimateValue to estimated minutes of targetTask
            if estimateValue is not missing value then set taskInfo to taskInfo & "Estimate: " & estimateValue & " minutes" & return
            set subtaskCount to number of tasks of targetTask
            if subtaskCount > 0 then set taskInfo to taskInfo & "Subtasks: " & subtaskCount & return
            
            -- Note, shortened if very long
            set taskNote to note of targetTask
            if taskNote is not "" then
                if (length of taskNote) > 2000 then set taskNote to (text 1 thru 2000 of taskNote) & "..."
                set taskInfo to taskInfo & "Note: " & taskNote & return
            end if
            return taskInfo
        end tell
    end tell
end run

on projectFolderNames(aProject)
    -- Folder names from the outermost folder down to the one holding the project; {} at top level
    set folderNames to {}
    tell application "OmniFocus"
        try
            set currentFolder to folder of aProject
            repeat while currentFolder is not missing value
                set beginning of folderNames to name of currentFolder
                set parentContainer to container of currentFolder
                if class of parentContainer is folder then
                    set currentFolder to parentContainer
                else
                    set currentFolder to missing value
                end if
            end repeat
        end try
    end tell
    return folderNames
end projectFolderNames

on projectLabel(aProject)
    -- "Folder > Subfolder > Project", the same form resolveProject accepts
    tell application "OmniFocus" to set projectName to name of aProject
    set labelText to ""
    repeat with folderName in my projectFolderNames(aProject)
        set labelText to labelText & folderName & " > "
    end repeat
    return labelText & projectName
end projectLabel

