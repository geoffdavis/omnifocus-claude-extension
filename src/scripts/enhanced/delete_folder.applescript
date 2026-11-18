on run argv
    -- Delete a folder. Deleting is permanent (undo can bring it back right afterwards).
    -- Usage: delete_folder.applescript "folder name, Parent > Folder or id:<id>" "confirm_delete" "delete_contents"
    --   confirm_delete: must be "true", otherwise nothing is deleted
    --   delete_contents: "true" also deletes the projects and subfolders in the folder; without it only an empty folder is deleted

    if (count of argv) < 1 then
        return "❌ Folder is required."
    end if
    set folderText to item 1 of argv
    set confirmDelete to false
    set deleteContents to false
    if (count of argv) > 1 then set confirmDelete to ((item 2 of argv) is "true")
    if (count of argv) > 2 then set deleteContents to ((item 3 of argv) is "true")

    -- The folder must exist and be unambiguous
    set folderLookup to my resolveFolder(folderText)
    if foundFolder of folderLookup is missing value then
        return errorText of folderLookup
    end if
    set targetFolder to foundFolder of folderLookup
    set originalLabel to my folderLabel(targetFolder)

    -- What the folder contains: projects and subfolders at any depth, and the tasks of the projects
    set projectCount to 0
    set subfolderCount to 0
    set taskCount to 0
    tell application "OmniFocus"
        try
            set projectList to every flattened project of targetFolder
            set projectCount to count of projectList
            repeat with aProject in projectList
                try
                    set taskCount to taskCount + (number of tasks of aProject)
                end try
            end repeat
        end try
        try
            set subfolderCount to count of (every flattened folder of targetFolder)
        end try
    end tell
    set contentText to my countText(projectCount, "project", "projects") & " with " & my countText(taskCount, "task", "tasks") & " and " & my countText(subfolderCount, "subfolder", "subfolders")

    if not confirmDelete then
        return "❌ Deleting a folder is permanent. Nothing was deleted. The folder \"" & originalLabel & "\" contains " & contentText & ". To delete it, call again with confirm_delete true" & my contentHint(projectCount, subfolderCount) & "."
    end if
    if (projectCount > 0 or subfolderCount > 0) and not deleteContents then
        return "❌ The folder \"" & originalLabel & "\" contains " & contentText & ". Nothing was deleted. Set delete_contents to true to delete the folder together with everything in it."
    end if

    try
        tell application "OmniFocus"
            tell default document
                delete targetFolder
            end tell
        end tell
    on error errMsg
        return "❌ Error deleting folder: " & errMsg
    end try
    if projectCount = 0 and subfolderCount = 0 then
        return "🗑️ Deleted folder: " & originalLabel
    end if
    return "🗑️ Deleted folder: " & originalLabel & " (it contained " & contentText & ")"
end run

on contentHint(projectCount, subfolderCount)
    if projectCount > 0 or subfolderCount > 0 then return " and delete_contents true"
    return ""
end contentHint

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

on countText(n, singularWord, pluralWord)
    -- "1 project", "2 projects"
    if n = 1 then return "1 " & singularWord
    return (n as text) & " " & pluralWord
end countText

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
