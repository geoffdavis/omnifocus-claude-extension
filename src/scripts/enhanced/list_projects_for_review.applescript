on run argv
    -- List projects whose review is due
    -- Usage: list_projects_for_review.applescript [days ahead]
    
    set daysAhead to 0
    if (count of argv) > 0 then
        try
            set daysAhead to (item 1 of argv) as integer
        end try
    end if
    
    -- Projects below hidden (dropped) folders are not reviewed
    set hiddenIDs to my hiddenFolderProjectIDs()
    set reviewLimit to (current date) + daysAhead * days
    set dueProjects to {}
    
    tell application "OmniFocus"
        tell default document
            set candidateProjects to every flattened project whose next review date ≤ reviewLimit
            repeat with aProject in candidateProjects
                set theProject to contents of aProject
                set projectState to effective status of theProject
                if projectState is active status or projectState is on hold status then
                    if not (my isHiddenItem(theProject, hiddenIDs)) then set end of dueProjects to theProject
                end if
            end repeat
            
            if (count of dueProjects) = 0 then
                return "✅ No projects due for review"
            end if
            
            set reviewList to "🔎 Projects due for review (" & (count of dueProjects) & "):" & return
            repeat with aProject in dueProjects
                set theProject to contents of aProject
                set reviewList to reviewList & "• " & my projectLabel(theProject)
                if effective status of theProject is on hold status then set reviewList to reviewList & " ⏸"
                set reviewList to reviewList & " [id:" & (id of theProject) & "]" & return
                set reviewList to reviewList & "  Last reviewed: " & my formatDate(last review date of theProject)
                set reviewList to reviewList & " | Review due: " & my formatDate(next review date of theProject)
                set hintText to my projectHint(theProject)
                if hintText is not "" then set reviewList to reviewList & " | ⚠️ " & hintText
                set reviewList to reviewList & return
            end repeat
            return reviewList
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
