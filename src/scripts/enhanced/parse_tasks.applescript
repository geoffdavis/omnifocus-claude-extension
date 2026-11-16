on run argv
    -- Turn text into tasks: one task per line, indented lines become subtasks.
    -- Every line is handed to the text parser of OmniFocus ("parse tasks into"), so its inline syntax works
    -- (for example a note after //). A list marker at the start of a line ("- ", "* " or "• ") is removed.
    -- OmniFocus itself turns a multi-line text into one single task, therefore the lines are split here.
    -- Usage: parse_tasks.applescript "text" "project" "parent_task" "single_task" "from_note" "clear_note"
    --   text:        the lines to turn into tasks (leave empty when from_note is used)
    --   project:     put the new tasks into this project (name, "Folder > Project" or "id:<id>"), default is the inbox
    --   parent_task: or create them as subtasks of this open task (name or "id:<id>")
    --   single_task: "true" = the whole text becomes one task (first line is the name, the rest the note)
    --   from_note:   use the note of this open task (name or "id:<id>") as the text; the new tasks become its subtasks
    --   clear_note:  "true" = empty the note of the from_note task after the tasks were created
    -- Everything is checked before anything is created.

    set sourceText to ""
    set projectQuery to ""
    set parentQuery to ""
    set singleTask to false
    set noteSource to ""
    set clearNote to false
    if (count of argv) > 0 then set sourceText to item 1 of argv
    if (count of argv) > 1 then set projectQuery to my trimItem(item 2 of argv)
    if (count of argv) > 2 then set parentQuery to my trimItem(item 3 of argv)
    if (count of argv) > 3 then set singleTask to ((item 4 of argv) is "true")
    if (count of argv) > 4 then set noteSource to my trimItem(item 5 of argv)
    if (count of argv) > 5 then set clearNote to ((item 6 of argv) is "true")

    set hasText to (my trimItem(sourceText) is not "")
    if noteSource is "" and not hasText then return "❌ Give either text or from_note. Nothing was created."
    if noteSource is not "" and hasText then return "❌ Use either text or from_note, not both. Nothing was created."
    if projectQuery is not "" and parentQuery is not "" then return "❌ Use either project or parent_task, not both. Nothing was created."
    if clearNote and noteSource is "" then return "❌ clear_note only works together with from_note. Nothing was created."

    -- The task whose note is the text
    set sourceTask to missing value
    set sourceName to ""
    if noteSource is not "" then
        set sourceLookup to my resolveTask(noteSource)
        if foundTask of sourceLookup is missing value then
            return (errorText of sourceLookup) & return & "Nothing was created."
        end if
        set sourceTask to foundTask of sourceLookup
        tell application "OmniFocus"
            set sourceName to name of sourceTask
            set sourceText to (note of sourceTask) as text
        end tell
        if my trimItem(sourceText) is "" then
            return "❌ The task \"" & sourceName & "\" has no note. Nothing was created."
        end if
    end if

    -- Where the new tasks go
    set destinationProject to missing value
    set destinationTask to missing value
    set destinationText to ""
    if projectQuery is not "" and projectQuery is not "inbox" then
        set projectLookup to my resolveProject(projectQuery)
        if foundProject of projectLookup is missing value then
            return (errorText of projectLookup) & return & "Nothing was created."
        end if
        set destinationProject to foundProject of projectLookup
        set destinationText to " in the project \"" & my projectLabel(destinationProject) & "\""
    else if parentQuery is not "" then
        set parentLookup to my resolveTask(parentQuery)
        if foundTask of parentLookup is missing value then
            return (errorText of parentLookup) & return & "Nothing was created."
        end if
        set destinationTask to foundTask of parentLookup
    else if sourceTask is not missing value then
        set destinationTask to sourceTask
    end if
    if destinationTask is not missing value then
        tell application "OmniFocus" to set destinationName to name of destinationTask
        set destinationText to " below the task \"" & destinationName & "\""
    end if

    -- One entry for every task to create: the text of the line and how deep it is indented
    if singleTask then
        set lineTexts to {sourceText}
        set lineLevels to {0}
    else
        set splitInfo to my splitIntoLines(sourceText)
        set lineTexts to textList of splitInfo
        set lineLevels to levelList of splitInfo
    end if
    if (count of lineTexts) = 0 then
        return "❌ The text did not contain any tasks. Nothing was created."
    end if

    -- Create the tasks one by one; every line is parsed by OmniFocus and then put in its place
    set rootIDs to {}
    set levelTaskIDs to {}
    repeat with i from 1 to count of lineTexts
        set lineText to item i of lineTexts
        set lineLevel to item i of lineLevels
        set newID to ""
        try
            tell application "OmniFocus"
                set parsedTasks to parse tasks into default document with transport text lineText as single task true
                if (count of parsedTasks) = 0 then error "no task was returned"
                set newID to id of (item 1 of parsedTasks)
            end tell
        on error errMsg
            return "❌ OmniFocus could not create the task \"" & lineText & "\": " & errMsg & return & "Tasks created before this line: " & (i - 1)
        end try

        tell application "OmniFocus"
            tell default document
                set newTask to first flattened task whose id is newID
            end tell
            if lineLevel > 0 and (count of levelTaskIDs) ≥ lineLevel then
                -- below the closest task above that is indented less
                set levelParentID to item lineLevel of levelTaskIDs
                tell default document
                    set levelParent to first flattened task whose id is levelParentID
                end tell
                move newTask to end of tasks of levelParent
            else if destinationProject is not missing value then
                move newTask to end of tasks of destinationProject
            else if destinationTask is not missing value then
                move newTask to end of tasks of destinationTask
            end if
        end tell
        if lineLevel is 0 or (count of levelTaskIDs) < lineLevel then set end of rootIDs to newID

        -- remember the task as the latest one of its level
        set keptLevels to lineLevel
        if keptLevels > (count of levelTaskIDs) then set keptLevels to count of levelTaskIDs
        if keptLevels = 0 then
            set levelTaskIDs to {newID}
        else
            set levelTaskIDs to (items 1 thru keptLevels of levelTaskIDs) & {newID}
        end if
    end repeat

    -- Report what was created
    set createdCount to 0
    set reportLines to ""
    repeat with rootID in rootIDs
        tell application "OmniFocus"
            tell default document
                set rootTask to first flattened task whose id is (contents of rootID)
            end tell
        end tell
        set treeInfo to my treeLines(rootTask, 0)
        set createdCount to createdCount + (taskCount of treeInfo)
        if reportLines is "" then
            set reportLines to linesText of treeInfo
        else
            set reportLines to reportLines & return & (linesText of treeInfo)
        end if
    end repeat

    set taskWord to "tasks"
    if createdCount is 1 then set taskWord to "task"
    set reportText to "✅ Created " & createdCount & " " & taskWord & destinationText & ":" & return & reportLines

    if clearNote then
        tell application "OmniFocus" to set note of sourceTask to ""
        set reportText to reportText & return & "🧹 Emptied the note of \"" & sourceName & "\"."
    end if
    return reportText
end run

on splitIntoLines(sourceText)
    -- The non-empty lines of the text without list markers, and how deep each one is indented.
    -- A tab counts like four spaces; a line is a subtask of the closest line above that is indented less.
    -- Returns {textList, levelList}
    set textList to {}
    set levelList to {}
    set openWidths to {}
    repeat with aLine in (paragraphs of sourceText)
        set rawLine to contents of aLine
        set cleanLine to my trimItem(rawLine)
        if cleanLine starts with "- " or cleanLine starts with "* " or cleanLine starts with "• " then
            set cleanLine to my trimItem(text 3 thru -1 of cleanLine)
        end if
        if cleanLine is not "" then
            set indentWidth to 0
            repeat with aChar in characters of rawLine
                if (contents of aChar) is " " then
                    set indentWidth to indentWidth + 1
                else if (contents of aChar) is tab then
                    set indentWidth to indentWidth + 4
                else
                    exit repeat
                end if
            end repeat
            -- close the levels that are indented more than this line
            repeat while (count of openWidths) > 0 and (last item of openWidths) > indentWidth
                if (count of openWidths) = 1 then
                    set openWidths to {}
                else
                    set openWidths to items 1 thru ((count of openWidths) - 1) of openWidths
                end if
            end repeat
            if (count of openWidths) = 0 or (last item of openWidths) < indentWidth then set end of openWidths to indentWidth
            set end of textList to cleanLine
            set end of levelList to (count of openWidths) - 1
        end if
    end repeat
    return {textList:textList, levelList:levelList}
end splitIntoLines

on treeLines(aTask, depth)
    -- The task and all its subtasks as indented lines. Returns {linesText, taskCount}
    set indentText to ""
    repeat depth times
        set indentText to indentText & "    "
    end repeat
    tell application "OmniFocus"
        set taskName to name of aTask
        set taskID to id of aTask
        set childTasks to every task of aTask
    end tell
    set resultLines to indentText & "• " & taskName & " [id:" & taskID & "]"
    set resultCount to 1
    repeat with aChild in childTasks
        set childInfo to my treeLines(contents of aChild, depth + 1)
        set resultLines to resultLines & return & (linesText of childInfo)
        set resultCount to resultCount + (taskCount of childInfo)
    end repeat
    return {linesText:resultLines, taskCount:resultCount}
end treeLines

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
