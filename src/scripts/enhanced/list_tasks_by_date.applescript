on run argv
    -- List tasks or projects by the date they were created, last modified or dropped, newest first, grouped by day.
    -- Usage: list_tasks_by_date.applescript date_field item_type days since until status project limit
    --   date_field: "created", "modified" or "dropped" (completed tasks: list_completed_tasks)
    --   item_type:  "tasks" (default) or "projects"
    --   days:       look back this many days (default 7); with only "until" given, the days before that date
    --   since:      start of the period: "YYYY-MM-DD" (start of that day), "YYYY-MM-DD HH:MM", "today" or "yesterday"
    --   until:      end of the period: "YYYY-MM-DD" (through the end of that day), "YYYY-MM-DD HH:MM", "today" or "yesterday"
    --   status:     "all" (default) or "open" (tasks: not completed, not dropped; projects: active or on hold)
    --   project:    tasks only: only tasks of this project (name, "Folder > Project" or "id:<id>")
    --   limit:      maximum number of items to list (default 100)
    -- Items below hidden (dropped) folders are left out. Nothing is changed.

    set fieldName to ""
    set itemType to "tasks"
    set daysText to ""
    set sinceText to ""
    set untilText to ""
    set statusText to "all"
    set projectText to ""
    set limitText to ""
    if (count of argv) > 0 then set fieldName to my trimItem(item 1 of argv)
    if (count of argv) > 1 and my trimItem(item 2 of argv) is not "" then set itemType to my trimItem(item 2 of argv)
    if (count of argv) > 2 then set daysText to my trimItem(item 3 of argv)
    if (count of argv) > 3 then set sinceText to my trimItem(item 4 of argv)
    if (count of argv) > 4 then set untilText to my trimItem(item 5 of argv)
    if (count of argv) > 5 and my trimItem(item 6 of argv) is not "" then set statusText to my trimItem(item 6 of argv)
    if (count of argv) > 6 then set projectText to my trimItem(item 7 of argv)
    if (count of argv) > 7 then set limitText to my trimItem(item 8 of argv)

    -- Check every value before anything is read
    if fieldName is "" then
        return "❌ date_field is required: created, modified or dropped."
    end if
    if fieldName is not "created" and fieldName is not "modified" and fieldName is not "dropped" then
        return "❌ Invalid date_field: " & fieldName & ". Use created, modified or dropped (completed tasks: list_completed_tasks)."
    end if
    if itemType is not "tasks" and itemType is not "projects" then
        return "❌ Invalid item_type: " & itemType & ". Use tasks or projects."
    end if
    if statusText is not "all" and statusText is not "open" then
        return "❌ Invalid status: " & statusText & ". Use all or open."
    end if
    if statusText is "open" and fieldName is "dropped" then
        return "❌ Dropped items are never open. Use status all with date_field dropped."
    end if
    if projectText is not "" and itemType is "projects" then
        return "❌ project only applies to tasks."
    end if

    set dayCount to 7
    set daysGiven to (daysText is not "")
    if daysGiven then
        if not my isDigits(daysText) or (length of daysText) > 5 or (daysText as integer) < 1 then
            return "❌ Invalid days: " & daysText & ". Use a whole number of days, 1 or more."
        end if
        set dayCount to daysText as integer
    end if
    set maxResults to 100
    if limitText is not "" then
        if not my isDigits(limitText) or (length of limitText) > 5 or (limitText as integer) < 1 then
            return "❌ Invalid limit: " & limitText & ". Use a whole number, 1 or more."
        end if
        set maxResults to limitText as integer
    end if

    -- The period [sinceDate, untilDate)
    set nowDate to current date
    set sinceDate to nowDate - dayCount * days
    set untilDate to nowDate + 1 * days
    set dayWord to "days"
    if dayCount is 1 then set dayWord to "day"
    set rangeText to "in the last " & dayCount & " " & dayWord
    if untilText is not "" then
        try
            set untilDate to my parseRangeDate(untilText, true)
        on error
            return "❌ Invalid until date: " & untilText & ". Use YYYY-MM-DD, YYYY-MM-DD HH:MM, today or yesterday."
        end try
    end if
    if sinceText is not "" then
        try
            set sinceDate to my parseRangeDate(sinceText, false)
        on error
            return "❌ Invalid since date: " & sinceText & ". Use YYYY-MM-DD, YYYY-MM-DD HH:MM, today or yesterday."
        end try
    else if untilText is not "" then
        if daysGiven then
            set sinceDate to untilDate - dayCount * days
        else
            set sinceDate to my parseRangeDate("2000-01-01", false)
        end if
    end if
    if sinceText is not "" or untilText is not "" then
        if sinceDate ≥ untilDate then return "❌ since must be before until."
        if sinceText is not "" and untilText is not "" then
            set rangeText to "from " & (my shortDate(sinceDate)) & " to " & (my shortDate(untilDate - 1))
        else if sinceText is not "" then
            set rangeText to "since " & (my shortDate(sinceDate))
        else if daysGiven then
            set rangeText to "in the " & dayCount & " " & dayWord & " until " & (my shortDate(untilDate - 1))
        else
            set rangeText to "until " & (my shortDate(untilDate - 1))
        end if
    end if

    -- Where to look
    set scopeRef to missing value
    set scopeLabel to ""
    if projectText is not "" then
        set lookupResult to my resolveProject(projectText)
        if foundProject of lookupResult is missing value then return errorText of lookupResult
        set scopeRef to foundProject of lookupResult
        set scopeLabel to my projectLabel(scopeRef)
    else
        tell application "OmniFocus" to set scopeRef to default document
    end if

    -- Read everything with a few bulk queries (one per property, not one per item), then filter here
    set refList to {}
    set idList to {}
    set dateList to {}
    set doneList to {}
    set droppedList to {}
    set directDropList to {}
    set statusList to {}
    set projectStates to {}
    set projectIDs to {}
    set nameList to {}
    set containerProjectIDList to {}
    try
        tell application "OmniFocus"
            if itemType is "tasks" then
                set refList to every flattened task of scopeRef
                set idList to id of every flattened task of scopeRef
                set nameList to name of every flattened task of scopeRef
                set containerProjectIDList to id of containing project of every flattened task of scopeRef
                set doneList to completed of every flattened task of scopeRef
                set droppedList to effectively dropped of every flattened task of scopeRef
                if fieldName is "created" then
                    set dateList to creation date of every flattened task of scopeRef
                else if fieldName is "modified" then
                    set dateList to modification date of every flattened task of scopeRef
                else
                    set dateList to dropped date of every flattened task of scopeRef
                    set directDropList to dropped of every flattened task of scopeRef
                end if
                -- The root task of a project is part of the flattened tasks and has the ID of its project: leave it out
                tell default document
                    set projectIDs to id of every flattened project
                end tell
            else
                tell default document
                    set refList to every flattened project
                    set idList to id of every flattened project
                    set statusList to status of every flattened project
                    if fieldName is "created" then
                        set dateList to creation date of every flattened project
                    else if fieldName is "modified" then
                        set dateList to modification date of every flattened project
                    else
                        set dateList to dropped date of every flattened project
                    end if
                end tell
                repeat with i from 1 to count of statusList
                    set statusValue to item i of statusList
                    if statusValue is on hold status then
                        set end of projectStates to "on hold"
                    else if statusValue is done status then
                        set end of projectStates to "completed"
                    else if statusValue is dropped status then
                        set end of projectStates to "dropped"
                    else
                        set end of projectStates to "active"
                    end if
                end repeat
            end if
        end tell
    on error errMsg
        return "❌ OmniFocus could not read the " & itemType & ": " & errMsg
    end try

    -- Projects and folders of the whole database: label with folder path and the hidden folder check come from these lists
    tell application "OmniFocus"
        tell default document
            set allProjectIDList to id of every flattened project
            set allProjectNameList to name of every flattened project
            set allProjectFolderIDList to id of folder of every flattened project
            set folderIDList to id of every flattened folder
            set folderNameList to name of every flattened folder
            set folderParentIDList to id of container of every flattened folder
        end tell
    end tell
    set hiddenProjectIDList to my hiddenFolderProjectIDs()

    set listSize to count of idList
    set listsFit to ((count of refList) is listSize and (count of dateList) is listSize)
    if itemType is "tasks" then
        set listsFit to (listsFit and (count of doneList) is listSize and (count of droppedList) is listSize)
        set listsFit to (listsFit and (count of nameList) is listSize and (count of containerProjectIDList) is listSize)
        if fieldName is "dropped" then set listsFit to (listsFit and (count of directDropList) is listSize)
    else
        set listsFit to (listsFit and (count of projectStates) is listSize)
    end if
    if not listsFit then return "❌ OmniFocus changed while the " & itemType & " were read. Try again."

    -- The items of the period with their state (the status filter needs the state, the sort order the date)
    set keptIndexes to {}
    set keptKeys to {}
    set keptStates to {}
    repeat with i from 1 to listSize
        set whenDate to item i of dateList
        if whenDate is not missing value then
            if whenDate ≥ sinceDate and whenDate < untilDate then
                set stateText to "open"
                if itemType is "tasks" then
                    if item i of doneList then
                        set stateText to "completed"
                    else if item i of droppedList then
                        set stateText to "dropped"
                    end if
                else
                    set stateText to item i of projectStates
                end if
                set keepItem to true
                if fieldName is "dropped" then
                    if itemType is "tasks" then
                        if not (item i of directDropList) then set keepItem to false
                    else if stateText is not "dropped" then
                        set keepItem to false
                    end if
                end if
                if statusText is "open" and (stateText is "completed" or stateText is "dropped") then set keepItem to false
                if keepItem and itemType is "tasks" then
                    if projectIDs contains (item i of idList) then set keepItem to false
                end if
                if keepItem then
                    set end of keptIndexes to i
                    set end of keptKeys to (whenDate - sinceDate)
                    set end of keptStates to stateText
                end if
            end if
        end if
    end repeat

    set totalCount to count of keptIndexes
    set fieldWord to "Created"
    set fieldPast to "created"
    set fieldIcon to "🆕"
    if fieldName is "modified" then
        set fieldWord to "Modified"
        set fieldPast to "modified"
        set fieldIcon to "✏️"
    else if fieldName is "dropped" then
        set fieldWord to "Dropped"
        set fieldPast to "dropped"
        set fieldIcon to "🚫"
    end if
    if totalCount = 0 then
        set emptyText to "🔍 No " & itemType & " " & fieldPast & " " & rangeText
        if scopeLabel is not "" then set emptyText to emptyText & " in " & scopeLabel
        if statusText is "open" then set emptyText to emptyText & " (only open " & itemType & ")"
        return emptyText
    end if
    set sortedPositions to my sortPositions(keptKeys)

    -- Build the list in order; the project of a task is only read for the items that are looked at
    set entryLines to {}
    set entryDays to {}
    set projectCacheIDs to {}
    set projectCacheLabels to {}
    set projectCacheHidden to {}
    set shownCount to 0
    set processedCount to 0
    set hiddenCount to 0
    repeat with sortedPosition in sortedPositions
        if shownCount ≥ maxResults then exit repeat
        set processedCount to processedCount + 1
        set fullIndex to item sortedPosition of keptIndexes
        set itemID to item fullIndex of idList
        set stateText to item sortedPosition of keptStates
        set whenDate to item fullIndex of dateList

        -- Project (task) or the project itself, with folder path and the hidden folder check (cached per project)
        set labelText to "Inbox"
        set isHidden to false
        set theProjectID to missing value
        if itemType is "tasks" then
            set theProjectID to item fullIndex of containerProjectIDList
        else
            set theProjectID to itemID
        end if
        if theProjectID is not missing value then
            set cacheIndex to my indexOfItem(theProjectID, projectCacheIDs)
            if cacheIndex = 0 then
                set projectIndex to my indexOfItem(theProjectID, allProjectIDList)
                if projectIndex > 0 then
                    set labelText to item projectIndex of allProjectNameList
                    set folderPathText to my folderPathOf(item projectIndex of allProjectFolderIDList, folderIDList, folderNameList, folderParentIDList)
                    if folderPathText is not "" then set labelText to folderPathText & " > " & labelText
                end if
                set isHidden to (hiddenProjectIDList contains theProjectID)
                set end of projectCacheIDs to theProjectID
                set end of projectCacheLabels to labelText
                set end of projectCacheHidden to isHidden
            else
                set labelText to item cacheIndex of projectCacheLabels
                set isHidden to item cacheIndex of projectCacheHidden
            end if
        end if

        if isHidden then
            set hiddenCount to hiddenCount + 1
        else
            set entryText to "• " & labelText
            if itemType is "tasks" then set entryText to "• " & (item fullIndex of nameList) & " [" & labelText & "]"
            if stateText is "completed" then set entryText to entryText & " ✓"
            if stateText is "dropped" and fieldName is not "dropped" then set entryText to entryText & " 🚫"
            if stateText is "on hold" then set entryText to entryText & " (on hold)"
            if stateText is "active" and itemType is "projects" then set entryText to entryText & " (active)"
            set entryText to entryText & " " & (my shortTime(whenDate)) & " [id:" & itemID & "]"
            set end of entryLines to entryText
            set end of entryDays to (my shortDate(whenDate))
            set shownCount to shownCount + 1
        end if
    end repeat

    set reportText to fieldIcon & " " & fieldWord & " " & rangeText & ": " & itemType & " (" & totalCount & ")"
    if scopeLabel is not "" then set reportText to reportText & " in " & scopeLabel
    if statusText is "open" then set reportText to reportText & ", only open"
    set lastDay to ""
    repeat with i from 1 to count of entryLines
        if (item i of entryDays) is not lastDay then
            set lastDay to item i of entryDays
            set reportText to reportText & return & return & "📅 " & lastDay
        end if
        set reportText to reportText & return & (item i of entryLines)
    end repeat
    set restCount to totalCount - processedCount
    if restCount > 0 then
        set reportText to reportText & return & return & "… " & restCount & " more not shown (limit " & maxResults & ")."
    end if
    if hiddenCount > 0 then
        set reportText to reportText & return & return & "ℹ️ " & hiddenCount & " in hidden (dropped) folders left out."
    end if
    return reportText
end run

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
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to " > "
    set pathText to pathNames as text
    set AppleScript's text item delimiters to oldDelims
    return pathText
end folderPathOf

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

on parseRangeDate(valueText, isEnd)
    -- "today" and "yesterday" (start of that day), "YYYY-MM-DD" (start of that day; as an end date the start of the next
    -- day, so that the whole day counts) or "YYYY-MM-DD HH:MM". Raises an error for anything else.
    set dayStart to current date
    set time of dayStart to 0
    if valueText is "today" then
        if isEnd then return dayStart + 1 * days
        return dayStart
    else if valueText is "yesterday" then
        if isEnd then return dayStart
        return dayStart - 1 * days
    end if
    set parsedDate to my parseISODate(valueText)
    if parsedDate is missing value then error "Invalid date: " & valueText
    if isEnd and (length of valueText) is 10 then return parsedDate + 1 * days
    return parsedDate
end parseRangeDate

on parseISODate(dateString)
    -- Parses "YYYY-MM-DD", "YYYY-MM-DD HH:MM" or "YYYY-MM-DDTHH:MM".
    -- Returns missing value if dateString is not in ISO form, raises an error for impossible dates.
    set isoText to my trimItem(dateString)
    set isoLength to length of isoText
    if isoLength is not 10 and isoLength is not 16 then return missing value
    if character 5 of isoText is not "-" or character 8 of isoText is not "-" then return missing value

    set hourNum to 0
    set minuteNum to 0
    try
        set yearNum to (text 1 thru 4 of isoText) as integer
        set monthNum to (text 6 thru 7 of isoText) as integer
        set dayNum to (text 9 thru 10 of isoText) as integer
        if isoLength is 16 then
            if character 11 of isoText is not " " and character 11 of isoText is not "T" then return missing value
            if character 14 of isoText is not ":" then return missing value
            set hourNum to (text 12 thru 13 of isoText) as integer
            set minuteNum to (text 15 thru 16 of isoText) as integer
        end if
    on error
        return missing value
    end try

    if monthNum < 1 or monthNum > 12 or dayNum < 1 or dayNum > 31 or hourNum < 0 or hourNum > 23 or minuteNum < 0 or minuteNum > 59 then
        error "Invalid date: " & dateString
    end if

    set isoDate to current date
    set day of isoDate to 1
    set year of isoDate to yearNum
    set month of isoDate to monthNum
    set day of isoDate to dayNum
    set time of isoDate to hourNum * hours + minuteNum * minutes
    -- A day that does not exist in that month (e.g. 2026-02-30) rolls over; reject it
    if day of isoDate is not dayNum then error "Invalid date: " & dateString
    return isoDate
end parseISODate

on isDigits(theText)
    -- True if the text is not empty and has only the digits 0 to 9
    if theText is "" then return false
    repeat with aChar in characters of theText
        if "0123456789" does not contain (contents of aChar) then return false
    end repeat
    return true
end isDigits

on indexOfItem(anItem, aList)
    -- Position of anItem in aList, 0 if it is not in the list
    repeat with i from 1 to count of aList
        if (item i of aList) is anItem then return i
    end repeat
    return 0
end indexOfItem

on resolveProject(queryText)
    -- "id:<id>" addresses exactly one project
    if queryText starts with "id:" and (length of queryText) > 3 then
        tell application "OmniFocus"
            tell default document
                set wantedID to text 4 thru -1 of queryText
                set idMatches to every flattened project whose id is wantedID
            end tell
        end tell
        if (count of idMatches) = 1 then
            return {foundProject:item 1 of idMatches, errorText:""}
        end if
        return {foundProject:missing value, errorText:"❌ Project not found: " & queryText}
    end if
    
    -- Finds a project in any folder by name, or by "Folder > Subfolder > Project".
    -- Names match exactly or as a substring, ignoring case.
    -- Returns {foundProject, errorText}; foundProject is missing value if nothing or more than one project fits.
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ">"
    set rawParts to text items of queryText
    set AppleScript's text item delimiters to oldDelims
    
    set queryParts to {}
    repeat with rawPart in rawParts
        set cleanPart to my trimItem(rawPart as string)
        if cleanPart is not "" then set end of queryParts to cleanPart
    end repeat
    if (count of queryParts) = 0 then
        return {foundProject:missing value, errorText:"❌ Project name cannot be empty."}
    end if
    
    set projectQuery to item -1 of queryParts
    set folderQuery to {}
    if (count of queryParts) > 1 then set folderQuery to items 1 thru -2 of queryParts
    
    -- The names of all projects come with one query (an Apple Event per project costs about 17 ms)
    tell application "OmniFocus"
        tell default document
            set allProjects to every flattened project
            set allProjectNames to name of every flattened project
        end tell
    end tell
    
    set exactMatches to {}
    set partialMatches to {}
    repeat with projectIndex from 1 to count of allProjects
        set candidateProject to item projectIndex of allProjects
        set candidateName to item projectIndex of allProjectNames
        ignoring case
            if candidateName is projectQuery then
                set end of exactMatches to candidateProject
            else if candidateName contains projectQuery then
                set end of partialMatches to candidateProject
            end if
        end ignoring
    end repeat
    
    if (count of folderQuery) > 0 then
        set exactMatches to my filterByFolder(exactMatches, folderQuery)
        set partialMatches to my filterByFolder(partialMatches, folderQuery)
    end if
    
    -- A single exact name wins; otherwise every match counts and must be unique
    if (count of exactMatches) = 1 then
        return {foundProject:item 1 of exactMatches, errorText:""}
    end if
    set allMatches to exactMatches & partialMatches
    if (count of allMatches) = 1 then
        return {foundProject:item 1 of allMatches, errorText:""}
    end if
    if (count of allMatches) = 0 then
        return {foundProject:missing value, errorText:"❌ Project not found: " & queryText}
    end if
    
    set matchList to "❌ Ambiguous project \"" & queryText & "\" (" & (count of allMatches) & " matches). Nothing was changed. Use \"Folder > Project\" to pick one:"
    repeat with aMatch in allMatches
        set matchList to matchList & return & "• " & my projectLabel(contents of aMatch)
    end repeat
    return {foundProject:missing value, errorText:matchList}
end resolveProject

on filterByFolder(projectList, folderQuery)
    -- Keeps the projects whose innermost folders match folderQuery (outermost first)
    set keptProjects to {}
    repeat with aProject in projectList
        set candidateProject to contents of aProject
        set folderNames to my projectFolderNames(candidateProject)
        set queryCount to count of folderQuery
        set nameCount to count of folderNames
        set folderFits to (queryCount ≤ nameCount)
        if folderFits then
            ignoring case
                repeat with i from 1 to queryCount
                    set wantedName to item i of folderQuery
                    set actualName to item (nameCount - queryCount + i) of folderNames
                    if actualName does not contain wantedName then set folderFits to false
                end repeat
            end ignoring
        end if
        if folderFits then set end of keptProjects to candidateProject
    end repeat
    return keptProjects
end filterByFolder

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
