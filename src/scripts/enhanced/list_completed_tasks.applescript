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

    set hiddenProjectIDList to my hiddenFolderProjectIDs()
    set checkHidden to ((count of hiddenProjectIDList) > 0)
    set cutoffDate to (current date) - dayCount * days

    -- Every Apple Event costs about 17 ms, a query for one property of all elements about 0.1 s: the properties of all
    -- tasks, projects and folders are fetched at once (the same position in each list is the same item)
    tell application "OmniFocus"
        tell default document
            set completedList to completed of every flattened task
            set completionDateList to completion date of every flattened task
            set taskIDList to id of every flattened task
            set taskNameList to name of every flattened task
            set taskProjectIDList to id of containing project of every flattened task
            set projectIDList to id of every flattened project
            set projectNameList to name of every flattened project
            set projectFolderIDList to id of folder of every flattened project
            set folderIDList to id of every flattened folder
            set folderNameList to name of every flattened folder
            set folderParentIDList to id of container of every flattened folder
        end tell
    end tell

    -- The completed tasks of the period (positions in the lists) and when they were completed
    set doneIndexes to {}
    set sortKeys to {}
    repeat with i from 1 to count of taskIDList
        if item i of completedList then
            set completedAt to item i of completionDateList
            if completedAt is not missing value then
                if completedAt ≥ cutoffDate then
                    set isHidden to false
                    if checkHidden then
                        set projectID to item i of taskProjectIDList
                        if projectID is not missing value then
                            if hiddenProjectIDList contains projectID then set isHidden to true
                        end if
                    end if
                    if not isHidden then
                        set end of doneIndexes to i
                        set end of sortKeys to completedAt - cutoffDate
                    end if
                end if
            end if
        end if
    end repeat

    set totalCount to count of doneIndexes
    if totalCount = 0 then
        return "✅ No tasks completed in the last " & dayCount & " days"
    end if

    -- Newest first (tasks completed at the same time keep their order)
    set sortedPositions to my sortPositions(sortKeys)
    set shownCount to totalCount
    if shownCount > maxResults then set shownCount to maxResults

    set projectCacheIDs to {}
    set projectCacheLabels to {}
    set reportText to "✅ Completed in the last " & dayCount & " days (" & totalCount & ")"
    set lastDay to ""
    repeat with n from 1 to shownCount
        set i to item (item n of sortedPositions) of doneIndexes
        set completedAt to item i of completionDateList
        set taskID to item i of taskIDList

        -- Project with folder path (cached per project)
        set projectLabelText to "Inbox"
        set projectID to item i of taskProjectIDList
        if projectID is not missing value then
            set cacheIndex to my indexOfItem(projectID, projectCacheIDs)
            if cacheIndex = 0 then
                set projectIndex to my indexOfItem(projectID, projectIDList)
                if projectIndex > 0 then
                    set projectLabelText to item projectIndex of projectNameList
                    set folderPathText to my folderPathOf(item projectIndex of projectFolderIDList, folderIDList, folderNameList, folderParentIDList)
                    if folderPathText is not "" then set projectLabelText to folderPathText & " > " & projectLabelText
                end if
                set end of projectCacheIDs to projectID
                set end of projectCacheLabels to projectLabelText
            else
                set projectLabelText to item cacheIndex of projectCacheLabels
            end if
        end if

        set entry to "• " & (item i of taskNameList) & " [" & projectLabelText & "] ✓ " & (my shortTime(completedAt)) & " [id:" & taskID & "]"
        set dayText to my shortDate(completedAt)
        if dayText is not lastDay then
            set lastDay to dayText
            set reportText to reportText & return & return & "📅 " & lastDay
        end if
        set reportText to reportText & return & entry
    end repeat
    if totalCount > shownCount then
        set reportText to reportText & return & return & "… " & (totalCount - shownCount) & " more not shown (limit " & maxResults & ")."
    end if
    return reportText
end run

on sortPositions(keyList)
    -- The positions 1 to n of keyList, largest key first (bottom-up merge sort, equal keys keep their order)
    set itemCount to count of keyList
    set orderList to {}
    repeat with i from 1 to itemCount
        set end of orderList to i
    end repeat
    set blockSize to 1
    repeat while blockSize < itemCount
        set mergedList to {}
        set blockStart to 1
        repeat while blockStart ≤ itemCount
            set leftPos to blockStart
            set leftEnd to blockStart + blockSize - 1
            if leftEnd > itemCount then set leftEnd to itemCount
            set rightPos to blockStart + blockSize
            set rightEnd to blockStart + 2 * blockSize - 1
            if rightEnd > itemCount then set rightEnd to itemCount
            repeat while leftPos ≤ leftEnd and rightPos ≤ rightEnd
                if (item (item leftPos of orderList) of keyList) ≥ (item (item rightPos of orderList) of keyList) then
                    set end of mergedList to item leftPos of orderList
                    set leftPos to leftPos + 1
                else
                    set end of mergedList to item rightPos of orderList
                    set rightPos to rightPos + 1
                end if
            end repeat
            repeat while leftPos ≤ leftEnd
                set end of mergedList to item leftPos of orderList
                set leftPos to leftPos + 1
            end repeat
            repeat while rightPos ≤ rightEnd
                set end of mergedList to item rightPos of orderList
                set rightPos to rightPos + 1
            end repeat
            set blockStart to blockStart + 2 * blockSize
        end repeat
        set orderList to mergedList
        set blockSize to blockSize * 2
    end repeat
    return orderList
end sortPositions

on folderPathOf(folderID, folderIDList, folderNameList, folderParentIDList)
    -- "Folder > Subfolder" of the folder with this ID, from the lists of all folders ("" without a folder)
    set pathNames to {}
    set currentID to folderID
    repeat while currentID is not missing value
        set folderIndex to my indexOfItem(currentID, folderIDList)
        if folderIndex = 0 then exit repeat
        set beginning of pathNames to item folderIndex of folderNameList
        set currentID to item folderIndex of folderParentIDList
    end repeat
    return my joinText(pathNames, " > ")
end folderPathOf

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

on hiddenFolderProjectIDs()
    -- IDs of all projects below a hidden (dropped) folder, at any depth. One query per list instead of one per project:
    -- every Apple Event costs about 17 ms, a query for all elements about 50 ms.
    set idList to {}
    tell application "OmniFocus"
        tell default document
            try
                set hiddenFlags to effectively hidden of every flattened folder
                if hiddenFlags does not contain true then return {}
                set hiddenFolderIDList to id of every flattened folder whose effectively hidden is true
                set projectIDList to id of every flattened project
                set projectFolderIDList to id of folder of every flattened project
                repeat with i from 1 to count of projectIDList
                    set folderID to item i of projectFolderIDList
                    if folderID is not missing value then
                        if hiddenFolderIDList contains folderID then set end of idList to item i of projectIDList
                    end if
                end repeat
            end try
        end tell
    end tell
    return idList
end hiddenFolderProjectIDs

on shortDate(aDate)
    -- "2026-11-18": year, month and day with the digits 0 to 9 in a fixed order, independent of the language and the date
    -- format of the Mac (and shorter than "Wednesday, 18. November 2026" for a reader that counts tokens)
    set monthNumber to (month of aDate) as integer
    return (my plainNumberText(year of aDate)) & "-" & (text -2 thru -1 of ("0" & my plainNumberText(monthNumber))) & "-" & (text -2 thru -1 of ("0" & my plainNumberText(day of aDate)))
end shortDate

on shortTime(aDate)
    -- "08:30": hours and minutes with the digits 0 to 9
    return (text -2 thru -1 of ("0" & my plainNumberText(hours of aDate))) & ":" & (text -2 thru -1 of ("0" & my plainNumberText(minutes of aDate)))
end shortTime

on shortDateTime(aDate)
    -- "2026-11-18" for a date at midnight (a date without a time), "2026-11-18 08:30" otherwise
    if (time of aDate) is 0 then return my shortDate(aDate)
    return (my shortDate(aDate)) & " " & (my shortTime(aDate))
end shortDateTime

on plainNumberText(theNumber)
    -- A whole number as text with the digits 0 to 9. "as text" and "&" write the digits of the region instead
    -- (Eastern Arabic digits on a Mac with an Arabic or Persian region), which breaks text that is read by a program,
    -- for example an iCalendar rule.
    set wholeNumber to theNumber as integer
    if wholeNumber < 0 then return "-" & my plainNumberText(0 - wholeNumber)
    if wholeNumber < 10 then return character (wholeNumber + 1) of "0123456789"
    return (my plainNumberText(wholeNumber div 10)) & (character ((wholeNumber mod 10) + 1) of "0123456789")
end plainNumberText
