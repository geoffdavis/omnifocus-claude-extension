on run argv
    -- Undo or redo the last change(s) in OmniFocus, whoever made them.
    -- Usage: undo.applescript "action" "steps"
    --   action: "undo" (default) or "redo"
    --   steps: how many steps to go back or forward (default 1, at most 20)

    set actionName to "undo"
    if (count of argv) > 0 then
        if (item 1 of argv) is not "" then set actionName to item 1 of argv
    end if
    if actionName is not "undo" and actionName is not "redo" then
        return "❌ Unknown action: " & actionName & ". Valid actions: undo, redo"
    end if
    set stepCount to 1
    if (count of argv) > 1 then
        try
            set stepCount to (item 2 of argv) as integer
        end try
    end if
    if stepCount < 1 then set stepCount to 1
    if stepCount > 20 then set stepCount to 20

    set doneCount to 0
    set canUndoNow to false
    set canRedoNow to false
    tell application "OmniFocus"
        repeat stepCount times
            set stepPossible to false
            try
                if actionName is "redo" then
                    set stepPossible to can redo of default document
                else
                    set stepPossible to can undo of default document
                end if
            end try
            if not stepPossible then exit repeat
            try
                if actionName is "redo" then
                    redo default document
                else
                    undo default document
                end if
            on error errMsg
                return "❌ Could not " & actionName & " (" & doneCount & " steps done): " & errMsg
            end try
            set doneCount to doneCount + 1
        end repeat
        try
            set canUndoNow to can undo of default document
        end try
        try
            set canRedoNow to can redo of default document
        end try
    end tell

    if doneCount = 0 then
        if actionName is "redo" then return "ℹ️ Nothing to redo."
        return "ℹ️ Nothing to undo."
    end if
    set stepWord to "steps"
    if doneCount is 1 then set stepWord to "step"
    set resultText to "↩️ Undid " & doneCount & " " & stepWord & "."
    if actionName is "redo" then set resultText to "↪️ Redid " & doneCount & " " & stepWord & "."
    return resultText & " More can be undone: " & my yesNo(canUndoNow) & ", more can be redone: " & my yesNo(canRedoNow) & "."
end run

on yesNo(flagValue)
    if flagValue then return "yes"
    return "no"
end yesNo
