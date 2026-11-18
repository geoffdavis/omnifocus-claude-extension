on run argv
    -- List all active projects with optional task statistics
    -- Usage: list_projects.applescript ["true"|"false"]
    
    set includeStats to false
    
    if (count of argv) > 0 then
        set includeStats to (item 1 of argv is "true")
    end if
    
    -- include_dropped: "true" also shows dropped items and items below dropped (hidden) folders
    set includeDropped to false
    if (count of argv) > 1 then set includeDropped to (item 2 of argv is "true")
    set hiddenProjectIDList to {}
    if not includeDropped then set hiddenProjectIDList to my hiddenFolderProjectIDs()

    -- Every Apple Event costs about 17 ms, a query for one property of all elements about 0.05 s: the properties of all
    -- projects, folders and (for the statistics) tasks are fetched at once (the same position in each list is the same item)
    tell application "OmniFocus"
        tell default document
            set projectIDList to id of every flattened project
            set projectNameList to name of every flattened project
            set projectNoteList to note of every flattened project
            set projectFolderIDList to id of folder of every flattened project
            set projectStatusList to effective status of every flattened project
            set statusCodeList to {}
            repeat with aStatus in projectStatusList
                set statusValue to contents of aStatus
                if statusValue is active status then
                    set end of statusCodeList to "active"
                else if statusValue is on hold status then
                    set end of statusCodeList to "on hold"
                else if statusValue is dropped status then
                    set end of statusCodeList to "dropped"
                else
                    set end of statusCodeList to "other"
                end if
            end repeat
            set folderIDList to id of every flattened folder
            set folderNameList to name of every flattened folder
            set folderParentIDList to id of container of every flattened folder
            if includeStats then
                set parentIDList to id of parent task of every flattened task
                set effCompletedList to effectively completed of every flattened task
                set effDroppedList to effectively dropped of every flattened task
                set flaggedList to flagged of every flattened task
                set blockedList to blocked of every flattened task
                set deferDateList to defer date of every flattened task
                set dueDateList to due date of every flattened task
            end if
        end tell
    end tell

    -- Projects below hidden (dropped) folders count as dropped
    set activeIndexes to {}
    set onHoldIndexes to {}
    set droppedIndexes to {}
    set hiddenCount to 0
    repeat with i from 1 to count of projectIDList
        set statusCode to item i of statusCodeList
        if statusCode is "active" or statusCode is "on hold" then
            if hiddenProjectIDList contains (item i of projectIDList) then
                set hiddenCount to hiddenCount + 1
            else if statusCode is "active" then
                set end of activeIndexes to i
            else
                set end of onHoldIndexes to i
            end if
        else if statusCode is "dropped" then
            set end of droppedIndexes to i
        end if
    end repeat

    set totalActive to count of activeIndexes
    set totalOnHold to count of onHoldIndexes
    set totalDropped to (count of droppedIndexes) + hiddenCount

    if totalActive = 0 then
        return "📁 No active projects" & return & "(" & totalOnHold & " on hold, " & totalDropped & " dropped)"
    end if

    -- Statistics: the tasks directly below each active project (the project is the parent of the task)
    set remainingCounts to {}
    set availableCounts to {}
    set flaggedCounts to {}
    set dueSoonCounts to {}
    if includeStats then
        set activeIDList to {}
        repeat with i in activeIndexes
            set end of activeIDList to item (contents of i) of projectIDList
            set end of remainingCounts to 0
            set end of availableCounts to 0
            set end of flaggedCounts to 0
            set end of dueSoonCounts to 0
        end repeat
        set activeIDText to linefeed & my joinText(activeIDList, linefeed) & linefeed
        set nowDate to current date
        set weekFromNow to nowDate + 7 * days
        repeat with t from 1 to count of parentIDList
            set parentID to item t of parentIDList
            if parentID is not missing value then
                set activeIndex to my indexOfID(activeIDText, parentID)
                if activeIndex > 0 then
                    if not (item t of effCompletedList) and not (item t of effDroppedList) then
                        set item activeIndex of remainingCounts to (item activeIndex of remainingCounts) + 1
                        -- available: neither blocked nor deferred to the future
                        set isAvailable to true
                        if item t of blockedList then set isAvailable to false
                        set deferDate to item t of deferDateList
                        if deferDate is not missing value then
                            if deferDate > nowDate then set isAvailable to false
                        end if
                        if isAvailable then set item activeIndex of availableCounts to (item activeIndex of availableCounts) + 1
                        if item t of flaggedList then set item activeIndex of flaggedCounts to (item activeIndex of flaggedCounts) + 1
                        set dueDate to item t of dueDateList
                        if dueDate is not missing value then
                            if dueDate ≤ weekFromNow and dueDate ≥ nowDate then set item activeIndex of dueSoonCounts to (item activeIndex of dueSoonCounts) + 1
                        end if
                    end if
                end if
            end if
        end repeat
    end if

    set projectList to "📁 Projects Overview" & return
    set projectList to projectList & "Active: " & totalActive & " | On Hold: " & totalOnHold & " | Dropped: " & totalDropped & return & return

    set projectList to projectList & "📂 Active Projects:" & return

    repeat with n from 1 to totalActive
        set i to item n of activeIndexes
        set projectName to item i of projectNameList
        set projectNote to item i of projectNoteList
        set folderText to my folderTextOf(item i of projectFolderIDList, folderIDList, folderNameList, folderParentIDList)

        if includeStats then
            set projectList to projectList & "• " & projectName & folderText
            set projectList to projectList & " (" & (item n of remainingCounts) & " remaining"

            if (item n of availableCounts) > 0 then
                set projectList to projectList & ", " & (item n of availableCounts) & " available"
            end if

            if (item n of flaggedCounts) > 0 then
                set projectList to projectList & ", " & (item n of flaggedCounts) & " flagged"
            end if

            if (item n of dueSoonCounts) > 0 then
                set projectList to projectList & ", " & (item n of dueSoonCounts) & " due soon"
            end if

            set projectList to projectList & ")"

            -- Add project note preview if exists
            if projectNote is not "" then
                set noteLength to length of projectNote
                set previewLength to my minValue(50, noteLength)
                set notePreview to text 1 thru previewLength of projectNote
                if noteLength > 50 then set notePreview to notePreview & "..."
                set projectList to projectList & return & "  💬 " & notePreview
            end if
        else
            set projectList to projectList & "• " & projectName & folderText
        end if

        set projectList to projectList & return
    end repeat

    -- On hold projects, with their folder path
    if totalOnHold > 0 then
        set projectList to projectList & return & "⏸ On Hold Projects:" & return
        repeat with i in onHoldIndexes
            set projectList to projectList & "• " & (item (contents of i) of projectNameList) & my folderTextOf(item (contents of i) of projectFolderIDList, folderIDList, folderNameList, folderParentIDList) & return
        end repeat
    end if

    -- With include_dropped: also list dropped projects, with their folder path
    if includeDropped and (count of droppedIndexes) > 0 then
        set projectList to projectList & return & "🚫 Dropped Projects:" & return
        repeat with i in droppedIndexes
            set projectList to projectList & "• " & (item (contents of i) of projectNameList) & my folderTextOf(item (contents of i) of projectFolderIDList, folderIDList, folderNameList, folderParentIDList) & return
        end repeat
    end if

    -- Add summary statistics if requested
    if includeStats then
        set projectList to projectList & return & "📊 Summary Statistics:" & return
        set totalRemaining to 0
        set totalAvailable to 0
        set totalFlagged to 0
        repeat with n from 1 to totalActive
            set totalRemaining to totalRemaining + (item n of remainingCounts)
            set totalAvailable to totalAvailable + (item n of availableCounts)
            set totalFlagged to totalFlagged + (item n of flaggedCounts)
        end repeat

        set projectList to projectList & "• Total remaining tasks: " & totalRemaining & return
        set projectList to projectList & "• Total available tasks: " & totalAvailable & return
        set projectList to projectList & "• Total flagged tasks: " & totalFlagged
    end if

    return projectList
end run

on folderTextOf(folderID, folderIDList, folderNameList, folderParentIDList)
    -- " — 📂 Folder > Subfolder" for a project inside folders, "" at top level, from the lists of all folders
    set pathNames to {}
    set currentID to folderID
    repeat while currentID is not missing value
        set folderIndex to my indexOfItem(currentID, folderIDList)
        if folderIndex = 0 then exit repeat
        set beginning of pathNames to item folderIndex of folderNameList
        set currentID to item folderIndex of folderParentIDList
    end repeat
    if (count of pathNames) = 0 then return ""
    return " — 📂 " & my joinText(pathNames, " > ")
end folderTextOf

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

on minValue(x, y)
    if x < y then
        return x
    else
        return y
    end if
end minValue

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
