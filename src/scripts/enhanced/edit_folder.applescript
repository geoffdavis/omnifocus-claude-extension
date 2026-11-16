on run argv
    -- Edit an existing folder
    -- Usage: edit_folder.applescript "folder name, Parent > Folder or id:<id>" "property" "new value"
    -- Properties: name, note, append_note, parent, hidden
    --   parent: an existing folder, or "none" for top level; the folder is moved with everything in it
    --   hidden: true or false

    if (count of argv) < 3 then
        return "❌ Folder, property and value are required."
    end if

    set folderText to item 1 of argv
    set propertyName to item 2 of argv
    set newValue to item 3 of argv

    -- The folder must exist and be unambiguous
    set folderLookup to my resolveFolder(folderText)
    if foundFolder of folderLookup is missing value then
        return errorText of folderLookup
    end if
    set targetFolder to foundFolder of folderLookup
    set originalLabel to my folderLabel(targetFolder)

    tell application "OmniFocus"
        tell default document
            set targetID to id of targetFolder
            set currentName to name of targetFolder
            set currentParent to missing value
            set currentContainer to container of targetFolder
            if class of currentContainer is folder then set currentParent to currentContainer
        end tell
    end tell

    try
        if propertyName is "name" then
            set newName to my trimItem(newValue)
            if newName is "" then
                return "❌ New folder name cannot be empty."
            end if
            if my hasFolderNamed(currentParent, newName, targetID) then
                return "❌ A folder called \"" & newName & "\" already exists at that level. Nothing was changed."
            end if
            tell application "OmniFocus" to set name of targetFolder to newName
            return "✏️ Renamed folder: \"" & originalLabel & "\" → \"" & newName & "\""

        else if propertyName is "note" then
            tell application "OmniFocus" to set note of targetFolder to newValue
            return "✏️ Updated note for folder: " & originalLabel

        else if propertyName is "append_note" then
            -- Add text at the end of the note without touching what is already there
            if newValue is "" then
                return "❌ append_note needs a text to add. Nothing was changed."
            end if
            tell application "OmniFocus" to set currentNote to (note of targetFolder) as text
            if currentNote is "" then
                tell application "OmniFocus" to set note of targetFolder to newValue
            else
                -- Setting the note as plain text would lose attachments and formatting, so refuse in that case
                set noteProblem to my noteFormattingProblem(targetFolder)
                if noteProblem is not "" then
                    return "❌ " & noteProblem & " Nothing was changed."
                end if
                tell application "OmniFocus" to set note of targetFolder to currentNote & linefeed & newValue
            end if
            return "📝 Added to the note of folder: " & originalLabel

        else if propertyName is "parent" then
            if newValue is "none" or newValue is "top level" then
                if currentParent is missing value then
                    return "ℹ️ Folder is already at top level: " & originalLabel
                end if
                if my hasFolderNamed(missing value, currentName, targetID) then
                    return "❌ A top-level folder called \"" & currentName & "\" already exists. Nothing was changed."
                end if
                tell application "OmniFocus"
                    tell default document
                        move targetFolder to end of folders
                    end tell
                end tell
                return "📁 Moved folder \"" & currentName & "\" to top level"
            end if

            -- The new parent must exist, be unambiguous and not be the folder itself or one of its subfolders
            set parentLookup to my resolveFolder(newValue)
            if foundFolder of parentLookup is missing value then
                return errorText of parentLookup
            end if
            set newParent to foundFolder of parentLookup
            tell application "OmniFocus"
                tell default document
                    set newParentID to id of newParent
                    set ownIDs to {targetID}
                    try
                        set ownIDs to ownIDs & (id of every flattened folder of targetFolder)
                    end try
                end tell
            end tell
            if ownIDs contains newParentID then
                return "❌ A folder cannot be moved below itself or one of its subfolders. Nothing was changed."
            end if
            if currentParent is not missing value then
                tell application "OmniFocus" to set currentParentID to id of currentParent
                if currentParentID is newParentID then
                    return "ℹ️ Folder is already below that parent: " & originalLabel
                end if
            end if
            if my hasFolderNamed(newParent, currentName, targetID) then
                return "❌ The new parent already has a subfolder called \"" & currentName & "\". Nothing was changed."
            end if
            tell application "OmniFocus"
                tell default document
                    move targetFolder to end of folders of newParent
                end tell
            end tell
            return "📁 Moved folder \"" & originalLabel & "\" below: " & my folderLabel(newParent)

        else if propertyName is "hidden" then
            set flagValue to my parseFlag(newValue)
            if flagValue is "" then
                return "❌ Unknown value for hidden: " & newValue & ". Valid values: true, false"
            end if
            if flagValue is "true" then
                tell application "OmniFocus" to set hidden of targetFolder to true
                return "🙈 Folder is hidden: " & originalLabel
            end if
            tell application "OmniFocus" to set hidden of targetFolder to false
            return "👁️ Folder is visible: " & originalLabel

        else
            return "❌ Unknown property: " & propertyName & ". Valid properties: name, note, append_note, parent, hidden"
        end if
    on error errMsg
        return "❌ Error updating folder: " & errMsg
    end try
end run

on hasFolderNamed(parentFolder, wantedName, ignoreID)
    -- True if the parent folder (missing value = top level) has a subfolder with this name other than the one with ignoreID
    tell application "OmniFocus"
        tell default document
            if parentFolder is missing value then
                set siblingFolders to every folder
            else
                set siblingFolders to every folder of parentFolder
            end if
            repeat with aSibling in siblingFolders
                if (id of aSibling) is not ignoreID then
                    ignoring case
                        if (name of aSibling) is wantedName then return true
                    end ignoring
                end if
            end repeat
        end tell
    end tell
    return false
end hasFolderNamed

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

on parseFlag(valueText)
    -- "true" or "false" for the usual spellings, "" for anything else
    ignoring case
        if valueText is "true" or valueText is "yes" or valueText is "1" then return "true"
        if valueText is "false" or valueText is "no" or valueText is "0" then return "false"
    end ignoring
    return ""
end parseFlag

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
