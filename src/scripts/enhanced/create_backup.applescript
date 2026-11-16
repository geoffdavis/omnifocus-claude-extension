on run argv
    -- Write a backup archive of the OmniFocus database (OmniFocus' archive command).
    -- Usage: create_backup.applescript "full path" "compression"
    --   full path:   the new archive (a full path starting with / or ~). It must not exist, its folder must exist.
    --                OmniFocus writes the archive as a package (a folder that Finder shows as one file).
    --   compression: "true" (default) or "false": write the archive with data compression

    if (count of argv) < 1 then
        return "❌ The path of the archive is required."
    end if
    set archivePath to my attachmentPath(item 1 of argv)
    set compressionValue to my parseFlag("true")
    if (count of argv) > 1 and my trimItem(item 2 of argv) is not "" then set compressionValue to my parseFlag(my trimItem(item 2 of argv))

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
    set folderPath to ""
    try
        set folderPath to do shell script "/usr/bin/dirname " & quoted form of archivePath
        do shell script "/bin/test -d " & quoted form of folderPath
    on error
        return "❌ The folder of the archive does not exist: " & folderPath & ". Nothing was written."
    end try
    set alreadyThere to false
    try
        do shell script "/bin/test -e " & quoted form of archivePath
        set alreadyThere to true
    end try
    if alreadyThere then
        return "❌ " & archivePath & " exists already. Nothing was written."
    end if

    try
        tell application "OmniFocus"
            archive default document in (POSIX file archivePath) compression (compressionValue is "true")
        end tell
    on error errMsg
        return "❌ OmniFocus could not write the archive: " & errMsg
    end try

    -- The archive can be a file or a folder (a package); report its size either way
    set archiveSize to 0
    try
        set archiveSize to (do shell script "/usr/bin/du -sk " & quoted form of archivePath & " | /usr/bin/cut -f1") as number
    on error
        return "❌ OmniFocus did not write the archive: " & archivePath
    end try
    return "💾 Wrote a backup archive of the database (about " & my attachmentSizeText(archiveSize * 1024) & ") to: " & archivePath
end run

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
