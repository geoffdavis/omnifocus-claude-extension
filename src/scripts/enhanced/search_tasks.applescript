on run argv
    -- Search for tasks across all projects and contexts
    -- Usage: search_tasks.applescript "search term" ["all"|"available"|"remaining"] [limit] [include_dropped]
    
    set searchTerm to item 1 of argv
    set taskFilter to "all"
    set resultLimit to 50
    
    if (count of argv) > 1 then
        set taskFilter to item 2 of argv
    end if
    
    if (count of argv) > 2 then
        -- Only a whole number from 1 to 99999 is a limit; anything else keeps the default
        set limitText to item 3 of argv
        if my isDigits(limitText) and (length of limitText) < 6 and limitText is not "0" then set resultLimit to limitText as integer
    end if
    
    -- include_dropped: "true" also shows dropped items and items below dropped (hidden) folders
    set includeDropped to false
    if (count of argv) > 3 then set includeDropped to (item 4 of argv is "true")
    set hiddenProjectIDList to {}
    if not includeDropped then set hiddenProjectIDList to my hiddenFolderProjectIDs()
    set checkHidden to ((count of hiddenProjectIDList) > 0)
    set checkAvailable to (taskFilter is "available")
    set onlyOpen to (taskFilter is "available" or taskFilter is "remaining")
    
    -- Every Apple Event costs about 17 ms, a query for the property of all tasks about 0.1 s: the lists of all tasks are
    -- fetched at once (the same position in each list is the same task) and searched here.
    tell application "OmniFocus"
        tell default document
            set taskIDList to id of every flattened task
            set taskNameList to name of every flattened task
            set taskNoteList to note of every flattened task
            set completedList to completed of every flattened task
            set effCompletedList to effectively completed of every flattened task
            set effDroppedList to effectively dropped of every flattened task
            set flaggedList to flagged of every flattened task
            set dueDateList to due date of every flattened task
            set projectNameList to name of containing project of every flattened task
            if checkHidden then set projectIDList to id of containing project of every flattened task
            if checkAvailable then
                set blockedList to blocked of every flattened task
                set deferDateList to defer date of every flattened task
            end if
        end tell
    end tell
    set nowDate to current date
    
    -- Filter tasks by search term
    set matchingTasks to {}
    set taskCount to 0
    repeat with i from 1 to count of taskIDList
        if taskCount ≥ resultLimit then exit repeat
        
        -- "remaining" and "available": open tasks only; "all" also includes completed tasks.
        -- Dropped tasks are left out unless include_dropped is set.
        set taskMatches to true
        if onlyOpen and (item i of effCompletedList) then set taskMatches to false
        if taskMatches and not includeDropped and (item i of effDroppedList) then set taskMatches to false
        
        -- Search in both name and note
        if taskMatches then
            set taskName to item i of taskNameList
            set taskMatches to (taskName contains searchTerm) or ((item i of taskNoteList) contains searchTerm)
        end if
        
        -- "available" additionally excludes blocked tasks and tasks deferred to the future
        if taskMatches and checkAvailable then
            if item i of blockedList then set taskMatches to false
            set taskDefer to item i of deferDateList
            if taskDefer is not missing value then
                if taskDefer > nowDate then set taskMatches to false
            end if
        end if
        
        -- Leave out tasks of projects below hidden (dropped) folders
        if taskMatches and checkHidden then
            set projectID to item i of projectIDList
            if projectID is not missing value then
                if hiddenProjectIDList contains projectID then set taskMatches to false
            end if
        end if
        
        if taskMatches then
            set taskCount to taskCount + 1
            
            -- Build task info
            set taskInfo to "• " & taskName
            
            -- Add project info if available
            set projName to item i of projectNameList
            if projName is not missing value then set taskInfo to taskInfo & " [" & projName & "]"
            
            -- Add status indicators
            if item i of completedList then
                set taskInfo to taskInfo & " ✓"
            else if item i of flaggedList then
                set taskInfo to taskInfo & " 🚩"
            end if
            
            -- Add due date if present
            set dueDate to item i of dueDateList
            if dueDate is not missing value then set taskInfo to taskInfo & " 📅 " & (my shortDateTime(dueDate))
            
            set taskInfo to taskInfo & " [id:" & (item i of taskIDList) & "]"
            set end of matchingTasks to taskInfo
        end if
    end repeat
    
    -- Format results
    if (count of matchingTasks) = 0 then
        return "🔍 No tasks found matching: " & searchTerm
    else
        set resultText to "🔍 Found " & (count of matchingTasks) & " tasks matching \"" & searchTerm & "\":"
        repeat with taskLine in matchingTasks
            set resultText to resultText & return & taskLine
        end repeat
        
        if taskCount = resultLimit then
            set resultText to resultText & return & return & "… Limit of " & resultLimit & " tasks reached, more tasks may match. Use a more specific search or a higher limit."
        end if
        
        return resultText
    end if
end run

on isDigits(theText)
    -- True if the text is not empty and has only the digits 0 to 9
    if theText is "" then return false
    repeat with aChar in characters of theText
        if "0123456789" does not contain (contents of aChar) then return false
    end repeat
    return true
end isDigits

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
