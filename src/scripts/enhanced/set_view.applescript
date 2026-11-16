on run argv
    -- Change what the front OmniFocus window shows: perspective, search term and focus.
    -- Usage: set_view.applescript "perspective" "search term" "change search" "focus"
    --   perspective:   name of a built-in or custom perspective (empty = keep the current one)
    --   search term:   text for the search field
    --   change search: "yes" sets the search term (an empty term clears the search), anything else keeps it
    --   focus:         project or folder to focus on, or "none" to remove the focus (empty = keep it)
    -- Only the view of the window changes, no task, project or folder is touched.

    if (count of argv) < 4 then
        return "❌ Perspective, search term, change flag and focus are required."
    end if
    set perspectiveText to my trimText(item 1 of argv)
    set searchText to item 2 of argv
    set changeSearch to ((item 3 of argv) is "yes")
    set focusText to my trimText(item 4 of argv)

    if perspectiveText is "" and not changeSearch and focusText is "" then
        return "❌ Give a perspective, a search term or a focus."
    end if

    -- The front window of the default document
    set theWindow to missing value
    tell application "OmniFocus"
        try
            tell default document to set theWindow to document window 1
        end try
    end tell
    if theWindow is missing value then
        return "❌ OmniFocus has no open window. Open a window in OmniFocus first."
    end if

    set resultLines to {}

    -- Perspective: exact name first, then a name that contains the text (only if exactly one fits)
    if perspectiveText is not "" then
        set allNames to {}
        tell application "OmniFocus"
            try
                tell default document to set allNames to perspective names
            end try
        end tell
        set wantedName to ""
        set partialMatches to {}
        repeat with aName in allNames
            set candidateName to contents of aName
            if candidateName is perspectiveText then
                set wantedName to candidateName
                exit repeat
            end if
            if candidateName contains perspectiveText then set end of partialMatches to candidateName
        end repeat
        if wantedName is "" and (count of partialMatches) = 1 then set wantedName to item 1 of partialMatches
        if wantedName is "" then
            if (count of partialMatches) > 1 then
                return "❌ More than one perspective fits \"" & perspectiveText & "\": " & my joinText(partialMatches, ", ")
            end if
            return "❌ Perspective not found: " & perspectiveText & ". Available: " & my joinText(allNames, ", ")
        end if
        tell application "OmniFocus"
            set perspective name of theWindow to wantedName
        end tell
        delay 0.5
        set currentName to ""
        tell application "OmniFocus"
            try
                set currentName to (perspective name of theWindow) as text
            end try
        end tell
        if currentName is not wantedName then
            return "❌ OmniFocus did not switch to the perspective " & wantedName & " (it shows " & currentName & ")."
        end if
        set end of resultLines to "🧭 Perspective: " & wantedName
    end if

    -- Search term
    if changeSearch then
        tell application "OmniFocus"
            set search term of theWindow to searchText
        end tell
        delay 0.3
        set currentSearch to ""
        tell application "OmniFocus"
            try
                set currentSearch to (search term of theWindow) as text
            end try
        end tell
        if searchText is "" then
            set end of resultLines to "🔍 Search cleared"
        else if currentSearch is searchText then
            set end of resultLines to "🔍 Search: \"" & searchText & "\""
        else
            set end of resultLines to "⚠️ The search term was set to \"" & searchText & "\", but OmniFocus shows \"" & currentSearch & "\"."
        end if
    end if

    -- Focus
    if focusText is not "" then
        if focusText is "none" then
            tell application "OmniFocus"
                try
                    set focus of theWindow to {}
                end try
            end tell
            if my waitForFocus(theWindow, true) then
                set end of resultLines to "🎯 Focus removed"
            else
                set end of resultLines to "🎯 Focus removal sent. OmniFocus still reported the old focus when the script looked; check with get_selection."
            end if
        else
            -- A project or a folder, by name, path or id
            set focusItem to missing value
            set focusLabel to ""
            set focusType to "project"
            set projectLookup to my resolveProject(focusText)
            if foundProject of projectLookup is not missing value then
                set focusItem to foundProject of projectLookup
                set focusLabel to my projectLabel(focusItem)
            else if (errorText of projectLookup) starts with "❌ Project not found" then
                set folderLookup to my resolveFolder(focusText)
                if foundFolder of folderLookup is not missing value then
                    set focusItem to foundFolder of folderLookup
                    set focusType to "folder"
                    set focusLabel to my folderLabel(focusItem)
                else if (errorText of folderLookup) starts with "❌ Folder not found" then
                    return my withEarlier(resultLines, "❌ No project or folder found: " & focusText)
                else
                    return my withEarlier(resultLines, errorText of folderLookup)
                end if
            else
                return my withEarlier(resultLines, errorText of projectLookup)
            end if
            try
                tell application "OmniFocus"
                    set focus of theWindow to {focusItem}
                end tell
            on error errMsg
                return my withEarlier(resultLines, "❌ Could not set the focus: " & errMsg)
            end try
            if my waitForFocus(theWindow, false) then
                set end of resultLines to "🎯 Focus: " & focusLabel
                set hintText to my itemStateNote(focusItem, focusType)
                if hintText is not "" then set end of resultLines to hintText
            else
                set end of resultLines to "⚠️ OmniFocus did not accept the focus on " & focusLabel & "."
            end if
        end if
    end if

    return my joinText(resultLines, return)
end run

on focusItemCount(theWindow)
    -- Number of items of the focus. OmniFocus can report an old focus to the script that just changed it,
    -- so a new script process reads it; if that is not possible, the window is asked directly.
    set probeSource to "tell application \"OmniFocus\" to count of (focus of (document window 1 of default document))"
    try
        return (do shell script "/usr/bin/osascript -e " & quoted form of probeSource) as integer
    end try
    set focusTotal to 0
    tell application "OmniFocus"
        try
            set focusTotal to count of (focus of theWindow)
        end try
    end tell
    return focusTotal
end focusItemCount

on waitForFocus(theWindow, wantEmpty)
    -- OmniFocus applies a focus change a moment later: wait up to 3 seconds for the focus to be empty (or not empty)
    repeat 6 times
        delay 0.5
        set focusIsEmpty to (my focusItemCount(theWindow) = 0)
        if focusIsEmpty is wantEmpty then return true
    end repeat
    return false
end waitForFocus

on withEarlier(resultLines, lastLine)
    -- The lines of the steps that worked, then the line of the step that failed
    if (count of resultLines) = 0 then return lastLine
    return my joinText(resultLines, return) & return & lastLine
end withEarlier

on joinText(textItems, separator)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to separator
    set joined to textItems as text
    set AppleScript's text item delimiters to oldDelims
    return joined
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
