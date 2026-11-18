on run argv
    -- List all deferred tasks (tasks with defer dates in the future)
    -- Usage: list_deferred_tasks.applescript

    -- include_dropped: "true" also shows dropped items and items below dropped (hidden) folders
    set includeDropped to false
    if (count of argv) > 0 then set includeDropped to (item 1 of argv is "true")
    set hiddenProjectIDList to {}
    if not includeDropped then set hiddenProjectIDList to my hiddenFolderProjectIDs()

    -- Every Apple Event costs about 17 ms, a query for one property of all tasks about 0.1 s: the properties of all tasks
    -- are fetched at once (the same position in each list is the same task) and filtered and sorted in the script
    tell application "OmniFocus"
        tell default document
            set taskIDList to id of every flattened task
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

    -- Tasks actually deferred (defer date in the future), open, not in projects below hidden (dropped) folders
    set deferredIndexes to {}
    repeat with t from 1 to count of taskNameList
        set deferDate to item t of deferDateList
        if deferDate is not missing value then
            if deferDate > currentTime and not (item t of effCompletedList) then
                if includeDropped or not (item t of effDroppedList) then
                    if (not my isHiddenProjectID(item t of containerIDList, hiddenProjectIDList)) and ((item t of taskIDList) is not (item t of containerIDList)) then set end of deferredIndexes to t
                end if
            end if
        end if
    end repeat

    if (count of deferredIndexes) = 0 then
        return "⏸️ No deferred tasks - all tasks are currently available!"
    end if

    -- Sort tasks by defer date
    set deferredIndexes to my sortPositionsAscending(deferredIndexes, deferDateList)

    -- Build the output
    set taskList to "⏸️ Deferred Tasks (" & (count of deferredIndexes) & " items)" & return
    set taskList to taskList & return

    -- Group by time periods
    copy currentTime to todayEnd
    set hours of todayEnd to 23
    set minutes of todayEnd to 59
    set seconds of todayEnd to 59

    set tomorrowEnd to todayEnd + 1 * days
    set thisWeekEnd to todayEnd + 7 * days
    set thisMonthEnd to todayEnd + 30 * days

    set laterTodayTasks to {}
    set tomorrowTasks to {}
    set thisWeekTasks to {}
    set thisMonthTasks to {}
    set laterTasks to {}

    repeat with idx in deferredIndexes
        set t to contents of idx
        set deferDate to item t of deferDateList
        set lineText to my formatDeferredTask(item t of taskNameList, deferDate, item t of containerNameList, item t of flaggedList, item t of dueDateList, currentTime)

        if deferDate ≤ todayEnd then
            set end of laterTodayTasks to lineText
        else if deferDate ≤ tomorrowEnd then
            set end of tomorrowTasks to lineText
        else if deferDate ≤ thisWeekEnd then
            set end of thisWeekTasks to lineText
        else if deferDate ≤ thisMonthEnd then
            set end of thisMonthTasks to lineText
        else
            set end of laterTasks to lineText
        end if
    end repeat

    -- Output tasks by group
    if (count of laterTodayTasks) > 0 then
        set taskList to taskList & "📅 Later Today:" & return
        repeat with lineText in laterTodayTasks
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    if (count of tomorrowTasks) > 0 then
        set taskList to taskList & "📅 Tomorrow:" & return
        repeat with lineText in tomorrowTasks
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    if (count of thisWeekTasks) > 0 then
        set taskList to taskList & "📅 This Week:" & return
        repeat with lineText in thisWeekTasks
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    if (count of thisMonthTasks) > 0 then
        set taskList to taskList & "📅 This Month:" & return
        repeat with lineText in thisMonthTasks
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    if (count of laterTasks) > 0 then
        set taskList to taskList & "📅 Later:" & return
        repeat with lineText in laterTasks
            set taskList to taskList & lineText & return
        end repeat
    end if

    return taskList
end run

on formatDeferredTask(taskName, deferDate, projectName, isFlagged, dueDate, currentTime)
    -- One entry from values that are already read: no Apple Events
    -- Format the defer date (and time, if it has one)
    set dateStr to my shortDateTime(deferDate)

    -- Add project info if available
    set projectInfo to ""
    if projectName is not missing value then set projectInfo to " [" & projectName & "]"

    -- Add flags
    set flags to ""
    if isFlagged then set flags to flags & " 🚩"

    if dueDate is not missing value then
        set daysUntilDue to ((dueDate - currentTime) / days) as integer
        if daysUntilDue ≤ 7 then
            set flags to flags & " 📅"
        end if
    end if

    return "• " & taskName & projectInfo & flags & return & "  ⏰ Available: " & dateStr
end formatDeferredTask

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
