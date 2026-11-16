on run argv
    -- "Clean Up" of OmniFocus: moves inbox items that already have a project into their projects
    -- and hides completed tasks.
    -- Usage: clean_up.applescript

    set inboxBefore to 0
    set inboxAfter to 0
    tell application "OmniFocus"
        try
            set inboxBefore to count of (every inbox task of default document whose completed is false)
        end try
        try
            compact default document
        on error errMsg
            return "❌ Could not clean up: " & errMsg
        end try
        try
            set inboxAfter to count of (every inbox task of default document whose completed is false)
        end try
    end tell

    set movedCount to inboxBefore - inboxAfter
    if movedCount < 0 then set movedCount to 0
    set movedWord to "items"
    if movedCount is 1 then set movedWord to "item"
    return "🧹 Cleaned up: completed tasks are hidden, " & movedCount & " inbox " & movedWord & " moved into projects (" & inboxAfter & " left in the inbox)."
end run
