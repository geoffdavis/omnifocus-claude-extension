on run argv
    -- List the perspectives of the default document: the built-in ones and the custom ones.
    -- Usage: list_perspectives.applescript
    -- OmniFocus only gives scripts the name and the ID of a perspective, not its rules or its tasks.

    set allNames to {}
    set customNames to {}
    set customIDs to {}
    set unreadableCount to 0
    tell application "OmniFocus"
        tell default document
            try
                set allNames to perspective names
            end try
            set perspectiveList to {}
            try
                set perspectiveList to every perspective
            end try
            -- OmniFocus cannot resolve some built-in perspectives by their ID, so every one is read on its own
            repeat with aPerspective in perspectiveList
                try
                    set thePerspective to contents of aPerspective
                    set perspectiveName to name of thePerspective
                    if (class of thePerspective) is custom perspective then
                        set perspectiveID to ""
                        try
                            set perspectiveID to id of thePerspective
                        end try
                        set end of customNames to perspectiveName
                        set end of customIDs to perspectiveID
                    end if
                on error
                    set unreadableCount to unreadableCount + 1
                end try
            end repeat
        end tell
    end tell

    if (count of allNames) = 0 and (count of customNames) = 0 then
        return "❌ OmniFocus did not return any perspectives."
    end if

    -- Everything that is not a custom perspective is a built-in one
    set builtinNames to {}
    repeat with aName in allNames
        set perspectiveName to contents of aName
        if customNames does not contain perspectiveName then set end of builtinNames to perspectiveName
    end repeat

    set reportText to "🔭 Perspectives: " & (count of builtinNames) & " built-in, " & (count of customNames) & " custom"
    if (count of builtinNames) > 0 then
        set reportText to reportText & return & return & "Built-in"
        repeat with aName in builtinNames
            set reportText to reportText & return & "• " & (contents of aName)
        end repeat
    end if
    if (count of customNames) > 0 then
        set reportText to reportText & return & return & "Custom"
        repeat with i from 1 to count of customNames
            set reportText to reportText & return & "• " & (item i of customNames)
            if (item i of customIDs) is not "" then set reportText to reportText & " [id:" & (item i of customIDs) & "]"
        end repeat
    else if unreadableCount > 0 then
        set reportText to reportText & return & return & "Note: OmniFocus did not allow reading " & unreadableCount & " perspectives, so custom ones may be listed as built-in."
    else
        set reportText to reportText & return & return & "No custom perspectives (they need OmniFocus Pro)."
    end if
    return reportText
end run
