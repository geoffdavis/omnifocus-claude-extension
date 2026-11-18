on run argv
    -- List all flagged tasks across all projects
    -- Usage: list_flagged_tasks.applescript

    -- include_dropped: "true" also shows dropped items and items below dropped (hidden) folders
    set includeDropped to false
    if (count of argv) > 0 then set includeDropped to (item 1 of argv is "true")
    set hiddenProjectIDList to {}
    if not includeDropped then set hiddenProjectIDList to my hiddenFolderProjectIDs()

    -- Every Apple Event costs about 17 ms, a query for one property of all tasks about 0.1 s: the properties of all tasks
    -- are fetched at once (the same position in each list is the same task) and filtered in the script
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

    -- Open tasks only: not completed or dropped, also not through their project or parent task;
    -- tasks of projects below hidden (dropped) folders are left out
    set flaggedIndexes to {}
    repeat with t from 1 to count of taskNameList
        if item t of flaggedList and not (item t of effCompletedList) then
            if includeDropped or not (item t of effDroppedList) then
                if (not my isHiddenProjectID(item t of containerIDList, hiddenProjectIDList)) and ((item t of taskIDList) is not (item t of containerIDList)) then set end of flaggedIndexes to t
            end if
        end if
    end repeat

    if (count of flaggedIndexes) = 0 then
        return "🚩 No flagged tasks - inbox zero for priorities!"
    end if

    -- Group tasks by urgency
    set nowDate to current date
    set currentTime to current date
    set overdueTasks to {}
    set todayTasks to {}
    set thisWeekTasks to {}
    set laterTasks to {}
    set noDueTasks to {}

    set todayEnd to currentTime
    set hours of todayEnd to 23
    set minutes of todayEnd to 59
    set thisWeekEnd to todayEnd + 7 * days

    repeat with idx in flaggedIndexes
        set t to contents of idx
        set taskDue to item t of dueDateList
        if taskDue is missing value then
            set end of noDueTasks to my formatFlaggedTask(item t of taskNameList, item t of containerNameList, taskDue, false, item t of deferDateList, nowDate)
        else if taskDue < currentTime then
            set end of overdueTasks to my formatFlaggedTask(item t of taskNameList, item t of containerNameList, taskDue, true, item t of deferDateList, nowDate)
        else if taskDue ≤ todayEnd then
            set end of todayTasks to my formatFlaggedTask(item t of taskNameList, item t of containerNameList, taskDue, false, item t of deferDateList, nowDate)
        else if taskDue ≤ thisWeekEnd then
            set end of thisWeekTasks to my formatFlaggedTask(item t of taskNameList, item t of containerNameList, taskDue, false, item t of deferDateList, nowDate)
        else
            set end of laterTasks to my formatFlaggedTask(item t of taskNameList, item t of containerNameList, taskDue, false, item t of deferDateList, nowDate)
        end if
    end repeat

    -- Build output
    set taskList to "🚩 Flagged Tasks (" & (count of flaggedIndexes) & " items)" & return
    set taskList to taskList & return

    -- Overdue flagged tasks (highest priority)
    if (count of overdueTasks) > 0 then
        set taskList to taskList & "🔴 OVERDUE (" & (count of overdueTasks) & "):" & return
        repeat with lineText in overdueTasks
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    -- Due today
    if (count of todayTasks) > 0 then
        set taskList to taskList & "🟠 Due Today (" & (count of todayTasks) & "):" & return
        repeat with lineText in todayTasks
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    -- Due this week
    if (count of thisWeekTasks) > 0 then
        set taskList to taskList & "🟡 Due This Week (" & (count of thisWeekTasks) & "):" & return
        repeat with lineText in thisWeekTasks
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    -- Due later
    if (count of laterTasks) > 0 then
        set taskList to taskList & "🟢 Due Later (" & (count of laterTasks) & "):" & return
        repeat with lineText in laterTasks
            set taskList to taskList & lineText & return
        end repeat
        set taskList to taskList & return
    end if

    -- No due date
    if (count of noDueTasks) > 0 then
        set taskList to taskList & "⚪ No Due Date (" & (count of noDueTasks) & "):" & return
        repeat with lineText in noDueTasks
            set taskList to taskList & lineText & return
        end repeat
    end if

    return taskList
end run

on formatFlaggedTask(taskName, projectName, dueDate, isOverdue, deferDate, nowDate)
    -- One entry from values that are already read: no Apple Events
    -- Project info; tasks outside projects are in the inbox
    set projectInfo to " [Inbox]"
    if projectName is not missing value then set projectInfo to " [" & projectName & "]"

    -- Get due date info
    set dueInfo to ""
    if dueDate is not missing value then
        if isOverdue then
            set daysPast to (nowDate - dueDate) / days as integer
            if daysPast = 0 then
                set dueInfo to " (due earlier today)"
            else if daysPast = 1 then
                set dueInfo to " (1 day overdue)"
            else
                set dueInfo to " (" & daysPast & " days overdue)"
            end if
        else
            -- Format the due date nicely
            set dueInfo to " (due " & (my shortDate(dueDate)) & ")"
        end if
    end if

    -- Check if task is blocked
    set availabilityInfo to ""
    if deferDate is not missing value then
        if deferDate > nowDate then set availabilityInfo to " ⏸"
    end if

    return "• " & taskName & projectInfo & dueInfo & availabilityInfo
end formatFlaggedTask

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
