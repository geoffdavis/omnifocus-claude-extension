on run argv
    -- Write a backup archive of the OmniFocus database (OmniFocus' archive command) without blocking the caller.
    -- Usage: create_backup.applescript "full path" "compression" "wait_seconds" "status_only"
    --   full path:    the new archive (a full path starting with / or ~). It must not exist, its folder must exist.
    --                 OmniFocus writes the archive as a package (a folder that Finder shows as one file).
    --   compression:  "true" (default) or "false": write the archive with data compression
    --   wait_seconds: wait until the archive is written, at most this many seconds (default 40, 0 = do not wait, at most 70).
    --                 A large database can need more than a minute; the archive keeps being written in the background.
    --   status_only:  "true" = start nothing, only report whether the archive at this path is written, still being written
    --                 or failed (the answer to a call that stopped waiting)
    -- The archive command runs in a separate osascript process. A slow archive therefore never blocks this script, and a
    -- caller that stops waiting (the connection of the app gives up after about 80 seconds) cannot cut it off half way.
    -- That process leaves its result in a small file in the temp folder of the user, which status_only reads.

    if (count of argv) < 1 then
        return "❌ The path of the archive is required."
    end if
    set archivePath to my attachmentPath(item 1 of argv)
    set compressionValue to my parseFlag("true")
    if (count of argv) > 1 and my trimItem(item 2 of argv) is not "" then set compressionValue to my parseFlag(my trimItem(item 2 of argv))
    set waitSeconds to 40
    if (count of argv) > 2 and my trimItem(item 3 of argv) is not "" then
        set waitText to my trimItem(item 3 of argv)
        if not my isDigits(waitText) or (length of waitText) > 4 then
            return "❌ Invalid wait_seconds: " & waitText & ". Use a whole number of seconds, 0 or more. Nothing was written."
        end if
        set waitSeconds to waitText as integer
    end if
    if waitSeconds > 70 then set waitSeconds to 70
    set statusOnly to false
    if (count of argv) > 3 and my trimItem(item 4 of argv) is "true" then set statusOnly to true

    -- Check every value before anything is written
    if archivePath is "" then
        return "❌ The path of the archive is missing. Nothing was written."
    end if
    if archivePath does not start with "/" then
        return "❌ Give the full path of the archive, starting with / or ~. Nothing was written."
    end if
    if compressionValue is "" then
        return "❌ Invalid value for compression: " & (item 2 of argv) & ". Use true or false. Nothing was written."
    end if

    set markerPath to my markerPathFor(archivePath)
    if statusOnly then return my statusReport(archivePath, markerPath)

    -- A backup for this path that is already being written is only waited for; one that is finished is reported
    set stateName to my backupState(markerPath)
    if stateName is not "running" then
        if my pathExists(archivePath) then
            if stateName is "done" then return my statusReport(archivePath, markerPath)
            return "❌ " & archivePath & " exists already. Nothing was written. status_only shows what is known about it."
        end if
        set folderPath to ""
        try
            set folderPath to do shell script "/usr/bin/dirname " & quoted form of archivePath
            do shell script "/bin/test -d " & quoted form of folderPath
        on error
            return "❌ The folder of the archive does not exist: " & folderPath & ". Nothing was written."
        end try
        set startError to my startArchive(archivePath, compressionValue, markerPath)
        if startError is not "" then
            return "❌ The backup could not be started: " & startError
        end if
        set stateName to my backupState(markerPath)
    end if

    -- Wait for the result, at most waitSeconds
    repeat with i from 1 to waitSeconds
        if stateName is not "running" then exit repeat
        delay 1
        set stateName to my backupState(markerPath)
    end repeat

    if stateName is "running" then
        return "🔄 The backup is being written in the background and was not finished after " & waitSeconds & " seconds: " & archivePath & my sizeSoFarText(archivePath) & return & "It keeps running. Check it with create_backup, the same path and status_only true."
    end if
    return my statusReport(archivePath, markerPath)
end run

on startArchive(archivePath, compressionValue, markerPath)
    -- Starts the archive command in a separate osascript process that runs on its own. Returns "" or the error text.
    -- The process writes "done" or "error: <message>" to the marker file when OmniFocus has answered.
    try
        do shell script "/bin/rm -f " & quoted form of markerPath & " " & quoted form of (markerPath & ".pid")
        do shell script "/bin/echo running > " & quoted form of markerPath
        set runnerLines to {"on run argv", "set archivePath to item 1 of argv", "set compressionFlag to ((item 2 of argv) is \"true\")", "set markerPath to item 3 of argv", "set outcome to \"done\"", "try", "tell application \"OmniFocus\" to archive default document in (POSIX file archivePath) compression compressionFlag", "on error errMsg", "set outcome to \"error: \" & errMsg", "end try", "do shell script \"/bin/echo \" & quoted form of outcome & \" > \" & quoted form of markerPath", "end run"}
        set shellCommand to "/usr/bin/nohup /usr/bin/osascript"
        repeat with aLine in runnerLines
            set shellCommand to shellCommand & " -e " & quoted form of (contents of aLine)
        end repeat
        set shellCommand to shellCommand & " " & quoted form of archivePath & " " & compressionValue & " " & quoted form of markerPath & " > /dev/null 2>&1 & echo $!"
        set processID to do shell script shellCommand
        if my isDigits(processID) then
            do shell script "/bin/echo " & processID & " > " & quoted form of (markerPath & ".pid")
        end if
    on error errMsg
        return errMsg
    end try
    return ""
end startArchive

on backupState(markerPath)
    -- "none" (no backup was started for the path, or the record is gone), "running", "done", "error" or "interrupted"
    -- (the process ended without leaving a result, for example because the Mac went to sleep or OmniFocus quit)
    set markerText to my readFile(markerPath)
    if markerText is "" then return "none"
    if markerText starts with "done" then return "done"
    if markerText starts with "error" then return "error"
    if markerText starts with "running" then
        set processID to my readFile(markerPath & ".pid")
        if not my isDigits(processID) then return "running"
        try
            do shell script "/bin/kill -0 " & processID
            return "running"
        on error
            -- The process is gone: it may just have written its result
            set markerText to my readFile(markerPath)
            if markerText starts with "done" then return "done"
            if markerText starts with "error" then return "error"
            return "interrupted"
        end try
    end if
    return "none"
end backupState

on statusReport(archivePath, markerPath)
    -- What is known about the backup at this path: written, still being written, failed, interrupted or unknown
    set stateName to my backupState(markerPath)
    set existsNow to my pathExists(archivePath)
    set sizeText to ""
    if existsNow then set sizeText to " (about " & my attachmentSizeText(my sizeInBytes(archivePath)) & ")"
    if stateName is "running" then
        return "🔄 The backup is still being written, started " & my ageText(my fileAgeSeconds(markerPath)) & ": " & archivePath & sizeText & return & "Check it again with status_only true."
    else if stateName is "done" then
        if existsNow then return "💾 Wrote a backup archive of the database" & sizeText & " to: " & archivePath & " (finished " & my ageText(my fileAgeSeconds(markerPath)) & ")"
        return "⚠️ OmniFocus reported that the backup was written, but nothing is at: " & archivePath
    else if stateName is "error" then
        set detailText to my readFile(markerPath)
        if detailText starts with "error: " then set detailText to text 8 thru -1 of detailText
        return "❌ OmniFocus could not write the archive: " & detailText
    else if stateName is "interrupted" then
        return "⚠️ The process that writes the backup ended without a result (the Mac may have gone to sleep, or OmniFocus quit). The archive at " & archivePath & sizeText & " may be incomplete: delete it and start the backup again."
    end if
    if existsNow then return "ℹ️ Something is at " & archivePath & sizeText & ", but no backup was started for this path by this tool, so its state is unknown."
    return "ℹ️ Nothing is at " & archivePath & " and no backup was started for it."
end statusReport

on markerPathFor(archivePath)
    -- The file in the temp folder of the user that records how the backup for this path went (one file per path)
    set tempFolder to "/tmp/"
    try
        set tempFolder to do shell script "/usr/bin/getconf DARWIN_USER_TEMP_DIR"
        if tempFolder does not end with "/" then set tempFolder to tempFolder & "/"
    end try
    set pathDigest to "path"
    try
        set pathDigest to do shell script "/sbin/md5 -qs " & quoted form of archivePath
    end try
    return tempFolder & "omnifocus-mcp-backup-" & pathDigest & ".status"
end markerPathFor

on readFile(filePath)
    -- The text of a small file, "" if it does not exist
    try
        return do shell script "/bin/cat " & quoted form of filePath
    on error
        return ""
    end try
end readFile

on pathExists(thePath)
    try
        do shell script "/bin/test -e " & quoted form of thePath
        return true
    on error
        return false
    end try
end pathExists

on sizeInBytes(thePath)
    -- The size of a file or of a whole package (a folder), 0 if it cannot be read
    try
        return ((do shell script "/usr/bin/du -sk " & quoted form of thePath & " | /usr/bin/cut -f1") as number) * 1024
    on error
        return 0
    end try
end sizeInBytes

on sizeSoFarText(thePath)
    if my pathExists(thePath) then return " (about " & my attachmentSizeText(my sizeInBytes(thePath)) & " so far)"
    return ""
end sizeSoFarText

on fileAgeSeconds(filePath)
    -- Seconds since a file was last written, 0 if it cannot be read
    try
        return (do shell script "/bin/echo $(( $(/bin/date +%s) - $(/usr/bin/stat -f %m " & quoted form of filePath & ") ))") as integer
    on error
        return 0
    end try
end fileAgeSeconds

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

on isDigits(theText)
    -- True if the text is not empty and has only the digits 0 to 9
    if theText is "" then return false
    repeat with aChar in characters of theText
        if "0123456789" does not contain (contents of aChar) then return false
    end repeat
    return true
end isDigits

on parseFlag(valueText)
    -- "true" or "false" for the usual spellings, "" for anything else
    ignoring case
        if valueText is "true" or valueText is "yes" or valueText is "1" then return "true"
        if valueText is "false" or valueText is "no" or valueText is "0" then return "false"
    end ignoring
    return ""
end parseFlag

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

on attachmentPath(pathText)
    -- Removes spaces around the path and turns ~ into the home folder
    set cleaned to pathText
    set whitespaceChars to {" ", tab, linefeed, return}
    repeat
        if cleaned is "" then exit repeat
        if whitespaceChars does not contain (character 1 of cleaned) then exit repeat
        if (length of cleaned) = 1 then
            set cleaned to ""
        else
            set cleaned to text 2 thru -1 of cleaned
        end if
    end repeat
    repeat
        if cleaned is "" then exit repeat
        if whitespaceChars does not contain (last character of cleaned) then exit repeat
        if (length of cleaned) = 1 then
            set cleaned to ""
        else
            set cleaned to text 1 thru -2 of cleaned
        end if
    end repeat
    if cleaned is "~" or cleaned starts with "~/" then
        set homePath to POSIX path of (path to home folder)
        if cleaned is "~" or cleaned is "~/" then
            set cleaned to text 1 thru -2 of homePath
        else
            set cleaned to homePath & (text 3 thru -1 of cleaned)
        end if
    end if
    return cleaned
end attachmentPath

on attachmentSizeText(byteCount)
    -- "512 bytes", "12 KB", "3.4 MB"
    if byteCount < 1024 then return ((byteCount as integer) as text) & " bytes"
    if byteCount < 1048576 then return ((round (byteCount / 1024)) as text) & " KB"
    set tenths to round (byteCount / 104857.6)
    return ((tenths div 10) as text) & "." & ((tenths mod 10) as text) & " MB"
end attachmentSizeText
