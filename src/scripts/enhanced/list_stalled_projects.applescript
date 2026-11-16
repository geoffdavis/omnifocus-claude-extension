on run argv
    -- List active projects without a next action
    -- Usage: list_stalled_projects.applescript
    -- Single action lists are skipped; they have no next action by design.
    
    set hiddenIDs to my hiddenFolderProjectIDs()
    set stalledLines to {}
    
    tell application "OmniFocus"
        tell default document
            set candidateProjects to every flattened project where its effective status is active status
            repeat with aProject in candidateProjects
                set theProject to contents of aProject
                if not (my isHiddenItem(theProject, hiddenIDs)) then
                    set hintText to my projectHint(theProject)
                    if hintText is not "" then
                        set end of stalledLines to "• " & my projectLabel(theProject) & " [id:" & (id of theProject) & "]" & return & "  ⚠️ " & hintText
                    end if
                end if
            end repeat
        end tell
    end tell
    
    if (count of stalledLines) = 0 then
        return "✅ No stalled projects - every active project has a next action"
    end if
    
    set stalledList to "🧱 Stalled projects (" & (count of stalledLines) & "):"
    repeat with stalledLine in stalledLines
        set stalledList to stalledList & return & stalledLine
    end repeat
    return stalledList
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

on formatDate(aDate)
    -- Short text for a date that may be missing
    if aDate is missing value then return "never"
    return date string of aDate
end formatDate

on projectHint(aProject)
    -- Why a project may be stalled: "" if it has a next action or is a single action list
    tell application "OmniFocus"
        set openCount to count of (flattened tasks of aProject whose effectively completed is false and effectively dropped is false)
        if singleton action holder of aProject then return ""
        if openCount = 0 then return "no open tasks"
        if next task of aProject is missing value then return "no next action (open tasks are blocked or deferred)"
    end tell
    return ""
end projectHint


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
