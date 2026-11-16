on run argv
    -- Edit an existing task
    -- Usage: edit_task.applescript "task name" "property" "new value"
    -- Properties: name, note, append_note, due_date, defer_date, planned_date, flagged, project, estimated_minutes, tags, primary_tag, repeat, repeat_based_on, repeat_catch_up,
    --   parent_task, sequential, complete_with_last_item, floating_time_zone, assigned_container
    --   primary_tag: the first tag of the task: an existing tag moves to the front, a new tag is added in front (name, path or id; "none" removes the first tag)
    --   floating_time_zone: "true" = due and defer date keep their clock time in every time zone, "false" = fixed time zone
    --   assigned_container: an inbox task gets a provisional project (name, path or id) or parent task ("task:<name or id:id>") and stays in the inbox until Clean Up; "none" removes it
    --   append_note: adds the text as a new line at the end of the note (note replaces the whole note)
    --   attach_file: attaches the file with the given full path to the note (a copy is stored in OmniFocus)
    --   link_file: links the file with the given full path in the note (the file stays where it is)
    --   remove_attachment: removes the attachment with the given number (1 is the first one, see get_task)
    --   parent_task: moves the task (with its subtasks) below another open task, given by name or "id:<id>"
    --   sequential: "true" = the subtasks are done one after another, "false" = in any order
    --   complete_with_last_item: "true" = the task completes when its last subtask is completed
    --   repeat: "daily", "weekly", "monthly", "yearly", "3 days", "2 weeks", "every monday and thursday", "weekdays",
    --   "monthly on the 15th", "last friday of the month", ... or an iCalendar rule ("FREQ=WEEKLY;BYDAY=MO,TH");
    --   add "fixed" for a fixed schedule or "from completion"; "none" stops repeating
    --   repeat_based_on: the date a repeating task is based on: "due", "defer" or "planned"
    --   repeat_catch_up: "true" = skip the occurrences in the past (fixed schedule only), "false" = do not
    
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
                        set parsedDate to my parseDate(newValue)
                        if parsedDate is missing value then return my dateErrorText(newValue, "due_date") & " Nothing was changed."
                        set due date of targetTask to parsedDate
                        return "✏️ Set due date to " & (parsedDate as string) & " for: " & originalName
                    end if
                    
                else if propertyName is "defer_date" or propertyName is "defer" then
                    if newValue is "none" or newValue is "clear" then
                        set defer date of targetTask to missing value
                        return "✏️ Cleared defer date for: " & originalName
                    else
                        set parsedDate to my parseDate(newValue)
                        if parsedDate is missing value then return my dateErrorText(newValue, "defer_date") & " Nothing was changed."
                        set defer date of targetTask to parsedDate
                        return "✏️ Set defer date to " & (parsedDate as string) & " for: " & originalName
                    end if
                    
                else if propertyName is "planned_date" or propertyName is "planned" then
                    if newValue is "none" or newValue is "clear" then
                        set planned date of targetTask to missing value
                        return "✏️ Cleared planned date for: " & originalName
                    else
                        set parsedDate to my parseDate(newValue)
                        if parsedDate is missing value then return my dateErrorText(newValue, "planned_date") & " Nothing was changed."
                        set planned date of targetTask to parsedDate
                        return "✏️ Set planned date to " & (parsedDate as string) & " for: " & originalName
                    end if

                else if propertyName is "repeat" or propertyName is "repetition" then
                    return my setRepetition(targetTask, "task", originalName, newValue)

                else if propertyName is "repeat_based_on" then
                    return my changeRepetition(targetTask, "task", originalName, "based_on", newValue)

                else if propertyName is "repeat_catch_up" then
                    return my changeRepetition(targetTask, "task", originalName, "catch_up", newValue)

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
                    -- A whole number of minutes; "none", "clear" or 0 removes the estimate
                    set minutesText to my trimItem(newValue)
                    if minutesText is "none" or minutesText is "clear" or minutesText is "0" then
                        set estimated minutes of targetTask to missing value
                        return "⏱️ Cleared the estimate for: " & originalName
                    end if
                    if not my isDigits(minutesText) or (length of minutesText) > 7 then
                        return "❌ Invalid value for estimated_minutes: " & newValue & ". Use a whole number of minutes (for example 30) or \"none\" to clear the estimate. Nothing was changed."
                    end if
                    set estimated minutes of targetTask to (minutesText as integer)
                    return "⏱️ Set estimate to " & minutesText & " minutes for: " & originalName

                else if propertyName is "tags" then
                    -- Replace all tags with the new comma-separated list; "none" or "clear" removes all tags
                    return my setItemTags(targetTask, "task", originalName, newValue)

                else if propertyName is "primary_tag" then
                    -- The first tag of the task; the other tags stay, "none" removes the first tag
                    return my setItemPrimaryTag(targetTask, "task", originalName, newValue)

                else if propertyName is "floating_time_zone" or propertyName is "floating" then
                    set flagValue to my parseFlag(newValue)
                    if flagValue is "" then return "❌ Invalid value for floating_time_zone: " & newValue & ". Use true or false. Nothing was changed."
                    set should use floating time zone of targetTask to (flagValue is "true")
                    set hintText to ""
                    if (due date of targetTask) is missing value and (defer date of targetTask) is missing value then
                        set hintText to " (the task has no due or defer date, so OmniFocus keeps the default of the database until it has one)"
                    end if
                    if flagValue is "true" then
                        return "🌍 Due and defer date keep their clock time in every time zone: " & originalName & hintText
                    else
                        return "📍 Due and defer date use a fixed time zone: " & originalName & hintText
                    end if

                else if propertyName is "assigned_container" or propertyName is "assigned" then
                    return my setAssignedContainer(targetTask, originalName, newValue)

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
                    return "❌ Unknown property: " & propertyName & ". Valid properties: name, note, append_note, due_date, defer_date, planned_date, flagged, project, estimated_minutes, tags, primary_tag, repeat, repeat_based_on, repeat_catch_up, parent_task, sequential, complete_with_last_item, floating_time_zone, assigned_container, attach_file, link_file, remove_attachment"
                end if
                
            on error errMsg
                return "❌ Error updating task: " & errMsg
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

on joinText(textItems, separator)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to separator
    set joined to textItems as text
    set AppleScript's text item delimiters to oldDelims
    return joined
end joinText

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
                else if tokenText is "day" and my isDigits(nextText) then
                    set dayNumber to nextText as integer
                    set skipNext to true
                else if my unitCode(tokenText) is not "" then
                    set foundUnit to my unitCode(tokenText)
                    if unitFound is not "" and unitFound is not foundUnit then return invalidResult
                    set unitFound to foundUnit
                else if my isDigits(tokenText) then
                    if my unitCode(nextText) is "" then return invalidResult
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
            set extraPart to "BYDAY=" & (ordinalFound as text) & (item 1 of weekdayCodes)
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
        set extraPart to "BYMONTHDAY=" & (dayNumber as text)
    else
        if unitFound is "" then return invalidResult
        set frequencyText to unitFound
    end if

    set recurrenceText to "FREQ=" & frequencyText
    if intervalCount > 1 then set recurrenceText to recurrenceText & ";INTERVAL=" & intervalCount
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
                if my isDigits(numberPart) then return numberPart as integer
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

on setAssignedContainer(targetTask, originalName, newValue)
    -- An inbox task gets a provisional project or parent task without leaving the inbox; Clean Up moves it there
    set inInbox to false
    tell application "OmniFocus" to set inInbox to (in inbox of targetTask)
    if not inInbox then
        return "❌ Only inbox tasks have an assigned container. A task that is already in a project is moved with project or parent_task. Nothing was changed."
    end if
    set containerText to my trimItem(newValue)
    if containerText is "none" or containerText is "clear" then
        tell application "OmniFocus" to set assigned container of targetTask to missing value
        return "📥 Removed the assigned container of: " & originalName
    end if
    if containerText is "" then
        return "❌ assigned_container needs a project, \"task:<task>\" or \"none\". Nothing was changed."
    end if

    set containerRef to missing value
    set containerLabel to ""
    if containerText starts with "task:" then
        set parentLookup to my resolveTask(my trimItem(text 6 thru -1 of containerText))
        if foundTask of parentLookup is missing value then
            return (errorText of parentLookup) & return & "Nothing was changed."
        end if
        set containerRef to foundTask of parentLookup
        tell application "OmniFocus"
            set containerProject to missing value
            try
                set containerProject to containing project of containerRef
            end try
            set containerName to name of containerRef
            if containerProject is missing value then
                return "❌ The task \"" & containerName & "\" is in the inbox itself and cannot be a container. Nothing was changed."
            end if
            if (id of containerRef) is (id of targetTask) then
                return "❌ A task cannot be assigned to itself. Nothing was changed."
            end if
        end tell
        set containerLabel to "the task \"" & containerName & "\""
    else
        set projectLookup to my resolveProject(containerText)
        if foundProject of projectLookup is missing value then
            return (errorText of projectLookup) & return & "Nothing was changed."
        end if
        set containerRef to foundProject of projectLookup
        set containerLabel to "the project \"" & my projectLabel(containerRef) & "\""
    end if

    tell application "OmniFocus" to set assigned container of targetTask to containerRef
    return "📥 Assigned to " & containerLabel & ": " & originalName & ". It stays in the inbox until Clean Up (clean_up) moves it there."
end setAssignedContainer

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
