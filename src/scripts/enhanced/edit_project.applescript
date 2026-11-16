on run argv
    -- Edit an existing project
    -- Usage: edit_project.applescript "project name or Folder > Project" "property" "new value"
    -- Properties: name, note, append_note, folder, status, type, review_interval, next_review_date,
    --             due_date, defer_date, planned_date, flagged, complete_with_last_item, floating_time_zone,
    --             tags, primary_tag, repeat, repeat_based_on, repeat_catch_up, attach_file, link_file, remove_attachment
    --   tags: comma-separated tags (name, path "Parent > Child" or "id:<id>"; missing tags are created) that replace all
    --     current tags, or "none" to remove all tags
    --   primary_tag: the first tag of the project (the other tags stay), or "none" to remove the first tag
    --   repeat: "weekly", "2 weeks", "every monday and thursday", "monthly on the 15th", "last friday of the month", ...
    --     or an iCalendar rule ("FREQ=WEEKLY;BYDAY=MO,TH"); add "fixed" for a fixed schedule or "from completion";
    --     "none" stops repeating. The project needs a due, defer or planned date.
    --   repeat_based_on: the date a repeating project is based on: "due", "defer" or "planned"
    --   repeat_catch_up: "true" = skip the occurrences in the past (fixed schedule only), "false" = do not
    --   attach_file: attaches the file with the given full path to the note (a copy is stored in OmniFocus)
    --   link_file: links the file with the given full path in the note (the file stays where it is)
    --   remove_attachment: removes the attachment with the given number (1 is the first one, see get_project)
    --   review_interval: "1 week", "2 weeks", "1 month", "1 year", "weekly", ...
    --     (OmniFocus has no "no review" setting; to keep a project out of the reviews, set next_review_date far ahead)
    --   next_review_date: a date, or "none" to derive it again from the last review and the interval
    --   due_date, defer_date, planned_date: a date, or "none" to clear it
    --   flagged, complete_with_last_item: true or false
    --   floating_time_zone: "true" = due and defer date keep their clock time in every time zone, "false" = fixed time zone
    
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
                        if parsedDate is missing value then return my dateErrorText(newValue, "next_review_date") & " Nothing was changed."
                        set next review date of targetProject to parsedDate
                        return "🔎 Next review of project \"" & originalLabel & "\" set to " & (parsedDate as string)
                    end if

                else if propertyName is "due_date" or propertyName is "due" then
                    if newValue is "none" or newValue is "clear" then
                        set due date of targetProject to missing value
                        return "✏️ Cleared due date for project: " & originalLabel
                    else
                        set parsedDate to my parseDate(newValue)
                        if parsedDate is missing value then return my dateErrorText(newValue, "due_date") & " Nothing was changed."
                        set due date of targetProject to parsedDate
                        return "✏️ Set due date to " & (parsedDate as string) & " for project: " & originalLabel
                    end if

                else if propertyName is "defer_date" or propertyName is "defer" then
                    if newValue is "none" or newValue is "clear" then
                        set defer date of targetProject to missing value
                        return "✏️ Cleared defer date for project: " & originalLabel
                    else
                        set parsedDate to my parseDate(newValue)
                        if parsedDate is missing value then return my dateErrorText(newValue, "defer_date") & " Nothing was changed."
                        set defer date of targetProject to parsedDate
                        return "✏️ Set defer date to " & (parsedDate as string) & " for project: " & originalLabel
                    end if

                else if propertyName is "planned_date" or propertyName is "planned" then
                    if newValue is "none" or newValue is "clear" then
                        set planned date of targetProject to missing value
                        return "✏️ Cleared planned date for project: " & originalLabel
                    else
                        set parsedDate to my parseDate(newValue)
                        if parsedDate is missing value then return my dateErrorText(newValue, "planned_date") & " Nothing was changed."
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

                else if propertyName is "floating_time_zone" or propertyName is "floating" then
                    -- Due and defer date keep their clock time in every time zone
                    set flagValue to my parseFlag(newValue)
                    if flagValue is "" then return "❌ Invalid value for floating_time_zone: " & newValue & ". Use true or false. Nothing was changed."
                    set should use floating time zone of targetProject to (flagValue is "true")
                    set hintText to ""
                    if (due date of targetProject) is missing value and (defer date of targetProject) is missing value then
                        set hintText to " (the project has no due or defer date, so OmniFocus keeps the default of the database until it has one)"
                    end if
                    if flagValue is "true" then
                        return "🌍 Due and defer date keep their clock time in every time zone: " & originalLabel & hintText
                    else
                        return "📍 Due and defer date use a fixed time zone: " & originalLabel & hintText
                    end if

                else if propertyName is "tags" then
                    -- Replace all tags with the new comma-separated list; "none" or "clear" removes all tags
                    return my setItemTags(targetProject, "project", originalLabel, newValue)

                else if propertyName is "primary_tag" then
                    -- The first tag of the project; the other tags stay, "none" removes the first tag
                    return my setItemPrimaryTag(targetProject, "project", originalLabel, newValue)

                else if propertyName is "repeat" or propertyName is "repetition" then
                    return my setRepetition(targetProject, "project", originalLabel, newValue)

                else if propertyName is "repeat_based_on" then
                    return my changeRepetition(targetProject, "project", originalLabel, "based_on", newValue)

                else if propertyName is "repeat_catch_up" then
                    return my changeRepetition(targetProject, "project", originalLabel, "catch_up", newValue)

                else
                    return "❌ Unknown property: " & propertyName & ". Valid properties: name, note, append_note, folder, status, type, review_interval, next_review_date, due_date, defer_date, planned_date, flagged, complete_with_last_item, floating_time_zone, tags, primary_tag, repeat, repeat_based_on, repeat_catch_up, attach_file, link_file, remove_attachment"
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

on parseReviewInterval(valueText)
    -- Reads a review interval: "2 weeks", "1 month", "every 2 weeks", "week", "weekly".
    -- Units: day, week, month, year (plural allowed). OmniFocus has no "no review" setting.
    -- Returns {isValid, stepCount, unitName, errorText}
    set cleanText to my lowerText(my trimItem(valueText))
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
        if not my isDateDigits(item 1 of wordList) or (length of (item 1 of wordList)) > 6 then return {isValid:false, stepCount:0, unitName:"", errorText:problemText}
        set stepCount to (item 1 of wordList) as integer
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
    -- Only whole numbers: a text like 1.5 would be rounded by the coercion (or fail, depending on the region)
    set numberClean to my trimItem(numberText)
    if my isDigits(numberClean) and (length of numberClean) < 6 then set attachmentNumber to numberClean as integer
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

on describeRecurrence(recurrenceText)
    -- "FREQ=WEEKLY;INTERVAL=2" becomes "every 2 weeks", "FREQ=WEEKLY;BYDAY=MO,TH" becomes "every week on Monday and Thursday",
    -- "FREQ=MONTHLY;BYDAY=-1FR" becomes "every month on the last Friday"; rules with other parts are returned unchanged
    set cleanText to recurrenceText
    if cleanText starts with "RRULE:" then set cleanText to text 7 thru -1 of cleanText
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ";"
    set partList to text items of cleanText
    set AppleScript's text item delimiters to oldDelims

    set frequencyText to ""
    set stepCount to 1
    set dayText to ""
    set monthDayText to ""
    set setPositionText to ""
    repeat with aPart in partList
        set partText to aPart as text
        if partText starts with "FREQ=" then
            set frequencyText to text 6 thru -1 of partText
        else if partText starts with "INTERVAL=" then
            try
                set stepCount to (text 10 thru -1 of partText) as integer
            on error
                return recurrenceText
            end try
        else if partText starts with "BYDAY=" then
            set dayText to text 7 thru -1 of partText
        else if partText starts with "BYMONTHDAY=" then
            set monthDayText to text 12 thru -1 of partText
        else if partText starts with "BYSETPOS=" then
            set setPositionText to text 10 thru -1 of partText
        else
            return recurrenceText
        end if
    end repeat

    set unitName to ""
    if frequencyText is "DAILY" then set unitName to "day"
    if frequencyText is "WEEKLY" then set unitName to "week"
    if frequencyText is "MONTHLY" then set unitName to "month"
    if frequencyText is "YEARLY" then set unitName to "year"
    if unitName is "" or stepCount < 1 then return recurrenceText
    if stepCount is 1 then
        set baseText to "every " & unitName
    else
        set baseText to "every " & stepCount & " " & unitName & "s"
    end if
    if dayText is "" and monthDayText is "" and setPositionText is "" then return baseText

    if frequencyText is "WEEKLY" and dayText is not "" and monthDayText is "" and setPositionText is "" then
        if dayText is "MO,TU,WE,TH,FR" and stepCount is 1 then return "every weekday"
        set dayNames to {}
        set oldDelims to AppleScript's text item delimiters
        set AppleScript's text item delimiters to ","
        set codeList to text items of dayText
        set AppleScript's text item delimiters to oldDelims
        repeat with aCode in codeList
            set dayName to my weekdayName(aCode as text)
            if dayName is "" then return recurrenceText
            set end of dayNames to dayName
        end repeat
        return baseText & " on " & my joinNames(dayNames)
    end if

    if frequencyText is "MONTHLY" and monthDayText is not "" and dayText is "" and setPositionText is "" then
        if monthDayText is "-1" then return baseText & " on the last day"
        if my isDigits(monthDayText) then return baseText & " on day " & monthDayText
        return recurrenceText
    end if

    if frequencyText is "MONTHLY" and dayText is not "" and monthDayText is "" then
        -- "1MO" or "-1FR", or a weekday with BYSETPOS
        set positionText to setPositionText
        set codeText to dayText
        if positionText is "" and (length of dayText) > 2 then
            set positionText to text 1 thru -3 of dayText
            set codeText to text -2 thru -1 of dayText
        end if
        set dayName to my weekdayName(codeText)
        set ordinalWord to my ordinalName(positionText)
        if dayName is "" or ordinalWord is "" then return recurrenceText
        return baseText & " on the " & ordinalWord & " " & dayName
    end if
    return recurrenceText
end describeRecurrence

on weekdayName(codeText)
    if codeText is "MO" then return "Monday"
    if codeText is "TU" then return "Tuesday"
    if codeText is "WE" then return "Wednesday"
    if codeText is "TH" then return "Thursday"
    if codeText is "FR" then return "Friday"
    if codeText is "SA" then return "Saturday"
    if codeText is "SU" then return "Sunday"
    return ""
end weekdayName

on ordinalName(positionText)
    if positionText is "1" or positionText is "+1" then return "first"
    if positionText is "2" or positionText is "+2" then return "second"
    if positionText is "3" or positionText is "+3" then return "third"
    if positionText is "4" or positionText is "+4" then return "fourth"
    if positionText is "5" or positionText is "+5" then return "fifth"
    if positionText is "-1" then return "last"
    return ""
end ordinalName

on joinNames(nameList)
    -- "Monday", "Monday and Thursday", "Monday, Tuesday and Friday"
    set nameCount to count of nameList
    if nameCount = 1 then return item 1 of nameList
    set headText to my joinText(items 1 thru (nameCount - 1) of nameList, ", ")
    return headText & " and " & (item nameCount of nameList)
end joinNames

on isDigits(theText)
    -- True if the text is not empty and has only the digits 0 to 9
    if theText is "" then return false
    repeat with aChar in characters of theText
        if "0123456789" does not contain (contents of aChar) then return false
    end repeat
    return true
end isDigits

on readRepetition(theItem)
    -- The repetition of a task or project as {ruleExists, ruleRecurrence, ruleSchedule, ruleBasedOn, ruleCatchUp}
    --   ruleSchedule is "regularly" or "from completion", ruleBasedOn is "due", "defer" or "planned"
    set recurrenceText to ""
    set scheduleName to "from completion"
    set basedOnName to "due"
    set catchValue to false
    tell application "OmniFocus"
        try
            set theRule to repetition rule of theItem
        on error
            return {ruleExists:false, ruleRecurrence:"", ruleSchedule:"", ruleBasedOn:"", ruleCatchUp:false}
        end try
        if theRule is missing value then return {ruleExists:false, ruleRecurrence:"", ruleSchedule:"", ruleBasedOn:"", ruleCatchUp:false}
        try
            set recurrenceText to recurrence of theRule
        end try
        set readSchedule to false
        try
            set scheduleText to (repetition schedule of theRule) as text
            if scheduleText contains "completion" then
                set scheduleName to "from completion"
            else
                set scheduleName to "regularly"
            end if
            set basedOnText to (repetition based on of theRule) as text
            if basedOnText contains "defer" then
                set basedOnName to "defer"
            else if basedOnText contains "planned" then
                set basedOnName to "planned"
            else
                set basedOnName to "due"
            end if
            set readSchedule to true
        end try
        if not readSchedule then
            -- the older way: a repetition method
            try
                set methodText to (repetition method of theRule) as text
                if methodText contains "fixed" then
                    set scheduleName to "regularly"
                else if methodText contains "start" then
                    set basedOnName to "defer"
                end if
            end try
        end if
        try
            set catchValue to catch up automatically of theRule
        end try
    end tell
    return {ruleExists:true, ruleRecurrence:recurrenceText, ruleSchedule:scheduleName, ruleBasedOn:basedOnName, ruleCatchUp:catchValue}
end readRepetition

on repetitionText(theItem)
    -- Describes how a task or project repeats, for example "every 2 weeks, due date after completion" or
    -- "every week on Monday and Thursday, fixed schedule"; "" if it does not repeat
    set ruleInfo to my readRepetition(theItem)
    if not (ruleExists of ruleInfo) then return ""
    set resultText to "repeats"
    if (ruleRecurrence of ruleInfo) is not "" then set resultText to my describeRecurrence(ruleRecurrence of ruleInfo)
    set basedOnName to ruleBasedOn of ruleInfo
    if (ruleSchedule of ruleInfo) is "regularly" then
        set resultText to resultText & ", fixed schedule"
        if basedOnName is not "due" then set resultText to resultText & ", based on the " & basedOnName & " date"
        if ruleCatchUp of ruleInfo then set resultText to resultText & ", catches up automatically"
    else
        set resultText to resultText & ", " & basedOnName & " date after completion"
    end if
    return resultText
end repetitionText

on splitTagPath(queryText)
    -- Splits "Parent > Child" into trimmed, non-empty parts
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ">"
    set rawParts to text items of queryText
    set AppleScript's text item delimiters to oldDelims

    set queryParts to {}
    repeat with rawPart in rawParts
        set cleanPart to my trimItem(rawPart as string)
        if cleanPart is not "" then set end of queryParts to cleanPart
    end repeat
    return queryParts
end splitTagPath

on resolveTag(queryText, allowPartial)
    -- Finds a tag at any level of the tag hierarchy.
    --   queryText:    tag name, path "Parent > Child" or "id:<id>"
    --   allowPartial: also accept a part of a name, but only if no exact name fits and exactly one tag contains it
    -- Names are compared ignoring case.
    -- Returns {foundTag, errorText, notFound}; foundTag is missing value if no tag or more than one tag fits,
    -- notFound is true only if nothing fits by name or path.
    if queryText starts with "id:" and (length of queryText) > 3 then
        set wantedID to my trimItem(text 4 thru -1 of queryText)
        tell application "OmniFocus"
            tell default document
                set idMatches to every flattened tag whose id is wantedID
            end tell
        end tell
        if (count of idMatches) = 1 then
            return {foundTag:item 1 of idMatches, errorText:"", notFound:false}
        end if
        return {foundTag:missing value, errorText:"❌ Tag not found: " & queryText, notFound:false}
    end if

    set queryParts to my splitTagPath(queryText)
    if (count of queryParts) = 0 then
        return {foundTag:missing value, errorText:"❌ Tag name cannot be empty.", notFound:false}
    end if

    set nameQuery to item -1 of queryParts
    set parentQuery to {}
    if (count of queryParts) > 1 then set parentQuery to items 1 thru -2 of queryParts

    tell application "OmniFocus"
        tell default document
            set allTags to every flattened tag
        end tell
    end tell

    set exactMatches to {}
    set partialMatches to {}
    repeat with aTag in allTags
        set candidateTag to contents of aTag
        tell application "OmniFocus" to set candidateName to name of candidateTag
        ignoring case
            if candidateName is nameQuery then
                set end of exactMatches to candidateTag
            else if allowPartial and candidateName contains nameQuery then
                set end of partialMatches to candidateTag
            end if
        end ignoring
    end repeat

    if (count of parentQuery) > 0 then
        set exactMatches to my filterByParents(exactMatches, parentQuery, not allowPartial)
        set partialMatches to my filterByParents(partialMatches, parentQuery, not allowPartial)
    end if

    -- A single exact name wins; otherwise every match counts and must be unique
    if (count of exactMatches) = 1 then
        return {foundTag:item 1 of exactMatches, errorText:"", notFound:false}
    end if
    set allMatches to exactMatches & partialMatches
    if (count of allMatches) = 1 then
        return {foundTag:item 1 of allMatches, errorText:"", notFound:false}
    end if
    if (count of allMatches) = 0 then
        return {foundTag:missing value, errorText:"❌ Tag not found: " & queryText, notFound:true}
    end if

    set matchList to "❌ Ambiguous tag \"" & queryText & "\" (" & (count of allMatches) & " matches). Use \"Parent > Tag\" or id:<id> to pick one:"
    repeat with aMatch in allMatches
        set matchTag to contents of aMatch
        tell application "OmniFocus" to set matchID to id of matchTag
        set matchList to matchList & return & "• " & my joinText(my tagPathNames(matchTag), " > ") & " [id:" & matchID & "]"
    end repeat
    return {foundTag:missing value, errorText:matchList, notFound:false}
end resolveTag

on filterByParents(tagList, parentQuery, exactParents)
    -- Keeps the tags whose closest parent tags match parentQuery (outermost first).
    -- exactParents: parent names must be equal, otherwise a part of the name is enough.
    set keptTags to {}
    repeat with aTag in tagList
        set candidateTag to contents of aTag
        set pathNames to my tagPathNames(candidateTag)
        set ancestorCount to (count of pathNames) - 1
        set queryCount to count of parentQuery
        set parentsFit to (queryCount ≤ ancestorCount)
        if parentsFit then
            ignoring case
                repeat with i from 1 to queryCount
                    set wantedName to item i of parentQuery
                    set actualName to item (ancestorCount - queryCount + i) of pathNames
                    if exactParents then
                        if actualName is not wantedName then set parentsFit to false
                    else
                        if actualName does not contain wantedName then set parentsFit to false
                    end if
                end repeat
            end ignoring
        end if
        if parentsFit then set end of keptTags to candidateTag
    end repeat
    return keptTags
end filterByParents

on tagPathNames(aTag)
    -- Tag names from the outermost parent tag down to the tag itself
    set pathNames to {}
    tell application "OmniFocus"
        try
            set currentTag to aTag
            repeat while currentTag is not missing value
                set beginning of pathNames to name of currentTag
                set parentContainer to container of currentTag
                if class of parentContainer is tag then
                    set currentTag to parentContainer
                else
                    set currentTag to missing value
                end if
            end repeat
        end try
    end tell
    return pathNames
end tagPathNames

on findOrCreateTag(queryText)
    -- Finds a tag by exact name, path "Parent > Child" or "id:<id>" and creates it if it does not exist
    -- (at top level, or below the parent tag if a path was given). Never creates a tag for an id.
    -- Returns {foundTag, errorText, wasCreated}
    set lookup to my resolveTag(queryText, false)
    set lookedUpTag to foundTag of lookup
    if lookedUpTag is not missing value then
        return {foundTag:lookedUpTag, errorText:"", wasCreated:false}
    end if
    if not (notFound of lookup) then
        return {foundTag:missing value, errorText:errorText of lookup, wasCreated:false}
    end if

    set queryParts to my splitTagPath(queryText)
    set newName to item -1 of queryParts
    set parentTag to missing value
    if (count of queryParts) > 1 then
        set parentLookup to my resolveTag(my joinText(items 1 thru -2 of queryParts, " > "), false)
        set parentTag to foundTag of parentLookup
        if parentTag is missing value then
            return {foundTag:missing value, errorText:errorText of parentLookup, wasCreated:false}
        end if
    end if

    try
        tell application "OmniFocus"
            tell default document
                if parentTag is missing value then
                    set newTag to make new tag with properties {name:newName}
                else
                    set newTag to make new tag with properties {name:newName} at end of tags of parentTag
                end if
            end tell
        end tell
    on error errMsg
        return {foundTag:missing value, errorText:"❌ Error creating tag: " & errMsg, wasCreated:false}
    end try
    return {foundTag:newTag, errorText:"", wasCreated:true}
end findOrCreateTag

on hasTagNamed(parentTag, wantedName, excludeID)
    -- Is there a tag called wantedName directly below parentTag (missing value = top level),
    -- other than the tag with the id excludeID? Names are compared ignoring case.
    tell application "OmniFocus"
        tell default document
            if parentTag is missing value then
                set siblingTags to every tag
            else
                set siblingTags to every tag of parentTag
            end if
            repeat with aTag in siblingTags
                set siblingTag to contents of aTag
                if (id of siblingTag) is not excludeID then
                    ignoring case
                        if (name of siblingTag) is wantedName then return true
                    end ignoring
                end if
            end repeat
        end tell
    end tell
    return false
end hasTagNamed

on joinText(textItems, separator)
    -- Joins a list of text items with a separator
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to separator
    set joinedText to textItems as text
    set AppleScript's text item delimiters to oldDelims
    return joinedText
end joinText

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

on resolveTagList(listText)
    -- Finds (or creates) the tags of a comma-separated list: name, path "Parent > Child" or id:<id>.
    -- Returns {tagObjects, namesText, errorText}; errorText is "" if every tag was found.
    set originalDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ","
    set tagList to text items of listText
    set AppleScript's text item delimiters to originalDelims
    set resolvedTags to {}
    set namesText to ""
    repeat with tagItem in tagList
        set tagName to my trimItem(tagItem as string)
        if tagName is not "" then
            set tagLookup to my findOrCreateTag(tagName)
            set theTag to foundTag of tagLookup
            if theTag is missing value then
                return {tagObjects:resolvedTags, namesText:namesText, errorText:(errorText of tagLookup)}
            end if
            set end of resolvedTags to theTag
            if namesText is "" then
                set namesText to tagName
            else
                set namesText to namesText & ", " & tagName
            end if
        end if
    end repeat
    return {tagObjects:resolvedTags, namesText:namesText, errorText:""}
end resolveTagList

on tagNameList(theItem)
    -- The names of the tags of a task or project in their order, "none" without tags
    tell application "OmniFocus" to set tagNames to name of every tag of theItem
    if (count of tagNames) = 0 then return "none"
    return my joinText(tagNames, ", ")
end tagNameList

on setItemTags(theItem, itemWord, itemLabel, newValue)
    -- Replaces all tags of a task or project (itemWord "task" or "project"); "none" removes all of them
    set forText to "for: "
    if itemWord is "project" then set forText to "for project: "
    if newValue is "none" or newValue is "clear" then
        tell application "OmniFocus"
            set existingTags to tags of theItem
            repeat with existingTag in existingTags
                remove existingTag from tags of theItem
            end repeat
        end tell
        return "🏷️ Cleared all tags " & forText & itemLabel
    end if
    -- Find all tags first, so that a failed lookup leaves the item unchanged
    set tagInfo to my resolveTagList(newValue)
    if (errorText of tagInfo) is not "" then return (errorText of tagInfo) & return & "Tags were not changed."
    if (count of tagObjects of tagInfo) = 0 then return "❌ No tag name given. Use \"none\" to remove all tags. Tags were not changed."
    tell application "OmniFocus"
        set existingTags to tags of theItem
        repeat with existingTag in existingTags
            remove existingTag from tags of theItem
        end repeat
        repeat with resolvedTag in (tagObjects of tagInfo)
            add (contents of resolvedTag) to tags of theItem
        end repeat
    end tell
    return "🏷️ Set tags to [" & (namesText of tagInfo) & "] " & forText & itemLabel
end setItemTags

on setItemPrimaryTag(theItem, itemWord, itemLabel, newValue)
    -- Makes a tag the first tag of a task or project; the other tags stay. "none" removes the first tag.
    if newValue is "none" or newValue is "clear" then
        set currentPrimary to missing value
        set primaryName to ""
        tell application "OmniFocus"
            try
                set currentPrimary to primary tag of theItem
            end try
            if currentPrimary is not missing value then
                set primaryName to name of currentPrimary
                set primary tag of theItem to missing value
            end if
        end tell
        if currentPrimary is missing value then return "ℹ️ The " & itemWord & " has no tags: " & itemLabel
        return "🏷️ Removed the primary tag \"" & primaryName & "\" from: " & itemLabel & ". The other tags stay (tags now: " & my tagNameList(theItem) & ")."
    end if
    set tagLookup to my findOrCreateTag(my trimItem(newValue))
    set theTag to foundTag of tagLookup
    if theTag is missing value then
        return (errorText of tagLookup) & return & "Nothing was changed."
    end if
    -- OmniFocus removes the current first tag when a new first tag is set, so the old tags are added again behind it
    tell application "OmniFocus"
        tell default document
            set oldTagIDs to id of every tag of theItem
            set primary tag of theItem to theTag
            set tagIDsNow to id of every tag of theItem
            repeat with oldTagID in oldTagIDs
                if tagIDsNow does not contain (contents of oldTagID) then
                    set oldTagMatches to every flattened tag whose id is (contents of oldTagID)
                    if (count of oldTagMatches) > 0 then add (item 1 of oldTagMatches) to tags of theItem
                end if
            end repeat
        end tell
        set newName to name of theTag
    end tell
    return "🏷️ Primary tag of \"" & itemLabel & "\" is now " & newName & " (tags: " & my tagNameList(theItem) & ")"
end setItemPrimaryTag

on parseRepeatRule(ruleText)
    -- Reads a repeat rule and returns {isValid, ruleString, scheduleName, errorText}.
    --   ruleString is an iCalendar string such as FREQ=WEEKLY;INTERVAL=2 or FREQ=MONTHLY;BYDAY=-1FR
    --   scheduleName is "regularly" (fixed schedule) or "from completion"
    -- Rules in words: "daily", "weekly", "monthly", "yearly", "3 days", "2 weeks", "every 2 weeks",
    --   "every monday", "monday and thursday", "weekdays", "every 2 weeks on monday",
    --   "monthly on the 15th", "monthly on day 15", "last day of the month",
    --   "first monday of the month", "last friday of the month", "every 3 months on the 2nd tuesday".
    -- An iCalendar rule is accepted as well: "FREQ=WEEKLY;BYDAY=MO,TH".
    -- At the end: "fixed" (fixed schedule) or "from completion". Without it, a rule that only has an interval
    -- follows the completion, a rule with weekdays or days of the month follows the calendar.
    set problemText to "❌ Invalid repeat: " & ruleText & ". Use for example \"daily\", \"weekly\", \"2 weeks\", \"every monday and thursday\", \"weekdays\", \"monthly on the 15th\", \"last friday of the month\", \"first monday of the month\" or an iCalendar rule like \"FREQ=WEEKLY;BYDAY=MO,TH\". Add \"fixed\" for a fixed schedule (\"weekly fixed\") or \"from completion\", or use \"none\" to stop repeating."
    set invalidResult to {isValid:false, ruleString:"", scheduleName:"", errorText:problemText}
    set cleanText to my trimItem(ruleText)
    if cleanText is "" then return invalidResult
    -- Words are compared in lower case: the system comparison of "I" and "i" depends on the region (Turkish)
    if cleanText does not contain "=" then set cleanText to my lowerText(cleanText)

    -- "fixed" or "from completion" at the end
    set scheduleName to ""
    if cleanText ends with " fixed" then
        set scheduleName to "regularly"
        set cleanText to my trimItem(text 1 thru -7 of cleanText)
    else if cleanText ends with " from completion" then
        set scheduleName to "from completion"
        set cleanText to my trimItem(text 1 thru -17 of cleanText)
    else if cleanText ends with " after completion" then
        set scheduleName to "from completion"
        set cleanText to my trimItem(text 1 thru -18 of cleanText)
    end if
    if cleanText is "" then return invalidResult

    -- An iCalendar rule
    if cleanText contains "=" then
        set rawText to my upperText(cleanText)
        set rawText to my removeText(rawText, " ")
        if rawText starts with "RRULE:" then set rawText to text 7 thru -1 of rawText
        repeat while (length of rawText) > 0 and rawText ends with ";"
            if (length of rawText) = 1 then
                set rawText to ""
            else
                set rawText to text 1 thru -2 of rawText
            end if
        end repeat
        if not (rawText starts with "FREQ=") then return invalidResult
        if rawText contains ";;" then return invalidResult
        set allowedChars to "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789=;,+-"
        repeat with aChar in characters of rawText
            if allowedChars does not contain (contents of aChar) then return invalidResult
        end repeat
        if scheduleName is "" then
            set scheduleName to "from completion"
            if rawText contains "BYDAY" or rawText contains "BYMONTHDAY" or rawText contains "BYSETPOS" then set scheduleName to "regularly"
        end if
        return {isValid:true, ruleString:rawText, scheduleName:scheduleName, errorText:""}
    end if

    -- A rule in words
    set tokenList to words of cleanText
    set intervalCount to 0
    set unitFound to ""
    set weekdayCodes to {}
    set ordinalFound to 0
    set hasOrdinal to false
    set dayNumber to 0
    set lastDayFlag to false
    set otherFlag to false
    set skipNext to false
    set tokenCount to count of tokenList
    repeat with i from 1 to tokenCount
        if skipNext then
            set skipNext to false
        else
            set tokenText to item i of tokenList
            set nextText to ""
            if i < tokenCount then set nextText to item (i + 1) of tokenList
            set previousText to ""
            if i > 1 then set previousText to item (i - 1) of tokenList
            ignoring case
                if tokenText is "every" or tokenText is "each" or tokenText is "on" or tokenText is "the" or tokenText is "of" or tokenText is "and" or tokenText is "at" or tokenText is "in" or tokenText is "a" or tokenText is "an" then
                    -- filler words
                else if tokenText is "other" then
                    set otherFlag to true
                else if tokenText is "weekday" or tokenText is "weekdays" then
                    repeat with dayCode in {"MO", "TU", "WE", "TH", "FR"}
                        if weekdayCodes does not contain (contents of dayCode) then set end of weekdayCodes to (contents of dayCode)
                    end repeat
                else if tokenText is "weekend" or tokenText is "weekends" then
                    repeat with dayCode in {"SA", "SU"}
                        if weekdayCodes does not contain (contents of dayCode) then set end of weekdayCodes to (contents of dayCode)
                    end repeat
                else if my weekdayCode(tokenText) is not "" then
                    set foundCode to my weekdayCode(tokenText)
                    if weekdayCodes does not contain foundCode then set end of weekdayCodes to foundCode
                else if tokenText is "day" and previousText is "last" then
                    set lastDayFlag to true
                else if tokenText is "day" and my isDigits(nextText) and (length of nextText) < 3 then
                    set dayNumber to nextText as integer
                    set skipNext to true
                else if my unitCode(tokenText) is not "" then
                    set foundUnit to my unitCode(tokenText)
                    if unitFound is not "" and unitFound is not foundUnit then return invalidResult
                    set unitFound to foundUnit
                else if my isDigits(tokenText) then
                    if my unitCode(nextText) is "" or (length of tokenText) > 6 then return invalidResult
                    set intervalCount to tokenText as integer
                    if intervalCount < 1 then return invalidResult
                else if my ordinalValue(tokenText) is not 0 then
                    set ordinalFound to my ordinalValue(tokenText)
                    set hasOrdinal to true
                else
                    return invalidResult
                end if
            end ignoring
        end if
    end repeat
    if otherFlag and intervalCount = 0 then set intervalCount to 2
    if intervalCount > 999 then return invalidResult

    set frequencyText to ""
    set extraPart to ""
    if (count of weekdayCodes) > 0 then
        if hasOrdinal then
            -- the first, second, ... or last weekday of the month
            if (count of weekdayCodes) is not 1 then return invalidResult
            if unitFound is not "" and unitFound is not "MONTHLY" then return invalidResult
            if not (ordinalFound is -1 or (ordinalFound ≥ 1 and ordinalFound ≤ 5)) then return invalidResult
            set frequencyText to "MONTHLY"
            set extraPart to "BYDAY=" & my plainNumberText(ordinalFound) & (item 1 of weekdayCodes)
        else
            if unitFound is not "" and unitFound is not "WEEKLY" then return invalidResult
            set frequencyText to "WEEKLY"
            set extraPart to "BYDAY=" & my joinText(weekdayCodes, ",")
        end if
    else if lastDayFlag then
        if unitFound is not "" and unitFound is not "MONTHLY" then return invalidResult
        set frequencyText to "MONTHLY"
        set extraPart to "BYMONTHDAY=-1"
    else if dayNumber > 0 or hasOrdinal then
        -- a day of the month: "monthly on the 15th", "monthly on day 15"
        if unitFound is not "MONTHLY" then return invalidResult
        if dayNumber = 0 then set dayNumber to ordinalFound
        if not (dayNumber is -1 or (dayNumber ≥ 1 and dayNumber ≤ 31)) then return invalidResult
        set frequencyText to "MONTHLY"
        set extraPart to "BYMONTHDAY=" & my plainNumberText(dayNumber)
    else
        if unitFound is "" then return invalidResult
        set frequencyText to unitFound
    end if

    set recurrenceText to "FREQ=" & frequencyText
    if intervalCount > 1 then set recurrenceText to recurrenceText & ";INTERVAL=" & my plainNumberText(intervalCount)
    if extraPart is not "" then set recurrenceText to recurrenceText & ";" & extraPart
    if scheduleName is "" then
        set scheduleName to "from completion"
        if extraPart is not "" then set scheduleName to "regularly"
    end if
    return {isValid:true, ruleString:recurrenceText, scheduleName:scheduleName, errorText:""}
end parseRepeatRule

on weekdayCode(wordText)
    -- "monday", "mondays", "mon" become "MO", and so on; "" for any other word
    set cleanWord to wordText
    ignoring case
        if cleanWord ends with "days" and (length of cleanWord) > 4 then set cleanWord to text 1 thru -2 of cleanWord
        if cleanWord is "monday" or cleanWord is "mon" then return "MO"
        if cleanWord is "tuesday" or cleanWord is "tue" or cleanWord is "tues" then return "TU"
        if cleanWord is "wednesday" or cleanWord is "wed" then return "WE"
        if cleanWord is "thursday" or cleanWord is "thu" or cleanWord is "thur" or cleanWord is "thurs" then return "TH"
        if cleanWord is "friday" or cleanWord is "fri" then return "FR"
        if cleanWord is "saturday" or cleanWord is "sat" then return "SA"
        if cleanWord is "sunday" or cleanWord is "sun" then return "SU"
    end ignoring
    return ""
end weekdayCode

on unitCode(wordText)
    -- "day", "days", "daily" become "DAILY", and so on; "" for any other word
    ignoring case
        if wordText is "day" or wordText is "days" or wordText is "daily" then return "DAILY"
        if wordText is "week" or wordText is "weeks" or wordText is "weekly" then return "WEEKLY"
        if wordText is "month" or wordText is "months" or wordText is "monthly" then return "MONTHLY"
        if wordText is "year" or wordText is "years" or wordText is "yearly" or wordText is "annually" then return "YEARLY"
    end ignoring
    return ""
end unitCode

on ordinalValue(wordText)
    -- "first" is 1 ... "fifth" is 5, "last" is -1, "15th" is 15; 0 for any other word
    ignoring case
        if wordText is "first" then return 1
        if wordText is "second" then return 2
        if wordText is "third" then return 3
        if wordText is "fourth" then return 4
        if wordText is "fifth" then return 5
        if wordText is "last" then return -1
        if (length of wordText) > 2 then
            set suffixText to text -2 thru -1 of wordText
            if suffixText is "st" or suffixText is "nd" or suffixText is "rd" or suffixText is "th" then
                set numberPart to text 1 thru -3 of wordText
                if my isDigits(numberPart) and (length of numberPart) < 3 then return numberPart as integer
            end if
        end if
    end ignoring
    return 0
end ordinalValue

on upperText(theText)
    set resultText to ""
    repeat with aChar in characters of theText
        set theChar to contents of aChar
        set codeValue to id of theChar
        if codeValue ≥ 97 and codeValue ≤ 122 then
            set resultText to resultText & (character id (codeValue - 32))
        else
            set resultText to resultText & theChar
        end if
    end repeat
    return resultText
end upperText

on removeText(theText, unwantedText)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to unwantedText
    set partList to text items of theText
    set AppleScript's text item delimiters to ""
    set resultText to partList as text
    set AppleScript's text item delimiters to oldDelims
    return resultText
end removeText

on hasRepetitionDate(theItem, basedOnName)
    -- True if the task or project has the date a repetition is based on: "due", "defer" or "planned"
    tell application "OmniFocus"
        try
            if basedOnName is "due" then return ((due date of theItem) is not missing value)
            if basedOnName is "defer" then return ((defer date of theItem) is not missing value)
            if basedOnName is "planned" then return ((planned date of theItem) is not missing value)
        end try
    end tell
    return false
end hasRepetitionDate

on defaultBasedOn(theItem)
    -- The date a new repetition is based on: the due date, else the defer date, else the planned date; "" if there is none
    if my hasRepetitionDate(theItem, "due") then return "due"
    if my hasRepetitionDate(theItem, "defer") then return "defer"
    if my hasRepetitionDate(theItem, "planned") then return "planned"
    return ""
end defaultBasedOn

on applyRepetition(theItem, recurrenceText, scheduleName, basedOnName, catchValue)
    -- Sets the repetition rule of a task or project. Returns "" or the text of an error (nothing is changed then).
    tell application "OmniFocus"
        try
            if scheduleName is "regularly" then
                if basedOnName is "defer" then
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:regularly, repetition based on:based on defer, catch up automatically:catchValue}
                else if basedOnName is "planned" then
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:regularly, repetition based on:based on planned, catch up automatically:catchValue}
                else
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:regularly, repetition based on:based on due, catch up automatically:catchValue}
                end if
            else
                if basedOnName is "defer" then
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:from completion, repetition based on:based on defer, catch up automatically:false}
                else if basedOnName is "planned" then
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:from completion, repetition based on:based on planned, catch up automatically:false}
                else
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:from completion, repetition based on:based on due, catch up automatically:false}
                end if
            end if
        on error errMsg number errNum
            if errNum is -1702 then
                return "❌ OmniFocus does not understand the repeat rule " & recurrenceText & ". Nothing was changed."
            end if
            return "❌ Could not set the repetition: " & errMsg
        end try
    end tell
    return ""
end applyRepetition

on setRepetition(theItem, kindWord, itemLabel, newValue)
    -- Sets, changes or stops (value "none") the repetition of a task or project; returns the message for the person.
    -- A rule that is replaced keeps the date it is based on (if the item still has it) and the catch-up setting.
    if newValue is "none" or newValue is "clear" or newValue is "off" then
        set oldRepeat to my repetitionText(theItem)
        if oldRepeat is "" then return "ℹ️ " & my capitalWord(kindWord) & " does not repeat: " & itemLabel
        tell application "OmniFocus" to set repetition rule of theItem to missing value
        return "✏️ Stopped repeating: " & itemLabel & " (was: " & oldRepeat & ")"
    end if

    set repeatInfo to my parseRepeatRule(newValue)
    if not (isValid of repeatInfo) then return errorText of repeatInfo

    -- A repeating item needs a date to repeat from
    set basedOnName to my defaultBasedOn(theItem)
    if basedOnName is "" then
        return "❌ A repeating " & kindWord & " needs a due, defer or planned date. Set one first. Nothing was changed: " & itemLabel
    end if
    set catchValue to false
    set oldInfo to my readRepetition(theItem)
    if ruleExists of oldInfo then
        if my hasRepetitionDate(theItem, ruleBasedOn of oldInfo) then set basedOnName to ruleBasedOn of oldInfo
        set catchValue to ruleCatchUp of oldInfo
    end if
    if (scheduleName of repeatInfo) is not "regularly" then set catchValue to false

    set problemText to my applyRepetition(theItem, ruleString of repeatInfo, scheduleName of repeatInfo, basedOnName, catchValue)
    if problemText is not "" then return problemText
    return "🔁 " & itemLabel & ": " & my repetitionText(theItem)
end setRepetition

on changeRepetition(theItem, kindWord, itemLabel, partName, valueText)
    -- Changes one setting of an existing repetition: partName "based_on" (due, defer or planned) or "catch_up" (true or false)
    set oldInfo to my readRepetition(theItem)
    if not (ruleExists of oldInfo) then
        return "❌ This " & kindWord & " does not repeat. Set a repeat rule first. Nothing was changed: " & itemLabel
    end if
    set basedOnName to ruleBasedOn of oldInfo
    set catchValue to ruleCatchUp of oldInfo
    set cleanValue to my trimItem(valueText)
    if partName is "based_on" then
        if cleanValue contains "due" then
            set basedOnName to "due"
        else if cleanValue contains "defer" or cleanValue is "start" then
            set basedOnName to "defer"
        else if cleanValue contains "plan" then
            set basedOnName to "planned"
        else
            return "❌ Invalid value for repeat_based_on: " & valueText & ". Use due, defer or planned."
        end if
        if not my hasRepetitionDate(theItem, basedOnName) then
            return "❌ This " & kindWord & " has no " & basedOnName & " date to repeat from. Set one first. Nothing was changed: " & itemLabel
        end if
    else
        if cleanValue is "true" or cleanValue is "yes" or cleanValue is "1" then
            set catchValue to true
        else if cleanValue is "false" or cleanValue is "no" or cleanValue is "0" then
            set catchValue to false
        else
            return "❌ Invalid value for repeat_catch_up: " & valueText & ". Use true or false."
        end if
        if catchValue and (ruleSchedule of oldInfo) is not "regularly" then
            return "❌ Catching up only works for a fixed schedule. Change the rule to a fixed schedule first (for example \"weekly fixed\"). Nothing was changed: " & itemLabel
        end if
    end if

    set problemText to my applyRepetition(theItem, ruleRecurrence of oldInfo, ruleSchedule of oldInfo, basedOnName, catchValue)
    if problemText is not "" then return problemText
    return "🔁 " & itemLabel & ": " & my repetitionText(theItem)
end changeRepetition

on capitalWord(theWord)
    if theWord is "" then return ""
    set firstChar to character 1 of theWord
    set restText to ""
    if (length of theWord) > 1 then set restText to text 2 thru -1 of theWord
    return my upperText(firstChar) & restText
end capitalWord

on plainNumberText(theNumber)
    -- A whole number as text with the digits 0 to 9. "as text" and "&" write the digits of the region instead
    -- (Eastern Arabic digits on a Mac with an Arabic or Persian region), which breaks text that is read by a program,
    -- for example an iCalendar rule.
    set wholeNumber to theNumber as integer
    if wholeNumber < 0 then return "-" & my plainNumberText(0 - wholeNumber)
    if wholeNumber < 10 then return character (wholeNumber + 1) of "0123456789"
    return (my plainNumberText(wholeNumber div 10)) & (character ((wholeNumber mod 10) + 1) of "0123456789")
end plainNumberText

on lowerText(theText)
    -- Lower case for the letters A to Z only. Used for keywords: the comparison of the system folds the letter I by the
    -- rules of the region (on a Turkish Mac "I" is not the same as "i" even when the case is ignored).
    set resultText to ""
    repeat with aChar in characters of theText
        set theChar to contents of aChar
        set codeValue to id of theChar
        if codeValue ≥ 65 and codeValue ≤ 90 then
            set resultText to resultText & (character id (codeValue + 32))
        else
            set resultText to resultText & theChar
        end if
    end repeat
    return resultText
end lowerText

on parseDate(dateString)
    -- Reads a date from text. Returns missing value if the text is not a date: nothing is guessed.
    -- Understood: YYYY-MM-DD (midnight), YYYY-MM-DD HH:MM, YYYY-MM-DDTHH:MM, today, tomorrow, next week,
    -- "3 days", "in 3 days", "2 weeks" and, as a last try, the date formats and weekday names of the system language.
    set todayDate to current date
    set trimmed to my trimItem(dateString as text)
    if trimmed is "" then return missing value

    -- ISO dates are built from their numeric parts, independent of the system language
    if my looksLikeISODate(trimmed) then return my parseISODate(trimmed)

    -- Keywords are compared in lower case: the system comparison of "I" and "i" depends on the region (Turkish)
    set keywordText to my lowerText(trimmed)
    if keywordText is "today" then return todayDate
    if keywordText is "tomorrow" then return todayDate + 1 * days
    if keywordText is "next week" or keywordText is "week" then return todayDate + 7 * days

    -- "3 days", "in 3 days", "1 week", "2 weeks" (no short-circuit in AppleScript: check the number of words first)
    set wordList to words of keywordText
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
    -- The system parser rolls a date that does not exist (31.31.2026) over into a later one and, in some regions, drops
    -- the time of a text like "01.12.2026 14:30". The result has to fit the numbers of the text.
    -- 1. A time in the text (14:30, 2:30 PM) has to be the time of the result.
    set colonPos to offset of ":" in theText
    if colonPos > 1 then
        set hourText to ""
        set pos to colonPos - 1
        repeat while pos ≥ 1 and (length of hourText) < 2 and "0123456789" contains (character pos of theText)
            set hourText to (character pos of theText) & hourText
            set pos to pos - 1
        end repeat
        set minuteText to ""
        set pos to colonPos + 1
        repeat while pos ≤ (length of theText) and (length of minuteText) < 2 and "0123456789" contains (character pos of theText)
            set minuteText to minuteText & (character pos of theText)
            set pos to pos + 1
        end repeat
        if hourText is not "" and (length of minuteText) = 2 then
            set hourNumber to hourText as integer
            if (minutes of theDate) is not (minuteText as integer) then return false
            if ((hours of theDate) mod 12) is not (hourNumber mod 12) then return false
            -- A marker behind a 12-hour time (PM, ...) that the system does not know is dropped without a message
            -- and leaves the hour as it is: such a time is refused.
            if hourNumber ≥ 1 and hourNumber ≤ 12 and (hours of theDate) is hourNumber then
                set restText to ""
                if pos ≤ (length of theText) then set restText to text pos thru -1 of theText
                set hasMarker to false
                repeat with aChar in characters of restText
                    if " 0123456789:.,/-" does not contain (contents of aChar) then set hasMarker to true
                end repeat
                if hasMarker and not my systemKnowsPM() then return false
            end if
        end if
    end if
    -- 2. A date written with numbers and dots or slashes: the day and the month of the result must be numbers of the text.
    set datePart to theText
    set spacePos to offset of " " in theText
    if spacePos > 1 then set datePart to text 1 thru (spacePos - 1) of theText
    if datePart does not contain "." and datePart does not contain "/" then return true
    -- Month names in any language: anything but digits, dots and slashes
    repeat with aChar in characters of datePart
        if "0123456789./" does not contain (contents of aChar) then return true
    end repeat
    set numberList to my numberTokens(datePart)
    if (count of numberList) < 2 then return true
    if numberList does not contain (day of theDate) then return false
    if numberList does not contain ((month of theDate) as integer) then return false
    return true
end fallbackDateFits

on systemKnowsPM()
    -- True if the date parser of the system reads "1:00 PM" as 13:00 (it depends on the language of the system)
    -- The text is in a variable: a date written as a literal in a script is read when the script is compiled,
    -- and a script with a date that the system cannot read would not run at all.
    set pmText to "1:00 PM"
    try
        set testDate to date pmText
        return ((hours of testDate) is 13)
    end try
    return false
end systemKnowsPM

on numberTokens(theText)
    -- The whole numbers in a text, in order: "31.12.2026" gives {31, 12, 2026}
    set tokenList to {}
    set currentToken to ""
    repeat with aChar in characters of theText
        if "0123456789" contains (contents of aChar) then
            set currentToken to currentToken & (contents of aChar)
        else if currentToken is not "" then
            set end of tokenList to my digitsValue(currentToken)
            set currentToken to ""
        end if
    end repeat
    if currentToken is not "" then set end of tokenList to my digitsValue(currentToken)
    return tokenList
end numberTokens

on digitsValue(digitText)
    -- The value of a text of digits; a longer number than nine digits is no date part and is not converted
    -- (a number that does not fit into an integer would become a real number or an error)
    if (length of digitText) > 9 then return 999999999
    return digitText as integer
end digitsValue

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
