on run argv
    -- Show a project with its properties and all its tasks as an indented list
    -- Usage: get_project.applescript "project name, Folder > Project or id:<id>" ["true" to include completed and dropped tasks"] [limit]
    -- Open tasks are always listed, also blocked and deferred ones, with their subtasks.

    if (count of argv) = 0 then
        return "❌ Project name is required."
    end if
    set projectText to my trimItem(item 1 of argv)
    if projectText is "" then
        return "❌ Project name cannot be empty."
    end if
    set includeDone to false
    if (count of argv) > 1 then
        ignoring case
            set includeDone to ((item 2 of argv) is "true")
        end ignoring
    end if
    set maxTasks to 300
    if (count of argv) > 2 then
        try
            set maxTasks to (item 3 of argv) as integer
        end try
    end if
    if maxTasks < 1 then set maxTasks to 300

    set projectLookup to my resolveProject(projectText)
    if foundProject of projectLookup is missing value then
        return errorText of projectLookup
    end if
    set targetProject to foundProject of projectLookup
    set nowDate to current date

    -- Project properties
    set reportText to "📂 " & my projectLabel(targetProject)
    tell application "OmniFocus"
        set reportText to reportText & " [id:" & (id of targetProject) & "]" & return

        set statusText to "active"
        set projectStatus to status of targetProject
        if projectStatus is on hold status then
            set statusText to "on hold"
        else if projectStatus is done status then
            set statusText to "completed"
        else if projectStatus is dropped status then
            set statusText to "dropped"
        end if
        set typeText to "parallel"
        if singleton action holder of targetProject then
            set typeText to "single action list"
        else if sequential of targetProject then
            set typeText to "sequential"
        end if
        set reportText to reportText & "Status: " & statusText & " | Type: " & typeText
        if flagged of targetProject then set reportText to reportText & " | 🚩 flagged"
        try
            if completed by children of targetProject then set reportText to reportText & " | completes with its last item"
        end try
        set reportText to reportText & return

        set dateLine to ""
        try
            set deferValue to defer date of targetProject
            if deferValue is not missing value then set dateLine to dateLine & " | Deferred until: " & (deferValue as string)
        end try
        try
            set plannedValue to planned date of targetProject
            if plannedValue is not missing value then set dateLine to dateLine & " | Planned: " & (plannedValue as string)
        end try
        try
            set dueValue to due date of targetProject
            if dueValue is not missing value then set dateLine to dateLine & " | Due: " & (dueValue as string)
        end try
        if dateLine is not "" then set reportText to reportText & (text 4 thru -1 of dateLine) & return

        try
            set lastReview to last review date of targetProject
            set nextReview to next review date of targetProject
            set reviewLine to "Review: " & my reviewIntervalText(targetProject)
            if lastReview is not missing value then set reviewLine to reviewLine & " | last " & (date string of lastReview)
            if nextReview is not missing value then set reviewLine to reviewLine & " | next " & (date string of nextReview)
            set reportText to reportText & reviewLine & return
        end try

        set openCount to count of (flattened tasks of targetProject whose effectively completed is false and effectively dropped is false)
        set doneCount to count of (flattened tasks of targetProject whose completed is true)
        set reportText to reportText & "Tasks: " & openCount & " open, " & doneCount & " completed"
        try
            set nextTask to next task of targetProject
            if nextTask is not missing value then set reportText to reportText & " | Next action: " & (name of nextTask)
        end try
        set reportText to reportText & return

        set projectNote to note of targetProject
        if projectNote is not "" then
            if (length of projectNote) > 500 then set projectNote to (text 1 thru 500 of projectNote) & "..."
            set reportText to reportText & "Note: " & projectNote & return
        end if
    end tell

    -- Tasks
    set treeResult to my taskTree(targetProject, 0, includeDone, nowDate, 0, maxTasks)
    if (usedCount of treeResult) = 0 then
        set reportText to reportText & return & "No tasks"
        if not includeDone then set reportText to reportText & " (completed and dropped tasks are not shown)"
        return reportText
    end if
    set reportText to reportText & return & (linesText of treeResult)
    if limitHit of treeResult then
        set reportText to reportText & return & "… Limit of " & maxTasks & " tasks reached, more tasks exist."
    end if
    set reportText to reportText & return & return & "▶ available  🔒 blocked  ⏸ deferred  📂 action group"
    return reportText
end run

on taskTree(parentItem, depth, includeDone, nowDate, startCount, maxCount)
    -- Lines for the tasks directly below a project or task, each followed by its subtasks.
    -- Returns {linesText, usedCount, limitHit}
    set linesText to ""
    set usedCount to startCount
    set limitReached to false
    set indentText to ""
    repeat depth times
        set indentText to indentText & "    "
    end repeat

    tell application "OmniFocus"
        set childTasks to every task of parentItem
    end tell
    repeat with aChild in childTasks
        set theTask to contents of aChild
        set entryInfo to my taskEntry(theTask, includeDone, nowDate)
        if (entryText of entryInfo) is not "" then
            if usedCount ≥ maxCount then
                set limitReached to true
                exit repeat
            end if
            set usedCount to usedCount + 1
            if linesText is not "" then set linesText to linesText & return
            set linesText to linesText & indentText & (entryText of entryInfo)
            if (childCount of entryInfo) > 0 and depth < 12 then
                set subResult to my taskTree(theTask, depth + 1, includeDone, nowDate, usedCount, maxCount)
                set usedCount to usedCount of subResult
                if (linesText of subResult) is not "" then set linesText to linesText & return & (linesText of subResult)
                if limitHit of subResult then
                    set limitReached to true
                    exit repeat
                end if
            end if
        end if
    end repeat
    return {linesText:linesText, usedCount:usedCount, limitHit:limitReached}
end taskTree

on taskEntry(theTask, includeDone, nowDate)
    -- One line for a task, "" if the task is not shown. Returns {entryText, childCount}
    tell application "OmniFocus"
        set isDone to completed of theTask
        set isDropped to dropped of theTask
        if (isDone or isDropped) and not includeDone then return {entryText:"", childCount:0}

        set childCount to number of tasks of theTask
        set markText to "▶"
        set stateText to ""
        set isDeferred to false
        try
            set deferValue to effective defer date of theTask
            if deferValue is missing value then set deferValue to defer date of theTask
            if deferValue is not missing value and deferValue > nowDate then
                set isDeferred to true
                set stateText to " (deferred until " & (date string of deferValue) & ")"
            end if
        end try
        if isDone then
            set markText to "✓"
            set doneDate to missing value
            try
                set doneDate to completion date of theTask
            end try
            if doneDate is not missing value then set stateText to " (completed " & (date string of doneDate) & ")"
        else if isDropped then
            set markText to "🚫"
            set stateText to " (dropped)"
        else if childCount > 0 then
            set markText to "📂"
            set doneChildren to 0
            try
                set doneChildren to number of completed tasks of theTask
            end try
            set groupNote to ""
            try
                if sequential of theTask then set groupNote to ", sequential"
            end try
            set stateText to stateText & " (" & (childCount - doneChildren) & " of " & childCount & " subtasks open" & groupNote & ")"
        else if isDeferred then
            set markText to "⏸"
        else
            set isBlocked to false
            try
                set isBlocked to blocked of theTask
            end try
            if isBlocked then set markText to "🔒"
        end if

        set entryText to markText & " " & (name of theTask)
        if flagged of theTask then set entryText to entryText & " 🚩"
        if not isDone and not isDropped then
            try
                set dueValue to due date of theTask
                if dueValue is not missing value then
                    if dueValue < nowDate then
                        set entryText to entryText & " ⚠️ overdue since " & (date string of dueValue)
                    else
                        set entryText to entryText & " 📅 due " & (date string of dueValue)
                    end if
                end if
            end try
        end if
        set entryText to entryText & stateText
        try
            set estimateValue to estimated minutes of theTask
            if estimateValue is not missing value and estimateValue > 0 then set entryText to entryText & " ⏱ " & estimateValue & " min"
        end try
        try
            set tagNames to name of tags of theTask
            if (count of tagNames) > 0 then set entryText to entryText & " 🏷 " & my joinText(tagNames, ", ")
        end try
        set entryText to entryText & " [id:" & (id of theTask) & "]"
    end tell
    return {entryText:entryText, childCount:childCount}
end taskEntry

on joinText(textItems, separator)
    -- Joins a list of text items with a separator
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to separator
    set joinedText to textItems as text
    set AppleScript's text item delimiters to oldDelims
    return joinedText
end joinText

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
