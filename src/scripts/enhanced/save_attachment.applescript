on run argv
    -- Save an embedded attachment of a note as a file
    -- Usage: save_attachment.applescript "task|project|folder" "task, project or folder" "number" "full path of the new file"
    --   number: the number of the attachment as shown by get_task, get_project (1 is the first one)
    --   the path must not exist yet, its folder must exist; a linked file is not copied, its path is shown instead

    if (count of argv) < 4 then
        return "❌ Item type, item, attachment number and destination are required."
    end if
    set itemType to item 1 of argv
    set itemText to item 2 of argv
    set numberText to item 3 of argv
    set destinationText to item 4 of argv

    -- Find the task, project or folder
    set targetItem to missing value
    set itemLabel to ""
    if itemText is "" then
        return "❌ The task, project or folder is required."
    end if
    if itemType is "task" then
        set lookup to my resolveTask(itemText)
        if foundTask of lookup is missing value then return errorText of lookup
        set targetItem to foundTask of lookup
        tell application "OmniFocus" to set itemLabel to name of targetItem
    else if itemType is "project" then
        set lookup to my resolveProject(itemText)
        if foundProject of lookup is missing value then return errorText of lookup
        set targetItem to foundProject of lookup
        set itemLabel to my projectLabel(targetItem)
    else if itemType is "folder" then
        set lookup to my resolveFolder(itemText)
        if foundFolder of lookup is missing value then return errorText of lookup
        set targetItem to foundFolder of lookup
        set itemLabel to my folderLabel(targetItem)
    else
        return "❌ Unknown item type: " & itemType & ". Valid types: task, project, folder"
    end if

    -- The attachment
    set attachmentNumber to 0
    -- Only whole numbers: a text like 1.5 would be rounded by the coercion (or fail, depending on the region)
    set numberClean to my trimItem(numberText)
    if my isDigits(numberClean) and (length of numberClean) < 6 then set attachmentNumber to numberClean as integer
    if attachmentNumber < 1 then
        return "❌ The number of the attachment is needed (1 is the first one, see get_task or get_project)."
    end if
    set attachmentTotal to 0
    set isEmbedded to true
    set linkedPath to ""
    tell application "OmniFocus"
        try
            set attachmentTotal to count of file attachment of (note of targetItem)
        on error errMsg
            return "❌ The note could not be read: " & errMsg
        end try
        if attachmentTotal = 0 then
            return "❌ The note of " & itemLabel & " has no attachments."
        end if
        if attachmentNumber > attachmentTotal then
            return "❌ The note of " & itemLabel & " has only " & attachmentTotal & " attachments."
        end if
        try
            set isEmbedded to embedded of (file attachment attachmentNumber of (note of targetItem))
        end try
        if not isEmbedded then
            try
                set fileReference to file name of (file attachment attachmentNumber of (note of targetItem))
                set linkedPath to POSIX path of fileReference
            end try
        end if
    end tell
    if not isEmbedded then
        if linkedPath is "" then
            return "ℹ️ Attachment " & attachmentNumber & " is a linked file, but OmniFocus does not know its path any more."
        end if
        return "ℹ️ Attachment " & attachmentNumber & " is a linked file, it is not copied: " & linkedPath
    end if

    -- The new file
    set destinationPath to my attachmentPath(destinationText)
    if destinationPath is "" then
        return "❌ The path of the new file is missing. Nothing was saved."
    end if
    if destinationPath does not start with "/" then
        return "❌ Give the full path of the new file, starting with / or ~. Nothing was saved."
    end if
    set folderPath to ""
    try
        set folderPath to do shell script "/usr/bin/dirname " & quoted form of destinationPath
        do shell script "/bin/test -d " & quoted form of folderPath
    on error
        return "❌ The folder of the new file does not exist: " & folderPath & ". Nothing was saved."
    end try
    set alreadyThere to false
    try
        do shell script "/bin/test -e " & quoted form of destinationPath
        set alreadyThere to true
    end try
    if alreadyThere then
        return "❌ " & destinationPath & " exists already. Nothing was saved."
    end if

    try
        tell application "OmniFocus"
            save (file attachment attachmentNumber of (note of targetItem)) in (POSIX file destinationPath)
        end tell
    on error errMsg
        return "❌ Could not save the attachment: " & errMsg
    end try
    set savedSize to 0
    try
        set savedSize to (do shell script "/usr/bin/stat -f %z " & quoted form of destinationPath) as number
    on error
        return "❌ OmniFocus did not write the file: " & destinationPath
    end try
    return "💾 Saved attachment " & attachmentNumber & " of " & itemLabel & " (" & my attachmentSizeText(savedSize) & ") to: " & destinationPath
end run

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

    -- The names and parents of all folders come with one query each (an Apple Event per folder costs about 17 ms)
    tell application "OmniFocus"
        tell default document
            set allFolders to every flattened folder
            set allFolderIDs to id of every flattened folder
            set allFolderNames to name of every flattened folder
            set allFolderParentIDs to id of container of every flattened folder
        end tell
    end tell

    set exactMatches to {}
    set partialMatches to {}
    repeat with folderIndex from 1 to count of allFolders
        set candidateFolder to item folderIndex of allFolders
        set folderNames to my folderNamesFromLists(folderIndex, allFolderIDs, allFolderNames, allFolderParentIDs)
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

on isDigits(theText)
    -- True if the text is not empty and has only the digits 0 to 9
    if theText is "" then return false
    repeat with aChar in characters of theText
        if "0123456789" does not contain (contents of aChar) then return false
    end repeat
    return true
end isDigits

on folderNamesFromLists(folderIndex, idList, nameList, parentIDList)
    -- Folder names from the outermost folder down to the folder at this position, from the lists of all folders
    set pathNames to {item folderIndex of nameList}
    set parentID to item folderIndex of parentIDList
    repeat
        set parentIndex to 0
        repeat with k from 1 to count of idList
            if (item k of idList) is parentID then
                set parentIndex to k
                exit repeat
            end if
        end repeat
        if parentIndex = 0 then exit repeat
        set beginning of pathNames to item parentIndex of nameList
        set parentID to item parentIndex of parentIDList
    end repeat
    return pathNames
end folderNamesFromLists
