on run argv
    -- Create multiple tasks at once
    -- Usage: batch_add_tasks.applescript "task1|task2|task3" "project_name" "due_date" "flagged" "tags"
    
    set taskNames to item 1 of argv
    set projectName to ""
    set dueDate to ""
    set isFlagged to false
    set tagsString to ""
    
    if (count of argv) > 1 then
        set projectName to item 2 of argv
    end if
    
    if (count of argv) > 2 then
        set dueDate to item 3 of argv
    end if
    
    if (count of argv) > 3 then
        set isFlagged to (item 4 of argv is "true")
    end if
    
    if (count of argv) > 4 then
        set tagsString to item 5 of argv
    end if
    
    -- Parse pipe-separated task names
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to "|"
    set taskList to text items of taskNames
    set AppleScript's text item delimiters to oldDelims

    -- Parse comma-separated tag names (resolved to objects inside the tell block)
    set tagNames to {}
    if tagsString is not "" then
        set oldDelims to AppleScript's text item delimiters
        set AppleScript's text item delimiters to ","
        set tagNames to text items of tagsString
        set AppleScript's text item delimiters to oldDelims
    end if
    
    tell application "OmniFocus"
        tell default document
            set createdTasks to {}
            set targetProject to missing value
            
            -- Find target project if specified
            if projectName is not "" and projectName is not "inbox" then
                -- Searches open projects in all folders; accepts "Folder > Subfolder > Project" and "id:<id>"
                set projectLookup to my resolveProject(projectName)
                if foundProject of projectLookup is missing value then
                    return errorText of projectLookup & return & "Nothing was created."
                end if
                set targetProject to foundProject of projectLookup
            end if
            
            -- Parse due date if specified
            set parsedDueDate to missing value
            if dueDate is not "" then
                set parsedDueDate to my parseDate(dueDate)
            end if

            -- Pre-resolve tag objects once so per-task application is O(1) per tag
            set resolvedTags to {}
            if (count of tagNames) > 0 then
                repeat with tagName in tagNames
                    set tagName to my trimText(tagName as string)
                    if tagName is not "" then
                        -- Tags at any level are found by name, path "Parent > Child" or id:<id>; missing tags are created
                        set tagLookup to my findOrCreateTag(tagName)
                        set theTag to foundTag of tagLookup
                        if theTag is missing value then
                            return (errorText of tagLookup) & return & "Nothing was created."
                        end if
                        set end of resolvedTags to theTag
                    end if
                end repeat
            end if
            
            -- Create each task
            repeat with taskName in taskList
                set taskName to taskName as string
                
                -- Check for subtask indicator (starts with -)
                set isSubtask to false
                set parentTask to missing value
                if taskName starts with "-" then
                    set isSubtask to true
                    set taskName to text 2 thru -1 of taskName -- Remove leading dash
                    
                    -- Get the last non-subtask as parent
                    if (count of createdTasks) > 0 then
                        repeat with i from (count of createdTasks) to 1 by -1
                            set potentialParent to item i of createdTasks
                            if class of potentialParent is not missing value then
                                set parentTask to potentialParent
                                exit repeat
                            end if
                        end repeat
                    end if
                end if
                
                -- Trim whitespace
                set taskName to my trimText(taskName)
                
                if taskName is not "" then
                    try
                        if targetProject is not missing value then
                            -- Create in project
                            if isSubtask and parentTask is not missing value then
                                tell parentTask
                                    set newTask to make new task with properties {name:taskName, flagged:isFlagged}
                                end tell
                            else
                                tell targetProject
                                    set newTask to make new task with properties {name:taskName, flagged:isFlagged}
                                end tell
                            end if
                        else
                            -- Create in inbox
                            set newTask to make new inbox task with properties {name:taskName, flagged:isFlagged}
                        end if
                        
                        -- Set due date if specified
                        if parsedDueDate is not missing value then
                            set due date of newTask to parsedDueDate
                        end if

                        -- Apply tags if specified
                        if (count of resolvedTags) > 0 then
                            repeat with theTag in resolvedTags
                                add theTag to tags of newTask
                            end repeat
                        end if

                        set end of createdTasks to newTask
                    on error
                        set end of createdTasks to missing value
                    end try
                end if
            end repeat
            
            -- Return summary
            set successCount to 0
            repeat with aTask in createdTasks
                if aTask is not missing value then
                    set successCount to successCount + 1
                end if
            end repeat
            
            if successCount = 0 then
                return "❌ Failed to create any tasks"
            else
                set resultText to "✅ Created " & successCount & " task"
                if successCount > 1 then set resultText to resultText & "s"
                
                if targetProject is not missing value then
                    set resultText to resultText & " in project: " & name of targetProject
                else
                    set resultText to resultText & " in inbox"
                end if
                
                if parsedDueDate is not missing value then
                    set resultText to resultText & return & "📅 Due: " & (parsedDueDate as string)
                end if
                
                if isFlagged then
                    set resultText to resultText & return & "🚩 All tasks flagged"
                end if

                if (count of resolvedTags) > 0 then
                    set resultText to resultText & return & "🏷️ Tags: " & tagsString
                end if

                return resultText
            end if
        end tell
    end tell
end run

on parseDate(dateString)
    set todayDate to current date
    
    if dateString is "today" then
        return todayDate
    else if dateString is "tomorrow" then
        return todayDate + 1 * days
    else if dateString is "next week" then
        return todayDate + 7 * days
    else if length of dateString is 10 and character 5 of dateString is "-" and character 8 of dateString is "-" then
        -- ISO date YYYY-MM-DD (midnight)
        try
            set isoDate to current date
            set day of isoDate to 1
            set year of isoDate to (text 1 thru 4 of dateString) as integer
            set month of isoDate to (text 6 thru 7 of dateString) as integer
            set day of isoDate to (text 9 thru 10 of dateString) as integer
            set time of isoDate to 0
            return isoDate
        on error
            return todayDate
        end try
    else if dateString contains "days" then
        try
            set dayCount to word 1 of dateString as integer
            return todayDate + dayCount * days
        on error
            return todayDate
        end try
    else
        try
            return date dateString
        on error
            return todayDate
        end try
    end if
end parseDate

on trimText(txt)
    set txt to txt as string
    repeat while txt begins with " "
        set txt to text 2 thru -1 of txt
    end repeat
    repeat while txt ends with " "
        set txt to text 1 thru -2 of txt
    end repeat
    return txt
end trimText

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
    
    -- Finds an open (active or on hold) project in any folder by name, or by "Folder > Subfolder > Project".
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
        set projectIsOpen to my isOpenProject(candidateProject)
        ignoring case
            if projectIsOpen and candidateName is projectQuery then
                set end of exactMatches to candidateProject
            else if projectIsOpen and candidateName contains projectQuery then
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

on isOpenProject(aProject)
    -- Dropped and completed projects are not valid targets for new tasks
    tell application "OmniFocus"
        try
            set projectStatus to effective status of aProject
            return (projectStatus is active status or projectStatus is on hold status)
        end try
    end tell
    return true
end isOpenProject

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
