on run argv
    -- Create a new project, optionally inside a folder
    -- Usage: create_project.applescript "project name" ["Folder > Subfolder"] ["note"]

    if (count of argv) = 0 then
        return "❌ Project name is required."
    end if

    set projectName to item 1 of argv
    set folderQueryText to ""
    set projectNote to ""
    if (count of argv) > 1 then set folderQueryText to item 2 of argv
    if (count of argv) > 2 then set projectNote to item 3 of argv

    if projectName is "" then
        return "❌ Project name cannot be empty."
    end if

    tell application "OmniFocus"
        tell default document
            try
                if folderQueryText is "" then
                    -- Create at top level
                    set existingProjects to every project whose name is projectName
                    if (count of existingProjects) > 0 then
                        return "⚠️ Project already exists at top level: " & projectName
                    end if
                    set newProject to make new project with properties {name:projectName}
                    set locationText to " (top level)"
                else
                    -- Create inside the folder; the folder must already exist and be unambiguous
                    set folderLookup to my resolveFolder(folderQueryText)
                    if foundFolder of folderLookup is missing value then
                        return errorText of folderLookup
                    end if
                    set targetFolder to foundFolder of folderLookup
                    set existingProjects to every project of targetFolder whose name is projectName
                    if (count of existingProjects) > 0 then
                        return "⚠️ Project already exists in " & my folderLabel(targetFolder) & ": " & projectName
                    end if
                    tell targetFolder
                        set newProject to make new project with properties {name:projectName}
                    end tell
                    set locationText to " (in " & my folderLabel(targetFolder) & ")"
                end if

                if projectNote is not "" then
                    set note of newProject to projectNote
                end if
                return "✅ Created project: " & projectName & locationText
            on error errMsg
                return "❌ Error creating project: " & errMsg
            end try
        end tell
    end tell
end run

on resolveFolder(queryText)
    -- Finds a folder at any depth by name, or by "Folder > Subfolder".
    -- Names match exactly or as a substring, ignoring case.
    -- Returns {foundFolder, errorText}; foundFolder is missing value if nothing or more than one folder fits.
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

    set matchList to "❌ Ambiguous folder \"" & queryText & "\" (" & (count of allMatches) & " matches). Nothing was created. Use \"Folder > Subfolder\" to pick one:"
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
