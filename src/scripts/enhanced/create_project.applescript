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
    if dueText is not "" then
        set dueDate to my parseDate(dueText)
        if dueDate is missing value then return my dateErrorText(dueText, "due_date") & " Nothing was created."
    end if
    if deferText is not "" then
        set deferDate to my parseDate(deferText)
        if deferDate is missing value then return my dateErrorText(deferText, "defer_date") & " Nothing was created."
    end if
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

on resolveFolder(queryText)
    -- Finds a folder at any depth by name, or by "Folder > Subfolder".
    -- Names match exactly or as a substring, ignoring case.
    -- "id:<id>" finds a folder by the ID shown by list_folders.
    -- Returns {foundFolder, errorText}; foundFolder is missing value if nothing or more than one folder fits.
    if queryText starts with "id:" then
        set wantedID to ""
        if (length of queryText) > 3 then set wantedID to my trimText(text 4 thru -1 of queryText)
        set idMatches to {}
        if wantedID is not "" then
            tell application "OmniFocus"
                tell default document
                    set idMatches to every flattened folder whose id is wantedID
                end tell
            end tell
        end if
        if (count of idMatches) = 1 then return {foundFolder:item 1 of idMatches, errorText:""}
        return {foundFolder:missing value, errorText:"❌ Folder not found: " & queryText}
    end if
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

    set matchList to "❌ Ambiguous folder \"" & queryText & "\" (" & (count of allMatches) & " matches). Nothing was changed. Use \"Folder > Subfolder\" to pick one:"
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
    -- Reads a date from text. Returns missing value if the text is not a date: nothing is guessed.
    -- Understood: YYYY-MM-DD (midnight), YYYY-MM-DD HH:MM, YYYY-MM-DDTHH:MM, today, tomorrow, next week,
    -- "3 days", "in 3 days", "2 weeks" and, as a last try, the date formats and weekday names of the system language.
    set todayDate to current date
    set trimmed to my trimItem(dateString as text)
    if trimmed is "" then return missing value

    -- ISO dates are built from their numeric parts, independent of the system language
    if my looksLikeISODate(trimmed) then return my parseISODate(trimmed)

    if trimmed is "today" then return todayDate
    if trimmed is "tomorrow" then return todayDate + 1 * days
    if trimmed is "next week" or trimmed is "week" then return todayDate + 7 * days

    -- "3 days", "in 3 days", "1 week", "2 weeks" (no short-circuit in AppleScript: check the number of words first)
    set wordList to words of trimmed
    if (count of wordList) = 3 then
        if (item 1 of wordList) is "in" then set wordList to {item 2 of wordList, item 3 of wordList}
    end if
    if (count of wordList) = 2 then
        if my isDateDigits(item 1 of wordList) and (length of (item 1 of wordList)) ≤ 4 then
            set amountNum to (item 1 of wordList) as integer
            set unitName to item 2 of wordList
            if unitName is "day" or unitName is "days" then return todayDate + amountNum * days
            if unitName is "week" or unitName is "weeks" then return todayDate + amountNum * weeks
        end if
    end if

    -- A dash between digits (2026-12-01, 12-01-2026) in another form than above would be misread by the system parser
    if my hasDigitDash(trimmed) then return missing value

    set systemDate to missing value
    try
        set systemDate to date trimmed
    end try
    if systemDate is missing value then return missing value
    if not my fallbackDateFits(trimmed, systemDate) then return missing value
    return systemDate
end parseDate

on fallbackDateFits(theText, theDate)
    -- The system parser rolls a date that does not exist (31.31.2026) over into a later one. For a date written with
    -- numbers and dots or slashes, the day and the month of the result must be numbers of the text.
    set datePart to theText
    set spacePos to offset of " " in theText
    if spacePos > 1 then set datePart to text 1 thru (spacePos - 1) of theText
    if datePart does not contain "." and datePart does not contain "/" then return true
    repeat with aChar in characters of datePart
        if "abcdefghijklmnopqrstuvwxyzäöüß" contains (contents of aChar) then return true
    end repeat
    set numberList to my numberTokens(datePart)
    if (count of numberList) < 2 then return true
    if numberList does not contain (day of theDate) then return false
    if numberList does not contain ((month of theDate) as integer) then return false
    return true
end fallbackDateFits

on numberTokens(theText)
    -- The whole numbers in a text, in order: "31.12.2026" gives {31, 12, 2026}
    set tokenList to {}
    set currentToken to ""
    repeat with aChar in characters of theText
        if "0123456789" contains (contents of aChar) then
            set currentToken to currentToken & (contents of aChar)
        else if currentToken is not "" then
            set end of tokenList to currentToken as integer
            set currentToken to ""
        end if
    end repeat
    if currentToken is not "" then set end of tokenList to currentToken as integer
    return tokenList
end numberTokens

on looksLikeISODate(theText)
    -- True if the text starts like an ISO date: four digits and a dash
    if (length of theText) < 5 then return false
    if not my isDateDigits(text 1 thru 4 of theText) then return false
    return (character 5 of theText) is "-"
end looksLikeISODate

on parseISODate(dateString)
    -- Reads "YYYY-MM-DD" (midnight), "YYYY-MM-DD HH:MM", "YYYY-MM-DDTHH:MM" or the same with ":SS".
    -- Returns missing value if the text has another form or the date does not exist (2026-02-30, month 13, 25:00).
    set isoText to my trimItem(dateString)
    set isoLength to length of isoText
    if isoLength is not 10 and isoLength is not 16 and isoLength is not 19 then return missing value
    if (character 5 of isoText) is not "-" or (character 8 of isoText) is not "-" then return missing value
    if not my isDateDigits(text 1 thru 4 of isoText) or not my isDateDigits(text 6 thru 7 of isoText) or not my isDateDigits(text 9 thru 10 of isoText) then return missing value

    set hourNum to 0
    set minuteNum to 0
    set secondNum to 0
    if isoLength ≥ 16 then
        if (character 11 of isoText) is not " " and (character 11 of isoText) is not "T" then return missing value
        if (character 14 of isoText) is not ":" then return missing value
        if not my isDateDigits(text 12 thru 13 of isoText) or not my isDateDigits(text 15 thru 16 of isoText) then return missing value
        set hourNum to (text 12 thru 13 of isoText) as integer
        set minuteNum to (text 15 thru 16 of isoText) as integer
    end if
    if isoLength is 19 then
        if (character 17 of isoText) is not ":" then return missing value
        if not my isDateDigits(text 18 thru 19 of isoText) then return missing value
        set secondNum to (text 18 thru 19 of isoText) as integer
    end if
    set yearNum to (text 1 thru 4 of isoText) as integer
    set monthNum to (text 6 thru 7 of isoText) as integer
    set dayNum to (text 9 thru 10 of isoText) as integer
    if yearNum < 1000 or monthNum < 1 or monthNum > 12 or dayNum < 1 or dayNum > 31 then return missing value
    if hourNum > 23 or minuteNum > 59 or secondNum > 59 then return missing value

    try
        set isoDate to current date
        set day of isoDate to 1
        set year of isoDate to yearNum
        set month of isoDate to monthNum
        set day of isoDate to dayNum
        set time of isoDate to hourNum * hours + minuteNum * minutes + secondNum
        -- A day that does not exist in that month (2026-02-30) rolls over into the next one; refuse it
        if (day of isoDate) is not dayNum then return missing value
    on error
        return missing value
    end try
    return isoDate
end parseISODate

on hasDigitDash(theText)
    -- True if a dash stands between two digits
    set textLength to length of theText
    if textLength < 3 then return false
    repeat with i from 2 to textLength - 1
        if (character i of theText) is "-" then
            if "0123456789" contains (character (i - 1) of theText) and "0123456789" contains (character (i + 1) of theText) then return true
        end if
    end repeat
    return false
end hasDigitDash

on isDateDigits(theText)
    -- True if the text is not empty and has only the digits 0 to 9
    if theText is "" then return false
    repeat with aChar in characters of theText
        if "0123456789" does not contain (contents of aChar) then return false
    end repeat
    return true
end isDateDigits

on dateErrorText(valueText, fieldName)
    -- The message for a date that cannot be read; the caller adds what was not done
    return "❌ Invalid date for " & fieldName & ": " & valueText & ". Use YYYY-MM-DD, YYYY-MM-DD HH:MM, today, tomorrow, next week, \"3 days\" or \"2 weeks\"."
end dateErrorText
