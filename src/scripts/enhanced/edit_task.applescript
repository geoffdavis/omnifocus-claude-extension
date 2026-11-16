on run argv
    -- Edit an existing task
    -- Usage: edit_task.applescript "task name" "property" "new value"
    -- Properties: name, note, append_note, due_date, defer_date, planned_date, flagged, project, estimated_minutes, tags, repeat,
    --   parent_task, sequential, complete_with_last_item
    --   append_note: adds the text as a new line at the end of the note (note replaces the whole note)
    --   attach_file: attaches the file with the given full path to the note (a copy is stored in OmniFocus)
    --   link_file: links the file with the given full path in the note (the file stays where it is)
    --   remove_attachment: removes the attachment with the given number (1 is the first one, see get_task)
    --   parent_task: moves the task (with its subtasks) below another open task, given by name or "id:<id>"
    --   sequential: "true" = the subtasks are done one after another, "false" = in any order
    --   complete_with_last_item: "true" = the task completes when its last subtask is completed
    --   repeat: "daily", "weekly", "monthly", "yearly", "3 days", "2 weeks", ... (add "fixed" for a fixed schedule,
    --   otherwise the next occurrence follows the completion), or "none" to stop repeating
    
    set searchTerm to item 1 of argv
    set propertyName to item 2 of argv
    set newValue to item 3 of argv
    
    tell application "OmniFocus"
        tell default document
            -- Find the task
            -- "id:<id>" addresses exactly one task; otherwise search open tasks by name
            if searchTerm starts with "id:" and (length of searchTerm) > 3 then
                set wantedID to text 4 thru -1 of searchTerm
                set foundTasks to every flattened task whose id is wantedID
            else
                set foundTasks to every flattened task whose name contains searchTerm and completed is false
            end if
            
            if (count of foundTasks) = 0 then
                return "❌ No matching tasks found for: " & searchTerm
            else if (count of foundTasks) > 1 then
                -- Multiple matches - show them
                set taskList to "🔍 Multiple tasks found (" & (count of foundTasks) & "):" & return
                repeat with aTask in foundTasks
                    set taskList to taskList & "• " & name of aTask & " [id:" & (id of aTask) & "]" & return
                end repeat
                set taskList to taskList & return & "Please be more specific or use id:<id>."
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
                    
                else if propertyName is "append_note" then
                    -- Add text at the end of the note without touching what is already there
                    if newValue is "" then
                        return "❌ append_note needs a text to add. Nothing was changed."
                    end if
                    set currentNote to (note of targetTask) as text
                    if currentNote is "" then
                        set note of targetTask to newValue
                    else
                        -- Setting the note as plain text would lose attachments and formatting, so refuse in that case
                        set noteProblem to my noteFormattingProblem(targetTask)
                        if noteProblem is not "" then
                            return "❌ " & noteProblem & " Nothing was changed."
                        end if
                        set note of targetTask to currentNote & linefeed & newValue
                    end if
                    return "📝 Added to the note of: " & originalName

                else if propertyName is "attach_file" or propertyName is "link_file" then
                    return my attachFileToNote(targetTask, originalName, newValue, propertyName is "attach_file")

                else if propertyName is "remove_attachment" then
                    return my removeAttachmentFromNote(targetTask, originalName, newValue)

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
                    
                else if propertyName is "planned_date" or propertyName is "planned" then
                    if newValue is "none" or newValue is "clear" then
                        set planned date of targetTask to missing value
                        return "✏️ Cleared planned date for: " & originalName
                    else
                        set parsedDate to my parseDate(newValue)
                        set planned date of targetTask to parsedDate
                        return "✏️ Set planned date to " & (parsedDate as string) & " for: " & originalName
                    end if

                else if propertyName is "repeat" or propertyName is "repetition" then
                    if newValue is "none" or newValue is "clear" or newValue is "off" then
                        set oldRepeat to my repetitionText(targetTask)
                        if oldRepeat is "" then return "ℹ️ Task does not repeat: " & originalName
                        set repetition rule of targetTask to missing value
                        return "✏️ Stopped repeating: " & originalName & " (was: " & oldRepeat & ")"
                    end if

                    set repeatInfo to my parseRepeatRule(newValue)
                    if not (isValid of repeatInfo) then return errorText of repeatInfo

                    -- A repeating task needs a date to repeat from
                    set hasDue to ((due date of targetTask) is not missing value)
                    set hasDefer to ((defer date of targetTask) is not missing value)
                    set hasPlanned to false
                    try
                        set hasPlanned to ((planned date of targetTask) is not missing value)
                    end try
                    if not (hasDue or hasDefer or hasPlanned) then
                        return "❌ A repeating task needs a due, defer or planned date. Set one first. Nothing was changed: " & originalName
                    end if
                    if useFixed of repeatInfo then
                        set repetition rule of targetTask to {repetition method:fixed repetition, recurrence:ruleString of repeatInfo}
                    else if hasDue then
                        set repetition rule of targetTask to {repetition method:due after completion, recurrence:ruleString of repeatInfo}
                    else
                        set repetition rule of targetTask to {repetition method:start after completion, recurrence:ruleString of repeatInfo}
                    end if
                    return "🔁 " & originalName & ": " & my repetitionText(targetTask)

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
                        -- Find all tags first (by name, path "Parent > Child" or id:<id>; missing tags are created),
                        -- so that a failed lookup leaves the task unchanged
                        set originalDelims to AppleScript's text item delimiters
                        set AppleScript's text item delimiters to ","
                        set tagList to text items of newValue
                        set AppleScript's text item delimiters to originalDelims
                        set resolvedTags to {}
                        set addedTags to ""
                        repeat with tagItem in tagList
                            set tagName to my trimItem(tagItem as string)
                            if tagName is not "" then
                                set tagLookup to my findOrCreateTag(tagName)
                                set theTag to foundTag of tagLookup
                                if theTag is missing value then
                                    return (errorText of tagLookup) & return & "Tags were not changed."
                                end if
                                set end of resolvedTags to theTag
                                if addedTags is "" then
                                    set addedTags to tagName
                                else
                                    set addedTags to addedTags & ", " & tagName
                                end if
                            end if
                        end repeat
                        -- Remove the existing tags, then add the new ones
                        set existingTags to tags of targetTask
                        repeat with existingTag in existingTags
                            remove existingTag from tags of targetTask
                        end repeat
                        repeat with resolvedTag in resolvedTags
                            add (contents of resolvedTag) to tags of targetTask
                        end repeat
                        return "🏷️ Set tags to [" & addedTags & "] for: " & originalName
                    end if

                else if propertyName is "parent_task" or propertyName is "parent" then
                    -- Move the task below another open task (it keeps its own subtasks)
                    set parentLookup to my resolveTask(newValue)
                    if foundTask of parentLookup is missing value then
                        return (errorText of parentLookup) & return & "Nothing was moved."
                    end if
                    set newParent to foundTask of parentLookup
                    -- A task cannot go below itself or below one of its own subtasks
                    set movedID to id of targetTask
                    set walkTask to newParent
                    repeat while walkTask is not missing value
                        if (id of walkTask) is movedID then
                            return "❌ A task cannot be moved below itself or one of its own subtasks. Nothing was moved."
                        end if
                        set walkTask to parent task of walkTask
                    end repeat
                    move targetTask to end of tasks of newParent
                    set resultText to "📂 Moved below the task \"" & (name of newParent) & "\": " & originalName
                    try
                        set parentProject to containing project of newParent
                        if parentProject is not missing value then set resultText to resultText & " (project: " & my projectLabel(parentProject) & ")"
                    end try
                    return resultText

                else if propertyName is "sequential" then
                    set flagValue to my parseFlag(newValue)
                    if flagValue is "" then return "❌ Invalid value for sequential: " & newValue & ". Use true or false."
                    set sequential of targetTask to (flagValue is "true")
                    set hintText to ""
                    if (number of tasks of targetTask) = 0 then set hintText to " (it has no subtasks yet)"
                    if flagValue is "true" then
                        return "🔢 Subtasks are done one after another: " & originalName & hintText
                    else
                        return "🔀 Subtasks can be done in any order: " & originalName & hintText
                    end if

                else if propertyName is "complete_with_last_item" then
                    set flagValue to my parseFlag(newValue)
                    if flagValue is "" then return "❌ Invalid value for complete_with_last_item: " & newValue & ". Use true or false."
                    set completed by children of targetTask to (flagValue is "true")
                    set hintText to ""
                    if (number of tasks of targetTask) = 0 then set hintText to " (it has no subtasks yet)"
                    if flagValue is "true" then
                        return "✅ Completes when its last subtask is completed: " & originalName & hintText
                    else
                        return "☑️ No longer completes automatically with its last subtask: " & originalName & hintText
                    end if

                else
                    return "❌ Unknown property: " & propertyName & ". Valid properties: name, note, append_note, due_date, defer_date, planned_date, flagged, project, estimated_minutes, tags, repeat, parent_task, sequential, complete_with_last_item, attach_file, link_file, remove_attachment"
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

on parseRepeatRule(ruleText)
    -- Reads a repeat rule: "daily", "weekly", "monthly", "yearly", "3 days", "2 weeks", "1 month", "every 2 weeks".
    -- "fixed" at the end means a fixed schedule instead of "after completion", for example "weekly fixed".
    -- Returns {isValid, ruleString, useFixed, errorText}; ruleString is an iCalendar string such as FREQ=WEEKLY;INTERVAL=2
    set problemText to "❌ Invalid repeat: " & ruleText & ". Use for example \"daily\", \"weekly\", \"2 weeks\", \"3 months\" or \"1 year\", add \"fixed\" for a fixed schedule (\"weekly fixed\"), or \"none\" to stop repeating."
    set wordList to words of ruleText
    set useFixed to false
    ignoring case
        if (count of wordList) > 1 and item 1 of wordList is "every" then set wordList to items 2 thru -1 of wordList
        if (count of wordList) > 1 and item -1 of wordList is "fixed" then
            set useFixed to true
            set wordList to items 1 thru -2 of wordList
        end if
    end ignoring

    set stepCount to 1
    if (count of wordList) = 1 then
        set unitWord to item 1 of wordList
    else if (count of wordList) = 2 then
        try
            set stepCount to (item 1 of wordList) as integer
        on error
            return {isValid:false, ruleString:"", useFixed:false, errorText:problemText}
        end try
        set unitWord to item 2 of wordList
    else
        return {isValid:false, ruleString:"", useFixed:false, errorText:problemText}
    end if
    if stepCount < 1 or stepCount > 999 then return {isValid:false, ruleString:"", useFixed:false, errorText:problemText}

    set frequencyText to ""
    ignoring case
        if unitWord is "daily" then set unitWord to "day"
        if unitWord is "weekly" then set unitWord to "week"
        if unitWord is "monthly" then set unitWord to "month"
        if unitWord is "yearly" or unitWord is "annually" then set unitWord to "year"
        if (length of unitWord) > 1 and unitWord ends with "s" then set unitWord to text 1 thru -2 of unitWord
        if unitWord is "day" then set frequencyText to "DAILY"
        if unitWord is "week" then set frequencyText to "WEEKLY"
        if unitWord is "month" then set frequencyText to "MONTHLY"
        if unitWord is "year" then set frequencyText to "YEARLY"
    end ignoring
    if frequencyText is "" then return {isValid:false, ruleString:"", useFixed:false, errorText:problemText}

    set recurrenceText to "FREQ=" & frequencyText
    if stepCount > 1 then set recurrenceText to recurrenceText & ";INTERVAL=" & stepCount
    return {isValid:true, ruleString:recurrenceText, useFixed:useFixed, errorText:""}
end parseRepeatRule

on describeRecurrence(recurrenceText)
    -- "FREQ=WEEKLY;INTERVAL=2" becomes "every 2 weeks"; rules with more parts are returned unchanged
    set cleanText to recurrenceText
    if cleanText starts with "RRULE:" then set cleanText to text 7 thru -1 of cleanText
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ";"
    set partList to text items of cleanText
    set AppleScript's text item delimiters to oldDelims

    set frequencyText to ""
    set stepCount to 1
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
    if stepCount is 1 then return "every " & unitName
    return "every " & stepCount & " " & unitName & "s"
end describeRecurrence

on repetitionText(theTask)
    -- Describes how a task repeats, for example "every 2 weeks, due date after completion", "" if it does not repeat
    set recurrenceText to ""
    set methodText to ""
    tell application "OmniFocus"
        try
            set theRule to repetition rule of theTask
        on error
            return ""
        end try
        if theRule is missing value then return ""
        try
            set recurrenceText to recurrence of theRule
        end try
        try
            set methodValue to repetition method of theRule
            if methodValue is fixed repetition then
                set methodText to "fixed schedule"
            else if methodValue is start after completion then
                set methodText to "defer date after completion"
            else if methodValue is due after completion then
                set methodText to "due date after completion"
            end if
        end try
    end tell
    set resultText to "repeats"
    if recurrenceText is not "" then set resultText to my describeRecurrence(recurrenceText)
    if methodText is not "" then set resultText to resultText & ", " & methodText
    return resultText
end repetitionText

on parseFlag(valueText)
    -- "true" or "false" for the usual spellings, "" for anything else
    ignoring case
        if valueText is "true" or valueText is "yes" or valueText is "1" then return "true"
        if valueText is "false" or valueText is "no" or valueText is "0" then return "false"
    end ignoring
    return ""
end parseFlag

on resolveTask(queryText)
  -- Finds one open task: "id:<id>", or a name (an exact name wins, otherwise part of a name; case is ignored).
  -- Returns {foundTask, errorText}; foundTask is missing value if nothing or more than one task fits.
  set searchText to my trimItem(queryText)
  if searchText is "" then
    return {foundTask:missing value, errorText:"❌ Parent task cannot be empty."}
  end if

  if searchText starts with "id:" and (length of searchText) > 3 then
    set wantedID to my trimItem(text 4 thru -1 of searchText)
    tell application "OmniFocus"
      tell default document
        set idMatches to every flattened task whose id is wantedID and effectively completed is false and effectively dropped is false
      end tell
    end tell
    if (count of idMatches) = 1 then
      return {foundTask:item 1 of idMatches, errorText:""}
    end if
    return {foundTask:missing value, errorText:"❌ Open task not found: " & searchText}
  end if

  tell application "OmniFocus"
    tell default document
      set nameMatches to every flattened task whose name contains searchText and effectively completed is false and effectively dropped is false
    end tell
  end tell

  set exactMatches to {}
  repeat with aMatch in nameMatches
    set matchTask to contents of aMatch
    tell application "OmniFocus" to set matchName to name of matchTask
    ignoring case
      if matchName is searchText then set end of exactMatches to matchTask
    end ignoring
  end repeat

  if (count of exactMatches) = 1 then
    return {foundTask:item 1 of exactMatches, errorText:""}
  end if
  if (count of nameMatches) = 1 then
    return {foundTask:item 1 of nameMatches, errorText:""}
  end if
  if (count of nameMatches) = 0 then
    return {foundTask:missing value, errorText:"❌ Open task not found: " & searchText}
  end if

  set matchList to "🔍 Several open tasks match \"" & searchText & "\" (" & (count of nameMatches) & "). Use id:<id> to pick one:"
  set shownCount to 0
  repeat with aMatch in nameMatches
    if shownCount ≥ 15 then
      set matchList to matchList & return & "… more not shown"
      exit repeat
    end if
    set matchTask to contents of aMatch
    tell application "OmniFocus"
      set matchLabel to name of matchTask
      try
        set matchProject to containing project of matchTask
        if matchProject is not missing value then set matchLabel to matchLabel & " [" & (name of matchProject) & "]"
      end try
      set matchLabel to matchLabel & " [id:" & (id of matchTask) & "]"
    end tell
    set matchList to matchList & return & "• " & matchLabel
    set shownCount to shownCount + 1
  end repeat
  return {foundTask:missing value, errorText:matchList}
end resolveTask

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
