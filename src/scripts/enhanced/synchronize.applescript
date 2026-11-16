on run argv
    -- Synchronize OmniFocus with the sync database set in OmniFocus > Settings > Sync.
    -- Usage: synchronize.applescript "wait_seconds"
    --   wait_seconds: wait until the synchronization is finished, at most this many seconds (default 15, 0 = do not wait)

    set waitSeconds to 15
    if (count of argv) > 0 then
        try
            set waitSeconds to (item 1 of argv) as integer
        end try
    end if
    if waitSeconds < 0 then set waitSeconds to 0
    if waitSeconds > 120 then set waitSeconds to 120

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
        if alreadySyncing then return "🔄 A synchronization is already running."
        return "🔄 Synchronization started."
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
        return "🔄 Synchronization " & my startedText(alreadySyncing) & " and is still running after " & waitSeconds & " seconds."
    end if
    return "✅ Synchronized: OmniFocus reports that no synchronization is running any more."
end run

on startedText(alreadySyncing)
    if alreadySyncing then return "was already running"
    return "started"
end startedText
