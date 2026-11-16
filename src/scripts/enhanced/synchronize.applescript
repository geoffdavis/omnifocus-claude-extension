on run argv
    -- Synchronize OmniFocus with the sync database set in OmniFocus > Settings > Sync, and report the last sync state.
    -- Usage: synchronize.applescript "wait_seconds" "status_only"
    --   wait_seconds: wait until the synchronization is finished, at most this many seconds (default 15, 0 = do not wait)
    --   status_only:  "true" = start nothing, only report whether a synchronization is running and how the last one ended

    set waitSeconds to 15
    if (count of argv) > 0 then
        try
            set waitSeconds to (item 1 of argv) as integer
        end try
    end if
    if waitSeconds < 0 then set waitSeconds to 0
    if waitSeconds > 120 then set waitSeconds to 120
    set statusOnly to false
    if (count of argv) > 1 and (item 2 of argv) is "true" then set statusOnly to true

    if statusOnly then
        set isSyncing to false
        tell application "OmniFocus"
            try
                set isSyncing to syncing of default document
            end try
        end tell
        if isSyncing then return "🔄 A synchronization is running." & my syncInfoText()
        return "ℹ️ No synchronization is running." & my syncInfoText()
    end if

    -- OmniFocus refuses to start a second synchronization while one is running; then only wait for it
    set alreadySyncing to false
    tell application "OmniFocus"
        try
            set alreadySyncing to syncing of default document
        end try
        if not alreadySyncing then
            try
                synchronize default document
            on error errMsg
                return "❌ Could not synchronize: " & errMsg
            end try
        end if
    end tell

    if waitSeconds = 0 then
        if alreadySyncing then return "🔄 A synchronization is already running." & my syncInfoText()
        return "🔄 Synchronization started." & my syncInfoText()
    end if

    set stillSyncing to true
    repeat with i from 1 to waitSeconds
        delay 1
        tell application "OmniFocus"
            try
                set stillSyncing to syncing of default document
            on error
                set stillSyncing to false
            end try
        end tell
        if not stillSyncing then exit repeat
    end repeat

    if stillSyncing then
        return "🔄 Synchronization " & my startedText(alreadySyncing) & " and is still running after " & waitSeconds & " seconds." & my syncInfoText()
    end if
    if my lastSyncError() is not "" then
        return "⚠️ The synchronization is finished, but OmniFocus reports an error." & my syncInfoText()
    end if
    return "✅ Synchronized: OmniFocus reports that no synchronization is running any more." & my syncInfoText()
end run

on startedText(alreadySyncing)
    if alreadySyncing then return "was already running"
    return "started"
end startedText

on lastSyncError()
    -- The error message of the last synchronization, "" if there was none
    set errorText to ""
    tell application "OmniFocus"
        try
            set errorValue to last sync error of default document
            if errorValue is not missing value then set errorText to errorValue as text
        end try
    end tell
    return errorText
end lastSyncError

on syncInfoText()
    -- Lines (each starts with a line break) about the last synchronization: when it finished and its error, if any
    set lastDate to missing value
    tell application "OmniFocus"
        try
            set lastDate to last sync date of default document
        end try
    end tell
    if lastDate is missing value then
        set infoText to return & "🕒 No finished synchronization is known (is a sync set up in OmniFocus > Settings > Sync?)."
    else
        set infoText to return & "🕒 Last synchronization: " & (date string of lastDate) & " " & (time string of lastDate) & " (" & my ageText((current date) - lastDate) & ")"
    end if
    set errorText to my lastSyncError()
    if errorText is not "" then set infoText to infoText & return & "⚠️ Error of the last synchronization: " & errorText
    return infoText
end syncInfoText

on ageText(secondsAgo)
    -- "5 seconds ago", "1 minute ago", "3 hours ago", "2 days ago"
    set amount to secondsAgo as integer
    if amount < 0 then set amount to 0
    if amount < 60 then return my countText(amount, "second") & " ago"
    if amount < 3600 then return my countText(amount div 60, "minute") & " ago"
    if amount < 86400 then return my countText(amount div 3600, "hour") & " ago"
    return my countText(amount div 86400, "day") & " ago"
end ageText

on countText(amount, unitName)
    -- "1 minute", "5 minutes"
    if amount is 1 then return "1 " & unitName
    return amount & " " & unitName & "s"
end countText
