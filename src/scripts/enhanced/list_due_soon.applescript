on run argv
    -- List open tasks that are due soon, grouped by tag, day or project
    -- Usage: list_due_soon.applescript "days" "group_by" "limit"
    --   days:     tasks due from now until the end of the day that is N days from today (default 7)
    --   group_by: "tag" (default, a task with several tags is listed under each of them), "day" or "project"
    --   limit:    maximum number of tasks to list (default 100), the soonest come first
    -- Overdue tasks are not listed here (see list_overdue_tasks).
    -- Dropped items and items below dropped (hidden) folders are always left out.

    set daysAhead to 7
    set groupMode to "tag"
    set maxResults to 100
    if (count of argv) > 0 then
        try
            set daysAhead to (item 1 of argv) as integer
        end try
    end if
    if daysAhead < 1 then set daysAhead to 7
    if (count of argv) > 1 then set groupMode to my trimItem(item 2 of argv)
    if groupMode is "" then set groupMode to "tag"
    if groupMode is not "tag" and groupMode is not "day" and groupMode is not "project" then
        return "❌ Unknown grouping: " & groupMode & ". Valid values: tag, day, project"
    end if
    if (count of argv) > 2 then
        try
            set maxResults to (item 3 of argv) as integer
        end try
    end if
    if maxResults < 1 then set maxResults to 100

    set nowDate to current date
    set endDate to nowDate
    set hours of endDate to 23
    set minutes of endDate to 59
    set seconds of endDate to 59
    set endDate to endDate + daysAhead * days
    set hiddenProjectIDList to my hiddenFolderProjectIDs()

    -- Every Apple Event costs about 17 ms, a query for one property of all tasks about 0.1 s: the properties of all tasks,
    -- projects and folders are fetched at once (the same position in each list is the same item) and filtered and
    -- sorted in the script
    tell application "OmniFocus"
        tell default document
            set taskIDList to id of every flattened task
            set taskNameList to name of every flattened task
            set flaggedList to flagged of every flattened task
            set dueDateList to due date of every flattened task
            set deferDateList to defer date of every flattened task
            set blockedList to blocked of every flattened task
            set estimateList to estimated minutes of every flattened task
            set effCompletedList to effectively completed of every flattened task
            set effDroppedList to effectively dropped of every flattened task
            set containerIDList to id of containing project of every flattened task
            set containerNameList to name of containing project of every flattened task
            set tagIDsList to id of tags of every flattened task
            set tagNamesList to name of tags of every flattened task
            set projectIDList to id of every flattened project
            set projectFolderIDList to id of folder of every flattened project
            set folderIDList to id of every flattened folder
            set folderNameList to name of every flattened folder
            set folderParentIDList to id of container of every flattened folder
        end tell
    end tell

    -- Open tasks due from now until the end date, not in projects below hidden (dropped) folders
    set dueIndexes to {}
    repeat with t from 1 to count of taskIDList
        set taskDue to item t of dueDateList
        if taskDue is not missing value then
            if taskDue ≥ nowDate and taskDue ≤ endDate and not (item t of effCompletedList) and not (item t of effDroppedList) then
                if not my isHiddenProjectID(item t of containerIDList, hiddenProjectIDList) then set end of dueIndexes to t
            end if
        end if
    end repeat

    -- Sort by due date, soonest first
    set sortedIndexes to my sortPositionsAscending(dueIndexes, dueDateList)

    set dayWord to "days"
    if daysAhead is 1 then set dayWord to "day"
    set titleText to "📅 Due in the next " & daysAhead & " " & dayWord
    if (count of sortedIndexes) = 0 then
        return titleText & ": none"
    end if

    set hitLimit to false
    if (count of sortedIndexes) > maxResults then
        set sortedIndexes to items 1 thru maxResults of sortedIndexes
        set hitLimit to true
    end if

    -- Build the entries and put them into groups
    set groupKeys to {}
    set groupHeadings to {}
    set groupTexts to {}
    repeat with idx from 1 to count of sortedIndexes
        set t to item idx of sortedIndexes
        set taskDue to item t of dueDateList
        set taskID to item t of taskIDList
        set projectID to item t of containerIDList
        set projectText to "Inbox"
        if projectID is not missing value then
            set projectText to item t of containerNameList
            set projectIndex to my indexOfItem(projectID, projectIDList)
            if projectIndex > 0 then
                set folderPath to my folderPathOf(item projectIndex of projectFolderIDList, folderIDList, folderNameList, folderParentIDList)
                if folderPath is not "" then set projectText to folderPath & " > " & projectText
            end if
        end if
        set entryInfo to my dueEntry(item t of taskNameList, taskID, item t of flaggedList, taskDue, item t of deferDateList, item t of blockedList, item t of estimateList, projectID, projectText, my listOf(item t of tagIDsList), my listOf(item t of tagNamesList), nowDate, groupMode)

        set theKeys to {}
        set theHeadings to {}
        if groupMode is "tag" then
            set entryTagIDs to tagIDs of entryInfo
            set entryTagNames to tagNames of entryInfo
            if (count of entryTagIDs) = 0 then
                set theKeys to {"none"}
                set theHeadings to {"🏷 (no tag)"}
            else
                repeat with k from 1 to count of entryTagIDs
                    set end of theKeys to (item k of entryTagIDs)
                    set end of theHeadings to "🏷 " & (item k of entryTagNames)
                end repeat
            end if
        else if groupMode is "day" then
            set dayText to date string of taskDue
            set theKeys to {dayText}
            set theHeadings to {"📅 " & dayText}
        else
            set theKeys to {projectKey of entryInfo}
            set theHeadings to {projectHeading of entryInfo}
        end if

        repeat with k from 1 to count of theKeys
            set groupIndex to my indexOfItem(item k of theKeys, groupKeys)
            if groupIndex = 0 then
                set end of groupKeys to (item k of theKeys)
                set end of groupHeadings to (item k of theHeadings)
                set end of groupTexts to (entryText of entryInfo)
            else
                set item groupIndex of groupTexts to (item groupIndex of groupTexts) & return & (entryText of entryInfo)
            end if
        end repeat
    end repeat

    set reportText to titleText & " (" & (count of sortedIndexes) & ")"
    if groupMode is "tag" then set reportText to reportText & ", grouped by tag (a task with several tags appears under each of them)"
    repeat with i from 1 to count of groupKeys
        set reportText to reportText & return & return & (item i of groupHeadings) & return & (item i of groupTexts)
    end repeat
    if hitLimit then
        set reportText to reportText & return & return & "… Limit of " & maxResults & " tasks reached, more tasks are due."
    end if
    return reportText
end run

on dueEntry(taskName, taskID, isFlagged, taskDue, deferDate, isBlocked, estimateValue, projectID, projectText, tagIDs, tagNames, nowDate, groupMode)
    -- One line for a task from values that are already read (no Apple Events), plus what is needed to group it.
    -- Returns {entryText, tagIDs, tagNames, projectKey, projectHeading}
    set entryText to "• " & taskName
    if isFlagged then set entryText to entryText & " 🚩"
    if groupMode is "day" then
        if (time of taskDue) is not 0 then set entryText to entryText & " 🕐 " & my timeText(taskDue)
    else
        set entryText to entryText & " 📅 due " & (date string of taskDue)
        if (time of taskDue) is not 0 then set entryText to entryText & " " & my timeText(taskDue)
    end if

    -- OmniFocus also calls deferred tasks blocked; only mention other reasons
    set isDeferred to false
    if deferDate is not missing value then
        if deferDate > nowDate then
            set isDeferred to true
            set entryText to entryText & " ⏸ deferred until " & (date string of deferDate)
        end if
    end if
    if not isDeferred then
        if isBlocked then set entryText to entryText & " 🔒 blocked"
    end if
    if estimateValue is not missing value then
        if estimateValue > 0 then set entryText to entryText & " ⏱ " & estimateValue & " min"
    end if

    set projectKey to "inbox"
    set projectHeading to "📥 Inbox"
    if projectID is not missing value then
        set projectKey to projectID
        set projectHeading to "📁 " & projectText
    end if
    if projectID is not missing value and projectKey is taskID then
        -- An empty project is returned like a task and has the same id
        set entryText to "• 📂 " & text 3 thru -1 of entryText
    else if groupMode is not "project" then
        set entryText to entryText & " 📁 " & projectText
    end if
    if groupMode is not "tag" and (count of tagNames) > 0 then set entryText to entryText & " 🏷 " & my joinText(tagNames, ", ")
    set entryText to entryText & " [id:" & taskID & "]"

    return {entryText:entryText, tagIDs:tagIDs, tagNames:tagNames, projectKey:projectKey, projectHeading:projectHeading}
end dueEntry

on listOf(aValue)
    -- The value as a list: a list stays, a missing value is an empty list, a single value is a list of one
    if aValue is missing value then return {}
    if class of aValue is list then return aValue
    return {aValue}
end listOf

on timeText(aDate)
    -- "09:30"
    set hourText to text -2 thru -1 of ("0" & (hours of aDate))
    set minuteText to text -2 thru -1 of ("0" & (minutes of aDate))
    return hourText & ":" & minuteText
end timeText

on trimItem(theText)
    set whitespaceChars to {" ", tab, return, linefeed}
    set textLength to length of theText
    if textLength is 0 then return ""
    set textStart to 1
    repeat while textStart ≤ textLength and character textStart of theText is in whitespaceChars
        set textStart to textStart + 1
    end repeat
    if textStart > textLength then return ""
    set textEnd to textLength
    repeat while textEnd ≥ textStart and character textEnd of theText is in whitespaceChars
        set textEnd to textEnd - 1
    end repeat
    return text textStart thru textEnd of theText
end trimItem

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
