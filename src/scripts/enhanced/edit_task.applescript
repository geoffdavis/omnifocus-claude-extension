on run argv
    -- Edit an existing task
    -- Usage: edit_task.applescript "task name" "property" "new value"
    -- Properties: name, note, due_date, defer_date, flagged, project, estimated_minutes, tags
    
    set searchTerm to item 1 of argv
    set propertyName to item 2 of argv
    set newValue to item 3 of argv
    
    tell application "OmniFocus"
        tell default document
            -- Find the task
            set foundTasks to every flattened task whose name contains searchTerm and completed is false
            
            if (count of foundTasks) = 0 then
                return "❌ No matching tasks found for: " & searchTerm
            else if (count of foundTasks) > 1 then
                -- Multiple matches - show them
                set taskList to "🔍 Multiple tasks found (" & (count of foundTasks) & "):" & return
                repeat with aTask in foundTasks
                    set taskList to taskList & "• " & name of aTask & return
                end repeat
                set taskList to taskList & return & "Please be more specific."
                return taskList
            end if
            
            -- Single task found - edit it
            set targetTask to item 1 of foundTasks
            set originalName to name of targetTask
            
            try
                if propertyName is "name" then
                    set name of targetTask to newValue
                    return "✏️ Renamed task: \"" & originalName & "\" → \"" & newValue & "\""
                    
                else if propertyName is "note" then
                    set note of targetTask to newValue
                    return "✏️ Updated note for: " & originalName
                    
                else if propertyName is "due_date" or propertyName is "due" then
                    if newValue is "none" or newValue is "clear" then
                        set due date of targetTask to missing value
                        return "✏️ Cleared due date for: " & originalName
                    else
                        -- Parse date string (basic parsing)
                        set parsedDate to my parseDate(newValue)
                        set due date of targetTask to parsedDate
                        return "✏️ Set due date to " & (parsedDate as string) & " for: " & originalName
                    end if
                    
                else if propertyName is "defer_date" or propertyName is "defer" then
                    if newValue is "none" or newValue is "clear" then
                        set defer date of targetTask to missing value
                        return "✏️ Cleared defer date for: " & originalName
                    else
                        set parsedDate to my parseDate(newValue)
                        set defer date of targetTask to parsedDate
                        return "✏️ Set defer date to " & (parsedDate as string) & " for: " & originalName
                    end if
                    
                else if propertyName is "flagged" or propertyName is "flag" then
                    if newValue is "true" or newValue is "yes" or newValue is "1" then
                        set flagged of targetTask to true
                        return "🚩 Flagged: " & originalName
                    else
                        set flagged of targetTask to false
                        return "🏳️ Unflagged: " & originalName
                    end if
                    
                else if propertyName is "project" then
                    if newValue is "inbox" or newValue is "none" then
                        try
                            move targetTask to end of inbox tasks
                        on error
                            set containing project of targetTask to missing value
                        end try
                        return "📥 Moved to inbox: " & originalName
                    else
                        -- Searches projects in all folders; accepts "Folder > Subfolder > Project"
                        set projectLookup to my resolveProject(newValue)
                        if foundProject of projectLookup is missing value then
                            return errorText of projectLookup
                        end if
                        set targetProject to foundProject of projectLookup
                        try
                            move targetTask to end of tasks of targetProject
                        on error
                            set containing project of targetTask to targetProject
                        end try
                        return "📁 Moved to project \"" & my projectLabel(targetProject) & "\": " & originalName
                    end if
                    
                else if propertyName is "estimated_minutes" or propertyName is "estimate" then
                    set estimated minutes of targetTask to (newValue as integer)
                    return "⏱️ Set estimate to " & newValue & " minutes for: " & originalName

                else if propertyName is "tags" then
                    -- Replace all tags with the new comma-separated list
                    -- Use "none" or "clear" to remove all tags
                    if newValue is "none" or newValue is "clear" then
                        set existingTags to tags of targetTask
                        repeat with existingTag in existingTags
                            remove existingTag from tags of targetTask
                        end repeat
                        return "🏷️ Cleared all tags for: " & originalName
                    else
                        -- Remove existing tags first
                        set existingTags to tags of targetTask
                        repeat with existingTag in existingTags
                            remove existingTag from tags of targetTask
                        end repeat
                        -- Add new tags
                        set originalDelims to AppleScript's text item delimiters
                        set AppleScript's text item delimiters to ","
                        set tagList to text items of newValue
                        set AppleScript's text item delimiters to originalDelims
                        set addedTags to ""
                        repeat with tagItem in tagList
                            set tagName to my trimItem(tagItem as string)
                            if tagName is not "" then
                                set matchingTags to every tag whose name is tagName
                                if (count of matchingTags) = 0 then
                                    set theTag to make new tag with properties {name:tagName}
                                else
                                    set theTag to item 1 of matchingTags
                                end if
                                add theTag to tags of targetTask
                                if addedTags is "" then
                                    set addedTags to tagName
                                else
                                    set addedTags to addedTags & ", " & tagName
                                end if
                            end if
                        end repeat
                        return "🏷️ Set tags to [" & addedTags & "] for: " & originalName
                    end if

                else
                    return "❌ Unknown property: " & propertyName & ". Valid properties: name, note, due_date, defer_date, flagged, project, estimated_minutes, tags"
                end if
                
            on error errMsg
                return "❌ Error updating task: " & errMsg
            end try
        end tell
    end tell
end run

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

on trimItem(theText)
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
end trimItem

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

on resolveProject(queryText)
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
