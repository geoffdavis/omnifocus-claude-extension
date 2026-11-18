on run argv
    -- List all overdue tasks
    -- Usage: list_overdue_tasks.applescript

    -- include_dropped: "true" also shows dropped items and items below dropped (hidden) folders
    set includeDropped to false
    if (count of argv) > 0 then set includeDropped to (item 1 of argv is "true")
    set hiddenProjectIDList to {}
    if not includeDropped then set hiddenProjectIDList to my hiddenFolderProjectIDs()

    -- Every Apple Event costs about 17 ms, a query for one property of all tasks about 0.1 s: the properties of all tasks
    -- are fetched at once (the same position in each list is the same task) and filtered and sorted in the script
    tell application "OmniFocus"
        tell default document
            set taskNameList to name of every flattened task
            set flaggedList to flagged of every flattened task
            set dueDateList to due date of every flattened task
            set deferDateList to defer date of every flattened task
            set effCompletedList to effectively completed of every flattened task
            set effDroppedList to effectively dropped of every flattened task
            set containerIDList to id of containing project of every flattened task
            set containerNameList to name of containing project of every flattened task
        end tell
    end tell
    set currentTime to current date

    -- Open tasks only: not completed or dropped, also not through their project or parent task;
    -- tasks of projects below hidden (dropped) folders are left out
    set overdueIndexes to {}
    repeat with t from 1 to count of taskNameList
        set dueDate to item t of dueDateList
        if dueDate is not missing value then
            if dueDate < currentTime and not (item t of effCompletedList) then
                if includeDropped or not (item t of effDroppedList) then
                    if not my isHiddenProjectID(item t of containerIDList, hiddenProjectIDList) then set end of overdueIndexes to t
                end if
            end if
        end if
    end repeat

    if (count of overdueIndexes) = 0 then
        return "✅ No overdue tasks! You're all caught up!"
    end if

    -- Sort tasks by how overdue they are (most overdue first)
    set overdueIndexes to my sortPositionsAscending(overdueIndexes, dueDateList)

    -- Group by overdue period
    set todayOverdue to {}
    set yesterdayOverdue to {}
    set thisWeekOverdue to {}
    set lastWeekOverdue to {}
    set olderOverdue to {}

    copy currentTime to todayStart
    set hours of todayStart to 0
    set minutes of todayStart to 0
    set seconds of todayStart to 0

    set yesterdayStart to todayStart - 1 * days
    set weekAgoStart to todayStart - 7 * days
    set twoWeeksAgoStart to todayStart - 14 * days

    repeat with idx in overdueIndexes
        set t to contents of idx
        set dueDate to item t of dueDateList
        set lineText to my formatOverdueTask(item t of taskNameList, dueDate, item t of containerNameList, item t of flaggedList, item t of deferDateList, currentTime)

        if dueDate ≥ todayStart then
            set end of todayOverdue to lineText
        else if dueDate ≥ yesterdayStart then
            set end of yesterdayOverdue to lineText
        else if dueDate ≥ weekAgoStart then
            set end of thisWeekOverdue to lineText
        else if dueDate ≥ twoWeeksAgoStart then
            set end of lastWeekOverdue to lineText
        else
            set end of olderOverdue to lineText
        end if
    end repeat

    -- Build output
    set taskList to "⚠️ Overdue Tasks (" & (count of overdueIndexes) & " items)" & return
    set taskList to taskList & return

    -- Earlier today
    if (count of todayOverdue) > 0 then
        set taskList to taskList & "🔴 Earlier Today (" & (count of todayOverdue) & "):" & return
        repeat with lineText in todayOverdue
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    -- Yesterday
    if (count of yesterdayOverdue) > 0 then
        set taskList to taskList & "🟠 Yesterday (" & (count of yesterdayOverdue) & "):" & return
        repeat with lineText in yesterdayOverdue
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    -- This week
    if (count of thisWeekOverdue) > 0 then
        set taskList to taskList & "🟡 This Week (" & (count of thisWeekOverdue) & "):" & return
        repeat with lineText in thisWeekOverdue
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    -- Last week
    if (count of lastWeekOverdue) > 0 then
        set taskList to taskList & "📅 Last Week (" & (count of lastWeekOverdue) & "):" & return
        repeat with lineText in lastWeekOverdue
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    -- Older
    if (count of olderOverdue) > 0 then
        set taskList to taskList & "📆 Older (" & (count of olderOverdue) & "):" & return
        repeat with lineText in olderOverdue
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    return taskList
end run

on formatOverdueTask(taskName, dueDate, projectName, isFlagged, deferDate, currentTime)
    -- One entry from values that are already read: no Apple Events
    -- Calculate how overdue
    set hoursOverdue to (currentTime - dueDate) / hours as integer
    set daysOverdue to (currentTime - dueDate) / days as integer

    set overdueText to ""
    if hoursOverdue < 24 then
        if hoursOverdue = 1 then
            set overdueText to "1 hour ago"
        else
            set overdueText to hoursOverdue & " hours ago"
        end if
    else if daysOverdue = 1 then
        set overdueText to "1 day ago"
    else
        set overdueText to daysOverdue & " days ago"
    end if

    -- Project info; tasks outside projects are in the inbox
    set projectInfo to " [Inbox]"
    if projectName is not missing value then set projectInfo to " [" & projectName & "]"

    -- Check flags
    set flags to ""
    if isFlagged then set flags to " 🚩"

    -- Check if blocked by defer date
    if deferDate is not missing value then
        if deferDate > currentTime then set flags to flags & " ⏸"
    end if

    return "• " & taskName & projectInfo & flags & return & "  ⏰ Was due: " & overdueText & " (" & (my shortDate(dueDate)) & ")"
end formatOverdueTask

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

on sortPositionsAscending(positionList, keyList)
    -- The positions in positionList ordered by the key at each position (keyList), smallest key first
    -- (bottom-up merge sort, equal keys keep their order). No Apple Events: the keys are values in a list.
    set itemCount to count of positionList
    set orderList to positionList
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
                if (item (item leftPos of orderList) of keyList) ≤ (item (item rightPos of orderList) of keyList) then
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
end sortPositionsAscending

on isHiddenProjectID(containerID, hiddenProjectIDList)
    -- True if the ID is the ID of a project below a hidden (dropped) folder (tasks outside projects have no project ID)
    if containerID is missing value then return false
    if (count of hiddenProjectIDList) = 0 then return false
    return (hiddenProjectIDList contains containerID)
end isHiddenProjectID

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
