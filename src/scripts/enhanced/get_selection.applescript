on run argv
    -- Show what the front OmniFocus window shows: perspective, search term, focus and the selected items.
    -- Usage: get_selection.applescript
    -- Every selected item is shown with its type, its name and its ID, so that other tools can take it
    -- with "id:<id>". Nothing is changed.

    set maxItems to 20

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

    -- Perspective, sidebar tab, search term
    set perspectiveText to ""
    set tabText to ""
    set searchText to ""
    tell application "OmniFocus"
        try
            set perspectiveText to (perspective name of theWindow) as text
        end try
        try
            set tabText to (selected sidebar tab of theWindow) as text
        end try
        try
            set searchText to (search term of theWindow) as text
        end try
    end tell
    if tabText ends with " tab" then set tabText to text 1 thru -5 of tabText

    -- Focus
    set focusText to my focusSummary(theWindow)

    -- Selected items of the content area and of the sidebar
    set contentLines to {}
    set contentTotal to 0
    set sidebarLines to {}
    set sidebarTotal to 0
    tell application "OmniFocus"
        try
            set contentTrees to every selected tree of (content of theWindow)
            set contentTotal to count of contentTrees
            repeat with i from 1 to contentTotal
                if i > maxItems then exit repeat
                set end of contentLines to my describeTree(item i of contentTrees)
            end repeat
        end try
        try
            set sidebarTrees to every selected tree of (sidebar of theWindow)
            set sidebarTotal to count of sidebarTrees
            repeat with i from 1 to sidebarTotal
                if i > maxItems then exit repeat
                set end of sidebarLines to my describeTree(item i of sidebarTrees)
            end repeat
        end try
    end tell

    set reportText to "🧭 Perspective: " & perspectiveText
    if tabText is not "" then set reportText to reportText & " (sidebar: " & tabText & ")"
    if searchText is "" then
        set reportText to reportText & return & "Search: none"
    else
        set reportText to reportText & return & "Search: \"" & searchText & "\""
    end if
    set reportText to reportText & return & "Focus: " & focusText
    set viewText to my viewOptionsText(theWindow)
    if viewText is not "" then set reportText to reportText & return & "List view: " & viewText

    if contentTotal = 0 and sidebarTotal = 0 then
        return reportText & return & "Selected: nothing"
    end if
    if contentTotal > 0 then
        set reportText to reportText & return & return & "Selected in the list: " & contentTotal
        repeat with lineText in contentLines
            set reportText to reportText & return & "• " & lineText
        end repeat
        if contentTotal > (count of contentLines) then
            set reportText to reportText & return & "… " & (contentTotal - (count of contentLines)) & " more not shown."
        end if
    end if
    if sidebarTotal > 0 then
        set reportText to reportText & return & return & "Selected in the sidebar: " & sidebarTotal
        repeat with lineText in sidebarLines
            set reportText to reportText & return & "• " & lineText
        end repeat
        if sidebarTotal > (count of sidebarLines) then
            set reportText to reportText & return & "… " & (sidebarTotal - (count of sidebarLines)) & " more not shown."
        end if
    end if
    set reportText to reportText & return & return & "Use id:<id> to give one of these items to get_task, get_project, edit_task and the other tools."
    return reportText
end run

on viewOptionsText(theWindow)
    -- Grouping, sorting and filters of the list and the smart group of the sidebar, as OmniFocus names them ("" if it gives none)
    set partList to {}
    tell application "OmniFocus"
        try
            set end of partList to "grouping " & ((selected grouping identifier of (content of theWindow)) as text)
        end try
        try
            set end of partList to "sorting " & ((selected sorting identifier of (content of theWindow)) as text)
        end try
        try
            set end of partList to "tasks " & ((selected task state filter identifier of (content of theWindow)) as text)
        end try
        try
            set end of partList to "duration " & ((selected task duration filter identifier of (content of theWindow)) as text)
        end try
        try
            set end of partList to "flagged " & ((selected task flagged filter identifier of (content of theWindow)) as text)
        end try
        try
            set smartGroupID to (selected smart group identifier of (sidebar of theWindow)) as text
            if smartGroupID is not "missing value" and smartGroupID is not "" then set end of partList to "smart group " & smartGroupID
        end try
    end tell
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ", "
    set joined to partList as text
    set AppleScript's text item delimiters to oldDelims
    return joined
end viewOptionsText

on describeTree(aTree)
    -- "task: Name [id:…]" for one selected row of the content area or the sidebar
    set typeText to "item"
    set nameText to ""
    set idText to ""
    set extraText to ""
    tell application "OmniFocus"
        try
            set theValue to value of aTree
            set typeText to (class of theValue) as text
            try
                set nameText to name of theValue
            end try
            try
                set idText to id of theValue
            end try
            if typeText is "task" then
                try
                    set parentProject to containing project of theValue
                    if parentProject is not missing value then set extraText to " (in " & (name of parentProject) & ")"
                end try
            end if
        on error
            try
                set nameText to name of aTree
            end try
            try
                set idText to id of aTree
            end try
        end try
    end tell
    set lineText to typeText & ": " & nameText & extraText
    if idText is not "" then set lineText to lineText & " [id:" & idText & "]"
    return lineText
end describeTree

on focusSummary(theWindow)
    -- Names of the projects and folders the window is focused on, or "none"
    set focusCount to 0
    set focusNames to {}
    tell application "OmniFocus"
        try
            set focusValue to focus of theWindow
            set focusCount to count of focusValue
            repeat with aFocus in focusValue
                -- OmniFocus does not always give the name directly: then look the project or folder up by its ID
                set focusName to ""
                try
                    set focusName to name of (contents of aFocus)
                end try
                if focusName is "" then
                    try
                        set focusName to name of aFocus
                    end try
                end if
                if focusName is "" then
                    try
                        set focusID to id of (contents of aFocus)
                        tell default document
                            try
                                set focusName to name of (first flattened project whose id is focusID)
                            end try
                            if focusName is "" then
                                try
                                    set focusName to name of (first flattened folder whose id is focusID)
                                end try
                            end if
                        end tell
                    end try
                end if
                if focusName is not "" then set end of focusNames to focusName
            end repeat
        end try
    end tell
    if focusCount = 0 then return "none"
    if (count of focusNames) = 0 then return (focusCount as text) & " item(s)"
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ", "
    set joined to focusNames as text
    set AppleScript's text item delimiters to oldDelims
    return joined
end focusSummary
