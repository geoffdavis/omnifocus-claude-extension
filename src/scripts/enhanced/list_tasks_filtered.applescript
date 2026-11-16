on run argv
    -- List open tasks, optionally filtered by tag, folder and availability
    -- Usage: list_tasks_filtered.applescript "tag" "folder" "available_only" "include_subtags" "include_inbox" "limit" "max_minutes" "include_unestimated" "show_age" "project"
    --   tag:             tag name, part of a name or path "Parent > Tag" ("" = no tag filter)
    --   folder:          only projects whose folder path contains this text ("" = all folders)
    --   available_only:  "true" leaves out blocked and deferred tasks, tasks of projects that are
    --                    not active and action groups (parent tasks with open subtasks)
    --   include_subtags: "true" also counts tasks that carry a child tag of the tag
    --   include_inbox:   "true" also lists inbox tasks (never together with a folder filter)
    --   limit:           maximum number of tasks to list (default 100)
    --   max_minutes:     only tasks with an estimate of at most this many minutes (0 or "" = no time filter)
    --   include_unestimated: "true" keeps tasks without an estimate when max_minutes is set
    --   show_age:        "true" shows how long each task exists (creation date) and lists the tasks as one
    --                    flat list, oldest first, with the project of each task
    --   project:         only the tasks of this project (name, "Folder > Project" or "id:<id>"; "" = all projects)
    -- Dropped items and items below dropped (hidden) folders are always left out.

    set tagQuery to ""
    set folderQuery to ""
    set availableOnly to false
    set includeSubtags to true
    set includeInbox to true
    set maxResults to 100
    set maxMinutes to 0
    set includeUnestimated to false
    set showAge to false
    set projectQuery to ""
    if (count of argv) > 0 then set tagQuery to my trimItem(item 1 of argv)
    if (count of argv) > 1 then set folderQuery to my trimItem(item 2 of argv)
    if (count of argv) > 2 then set availableOnly to (item 3 of argv is "true")
    if (count of argv) > 3 then set includeSubtags to (item 4 of argv is "true")
    if (count of argv) > 4 then set includeInbox to (item 5 of argv is "true")
    if (count of argv) > 5 then
        try
            set maxResults to (item 6 of argv) as integer
        end try
    end if
    if maxResults < 1 then set maxResults to 100
    if (count of argv) > 6 then
        try
            set maxMinutes to (item 7 of argv) as integer
        end try
    end if
    if maxMinutes < 0 then set maxMinutes to 0
    if (count of argv) > 7 then set includeUnestimated to (item 8 of argv is "true")
    if (count of argv) > 8 then set showAge to (item 9 of argv is "true")
    if (count of argv) > 9 then set projectQuery to my trimItem(item 10 of argv)

    -- Resolve the tag, including its child tags if requested
    set tagObjects to {}
    set tagDisplayName to ""
    if tagQuery is not "" then
        set tagLookup to my resolveTag(tagQuery, true)
        set theTag to foundTag of tagLookup
        if theTag is missing value then return errorText of tagLookup
        set tagObjects to {theTag}
        tell application "OmniFocus"
            set tagDisplayName to name of theTag
            if includeSubtags then
                try
                    set tagObjects to tagObjects & (every flattened tag of theTag)
                end try
            end if
        end tell
    end if

    -- Resolve the project filter: the IDs of all tasks below the project
    set projectFilterLabel to ""
    set projectTaskIDs to {}
    if projectQuery is not "" then
        set projectLookup to my resolveProject(projectQuery)
        set projectFilter to foundProject of projectLookup
        if projectFilter is missing value then return errorText of projectLookup
        set projectFilterLabel to my projectLabel(projectFilter)
        tell application "OmniFocus"
            try
                set projectTaskIDs to id of every flattened task of root task of projectFilter
            on error
                set projectTaskIDs to id of every flattened task of projectFilter
            end try
        end tell
    end if

    set hiddenProjectIDList to my hiddenFolderProjectIDs()
    set checkHidden to ((count of hiddenProjectIDList) > 0)

    -- Every Apple Event costs about 17 ms, a query for one property of all elements about 0.1 s: the properties of all
    -- tasks, projects and folders are fetched at once (the same position in each list is the same item)
    tell application "OmniFocus"
        tell default document
            set taskIDList to id of every flattened task
            set taskNameList to name of every flattened task
            set flaggedList to flagged of every flattened task
            set dueDateList to due date of every flattened task
            set deferDateList to defer date of every flattened task
            set blockedList to blocked of every flattened task
            set effCompletedList to effectively completed of every flattened task
            set effDroppedList to effectively dropped of every flattened task
            set estimateList to estimated minutes of every flattened task
            set tagNameLists to name of tags of every flattened task
            set taskProjectIDList to id of containing project of every flattened task
            set parentIDList to id of parent task of every flattened task
            set creationDateList to {}
            if showAge then set creationDateList to creation date of every flattened task
            set projectIDList to id of every flattened project
            set projectNameList to name of every flattened project
            set projectStatusList to effective status of every flattened project
            set projectFolderIDList to id of folder of every flattened project
            set folderIDList to id of every flattened folder
            set folderNameList to name of every flattened folder
            set folderParentIDList to id of container of every flattened folder
            set projectActiveList to {}
            repeat with aStatus in projectStatusList
                set end of projectActiveList to ((contents of aStatus) is active status)
            end repeat
        end tell
    end tell
    set nowDate to current date

    -- Position of a task ID in taskIDList without a loop: the IDs as one text, found with "offset"
    set taskIDText to linefeed & my joinText(taskIDList, linefeed) & linefeed

    -- Tasks that have open subtasks (action groups)
    set parentsWithOpenTasks to {}
    if availableOnly then
        repeat with i from 1 to count of taskIDList
            if not (item i of effCompletedList) and not (item i of effDroppedList) then
                set parentID to item i of parentIDList
                if parentID is not missing value then
                    if parentsWithOpenTasks does not contain parentID then set end of parentsWithOpenTasks to parentID
                end if
            end if
        end repeat
    end if

    -- Candidate tasks (positions in the lists): open ones that carry the tag, or all open ones without a tag filter
    set candidateIndexes to {}
    if (count of tagObjects) > 0 then
        repeat with aTag in tagObjects
            tell application "OmniFocus" to set tagTaskIDs to id of every task of (contents of aTag)
            repeat with tagTaskID in tagTaskIDs
                set i to my indexOfID(taskIDText, contents of tagTaskID)
                if i > 0 then
                    if not (item i of effCompletedList) and not (item i of effDroppedList) then set end of candidateIndexes to i
                end if
            end repeat
        end repeat
    else
        repeat with i from 1 to count of taskIDList
            if not (item i of effCompletedList) and not (item i of effDroppedList) then set end of candidateIndexes to i
        end repeat
    end if

    set seenIDs to {}
    set matchCount to 0
    set hitLimit to false
    set groupKeys to {}
    set groupHeadings to {}
    set groupTexts to {}
    set flatTexts to {}
    set flatDates to {}
    set projectCacheIDs to {}
    set projectCacheLabels to {}
    set projectCacheFolders to {}

    repeat with candidateIndex in candidateIndexes
        -- With show_age all matches are collected first, the limit applies after sorting
        if matchCount ≥ maxResults and not showAge then
            set hitLimit to true
            exit repeat
        end if

        set i to contents of candidateIndex
        set taskID to item i of taskIDList
        set projectID to item i of taskProjectIDList
        set keepTask to true

        -- Duplicates (a task with a tag and one of its child tags) and tasks below hidden folders
        if seenIDs contains taskID then set keepTask to false
        if keepTask and checkHidden and projectID is not missing value then
            if hiddenProjectIDList contains projectID then set keepTask to false
        end if
        if keepTask and projectFilterLabel is not "" and (projectTaskIDs does not contain taskID) then set keepTask to false

        -- Availability: not blocked, not deferred to the future and no action group (its open subtasks are actionable)
        if keepTask and availableOnly then
            if item i of blockedList then set keepTask to false
            set deferDate to item i of deferDateList
            if deferDate is not missing value then
                if deferDate > nowDate then set keepTask to false
            end if
            if parentsWithOpenTasks contains taskID then set keepTask to false
        end if

        -- Time filter
        if keepTask and maxMinutes > 0 then
            set estimateValue to item i of estimateList
            if estimateValue is missing value then
                if not includeUnestimated then set keepTask to false
            else if estimateValue is 0 then
                if not includeUnestimated then set keepTask to false
            else if estimateValue > maxMinutes then
                set keepTask to false
            end if
        end if

        -- Project, folder filter and group
        set projectIndex to 0
        if keepTask then
            if projectID is missing value then
                if (not includeInbox) or folderQuery is not "" then set keepTask to false
            else if projectID is taskID then
                -- A project without tasks is returned like a task and has the same id
                set keepTask to false
            else
                set projectIndex to my indexOfItem(projectID, projectIDList)
                if projectIndex = 0 then set keepTask to false
            end if
        end if
        if keepTask and availableOnly and projectIndex > 0 then
            if not (item projectIndex of projectActiveList) then set keepTask to false
        end if

        set groupKey to "inbox"
        set groupHeading to "📥 Inbox"
        if keepTask and projectIndex > 0 then
            set groupKey to projectID
            set cacheIndex to my indexOfItem(groupKey, projectCacheIDs)
            if cacheIndex = 0 then
                set folderPathText to my folderPathOf(item projectIndex of projectFolderIDList, folderIDList, folderNameList, folderParentIDList)
                set projectLabelText to item projectIndex of projectNameList
                if folderPathText is not "" then set projectLabelText to folderPathText & " > " & projectLabelText
                set end of projectCacheIDs to groupKey
                set end of projectCacheLabels to projectLabelText
                set end of projectCacheFolders to folderPathText
            else
                set projectLabelText to item cacheIndex of projectCacheLabels
                set folderPathText to item cacheIndex of projectCacheFolders
            end if
            set groupHeading to "📁 " & projectLabelText
            if folderQuery is not "" then
                ignoring case
                    if folderPathText does not contain folderQuery then set keepTask to false
                end ignoring
            end if
        end if

        if keepTask then
            set matchCount to matchCount + 1
            set end of seenIDs to taskID

            set entry to "• " & (item i of taskNameList)
            if item i of flaggedList then set entry to entry & " 🚩"
            set dueDate to item i of dueDateList
            if dueDate is not missing value then
                if dueDate < nowDate then
                    set entry to entry & " ⚠️ overdue since " & (date string of dueDate)
                else
                    set entry to entry & " 📅 due " & (date string of dueDate)
                end if
            end if
            if not availableOnly then
                set isDeferred to false
                set deferDate to item i of deferDateList
                if deferDate is not missing value then
                    if deferDate > nowDate then
                        set isDeferred to true
                        set entry to entry & " ⏸ deferred until " & (date string of deferDate)
                    end if
                end if
                -- OmniFocus also calls deferred tasks blocked; only mention other reasons
                if not isDeferred then
                    if item i of blockedList then set entry to entry & " 🔒 blocked"
                end if
            end if
            set estimateValue to item i of estimateList
            if estimateValue is not missing value then
                if estimateValue > 0 then set entry to entry & " ⏱ " & estimateValue & " min"
            end if
            set tagNames to item i of tagNameLists
            if class of tagNames is not list then set tagNames to {tagNames}
            if (count of tagNames) > 0 then set entry to entry & " 🏷 " & my joinText(tagNames, ", ")
            set createdDate to missing value
            if showAge then
                set createdDate to item i of creationDateList
                if createdDate is not missing value then set entry to entry & " 🕒 " & my ageText(createdDate, nowDate)
            end if
            set entry to entry & " [id:" & taskID & "]"

            if showAge then
                -- One flat list, oldest first (tasks without a creation date last), with the project
                set entry to entry & " " & groupHeading
                set insertAt to (count of flatTexts) + 1
                if createdDate is not missing value then
                    repeat with k from 1 to count of flatDates
                        set otherDate to item k of flatDates
                        if otherDate is missing value then
                            set insertAt to k
                            exit repeat
                        else if otherDate > createdDate then
                            set insertAt to k
                            exit repeat
                        end if
                    end repeat
                end if
                set flatTexts to my insertAtIndex(flatTexts, entry, insertAt)
                set flatDates to my insertAtIndex(flatDates, createdDate, insertAt)
            else
                set groupIndex to my indexOfItem(groupKey, groupKeys)
                if groupIndex = 0 then
                    set end of groupKeys to groupKey
                    set end of groupHeadings to groupHeading
                    set end of groupTexts to entry
                else
                    set item groupIndex of groupTexts to (item groupIndex of groupTexts) & return & entry
                end if
            end if
        end if
    end repeat

    -- Build the report
    set titleText to "🔎 Open tasks"
    if availableOnly then set titleText to "✅ Available tasks"
    set filterText to ""
    if tagDisplayName is not "" then
        set filterText to filterText & " tagged \"" & tagDisplayName & "\""
        if includeSubtags then set filterText to filterText & " (or a child tag)"
    end if
    if folderQuery is not "" then set filterText to filterText & " in folders matching \"" & folderQuery & "\""
    if projectFilterLabel is not "" then set filterText to filterText & " in the project \"" & projectFilterLabel & "\""

    if maxMinutes > 0 then
        set filterText to filterText & " with an estimate of up to " & maxMinutes & " min"
        if includeUnestimated then set filterText to filterText & " (or none)"
    end if

    if matchCount = 0 then
        return titleText & filterText & ": none found"
    end if

    if showAge then
        if (count of flatTexts) > maxResults then
            set flatTexts to items 1 thru maxResults of flatTexts
            set hitLimit to true
        end if
        set matchCount to count of flatTexts
        set reportText to titleText & filterText & " (" & matchCount & "), oldest first"
        repeat with i from 1 to count of flatTexts
            set reportText to reportText & return & (item i of flatTexts)
        end repeat
    else
        set reportText to titleText & filterText & " (" & matchCount & ")"
        repeat with i from 1 to count of groupKeys
            set reportText to reportText & return & return & (item i of groupHeadings) & return & (item i of groupTexts)
        end repeat
    end if
    if hitLimit then
        set reportText to reportText & return & return & "… Limit of " & maxResults & " tasks reached, more tasks may match."
    end if
    return reportText
end run

on indexOfItem(anItem, aList)
    -- Position of anItem in aList, 0 if it is not in the list
    repeat with i from 1 to count of aList
        if (item i of aList) is anItem then return i
    end repeat
    return 0
end indexOfItem

on indexOfID(idText, theID)
    -- Position of an ID in a list that was joined into one text (linefeed & id1 & linefeed & id2 & linefeed ...), 0 if it is
    -- not in it. The search is done by the system and does not loop over the list.
    set matchPosition to 0
    considering case
        set matchPosition to offset of (linefeed & theID & linefeed) in idText
    end considering
    if matchPosition = 0 then return 0
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to linefeed
    set linefeedCount to (count of text items of (text 1 thru matchPosition of idText)) - 1
    set AppleScript's text item delimiters to oldDelims
    return linefeedCount
end indexOfID

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
    return my joinText(pathNames, " > ")
end folderPathOf

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

    -- The names of all tags come with one query (an Apple Event per tag costs about 17 ms)
    tell application "OmniFocus"
        tell default document
            set allTags to every flattened tag
            set allTagNames to name of every flattened tag
        end tell
    end tell

    set exactMatches to {}
    set partialMatches to {}
    repeat with i from 1 to count of allTags
        set candidateTag to item i of allTags
        set candidateName to item i of allTagNames
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

on ageText(createdDate, nowDate)
    -- How long ago a task was created: "today", "3 days", "5 weeks", "4 months", "3 years"
    set dayCount to (nowDate - createdDate) div days
    if dayCount < 1 then return "today"
    if dayCount is 1 then return "1 day"
    if dayCount < 14 then return (dayCount as string) & " days"
    if dayCount < 90 then return ((dayCount div 7) as string) & " weeks"
    if dayCount < 730 then return ((dayCount div 30) as string) & " months"
    return ((dayCount div 365) as string) & " years"
end ageText

on insertAtIndex(aList, anItem, slotIndex)
    -- A copy of aList with anItem inserted before the item at slotIndex (at the end if slotIndex is past the end)
    if slotIndex ≤ 1 then return {anItem} & aList
    if slotIndex > (count of aList) then return aList & {anItem}
    return (items 1 thru (slotIndex - 1) of aList) & {anItem} & (items slotIndex thru -1 of aList)
end insertAtIndex

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
