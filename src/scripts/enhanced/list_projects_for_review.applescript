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
    set hiddenProjectIDList to my hiddenFolderProjectIDs()
    set reviewLimit to (current date) + daysAhead * days

    -- Every Apple Event costs about 17 ms, a query for one property of all elements about 0.05 s: the properties of all
    -- projects and folders are fetched at once (the same position in each list is the same item)
    tell application "OmniFocus"
        tell default document
            set projectIDList to id of every flattened project
            set projectNameList to name of every flattened project
            set projectFolderIDList to id of folder of every flattened project
            set projectStatusList to effective status of every flattened project
            set singletonList to singleton action holder of every flattened project
            set nextTaskIDList to id of next task of every flattened project
            set nextReviewList to next review date of every flattened project
            set lastReviewList to last review date of every flattened project
            set reviewIntervalList to review interval of every flattened project
            set folderIDList to id of every flattened folder
            set folderNameList to name of every flattened folder
            set folderParentIDList to id of container of every flattened folder
        end tell
        -- 1 = active, 2 = on hold, 0 = anything else
        set stateList to {}
        repeat with aStatus in projectStatusList
            set statusValue to contents of aStatus
            if statusValue is active status then
                set end of stateList to 1
            else if statusValue is on hold status then
                set end of stateList to 2
            else
                set end of stateList to 0
            end if
        end repeat
    end tell

    set dueIndexes to {}
    repeat with i from 1 to count of projectIDList
        if (item i of stateList) > 0 then
            set nextReview to item i of nextReviewList
            if nextReview is not missing value then
                if nextReview ≤ reviewLimit then
                    if hiddenProjectIDList does not contain (item i of projectIDList) then set end of dueIndexes to i
                end if
            end if
        end if
    end repeat

    if (count of dueIndexes) = 0 then
        return "✅ No projects due for review"
    end if

    set openCountList to my openTaskCounts(projectIDList)
    set reviewList to "🔎 Projects due for review (" & (count of dueIndexes) & "):" & return
    repeat with i in dueIndexes
        set labelText to item (contents of i) of projectNameList
        set folderPath to my folderPathOf(item (contents of i) of projectFolderIDList, folderIDList, folderNameList, folderParentIDList)
        if folderPath is not "" then set labelText to folderPath & " > " & labelText
        set reviewList to reviewList & "• " & labelText
        if (item (contents of i) of stateList) = 2 then set reviewList to reviewList & " ⏸"
        set reviewList to reviewList & " [id:" & (item (contents of i) of projectIDList) & "]" & return
        set reviewList to reviewList & "  Last reviewed: " & my formatDate(item (contents of i) of lastReviewList)
        set reviewList to reviewList & " | Review due: " & my formatDate(item (contents of i) of nextReviewList)
        set intervalText to my reviewIntervalText(item (contents of i) of reviewIntervalList)
        if intervalText is not "" then set reviewList to reviewList & " | " & intervalText
        -- Why a project may be stalled: no hint if it has a next action or is a single action list
        set hintText to ""
        if not (item (contents of i) of singletonList) then
            if (item (contents of i) of openCountList) = 0 then
                set hintText to "no open tasks"
            else if (item (contents of i) of nextTaskIDList) is missing value then
                set hintText to "no next action (open tasks are blocked or deferred)"
            end if
        end if
        if hintText is not "" then set reviewList to reviewList & " | ⚠️ " & hintText
        set reviewList to reviewList & return
    end repeat
    return reviewList
end run

on formatDate(aDate)
    -- Short text for a date that may be missing
    if aDate is missing value then return "never"
    return date string of aDate
end formatDate

on reviewIntervalText(intervalRecord)
    -- "every 2 weeks", or "" if the interval cannot be read
    set stepCount to 0
    set unitName to "?"
    tell application "OmniFocus"
        try
            set stepCount to steps of intervalRecord
            set unitValue to unit of intervalRecord
            if unitValue is day then
                set unitName to "day"
            else if unitValue is week then
                set unitName to "week"
            else if unitValue is month then
                set unitName to "month"
            else if unitValue is year then
                set unitName to "year"
            end if
        on error
            return ""
        end try
    end tell
    if stepCount < 1 then return ""
    if stepCount is 1 then return "every " & unitName
    return "every " & stepCount & " " & unitName & "s"
end reviewIntervalText

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

on indexOfItem(anItem, aList)
    -- Position of anItem in aList, 0 if it is not in the list
    repeat with i from 1 to count of aList
        if (item i of aList) is anItem then return i
    end repeat
    return 0
end indexOfItem

on indexOfID(idText, theID)
    -- Position of an ID in a list that was joined into one text (linefeed & id1 & linefeed & id2 & linefeed ...), 0 if it is
    -- not in it. The search is done by the system and does not loop over the list.
    if theID is missing value then return 0
    set matchPosition to 0
    considering case
        set matchPosition to offset of (linefeed & theID & linefeed) in idText
    end considering
    if matchPosition = 0 then return 0
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to linefeed
    set linefeedCount to (count of text items of (text 1 thru matchPosition of idText)) - 1
    set AppleScript's text item delimiters to oldDelims
    return linefeedCount
end indexOfID

on joinText(textItems, separator)
    -- Joins a list of text items with a separator
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to separator
    set joinedText to textItems as text
    set AppleScript's text item delimiters to oldDelims
    return joinedText
end joinText

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

on openTaskCounts(projectIDList)
    -- Number of open tasks (not completed, not dropped; all levels) in each project, in the order of projectIDList.
    -- The root task of a project has no parent task and is not counted. Four queries for all tasks instead of
    -- one query per project: every Apple Event costs about 17 ms, a query for all elements about 0.1 s.
    set openCounts to {}
    repeat with i from 1 to count of projectIDList
        set end of openCounts to 0
    end repeat
    tell application "OmniFocus"
        tell default document
            set taskProjectIDList to id of containing project of every flattened task
            set taskParentIDList to id of parent task of every flattened task
            set effCompletedList to effectively completed of every flattened task
            set effDroppedList to effectively dropped of every flattened task
        end tell
    end tell
    set projectIDText to linefeed & my joinText(projectIDList, linefeed) & linefeed
    repeat with t from 1 to count of taskProjectIDList
        set containerID to item t of taskProjectIDList
        if containerID is not missing value then
            if (item t of taskParentIDList) is not missing value then
                if not (item t of effCompletedList) and not (item t of effDroppedList) then
                    set projectIndex to my indexOfID(projectIDText, containerID)
                    if projectIndex > 0 then set item projectIndex of openCounts to (item projectIndex of openCounts) + 1
                end if
            end if
        end if
    end repeat
    return openCounts
end openTaskCounts
