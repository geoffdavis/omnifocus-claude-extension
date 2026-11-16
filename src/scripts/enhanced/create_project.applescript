on run argv
    -- Create a new project, optionally inside a folder
    -- Usage: create_project.applescript "project name" ["Folder > Subfolder"] ["note"] ["review interval"] ["due date"] ["defer date"] ["type"]
    --   review interval: "1 week", "2 weeks", "1 month", "1 year"
    --   due date, defer date: ISO date such as 2026-12-31 (or "today", "tomorrow", "next week", "N days")
    --   type: sequential, parallel or single_action
    -- Empty arguments are skipped. Everything is checked before the project is created.

    if (count of argv) = 0 then
        return "❌ Project name is required."
    end if

    set projectName to item 1 of argv
    set folderQueryText to ""
    set projectNote to ""
    if (count of argv) > 1 then set folderQueryText to item 2 of argv
    if (count of argv) > 2 then set projectNote to item 3 of argv
    set intervalText to ""
    set dueText to ""
    set deferText to ""
    set typeText to ""
    if (count of argv) > 3 then set intervalText to my trimText(item 4 of argv)
    if (count of argv) > 4 then set dueText to my trimText(item 5 of argv)
    if (count of argv) > 5 then set deferText to my trimText(item 6 of argv)
    if (count of argv) > 6 then set typeText to my trimText(item 7 of argv)

    if projectName is "" then
        return "❌ Project name cannot be empty."
    end if

    -- Check the optional settings first, so that an invalid value creates nothing
    set intervalInfo to missing value
    if intervalText is not "" then
        set intervalInfo to my parseReviewInterval(intervalText)
        if not (isValid of intervalInfo) then
            return (errorText of intervalInfo) & " Nothing was created."
        end if
    end if
    set dueDate to missing value
    set deferDate to missing value
    try
        if dueText is not "" then set dueDate to my parseDate(dueText)
        if deferText is not "" then set deferDate to my parseDate(deferText)
    on error errMsg
        return "❌ " & errMsg & ". Nothing was created."
    end try
    if typeText is not "" then
        if typeText is not "sequential" and typeText is not "parallel" and typeText is not "single_action" and typeText is not "single action" then
            return "❌ Unknown project type: " & typeText & ". Valid values: sequential, parallel, single_action. Nothing was created."
        end if
    end if

    tell application "OmniFocus"
        tell default document
            try
                if folderQueryText is "" then
                    -- Create at top level
                    set existingProjects to every project whose name is projectName
                    if (count of existingProjects) > 0 then
                        return "⚠️ Project already exists at top level: " & projectName
                    end if
                    set newProject to make new project with properties {name:projectName}
                    set locationText to " (top level)"
                else
                    -- Create inside the folder; the folder must already exist and be unambiguous
                    set folderLookup to my resolveFolder(folderQueryText)
                    if foundFolder of folderLookup is missing value then
                        return errorText of folderLookup
                    end if
                    set targetFolder to foundFolder of folderLookup
                    set existingProjects to every project of targetFolder whose name is projectName
                    if (count of existingProjects) > 0 then
                        return "⚠️ Project already exists in " & my folderLabel(targetFolder) & ": " & projectName
                    end if
                    tell targetFolder
                        set newProject to make new project with properties {name:projectName}
                    end tell
                    set locationText to " (in " & my folderLabel(targetFolder) & ")"
                end if

                if projectNote is not "" then
                    set note of newProject to projectNote
                end if

                -- Optional settings; a failure is reported, the project itself exists at this point
                set extraText to ""
                set problemText to ""
                if typeText is "sequential" then
                    set sequential of newProject to true
                    set extraText to extraText & ", sequential"
                else if typeText is "parallel" then
                    set sequential of newProject to false
                    set extraText to extraText & ", parallel"
                else if typeText is "single_action" or typeText is "single action" then
                    set singleton action holder of newProject to true
                    set extraText to extraText & ", single action list"
                end if
                if dueDate is not missing value then
                    set due date of newProject to dueDate
                    set extraText to extraText & ", due " & (dueDate as string)
                end if
                if deferDate is not missing value then
                    set defer date of newProject to deferDate
                    set extraText to extraText & ", deferred until " & (deferDate as string)
                end if
                if intervalInfo is not missing value then
                    try
                        my setReviewInterval(newProject, stepCount of intervalInfo, unitName of intervalInfo)
                        set readBack to my reviewIntervalText(newProject)
                        if readBack is "" then set readBack to intervalText
                        set extraText to extraText & ", review: " & readBack
                    on error errMsg
                        set problemText to return & "⚠️ The review interval could not be set: " & errMsg
                    end try
                end if
                if extraText is not "" then set extraText to " [" & text 3 thru -1 of extraText & "]"
                return "✅ Created project: " & projectName & locationText & extraText & problemText
            on error errMsg
                return "❌ Error creating project: " & errMsg
            end try
        end tell
    end tell
end run

on resolveFolder(queryText)
    -- Finds a folder at any depth by name, or by "Folder > Subfolder".
    -- Names match exactly or as a substring, ignoring case.
    -- Returns {foundFolder, errorText}; foundFolder is missing value if nothing or more than one folder fits.
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ">"
    set rawParts to text items of queryText
    set AppleScript's text item delimiters to oldDelims

    set queryParts to {}
    repeat with rawPart in rawParts
        set cleanPart to my trimText(rawPart as string)
        if cleanPart is not "" then set end of queryParts to cleanPart
    end repeat
    if (count of queryParts) = 0 then
        return {foundFolder:missing value, errorText:"❌ Folder name cannot be empty."}
    end if

    set folderQuery to item -1 of queryParts
    set parentQuery to {}
    if (count of queryParts) > 1 then set parentQuery to items 1 thru -2 of queryParts

    tell application "OmniFocus"
        tell default document
            set allFolders to every flattened folder
        end tell
    end tell

    set exactMatches to {}
    set partialMatches to {}
    repeat with aFolder in allFolders
        set candidateFolder to contents of aFolder
        set folderNames to my folderNamePath(candidateFolder)
        set candidateName to item -1 of folderNames
        set parentNames to {}
        if (count of folderNames) > 1 then set parentNames to items 1 thru -2 of folderNames

        -- The parent folders given in the query must match the innermost parents
        set queryCount to count of parentQuery
        set nameCount to count of parentNames
        set parentFits to (queryCount ≤ nameCount)
        ignoring case
            if parentFits then
                repeat with i from 1 to queryCount
                    set wantedName to item i of parentQuery
                    set actualName to item (nameCount - queryCount + i) of parentNames
                    if actualName does not contain wantedName then set parentFits to false
                end repeat
            end if
            if parentFits then
                if candidateName is folderQuery then
                    set end of exactMatches to candidateFolder
                else if candidateName contains folderQuery then
                    set end of partialMatches to candidateFolder
                end if
            end if
        end ignoring
    end repeat

    -- A single exact name wins; otherwise every match counts and must be unique
    if (count of exactMatches) = 1 then
        return {foundFolder:item 1 of exactMatches, errorText:""}
    end if
    set allMatches to exactMatches & partialMatches
    if (count of allMatches) = 1 then
        return {foundFolder:item 1 of allMatches, errorText:""}
    end if
    if (count of allMatches) = 0 then
        return {foundFolder:missing value, errorText:"❌ Folder not found: " & queryText}
    end if

    set matchList to "❌ Ambiguous folder \"" & queryText & "\" (" & (count of allMatches) & " matches). Nothing was created. Use \"Folder > Subfolder\" to pick one:"
    repeat with aMatch in allMatches
        set matchList to matchList & return & "• " & my folderLabel(contents of aMatch)
    end repeat
    return {foundFolder:missing value, errorText:matchList}
end resolveFolder

on folderNamePath(aFolder)
    -- Folder names from the outermost folder down to aFolder itself
    set folderNames to {}
    tell application "OmniFocus"
        set beginning of folderNames to name of aFolder
        try
            set parentContainer to container of aFolder
            repeat while class of parentContainer is folder
                set beginning of folderNames to name of parentContainer
                set parentContainer to container of parentContainer
            end repeat
        end try
    end tell
    return folderNames
end folderNamePath

on folderLabel(aFolder)
    -- "Folder > Subfolder", the same form resolveFolder accepts
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to " > "
    set labelText to (my folderNamePath(aFolder)) as string
    set AppleScript's text item delimiters to oldDelims
    return labelText
end folderLabel

on trimText(theText)
    set whitespaceChars to {" ", tab}
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
end trimText

on parseDate(dateString)
    set todayDate to current date

    -- ISO dates are built from their numeric parts, independent of the system language
    set isoDate to my parseISODate(dateString)
    if isoDate is not missing value then return isoDate

    if dateString is "today" then
        return todayDate
    else if dateString is "tomorrow" then
        return todayDate + 1 * days
    else if dateString is "next week" then
        return todayDate + 7 * days
    else if dateString contains "days" then
        try
            set dayCount to word 1 of dateString as integer
            return todayDate + dayCount * days
        on error
            return todayDate
        end try
    else
        -- Try to parse as date directly
        try
            return date dateString
        on error
            return todayDate
        end try
    end if
end parseDate

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

on parseReviewInterval(valueText)
    -- Reads a review interval: "2 weeks", "1 month", "every 2 weeks", "week", "weekly".
    -- Units: day, week, month, year (plural allowed). OmniFocus has no "no review" setting.
    -- Returns {isValid, stepCount, unitName, errorText}
    set cleanText to my trimItem(valueText)
    set problemText to "❌ Invalid review interval: " & valueText & ". Use for example \"1 week\", \"2 weeks\", \"1 month\" or \"1 year\"."
    ignoring case
        if cleanText is "daily" then return {isValid:true, stepCount:1, unitName:"day", errorText:""}
        if cleanText is "weekly" then return {isValid:true, stepCount:1, unitName:"week", errorText:""}
        if cleanText is "monthly" then return {isValid:true, stepCount:1, unitName:"month", errorText:""}
        if cleanText is "yearly" then return {isValid:true, stepCount:1, unitName:"year", errorText:""}
    end ignoring

    set wordList to words of cleanText
    -- "every 2 weeks" is the same as "2 weeks"
    ignoring case
        if (count of wordList) > 1 and item 1 of wordList is "every" then set wordList to items 2 thru -1 of wordList
    end ignoring
    set stepCount to 1
    if (count of wordList) = 1 then
        set unitWord to item 1 of wordList
    else if (count of wordList) = 2 then
        try
            set stepCount to (item 1 of wordList) as integer
        on error
            return {isValid:false, stepCount:0, unitName:"", errorText:problemText}
        end try
        set unitWord to item 2 of wordList
    else
        return {isValid:false, stepCount:0, unitName:"", errorText:problemText}
    end if
    if stepCount < 1 or stepCount > 999 then return {isValid:false, stepCount:0, unitName:"", errorText:problemText}

    ignoring case
        if (length of unitWord) > 1 and unitWord ends with "s" then set unitWord to text 1 thru -2 of unitWord
        if unitWord is "day" then return {isValid:true, stepCount:stepCount, unitName:"day", errorText:""}
        if unitWord is "week" then return {isValid:true, stepCount:stepCount, unitName:"week", errorText:""}
        if unitWord is "month" then return {isValid:true, stepCount:stepCount, unitName:"month", errorText:""}
        if unitWord is "year" then return {isValid:true, stepCount:stepCount, unitName:"year", errorText:""}
    end ignoring
    return {isValid:false, stepCount:0, unitName:"", errorText:problemText}
end parseReviewInterval

on setReviewInterval(aProject, stepCount, unitName)
    -- Sets the review interval of a project (stepCount of at least 1)
    tell application "OmniFocus"
        if unitName is "day" then
            set review interval of aProject to {unit:day, steps:stepCount, fixed:true}
        else if unitName is "week" then
            set review interval of aProject to {unit:week, steps:stepCount, fixed:true}
        else if unitName is "month" then
            set review interval of aProject to {unit:month, steps:stepCount, fixed:true}
        else
            set review interval of aProject to {unit:year, steps:stepCount, fixed:true}
        end if
    end tell
end setReviewInterval

on reviewIntervalText(aProject)
    -- "every 2 weeks", or "" if the interval cannot be read
    set stepCount to 0
    set unitName to "?"
    tell application "OmniFocus"
        try
            set intervalRecord to review interval of aProject
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
