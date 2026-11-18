on run argv
    -- Read OmniFocus settings (stored per database) and preferences (stored per application). Nothing is changed.
    -- Usage: get_settings.applescript "scope" "filter" "limit"
    --   scope:  "document" (default, the settings of the database), "application" (the preferences of the app) or "all"
    --   filter: only entries whose ID contains this text (ignoring case), for example "due" or "review"
    --   limit:  maximum number of entries per group (default 100)

    set scopeName to "document"
    set filterText to ""
    set limitText to ""
    if (count of argv) > 0 and my trimItem(item 1 of argv) is not "" then set scopeName to my trimItem(item 1 of argv)
    if (count of argv) > 1 then set filterText to my trimItem(item 2 of argv)
    if (count of argv) > 2 then set limitText to my trimItem(item 3 of argv)

    if scopeName is not "document" and scopeName is not "application" and scopeName is not "all" then
        return "❌ Invalid scope: " & scopeName & ". Use document, application or all."
    end if
    set maxResults to 100
    if limitText is not "" then
        if not my isDigits(limitText) or (length of limitText) > 5 or (limitText as integer) < 1 then
            return "❌ Invalid limit: " & limitText & ". Use a whole number, 1 or more."
        end if
        set maxResults to limitText as integer
    end if

    set reportText to ""
    if scopeName is "document" or scopeName is "all" then
        set reportText to my settingsReport("document", filterText, maxResults)
    end if
    if scopeName is "application" or scopeName is "all" then
        if reportText is not "" then set reportText to reportText & return & return
        set reportText to reportText & my settingsReport("application", filterText, maxResults)
    end if
    -- The version of OmniFocus first: the available settings and their values depend on it
    set versionLine to my appVersionLine()
    if versionLine is not "" then set reportText to versionLine & return & return & reportText
    return reportText
end run

on appVersionLine()
    -- "🖥 OmniFocus 4.10.1 (build 192.18.1)", or "" if OmniFocus gives neither
    set versionText to ""
    set buildText to ""
    -- Inside the tell block, so that "build number" (a term of the OmniFocus dictionary) is known when compiling
    try
        tell application "OmniFocus"
            set versionText to (version) as text
        end tell
    end try
    try
        tell application "OmniFocus"
            set buildText to (build number) as text
        end tell
    end try
    if versionText is "" and buildText is "" then return ""
    set lineText to "🖥 OmniFocus"
    if versionText is not "" then set lineText to lineText & " " & versionText
    if buildText is not "" then set lineText to lineText & " (build " & buildText & ")"
    return lineText
end appVersionLine

on settingsReport(groupName, filterText, maxResults)
    -- One group: the settings of the database or the preferences of the app, sorted by ID
    set idList to {}
    set groupTitle to "⚙️ Settings of the database"
    if groupName is "application" then set groupTitle to "🔧 Preferences of the app"
    -- Only the IDs are read for all entries: OmniFocus cannot hand over the values of all entries at once,
    -- because a few have a type that AppleScript cannot return (lists, data)
    try
        tell application "OmniFocus"
            if groupName is "document" then
                tell default document
                    set idList to id of every setting
                end tell
            else
                set idList to id of every preference
            end if
        end tell
    on error errMsg
        return groupTitle & ": ❌ could not be read: " & errMsg
    end try
    set totalCount to count of idList

    -- Entries that fit the filter
    set matchPositions to {}
    set matchKeys to {}
    repeat with i from 1 to totalCount
        set idText to (item i of idList) as text
        set fits to true
        if filterText is not "" then
            ignoring case
                if idText does not contain filterText then set fits to false
            end ignoring
        end if
        if fits then
            set end of matchPositions to i
            set end of matchKeys to idText
        end if
    end repeat
    set matchCount to count of matchPositions

    set headerText to groupTitle & " (" & matchCount
    if filterText is not "" then
        set headerText to headerText & " of " & totalCount & " with \"" & filterText & "\"" & ")"
    else
        set headerText to headerText & ")"
    end if
    if matchCount = 0 then return headerText

    set sortedOrder to my sortTextPositions(matchKeys)
    set reportText to headerText
    set shownCount to 0
    repeat with sortedPosition in sortedOrder
        if shownCount ≥ maxResults then exit repeat
        set listIndex to item sortedPosition of matchPositions
        set entryValues to my readEntry(groupName, item sortedPosition of matchKeys, listIndex)
        set valueText to item 1 of entryValues
        set defaultText to item 2 of entryValues
        set entryText to "• " & (item sortedPosition of matchKeys) & " = " & valueText
        if valueText is not defaultText then set entryText to entryText & " (default: " & defaultText & ")"
        set reportText to reportText & return & entryText
        set shownCount to shownCount + 1
    end repeat
    if matchCount > shownCount then
        set reportText to reportText & return & "… " & (matchCount - shownCount) & " more not shown (limit " & maxResults & ")."
    end if
    return reportText
end settingsReport

on readEntry(groupName, idText, listPosition)
    -- {value, default value} of one entry as text. An entry is found by its ID, or by its position as a second try.
    set unreadableText to "(cannot be read: a list or data)"
    set theEntry to missing value
    tell application "OmniFocus"
        try
            if groupName is "document" then
                set theEntry to setting id idText of default document
            else
                set theEntry to preference id idText
            end if
        end try
        if theEntry is missing value then
            try
                if groupName is "document" then
                    set theEntry to setting listPosition of default document
                else
                    set theEntry to preference listPosition
                end if
            end try
        end if
        if theEntry is missing value then return {"(not found)", "(not found)"}
        set valueText to unreadableText
        set defaultText to unreadableText
        try
            set valueText to my valueAsText(value of theEntry)
        end try
        try
            set defaultText to my valueAsText(default value of theEntry)
        end try
    end tell
    return {valueText, defaultText}
end readEntry

on valueAsText(theValue)
    -- A value as text: "(not set)" for missing value, whole numbers without decimals, a decimal point, "(empty)" for ""
    if theValue is missing value then return "(not set)"
    try
        if class of theValue is boolean then
            if theValue then return "true"
            return "false"
        end if
        if class of theValue is real or class of theValue is integer then
            if theValue = (round theValue) then return ((round theValue) as integer) as text
            set numberText to theValue as text
            set oldDelims to AppleScript's text item delimiters
            set AppleScript's text item delimiters to ","
            set numberParts to text items of numberText
            set AppleScript's text item delimiters to "."
            set numberText to numberParts as text
            set AppleScript's text item delimiters to oldDelims
            return numberText
        end if
        set valueText to theValue as text
        if valueText is "" then return "(empty)"
        return valueText
    on error
        return "(a value that cannot be shown as text)"
    end try
end valueAsText

on sortTextPositions(keyList)
    -- The positions 1 to n of keyList in ascending order of the texts (bottom-up merge sort, ignoring case)
    set itemCount to count of keyList
    set orderList to {}
    repeat with i from 1 to itemCount
        set end of orderList to i
    end repeat
    set blockSize to 1
    repeat while blockSize < itemCount
        set mergedList to {}
        set blockStart to 1
        repeat while blockStart ≤ itemCount
            set leftPos to blockStart
            set leftEnd to blockStart + blockSize - 1
            if leftEnd > itemCount then set leftEnd to itemCount
            set rightPos to blockStart + blockSize
            set rightEnd to blockStart + 2 * blockSize - 1
            if rightEnd > itemCount then set rightEnd to itemCount
            repeat while leftPos ≤ leftEnd and rightPos ≤ rightEnd
                set leftKey to item (item leftPos of orderList) of keyList
                set rightKey to item (item rightPos of orderList) of keyList
                set leftFirst to true
                ignoring case
                    if leftKey > rightKey then set leftFirst to false
                end ignoring
                if leftFirst then
                    set end of mergedList to item leftPos of orderList
                    set leftPos to leftPos + 1
                else
                    set end of mergedList to item rightPos of orderList
                    set rightPos to rightPos + 1
                end if
            end repeat
            repeat while leftPos ≤ leftEnd
                set end of mergedList to item leftPos of orderList
                set leftPos to leftPos + 1
            end repeat
            repeat while rightPos ≤ rightEnd
                set end of mergedList to item rightPos of orderList
                set rightPos to rightPos + 1
            end repeat
            set blockStart to blockStart + 2 * blockSize
        end repeat
        set orderList to mergedList
        set blockSize to blockSize * 2
    end repeat
    return orderList
end sortTextPositions

on isDigits(theText)
    -- True if the text is not empty and has only the digits 0 to 9
    if theText is "" then return false
    repeat with aChar in characters of theText
        if "0123456789" does not contain (contents of aChar) then return false
    end repeat
    return true
end isDigits

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
