on run argv
    -- The days of the Forecast with the badge counts that the Forecast sidebar of OmniFocus shows.
    -- Usage: get_forecast.applescript "days"
    --   days: how many days to list (1 to 35, the first one is "Past")
    -- OmniFocus gives the days only while the Forecast is shown, so the window switches to it for a moment and back.
    -- Nothing but the view of the window changes.

    set maxDays to 14
    if (count of argv) ≥ 1 then
        try
            set maxDays to (item 1 of argv) as integer
        end try
    end if
    if maxDays < 1 then set maxDays to 1
    if maxDays > 35 then set maxDays to 35

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

    -- Is the Forecast shown? If not, switch to it and remember the perspective
    set originalName to ""
    set sidebarClass to ""
    tell application "OmniFocus"
        try
            set originalName to (perspective name of theWindow) as text
        end try
        try
            set sidebarClass to (class of (sidebar of theWindow)) as text
        end try
    end tell
    set switched to false
    if sidebarClass is not "forecast sidebar tree" then
        tell application "OmniFocus"
            try
                set selected sidebar tab of theWindow to forecast tab
            on error
                try
                    set perspective name of theWindow to "Forecast"
                end try
            end try
        end tell
        set switched to true
        delay 1
        tell application "OmniFocus"
            try
                set sidebarClass to (class of (sidebar of theWindow)) as text
            end try
        end tell
    end if

    -- Read the days
    set dayNames to {}
    set dayIDs to {}
    set dayBadges to {}
    set dayEmpty to {}
    set readError to ""
    if sidebarClass is "forecast sidebar tree" then
        tell application "OmniFocus"
            try
                set dayTotal to count of forecast day of (sidebar of theWindow)
                repeat with i from 1 to dayTotal
                    if i > maxDays then exit repeat
                    set end of dayNames to (name of forecast day i of (sidebar of theWindow)) as text
                    set end of dayIDs to (id of forecast day i of (sidebar of theWindow)) as text
                    set end of dayBadges to (badge count of forecast day i of (sidebar of theWindow)) as integer
                    set end of dayEmpty to (empty of forecast day i of (sidebar of theWindow)) as boolean
                end repeat
            on error errMsg
                set readError to errMsg
            end try
        end tell
    end if

    -- Back to the perspective of before
    if switched and originalName is not "" then
        tell application "OmniFocus"
            try
                set perspective name of theWindow to originalName
            end try
        end tell
        delay 0.5
    end if

    if sidebarClass is not "forecast sidebar tree" then
        return "❌ OmniFocus did not show the Forecast, so the days could not be read."
    end if
    if readError is not "" then
        return "❌ The days of the Forecast could not be read: " & readError
    end if
    if (count of dayNames) = 0 then
        return "ℹ️ The Forecast has no days."
    end if

    set reportText to "📅 Forecast: " & (count of dayNames) & " days (the numbers are the badges of the Forecast sidebar of OmniFocus)"
    repeat with i from 1 to count of dayNames
        set lineText to "• " & (item i of dayNames)
        if (item i of dayIDs) is not "past" then set lineText to lineText & " (" & (item i of dayIDs) & ")"
        set lineText to lineText & ": " & (item i of dayBadges)
        if item i of dayEmpty then set lineText to lineText & " (empty)"
        set reportText to reportText & return & lineText
    end repeat
    return reportText
end run
