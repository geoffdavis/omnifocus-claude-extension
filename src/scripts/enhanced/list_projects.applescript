on run argv
    -- List all active projects with optional task statistics
    -- Usage: list_projects.applescript ["true"|"false"]
    
    set includeStats to false
    
    if (count of argv) > 0 then
        set includeStats to (item 1 of argv is "true")
    end if
    
    -- include_dropped: "true" also shows dropped items and items below dropped (hidden) folders
    set includeDropped to false
    if (count of argv) > 1 then set includeDropped to (item 2 of argv is "true")
    set hiddenIDs to {}
    if not includeDropped then set hiddenIDs to my hiddenFolderProjectIDs()
    
    tell application "OmniFocus"
        tell default document
            -- The effective status also reflects a project's containers
            set allActiveProjects to every flattened project where its effective status is active status
            set allOnHoldProjects to every flattened project where its effective status is on hold status
            set droppedProjects to every flattened project where its effective status is dropped status
            
            -- Projects below hidden (dropped) folders count as dropped
            set activeProjects to {}
            set hiddenProjects to {}
            repeat with aProject in allActiveProjects
                if my isHiddenItem(contents of aProject, hiddenIDs) then
                    set end of hiddenProjects to contents of aProject
                else
                    set end of activeProjects to contents of aProject
                end if
            end repeat
            set totalOnHold to 0
            set onHoldProjects to {}
            repeat with aProject in allOnHoldProjects
                if my isHiddenItem(contents of aProject, hiddenIDs) then
                    set end of hiddenProjects to contents of aProject
                else
                    set totalOnHold to totalOnHold + 1
                    set end of onHoldProjects to contents of aProject
                end if
            end repeat
            
            set totalActive to count of activeProjects
            set totalDropped to (count of droppedProjects) + (count of hiddenProjects)
            
            if totalActive = 0 then
                return "📁 No active projects" & return & "(" & totalOnHold & " on hold, " & totalDropped & " dropped)"
            end if
            
            set projectList to "📁 Projects Overview" & return
            set projectList to projectList & "════════════════════" & return
            set projectList to projectList & "Active: " & totalActive & " | On Hold: " & totalOnHold & " | Dropped: " & totalDropped & return & return
            
            set projectList to projectList & "📂 Active Projects:" & return
            
            repeat with aProject in activeProjects
                set projectName to name of aProject
                set projectNote to note of aProject
                set folderText to my projectFolderText(contents of aProject)
                
                if includeStats then
                    -- Count various task states
                    set allTasks to tasks of aProject
                    set remainingCount to count of (tasks of aProject whose effectively completed is false and effectively dropped is false)
                    set availableCount to my countAvailable(contents of aProject)
                    set flaggedCount to count of (tasks of aProject whose flagged is true and effectively completed is false and effectively dropped is false)
                    
                    -- Check for due soon tasks (next 7 days)
                    set weekFromNow to (current date) + 7 * days
                    set dueSoonCount to count of (tasks of aProject whose due date ≤ weekFromNow and due date ≥ (current date) and effectively completed is false and effectively dropped is false)
                    
                    set projectList to projectList & "• " & projectName & folderText
                    set projectList to projectList & " (" & remainingCount & " remaining"
                    
                    if availableCount > 0 then
                        set projectList to projectList & ", " & availableCount & " available"
                    end if
                    
                    if flaggedCount > 0 then
                        set projectList to projectList & ", " & flaggedCount & " flagged"
                    end if
                    
                    if dueSoonCount > 0 then
                        set projectList to projectList & ", " & dueSoonCount & " due soon"
                    end if
                    
                    set projectList to projectList & ")"
                    
                    -- Add project note preview if exists
                    if projectNote is not "" then
                        set noteLength to length of projectNote
                        set previewLength to my minValue(50, noteLength)
                        set notePreview to text 1 thru previewLength of projectNote
                        if noteLength > 50 then set notePreview to notePreview & "..."
                        set projectList to projectList & return & "  💬 " & notePreview
                    end if
                else
                    set projectList to projectList & "• " & projectName & folderText
                end if
                
                set projectList to projectList & return
            end repeat
            
            -- On hold projects, with their folder path
            if (count of onHoldProjects) > 0 then
                set projectList to projectList & return & "⏸ On Hold Projects:" & return
                repeat with aProject in onHoldProjects
                    set projectList to projectList & "• " & (name of aProject) & my projectFolderText(contents of aProject) & return
                end repeat
            end if

            -- With include_dropped: also list dropped projects, with their folder path
            if includeDropped and (count of droppedProjects) > 0 then
                set projectList to projectList & return & "🚫 Dropped Projects:" & return
                repeat with aProject in droppedProjects
                    set projectList to projectList & "• " & (name of aProject) & my projectFolderText(contents of aProject) & return
                end repeat
            end if
            
            -- Add summary statistics if requested
            if includeStats then
                set projectList to projectList & return & "📊 Summary Statistics:" & return
                
                -- Calculate totals across all active projects
                set totalRemaining to 0
                set totalAvailable to 0
                set totalFlagged to 0
                
                repeat with aProject in activeProjects
                    set totalRemaining to totalRemaining + (count of (tasks of aProject whose effectively completed is false and effectively dropped is false))
                    set totalAvailable to totalAvailable + (my countAvailable(contents of aProject))
                    set totalFlagged to totalFlagged + (count of (tasks of aProject whose flagged is true and effectively completed is false and effectively dropped is false))
                end repeat
                
                set projectList to projectList & "• Total remaining tasks: " & totalRemaining & return
                set projectList to projectList & "• Total available tasks: " & totalAvailable & return
                set projectList to projectList & "• Total flagged tasks: " & totalFlagged
            end if
            
            return projectList
        end tell
    end tell
end run

on projectFolderText(aProject)
    -- " — 📂 Folder > Subfolder" for a project inside folders, "" at top level
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
    if (count of folderNames) = 0 then return ""
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to " > "
    set folderText to folderNames as string
    set AppleScript's text item delimiters to oldDelims
    return " — 📂 " & folderText
end projectFolderText

on minValue(x, y)
    if x < y then
        return x
    else
        return y
    end if
end minValue

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

on countAvailable(aProject)
    -- Open tasks that are neither blocked nor deferred to the future
    set availableCount to 0
    set nowDate to current date
    tell application "OmniFocus"
        set openTasks to (tasks of aProject whose effectively completed is false and effectively dropped is false)
        repeat with aTask in openTasks
            set isAvailable to true
            try
                if blocked of aTask then set isAvailable to false
            end try
            try
                set deferDate to defer date of aTask
                if deferDate is not missing value and deferDate > nowDate then set isAvailable to false
            end try
            if isAvailable then set availableCount to availableCount + 1
        end repeat
    end tell
    return availableCount
end countAvailable
