on run argv
    -- List tasks that were completed within the last N days, newest first, grouped by day
    -- Usage: list_completed_tasks.applescript days limit
    --   days:  look back this many days (default 7)
    --   limit: maximum number of tasks to list (default 100)
    -- Tasks below dropped (hidden) folders are left out.

    set dayCount to 7
    set maxResults to 100
    if (count of argv) > 0 then
        try
            set dayCount to (item 1 of argv) as integer
        end try
    end if
    if (count of argv) > 1 then
        try
            set maxResults to (item 2 of argv) as integer
        end try
    end if
    if dayCount < 1 then set dayCount to 7
    if maxResults < 1 then set maxResults to 100

    set hiddenIDs to my hiddenFolderTaskIDs()
    set cutoffDate to (current date) - dayCount * days

    set sortKeys to {}
    set sortEntries to {}
    set sortDays to {}
    set projectCacheIDs to {}
    set projectCacheLabels to {}

    tell application "OmniFocus"
        tell default document
            set doneTasks to every flattened task whose completed is true and completion date ≥ cutoffDate

            repeat with aTask in doneTasks
                set theTask to contents of aTask
                set taskID to id of theTask
                if hiddenIDs does not contain taskID then
                    set completedAt to completion date of theTask

                    -- Project with folder path (cached per project)
                    set projectLabelText to "Inbox"
                    set theProject to missing value
                    try
                        set theProject to containing project of theTask
                    end try
                    if theProject is not missing value then
                        set projectID to id of theProject
                        set cacheIndex to my indexOfItem(projectID, projectCacheIDs)
                        if cacheIndex = 0 then
                            set folderNames to my projectFolderNames(theProject)
                            set projectLabelText to name of theProject
                            if (count of folderNames) > 0 then set projectLabelText to (my joinText(folderNames, " > ")) & " > " & projectLabelText
                            set end of projectCacheIDs to projectID
                            set end of projectCacheLabels to projectLabelText
                        else
                            set projectLabelText to item cacheIndex of projectCacheLabels
                        end if
                    end if

                    set entry to "• " & (name of theTask) & " [" & projectLabelText & "] ✓ " & (time string of completedAt) & " [id:" & taskID & "]"
                    set keyValue to completedAt - cutoffDate
                    set dayText to date string of completedAt

                    -- Insert so that the newest task comes first
                    set insertAt to (count of sortKeys) + 1
                    repeat with i from 1 to count of sortKeys
                        if keyValue > (item i of sortKeys) then
                            set insertAt to i
                            exit repeat
                        end if
                    end repeat
                    set sortKeys to my insertItem(sortKeys, keyValue, insertAt)
                    set sortEntries to my insertItem(sortEntries, entry, insertAt)
                    set sortDays to my insertItem(sortDays, dayText, insertAt)
                end if
            end repeat
        end tell
    end tell

    set totalCount to count of sortKeys
    if totalCount = 0 then
        return "✅ No tasks completed in the last " & dayCount & " days"
    end if

    set shownCount to totalCount
    if shownCount > maxResults then set shownCount to maxResults

    set reportText to "✅ Completed in the last " & dayCount & " days (" & totalCount & ")"
    set lastDay to ""
    repeat with i from 1 to shownCount
        if (item i of sortDays) is not lastDay then
            set lastDay to item i of sortDays
            set reportText to reportText & return & return & "📅 " & lastDay
        end if
        set reportText to reportText & return & (item i of sortEntries)
    end repeat
    if totalCount > shownCount then
        set reportText to reportText & return & return & "… " & (totalCount - shownCount) & " more not shown (limit " & maxResults & ")."
    end if
    return reportText
end run

on insertItem(aList, anItem, idx)
    -- Returns a copy of aList with anItem inserted at position idx
    set listLength to count of aList
    if idx > listLength then return aList & {anItem}
    if idx = 1 then return {anItem} & aList
    return (items 1 thru (idx - 1) of aList) & {anItem} & (items idx thru -1 of aList)
end insertItem

on indexOfItem(anItem, aList)
    -- Position of anItem in aList, 0 if it is not in the list
    repeat with i from 1 to count of aList
        if (item i of aList) is anItem then return i
    end repeat
    return 0
end indexOfItem

on joinText(textItems, separator)
    -- Joins a list of text items with a separator
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to separator
    set joinedText to textItems as text
    set AppleScript's text item delimiters to oldDelims
    return joinedText
end joinText

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
