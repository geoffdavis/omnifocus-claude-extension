on run argv
    -- Edit an existing project
    -- Usage: edit_project.applescript "project name or Folder > Project" "property" "new value"
    -- Properties: name, note, append_note, folder, status, type, review_interval, next_review_date,
    --             due_date, defer_date, planned_date, flagged, complete_with_last_item,
    --             attach_file, link_file, remove_attachment
    --   attach_file: attaches the file with the given full path to the note (a copy is stored in OmniFocus)
    --   link_file: links the file with the given full path in the note (the file stays where it is)
    --   remove_attachment: removes the attachment with the given number (1 is the first one, see get_project)
    --   review_interval: "1 week", "2 weeks", "1 month", "1 year", "weekly", ...
    --     (OmniFocus has no "no review" setting; to keep a project out of the reviews, set next_review_date far ahead)
    --   next_review_date: a date, or "none" to derive it again from the last review and the interval
    --   due_date, defer_date, planned_date: a date, or "none" to clear it
    --   flagged, complete_with_last_item: true or false
    
    if (count of argv) < 3 then
        return "❌ Project, property and value are required."
    end if
    
    set projectText to item 1 of argv
    set propertyName to item 2 of argv
    set newValue to item 3 of argv
    
    -- Searches projects in all folders; accepts "Folder > Subfolder > Project"
    set projectLookup to my resolveProject(projectText)
    if foundProject of projectLookup is missing value then
        return errorText of projectLookup
    end if
    set targetProject to foundProject of projectLookup
    set originalLabel to my projectLabel(targetProject)
    
    tell application "OmniFocus"
        tell default document
            try
                if propertyName is "name" then
                    if newValue is "" then
                        return "❌ New project name cannot be empty."
                    end if
                    set name of targetProject to newValue
                    return "✏️ Renamed project: \"" & originalLabel & "\" → \"" & newValue & "\""
                    
                else if propertyName is "note" then
                    set note of targetProject to newValue
                    return "✏️ Updated note for project: " & originalLabel
                    
                else if propertyName is "append_note" then
                    -- Add text at the end of the note without touching what is already there
                    if newValue is "" then
                        return "❌ append_note needs a text to add. Nothing was changed."
                    end if
                    set currentNote to (note of targetProject) as text
                    if currentNote is "" then
                        set note of targetProject to newValue
                    else
                        -- Setting the note as plain text would lose attachments and formatting, so refuse in that case
                        set noteProblem to my noteFormattingProblem(targetProject)
                        if noteProblem is not "" then
                            return "❌ " & noteProblem & " Nothing was changed."
                        end if
                        set note of targetProject to currentNote & linefeed & newValue
                    end if
                    return "📝 Added to the note of project: " & originalLabel

                else if propertyName is "attach_file" or propertyName is "link_file" then
                    return my attachFileToNote(targetProject, originalLabel, newValue, propertyName is "attach_file")

                else if propertyName is "remove_attachment" then
                    return my removeAttachmentFromNote(targetProject, originalLabel, newValue)

                else if propertyName is "folder" then
                    if newValue is "none" or newValue is "top level" then
                        try
                            move targetProject to end of projects
                        on error
                            move targetProject to end of sections
                        end try
                        return "📁 Moved project to top level: " & originalLabel
                    else
                        -- The folder must already exist and be unambiguous
                        set folderLookup to my resolveFolder(newValue)
                        if foundFolder of folderLookup is missing value then
                            return errorText of folderLookup
                        end if
                        set targetFolder to foundFolder of folderLookup
                        try
                            move targetProject to end of projects of targetFolder
                        on error
                            move targetProject to end of sections of targetFolder
                        end try
                        return "📁 Moved project \"" & originalLabel & "\" to folder: " & my folderLabel(targetFolder)
                    end if
                    
                else if propertyName is "status" then
                    if newValue is "active" then
                        set status of targetProject to active status
                        return "▶️ Project is active: " & originalLabel
                    else if newValue is "on_hold" or newValue is "on hold" then
                        set status of targetProject to on hold status
                        return "⏸️ Project is on hold: " & originalLabel
                    else if newValue is "completed" or newValue is "done" then
                        mark complete targetProject
                        return "✅ Project completed: " & originalLabel
                    else if newValue is "dropped" then
                        mark dropped targetProject
                        return "🚫 Project dropped: " & originalLabel
                    else
                        return "❌ Unknown status: " & newValue & ". Valid values: active, on_hold, completed, dropped"
                    end if
                    
                else if propertyName is "type" then
                    -- Sequential and parallel projects hold tasks, a single action list holds independent actions
                    if newValue is "sequential" then
                        set singleton action holder of targetProject to false
                        set sequential of targetProject to true
                        return "🔢 Project is sequential: " & originalLabel
                    else if newValue is "parallel" then
                        set singleton action holder of targetProject to false
                        set sequential of targetProject to false
                        return "🔀 Project is parallel: " & originalLabel
                    else if newValue is "single_action" or newValue is "single action" then
                        set sequential of targetProject to false
                        set singleton action holder of targetProject to true
                        return "☑️ Project is a single action list: " & originalLabel
                    else
                        return "❌ Unknown project type: " & newValue & ". Valid values: sequential, parallel, single_action"
                    end if

                else if propertyName is "review_interval" then
                    -- How often the project is reviewed
                    set intervalInfo to my parseReviewInterval(newValue)
                    if not (isValid of intervalInfo) then
                        return errorText of intervalInfo
                    end if
                    my setReviewInterval(targetProject, stepCount of intervalInfo, unitName of intervalInfo)
                    set intervalText to my reviewIntervalText(targetProject)
                    if intervalText is "" then set intervalText to newValue
                    set nextText to ""
                    try
                        set nextReview to next review date of targetProject
                        if nextReview is not missing value then set nextText to " (next review: " & (date string of nextReview) & ")"
                    end try
                    return "🔎 Review interval of project \"" & originalLabel & "\": " & intervalText & nextText

                else if propertyName is "next_review_date" or propertyName is "next_review" then
                    if newValue is "none" or newValue is "clear" then
                        -- OmniFocus derives the date again from the last review and the review interval
                        set next review date of targetProject to missing value
                        set nextReview to next review date of targetProject
                        if nextReview is missing value then
                            return "🔎 Next review of project \"" & originalLabel & "\" is derived from the review interval"
                        end if
                        return "🔎 Next review of project \"" & originalLabel & "\" is derived from the review interval: " & (date string of nextReview)
                    else
                        set parsedDate to my parseDate(newValue)
                        set next review date of targetProject to parsedDate
                        return "🔎 Next review of project \"" & originalLabel & "\" set to " & (parsedDate as string)
                    end if

                else if propertyName is "due_date" or propertyName is "due" then
                    if newValue is "none" or newValue is "clear" then
                        set due date of targetProject to missing value
                        return "✏️ Cleared due date for project: " & originalLabel
                    else
                        set parsedDate to my parseDate(newValue)
                        set due date of targetProject to parsedDate
                        return "✏️ Set due date to " & (parsedDate as string) & " for project: " & originalLabel
                    end if

                else if propertyName is "defer_date" or propertyName is "defer" then
                    if newValue is "none" or newValue is "clear" then
                        set defer date of targetProject to missing value
                        return "✏️ Cleared defer date for project: " & originalLabel
                    else
                        set parsedDate to my parseDate(newValue)
                        set defer date of targetProject to parsedDate
                        return "✏️ Set defer date to " & (parsedDate as string) & " for project: " & originalLabel
                    end if

                else if propertyName is "planned_date" or propertyName is "planned" then
                    if newValue is "none" or newValue is "clear" then
                        set planned date of targetProject to missing value
                        return "✏️ Cleared planned date for project: " & originalLabel
                    else
                        set parsedDate to my parseDate(newValue)
                        set planned date of targetProject to parsedDate
                        return "✏️ Set planned date to " & (parsedDate as string) & " for project: " & originalLabel
                    end if

                else if propertyName is "flagged" or propertyName is "flag" then
                    set flagValue to my parseFlag(newValue)
                    if flagValue is "" then return "❌ Invalid value for flagged: " & newValue & ". Use true or false."
                    if flagValue is "true" then
                        set flagged of targetProject to true
                        return "🚩 Flagged project: " & originalLabel
                    else
                        set flagged of targetProject to false
                        return "🏳️ Unflagged project: " & originalLabel
                    end if

                else if propertyName is "complete_with_last_item" or propertyName is "complete_with_last_action" then
                    -- The project is completed automatically when its last open task is completed
                    set flagValue to my parseFlag(newValue)
                    if flagValue is "" then return "❌ Invalid value for complete_with_last_item: " & newValue & ". Use true or false."
                    if flagValue is "true" then
                        set completed by children of targetProject to true
                        return "☑️ Project will complete with its last item: " & originalLabel
                    else
                        set completed by children of targetProject to false
                        return "☑️ Project no longer completes with its last item: " & originalLabel
                    end if

                else
                    return "❌ Unknown property: " & propertyName & ". Valid properties: name, note, append_note, folder, status, type, review_interval, next_review_date, due_date, defer_date, planned_date, flagged, complete_with_last_item, attach_file, link_file, remove_attachment"
                end if
            on error errMsg
                return "❌ Error updating project: " & errMsg
            end try
        end tell
    end tell
end run

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
    
    tell application "OmniFocus"
        tell default document
            set allProjects to every flattened project
        end tell
    end tell
    
    set exactMatches to {}
    set partialMatches to {}
    repeat with aProject in allProjects
        set candidateProject to contents of aProject
        tell application "OmniFocus" to set candidateName to name of candidateProject
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

on parseFlag(valueText)
    -- "true" or "false" for the usual spellings, "" for anything else
    ignoring case
        if valueText is "true" or valueText is "yes" or valueText is "1" then return "true"
        if valueText is "false" or valueText is "no" or valueText is "0" then return "false"
    end ignoring
    return ""
end parseFlag

on noteFormattingProblem(theItem)
    -- Returns "" when the note of a task or project can be rewritten as plain text without losing anything
    -- that matters, otherwise the reason. Attachments and formatting (bold, colors, fonts, ...) would be lost.
    -- Links are fine: OmniFocus makes them again from the text.
    set referenceSignature to missing value
    tell application "OmniFocus"
        try
            if (count of attachment of (note of theItem)) > 0 then
                return "The note contains attachments that would be lost."
            end if
            set runCount to count of attribute run of (note of theItem)
            if runCount > 1 then
                repeat with i from 1 to runCount
                    set runText to text of attribute run i of (note of theItem)
                    if runText does not contain "://" then
                        set runSignature to {font of attribute run i of (note of theItem), size of attribute run i of (note of theItem), color of attribute run i of (note of theItem), underlined of attribute run i of (note of theItem)}
                        if referenceSignature is missing value then
                            set referenceSignature to runSignature
                        else if runSignature is not referenceSignature then
                            return "The note contains formatting that would be lost."
                        end if
                    end if
                end repeat
            end if
        on error errMsg
            return "The formatting of the note could not be checked (" & errMsg & ")."
        end try
    end tell
    return ""
end noteFormattingProblem

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

on attachFileToNote(theItem, itemLabel, pathText, embedFile)
    -- Attaches a file at the end of the note of a task, project or folder and returns the message for the user.
    -- embedFile true: a copy of the file is stored in the OmniFocus database and synchronized to all devices.
    -- embedFile false: the note only links to the file, which has to stay where it is (it opens on this Mac only).
    -- Needs noteFormattingProblem in the same script.
    set filePath to my attachmentPath(pathText)
    if filePath is "" then
        return "❌ The path of the file is missing. Nothing was attached."
    end if
    if filePath does not start with "/" then
        return "❌ Give the full path of the file, starting with / or ~. Nothing was attached."
    end if
    set fileSize to 0
    try
        do shell script "/bin/test -f " & quoted form of filePath
        set fileSize to (do shell script "/usr/bin/stat -f %z " & quoted form of filePath) as number
    on error
        return "❌ The file does not exist, is a folder or cannot be read: " & filePath & ". Nothing was attached."
    end try
    set fileName to do shell script "/usr/bin/basename " & quoted form of filePath
    set theFile to POSIX file filePath

    set noteText to ""
    set attachmentsBefore to 0
    tell application "OmniFocus"
        try
            set noteText to (note of theItem) as text
            set attachmentsBefore to count of attachment of (note of theItem)
        on error errMsg
            return "❌ The note could not be read: " & errMsg
        end try
    end tell

    -- The attachment is added at the end of the note, in its own line as long as the note can be rewritten as plain text
    if noteText is not "" then
        set lastCharacter to last character of noteText
        if lastCharacter is not linefeed and lastCharacter is not return then
            if my noteFormattingProblem(theItem) is "" then
                tell application "OmniFocus" to set note of theItem to noteText & linefeed
            end if
        end if
    end if

    set attachmentsAfter to attachmentsBefore
    tell application "OmniFocus"
        try
            if noteText is "" then
                tell note of theItem
                    make new file attachment with properties {file name:theFile, embedded:embedFile}
                end tell
            else
                make new file attachment at after last character of (note of theItem) with properties {file name:theFile, embedded:embedFile}
            end if
            set attachmentsAfter to count of attachment of (note of theItem)
        on error errMsg
            return "❌ Could not attach the file: " & errMsg
        end try
    end tell
    if attachmentsAfter <= attachmentsBefore then
        return "❌ OmniFocus did not attach the file."
    end if
    set kindText to "embedded"
    if not embedFile then set kindText to "linked, stays where it is"
    return "📎 Attached " & fileName & " (" & my attachmentSizeText(fileSize) & ", " & kindText & ") to: " & itemLabel
end attachFileToNote

on removeAttachmentFromNote(theItem, itemLabel, numberText)
    -- Removes one attachment from the note, numbered as in the attachment list of get_task
    set attachmentNumber to 0
    try
        set attachmentNumber to numberText as integer
    end try
    if attachmentNumber < 1 then
        return "❌ remove_attachment needs the number of the attachment (1 is the first one, see get_task). Nothing was removed."
    end if
    set attachmentTotal to 0
    tell application "OmniFocus"
        try
            set attachmentTotal to count of file attachment of (note of theItem)
        on error errMsg
            return "❌ The note could not be read: " & errMsg
        end try
        if attachmentTotal = 0 then
            return "❌ The note has no attachments. Nothing was removed."
        end if
        if attachmentNumber > attachmentTotal then
            return "❌ The note has only " & attachmentTotal & " attachments. Nothing was removed."
        end if
        try
            delete (file attachment attachmentNumber of (note of theItem))
        on error errMsg
            return "❌ Could not remove the attachment: " & errMsg
        end try
    end tell
    return "🗑️ Removed attachment " & attachmentNumber & " from: " & itemLabel
end removeAttachmentFromNote

on attachmentPath(pathText)
    -- Removes spaces around the path and turns ~ into the home folder
    set cleaned to pathText
    set whitespaceChars to {" ", tab, linefeed, return}
    repeat
        if cleaned is "" then exit repeat
        if whitespaceChars does not contain (character 1 of cleaned) then exit repeat
        if (length of cleaned) = 1 then
            set cleaned to ""
        else
            set cleaned to text 2 thru -1 of cleaned
        end if
    end repeat
    repeat
        if cleaned is "" then exit repeat
        if whitespaceChars does not contain (last character of cleaned) then exit repeat
        if (length of cleaned) = 1 then
            set cleaned to ""
        else
            set cleaned to text 1 thru -2 of cleaned
        end if
    end repeat
    if cleaned is "~" or cleaned starts with "~/" then
        set homePath to POSIX path of (path to home folder)
        if cleaned is "~" or cleaned is "~/" then
            set cleaned to text 1 thru -2 of homePath
        else
            set cleaned to homePath & (text 3 thru -1 of cleaned)
        end if
    end if
    return cleaned
end attachmentPath

on attachmentSizeText(byteCount)
    -- "512 bytes", "12 KB", "3.4 MB"
    if byteCount < 1024 then return ((byteCount as integer) as text) & " bytes"
    if byteCount < 1048576 then return ((round (byteCount / 1024)) as text) & " KB"
    set tenths to round (byteCount / 104857.6)
    return ((tenths div 10) as text) & "." & ((tenths mod 10) as text) & " MB"
end attachmentSizeText
