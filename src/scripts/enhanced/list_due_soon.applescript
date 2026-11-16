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
    set hiddenIDs to my hiddenFolderTaskIDs()

    tell application "OmniFocus"
        tell default document
            set dueTasks to every flattened task whose due date ≥ nowDate and due date ≤ endDate and effectively completed is false and effectively dropped is false
        end tell
    end tell

    -- Sort by due date, soonest first
    set sortedTasks to {}
    set sortedDates to {}
    repeat with aTask in dueTasks
        set theTask to contents of aTask
        tell application "OmniFocus" to set taskID to id of theTask
        if hiddenIDs does not contain taskID then
            tell application "OmniFocus" to set taskDue to due date of theTask
            set insertAt to (count of sortedDates) + 1
            repeat with i from 1 to count of sortedDates
                if (item i of sortedDates) > taskDue then
                    set insertAt to i
                    exit repeat
                end if
            end repeat
            set sortedTasks to my insertAtIndex(sortedTasks, theTask, insertAt)
            set sortedDates to my insertAtIndex(sortedDates, taskDue, insertAt)
        end if
    end repeat

    set dayWord to "days"
    if daysAhead is 1 then set dayWord to "day"
    set titleText to "📅 Due in the next " & daysAhead & " " & dayWord
    if (count of sortedTasks) = 0 then
        return titleText & ": none"
    end if

    set hitLimit to false
    if (count of sortedTasks) > maxResults then
        set sortedTasks to items 1 thru maxResults of sortedTasks
        set sortedDates to items 1 thru maxResults of sortedDates
        set hitLimit to true
    end if

    -- Build the entries and put them into groups
    set groupKeys to {}
    set groupHeadings to {}
    set groupTexts to {}
    repeat with idx from 1 to count of sortedTasks
        set theTask to item idx of sortedTasks
        set taskDue to item idx of sortedDates
        set entryInfo to my dueEntry(theTask, taskDue, nowDate, groupMode)

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

    set reportText to titleText & " (" & (count of sortedTasks) & ")"
    if groupMode is "tag" then set reportText to reportText & ", grouped by tag (a task with several tags appears under each of them)"
    repeat with i from 1 to count of groupKeys
        set reportText to reportText & return & return & (item i of groupHeadings) & return & (item i of groupTexts)
    end repeat
    if hitLimit then
        set reportText to reportText & return & return & "… Limit of " & maxResults & " tasks reached, more tasks are due."
    end if
    return reportText
end run

on dueEntry(theTask, taskDue, nowDate, groupMode)
    -- One line for a task, plus what is needed to group it.
    -- Returns {entryText, tagIDs, tagNames, projectKey, projectHeading}
    set theProject to missing value
    tell application "OmniFocus"
        set taskName to name of theTask
        set taskID to id of theTask
        set isFlagged to flagged of theTask
        try
            set theProject to containing project of theTask
        end try
        set tagIDs to {}
        set tagNames to {}
        try
            set tagIDs to id of every tag of theTask
            set tagNames to name of every tag of theTask
        end try
    end tell

    set entryText to "• " & taskName
    if isFlagged then set entryText to entryText & " 🚩"
    if groupMode is "day" then
        if (time of taskDue) is not 0 then set entryText to entryText & " 🕐 " & my timeText(taskDue)
    else
        set entryText to entryText & " 📅 due " & (date string of taskDue)
        if (time of taskDue) is not 0 then set entryText to entryText & " " & my timeText(taskDue)
    end if

    tell application "OmniFocus"
        -- OmniFocus also calls deferred tasks blocked; only mention other reasons
        set isDeferred to false
        try
            set deferDate to defer date of theTask
            if deferDate is not missing value and deferDate > nowDate then
                set isDeferred to true
                set entryText to entryText & " ⏸ deferred until " & (date string of deferDate)
            end if
        end try
        if not isDeferred then
            try
                if blocked of theTask then set entryText to entryText & " 🔒 blocked"
            end try
        end if
        try
            set estimateValue to estimated minutes of theTask
            if estimateValue is not missing value and estimateValue > 0 then set entryText to entryText & " ⏱ " & estimateValue & " min"
        end try
    end tell

    set projectKey to "inbox"
    set projectHeading to "📥 Inbox"
    set projectText to "Inbox"
    if theProject is not missing value then
        tell application "OmniFocus" to set projectKey to id of theProject
        set projectText to my projectLabel(theProject)
        set projectHeading to "📁 " & projectText
    end if
    if theProject is not missing value and projectKey is taskID then
        -- An empty project is returned like a task and has the same id
        set entryText to "• 📂 " & text 3 thru -1 of entryText
    else if groupMode is not "project" then
        set entryText to entryText & " 📁 " & projectText
    end if
    if groupMode is not "tag" and (count of tagNames) > 0 then set entryText to entryText & " 🏷 " & my joinText(tagNames, ", ")
    set entryText to entryText & " [id:" & taskID & "]"

    return {entryText:entryText, tagIDs:tagIDs, tagNames:tagNames, projectKey:projectKey, projectHeading:projectHeading}
end dueEntry

on timeText(aDate)
    -- "09:30"
    set hourText to text -2 thru -1 of ("0" & (hours of aDate))
    set minuteText to text -2 thru -1 of ("0" & (minutes of aDate))
    return hourText & ":" & minuteText
end timeText

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

on insertAtIndex(aList, anItem, slotIndex)
    -- A copy of aList with anItem inserted before the item at slotIndex (at the end if slotIndex is past the end)
    if slotIndex ≤ 1 then return {anItem} & aList
    if slotIndex > (count of aList) then return aList & {anItem}
    return (items 1 thru (slotIndex - 1) of aList) & {anItem} & (items slotIndex thru -1 of aList)
end insertAtIndex

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
