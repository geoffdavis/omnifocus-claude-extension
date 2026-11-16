on run argv
    -- Rename an existing folder
    -- Usage: rename_folder.applescript "folder name or Parent > Folder" "new name"
    
    if (count of argv) < 2 then
        return "❌ Both folder and new name are required."
    end if
    
    set folderText to item 1 of argv
    set newName to item 2 of argv
    
    if newName is "" then
        return "❌ New folder name cannot be empty."
    end if
    
    -- The folder must exist and be unambiguous
    set folderLookup to my resolveFolder(folderText)
    if foundFolder of folderLookup is missing value then
        return errorText of folderLookup
    end if
    set targetFolder to foundFolder of folderLookup
    set originalLabel to my folderLabel(targetFolder)
    
    tell application "OmniFocus"
        try
            set name of targetFolder to newName
            return "✏️ Renamed folder: \"" & originalLabel & "\" → \"" & newName & "\""
        on error errMsg
            return "❌ Error renaming folder: " & errMsg
        end try
    end tell
end run

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
