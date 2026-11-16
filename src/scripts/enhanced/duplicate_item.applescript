on run argv
    -- Duplicate a task (with its subtasks) or a project (with all its tasks).
    -- Usage: duplicate_item.applescript "task|project" "item" "project" "parent_task" "folder" "new_name" "reopen_completed"
    --   item: a task (open) or a project: name, path "Folder > Project" or "id:<id>"
    --   project, parent_task: where the copy of a task goes ("inbox" for the inbox); without both, directly after the original
    --   folder: where the copy of a project goes ("none" for the top level); without it, directly after the original
    --   new_name: name of the copy; a project copy gets " copy" if the folder already has a project with this name
    --   reopen_completed: "true" opens the completed tasks in the copy again
    -- Notes, tags, dates, estimate, flag and repetition are copied by OmniFocus. A copy loses the dropped state of
    -- tasks, so it is restored here. Folders cannot be duplicated by OmniFocus.

    if (count of argv) < 2 then
        return "❌ Item type and item are required."
    end if
    set itemType to my trimItem(item 1 of argv)
    set itemText to my trimItem(item 2 of argv)
    set projectText to ""
    set parentText to ""
    set folderText to ""
    set newName to ""
    set reopenCompleted to false
    if (count of argv) > 2 then set projectText to my trimItem(item 3 of argv)
    if (count of argv) > 3 then set parentText to my trimItem(item 4 of argv)
    if (count of argv) > 4 then set folderText to my trimItem(item 5 of argv)
    if (count of argv) > 5 then set newName to my trimItem(item 6 of argv)
    if (count of argv) > 6 then set reopenCompleted to ((item 7 of argv) is "true")

    -- Check the values before anything is looked up
    if itemType is not "task" and itemType is not "project" then
        return "❌ Unknown item type: " & itemType & ". Valid types: task, project. Folders cannot be duplicated."
    end if
    if itemText is "" then
        return "❌ The task or project to duplicate is required."
    end if
    if itemType is "task" then
        if folderText is not "" then
            return "❌ folder only applies to projects. A task copy goes into a project (project) or below a task (parent_task). Nothing was duplicated."
        end if
        if projectText is not "" and parentText is not "" then
            return "❌ Give project or parent_task, not both. Nothing was duplicated."
        end if
    else
        if projectText is not "" or parentText is not "" then
            return "❌ project and parent_task only apply to tasks. A project copy goes into a folder (folder). Nothing was duplicated."
        end if
    end if

    -- The original
    set sourceItem to missing value
    set sourceName to ""
    if itemType is "task" then
        set lookup to my resolveTask(itemText)
        if foundTask of lookup is missing value then return (errorText of lookup) & return & "Nothing was duplicated."
        set sourceItem to foundTask of lookup
    else
        set lookup to my resolveProject(itemText)
        if foundProject of lookup is missing value then return (errorText of lookup) & return & "Nothing was duplicated."
        set sourceItem to foundProject of lookup
    end if
    tell application "OmniFocus" to set sourceName to name of sourceItem

    -- The place of the copy
    set destKind to "after"
    set destItem to missing value
    if itemType is "task" then
        if my lowerText(projectText) is "inbox" then
            set destKind to "inbox"
        else if projectText is not "" then
            set lookup to my resolveProject(projectText)
            if foundProject of lookup is missing value then return (errorText of lookup) & return & "Nothing was duplicated."
            set destKind to "project"
            set destItem to foundProject of lookup
        else if parentText is not "" then
            set lookup to my resolveTask(parentText)
            if foundTask of lookup is missing value then return (errorText of lookup) & return & "Nothing was duplicated."
            set destKind to "task"
            set destItem to foundTask of lookup
        end if
    else
        if folderText is "none" then
            set destKind to "top"
        else if folderText is not "" then
            set lookup to my resolveFolder(folderText)
            if foundFolder of lookup is missing value then return (errorText of lookup) & return & "Nothing was duplicated."
            set destKind to "folder"
            set destItem to foundFolder of lookup
        end if
    end if

    -- The name of the copy: a project name is only reused in another folder
    set copyName to newName
    if copyName is "" and itemType is "project" then
        set nameFolder to missing value
        if destKind is "folder" then
            set nameFolder to destItem
        else if destKind is "after" then
            tell application "OmniFocus"
                try
                    set nameFolder to folder of sourceItem
                end try
            end tell
        end if
        if my projectNameTaken(nameFolder, sourceName) then set copyName to sourceName & " copy"
    end if

    -- Duplicate
    set copyItem to missing value
    try
        tell application "OmniFocus"
            tell default document
                if destKind is "after" then
                    set dupResult to duplicate sourceItem to after sourceItem
                else if destKind is "inbox" then
                    set dupResult to duplicate sourceItem to end of inbox tasks
                else if destKind is "project" or destKind is "task" then
                    set dupResult to duplicate sourceItem to end of tasks of destItem
                else if destKind is "folder" then
                    set dupResult to duplicate sourceItem to end of projects of destItem
                else
                    set dupResult to duplicate sourceItem to end of projects
                end if
            end tell
        end tell
        set copyItem to my firstOf(dupResult)
    on error errMsg
        return "❌ OmniFocus could not duplicate the " & itemType & " \"" & sourceName & "\": " & errMsg & ". Nothing was changed."
    end try
    if copyItem is missing value then
        return "⚠️ OmniFocus duplicated the " & itemType & " \"" & sourceName & "\" but did not say where the copy is. Look for it in OmniFocus."
    end if

    -- The dropped state is lost in a copy, the completed state is kept (the copy still has the name of the original here)
    set stateInfo to my restoreStates(sourceItem, copyItem, itemType, reopenCompleted)

    -- Name of the copy
    set problemLines to {}
    if copyName is not "" then
        try
            tell application "OmniFocus" to set name of copyItem to copyName
        on error errMsg
            set end of problemLines to "⚠️ The copy could not be renamed (" & errMsg & "), it keeps the name \"" & sourceName & "\"."
            set copyName to ""
        end try
    end if

    -- Report
    set copyID to ""
    set taskCount to 0
    tell application "OmniFocus"
        set copyID to id of copyItem
        try
            set taskCount to count of (every flattened task of copyItem)
        end try
    end tell
    if copyName is "" then set copyName to sourceName

    set whereText to my copyLocation(copyItem, itemType)
    if itemType is "task" then
        set resultText to "📑 Duplicated task \"" & sourceName & "\": the copy \"" & copyName & "\" is " & whereText
        if taskCount > 0 then set resultText to resultText & " (with " & taskCount & " subtask" & my pluralEnding(taskCount) & ")"
    else
        set resultText to "📑 Duplicated project \"" & sourceName & "\": the copy \"" & copyName & "\" is " & whereText & " (" & taskCount & " task" & my pluralEnding(taskCount) & ")"
    end if
    set resultText to resultText & " [id:" & copyID & "]"

    set droppedAgain to droppedCount of stateInfo
    if droppedAgain > 0 then
        set resultText to resultText & return & "🚫 Dropped tasks stay dropped in the copy: " & droppedAgain & "."
    end if
    set reopenedTotal to reopenedCount of stateInfo
    if reopenedTotal > 0 then
        set resultText to resultText & return & "↩️ Completed tasks reopened in the copy: " & reopenedTotal & "."
    end if
    set stillCompleted to completedLeft of stateInfo
    if stillCompleted > 0 then
        set resultText to resultText & return & "ℹ️ Completed tasks stay completed in the copy: " & stillCompleted & " (reopen_completed: true opens them)."
    end if
    if (problemText of stateInfo) is not "" then set end of problemLines to problemText of stateInfo
    repeat with problemLine in problemLines
        set resultText to resultText & return & problemLine
    end repeat

    if itemType is "project" then
        set hintText to my itemStateNote(copyItem, "project")
        if hintText is not "" then set resultText to resultText & return & hintText
    end if
    return resultText
end run

on firstOf(resultValue)
    -- The result of duplicate is one item or a list of items
    tell application "OmniFocus"
        try
            if class of resultValue is list then
                if (count of resultValue) = 0 then return missing value
                return item 1 of resultValue
            end if
        end try
    end tell
    return resultValue
end firstOf

on pluralEnding(countValue)
    if countValue = 1 then return ""
    return "s"
end pluralEnding

on projectNameTaken(parentFolder, wantedName)
    -- True if a project with this name is directly in the folder (missing value: at the top level)
    try
        tell application "OmniFocus"
            tell default document
                if parentFolder is missing value then
                    return (count of (every project whose name is wantedName)) > 0
                end if
                return (count of (every project of parentFolder whose name is wantedName)) > 0
            end tell
        end tell
    end try
    return false
end projectNameTaken

on copyLocation(copyItem, itemType)
    -- "in the folder X", "at the top level", "in the project X", "below the task X" or "in the inbox"
    tell application "OmniFocus"
        if itemType is "project" then
            try
                set parentFolder to folder of copyItem
                if parentFolder is not missing value then return "in the folder " & my folderLabel(parentFolder)
            end try
            return "at the top level"
        end if
        set copyProject to missing value
        try
            set copyProject to containing project of copyItem
        end try
        if copyProject is missing value then return "in the inbox"
        try
            set parentTask to parent task of copyItem
            if parentTask is not missing value and (id of parentTask) is not (id of copyProject) then
                return "below the task \"" & (name of parentTask) & "\" in the project " & my projectLabel(copyProject)
            end if
        end try
        return "in the project " & my projectLabel(copyProject)
    end tell
end copyLocation

on restoreStates(sourceItem, copyItem, itemType, reopenCompleted)
    -- Drops the tasks again that were dropped in the original (a copy loses this), task by task: the copy has the
    -- same tasks in the same order. Opens the completed tasks of the copy again if reopenCompleted is true.
    -- Returns {droppedCount, reopenedCount, completedLeft, problemText}.
    set droppedCount to 0
    set reopenedCount to 0
    set completedLeft to 0
    set problemText to ""
    try
        tell application "OmniFocus"
            set sourceTasks to every flattened task of sourceItem
            set copyTasks to every flattened task of copyItem
            if itemType is "task" then
                set sourceTasks to {sourceItem} & sourceTasks
                set copyTasks to {copyItem} & copyTasks
            end if
            set pairCount to count of sourceTasks
            set sameTasks to ((count of copyTasks) = pairCount)
            if sameTasks then
                repeat with i from 1 to pairCount
                    if (name of item i of sourceTasks) is not (name of item i of copyTasks) then
                        set sameTasks to false
                        exit repeat
                    end if
                end repeat
            end if
            if sameTasks then
                repeat with i from 1 to pairCount
                    set sourceTask to item i of sourceTasks
                    set copyTask to item i of copyTasks
                    if (dropped of sourceTask) and not (dropped of copyTask) then
                        try
                            mark dropped copyTask
                            set droppedCount to droppedCount + 1
                        end try
                    end if
                end repeat
            else
                set problemText to "⚠️ The tasks of the copy differ from the original, so dropped tasks of the original may be open in the copy."
            end if
            repeat with i from 1 to count of copyTasks
                set copyTask to item i of copyTasks
                if completed of copyTask then
                    if reopenCompleted then
                        try
                            mark incomplete copyTask
                            set reopenedCount to reopenedCount + 1
                        end try
                    else
                        set completedLeft to completedLeft + 1
                    end if
                end if
            end repeat
        end tell
    on error errMsg
        set problemText to "⚠️ The task states of the copy could not be checked (" & errMsg & "): dropped tasks of the original may be open in the copy."
    end try
    return {droppedCount:droppedCount, reopenedCount:reopenedCount, completedLeft:completedLeft, problemText:problemText}
end restoreStates

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

on itemStateNote(anItem, itemType)
    -- A hint for a project that is completed or dropped, or for a project or folder that is hidden or below a hidden
    -- (dropped) folder; "" if nothing is special. Other item types get no hint.
    if itemType is not "project" and itemType is not "folder" then return ""
    set statusText to ""
    set hiddenFolderName to ""
    set hiddenIsItself to false
    set currentFolder to missing value
    tell application "OmniFocus"
        if itemType is "project" then
            try
                set projectStatus to status of anItem
                if projectStatus is done status then set statusText to "completed"
                if projectStatus is dropped status then set statusText to "dropped"
            end try
            try
                set currentFolder to folder of anItem
            end try
        else
            set currentFolder to anItem
        end if
        repeat while currentFolder is not missing value
            try
                if hidden of currentFolder then
                    set hiddenFolderName to name of currentFolder
                    if itemType is "folder" then set hiddenIsItself to ((id of currentFolder) is (id of anItem))
                    exit repeat
                end if
            end try
            try
                set parentContainer to container of currentFolder
                if class of parentContainer is folder then
                    set currentFolder to parentContainer
                else
                    set currentFolder to missing value
                end if
            on error
                set currentFolder to missing value
            end try
        end repeat
    end tell
    set hintText to ""
    if statusText is not "" then set hintText to "the project is " & statusText
    if hiddenFolderName is not "" then
        if hintText is not "" then set hintText to hintText & " and "
        if itemType is "folder" and hiddenIsItself then
            set hintText to hintText & "the folder is hidden"
        else if itemType is "folder" then
            set hintText to hintText & "the folder is below the hidden folder " & hiddenFolderName
        else
            set hintText to hintText & "it is below the hidden folder " & hiddenFolderName
        end if
    end if
    if hintText is "" then return ""
    return "ℹ️ Note: " & hintText & ". OmniFocus may not show it in the window."
end itemStateNote

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
