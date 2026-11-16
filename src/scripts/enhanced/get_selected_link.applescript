on run argv
    -- Show what is selected (or open) in another app, with a link for each item that opens it again.
    -- Usage: get_selected_link.applescript "app" "limit"
    --   app: Mail, Safari, Google Chrome (also Brave Browser, Microsoft Edge, Arc, Vivaldi, Chromium), Finder or Contacts
    --   limit: maximum number of items to show (default 10)
    -- Only titles, senders, dates and IDs are read, never the body of a message or the content of a file.
    -- The app is not started by this script; the first use of each app asks for permission to control it.
    -- Each app is controlled by a script that is compiled only when it is needed, so an app that is not installed
    -- does not stop the others.

    set appInput to "Mail"
    if (count of argv) > 0 then
        if (item 1 of argv) is not "" then set appInput to item 1 of argv
    end if
    set maxItems to 10
    if (count of argv) > 1 then
        try
            set maxItems to (item 2 of argv) as integer
        end try
    end if
    if maxItems < 1 then set maxItems to 10

    -- Find out which kind of app it is and its real name
    set appKind to ""
    set appName to ""
    if appInput is "mail" then
        set appKind to "mail"
        set appName to "Mail"
    else if appInput is "safari" or appInput is "safari technology preview" then
        set appKind to "safari"
        set appName to "Safari"
        if appInput is "safari technology preview" then set appName to "Safari Technology Preview"
    else if appInput is "chrome" or appInput is "google chrome" then
        set appKind to "chromium"
        set appName to "Google Chrome"
    else if appInput is "brave" or appInput is "brave browser" then
        set appKind to "chromium"
        set appName to "Brave Browser"
    else if appInput is "edge" or appInput is "microsoft edge" then
        set appKind to "chromium"
        set appName to "Microsoft Edge"
    else if appInput is "arc" or appInput is "vivaldi" or appInput is "chromium" then
        set appKind to "chromium"
        set appName to appInput
        if appInput is "arc" then set appName to "Arc"
        if appInput is "vivaldi" then set appName to "Vivaldi"
        if appInput is "chromium" then set appName to "Chromium"
    else if appInput is "finder" then
        set appKind to "finder"
        set appName to "Finder"
    else if appInput is "contacts" or appInput is "address book" then
        set appKind to "contacts"
        set appName to "Contacts"
    else
        return "❌ Unsupported app: " & appInput & ". Supported apps: Mail, Safari, Google Chrome (also Brave Browser, Microsoft Edge, Arc, Vivaldi, Chromium), Finder, Contacts. Apple Notes cannot be linked because it gives scripts no link to a note. For any other app, give the link of that app to add_task or edit_task (append_note) as text."
    end if

    -- Do not start the app: look at the running processes
    set appIsRunning to false
    try
        do shell script "/usr/bin/pgrep -x " & quoted form of appName
        set appIsRunning to true
    end try
    if not appIsRunning then
        return "❌ " & appName & " is not running. Open " & appName & " and select something first."
    end if

    -- The script for the app returns {total, {{title, detail, raw}, ...}}
    set sourceText to my scriptFor(appKind, appName)
    set scriptResult to {}
    try
        set scriptResult to run script sourceText with parameters {maxItems}
    on error errMsg number errNum
        if errNum is -1743 then
            return "❌ This app is not allowed to control " & appName & ". Allow it in System Settings > Privacy & Security > Automation."
        end if
        return "❌ Could not read the selection in " & appName & ": " & errMsg
    end try
    set totalSelected to item 1 of scriptResult
    set itemList to item 2 of scriptResult

    if totalSelected = 0 then
        if appKind is "safari" or appKind is "chromium" then
            return "❌ " & appName & " has no open window."
        end if
        return "❌ Nothing is selected in " & appName & "."
    end if

    set headerText to "🔗 " & totalSelected & " selected in " & appName
    if appKind is "safari" or appKind is "chromium" then set headerText to "🔗 Front tab of " & appName
    set reportText to headerText
    repeat with i from 1 to count of itemList
        set anItem to item i of itemList
        set itemTitle to item 1 of anItem
        set itemDetail to item 2 of anItem
        set itemRaw to item 3 of anItem
        set reportText to reportText & return & return & "• " & itemTitle
        if itemDetail is not "" then set reportText to reportText & return & "  " & itemDetail
        set reportText to reportText & return & "  Link: " & my linkFor(appKind, itemRaw)
    end repeat
    if totalSelected > (count of itemList) then
        set reportText to reportText & return & return & "… " & (totalSelected - (count of itemList)) & " more selected items not shown."
    end if
    return reportText
end run

on scriptFor(appKind, appName)
    -- Builds the script that reads the selection of the app. It is compiled when it runs.
    set q to "\""
    set src to "on run argv" & linefeed
    set src to src & "set maxN to item 1 of argv" & linefeed
    set src to src & "set outList to {}" & linefeed
    set src to src & "set total to 0" & linefeed
    set src to src & "tell application " & q & appName & q & linefeed
    if appKind is "mail" then
        set src to src & "set sel to selection" & linefeed
        set src to src & "set total to count of sel" & linefeed
        set src to src & "repeat with i from 1 to total" & linefeed
        set src to src & "if i > maxN then exit repeat" & linefeed
        set src to src & "set m to item i of sel" & linefeed
        set src to src & "set end of outList to {subject of m, (sender of m) & \" | \" & ((date received of m) as string), message id of m}" & linefeed
        set src to src & "end repeat" & linefeed
    else if appKind is "safari" then
        set src to src & "if (count of windows) > 0 then" & linefeed
        set src to src & "set t to current tab of front window" & linefeed
        set src to src & "set total to 1" & linefeed
        set src to src & "set end of outList to {name of t, \"\", URL of t}" & linefeed
        set src to src & "end if" & linefeed
    else if appKind is "chromium" then
        set src to src & "if (count of windows) > 0 then" & linefeed
        set src to src & "set t to active tab of front window" & linefeed
        set src to src & "set total to 1" & linefeed
        set src to src & "set end of outList to {title of t, \"\", URL of t}" & linefeed
        set src to src & "end if" & linefeed
    else if appKind is "finder" then
        set src to src & "set sel to selection" & linefeed
        set src to src & "set total to count of sel" & linefeed
        set src to src & "repeat with i from 1 to total" & linefeed
        set src to src & "if i > maxN then exit repeat" & linefeed
        set src to src & "set f to item i of sel" & linefeed
        set src to src & "set end of outList to {name of f, \"\", POSIX path of (f as alias)}" & linefeed
        set src to src & "end repeat" & linefeed
    else if appKind is "contacts" then
        set src to src & "set sel to selection" & linefeed
        set src to src & "set total to count of sel" & linefeed
        set src to src & "repeat with i from 1 to total" & linefeed
        set src to src & "if i > maxN then exit repeat" & linefeed
        set src to src & "set p to item i of sel" & linefeed
        set src to src & "set end of outList to {name of p, \"\", id of p}" & linefeed
        set src to src & "end repeat" & linefeed
    end if
    set src to src & "end tell" & linefeed
    set src to src & "return {total, outList}" & linefeed
    set src to src & "end run" & linefeed
    return src
end scriptFor

on linkFor(appKind, rawValue)
    -- Turns what the app returned into a link that opens the item
    if appKind is "mail" then
        set messageID to rawValue
        if messageID starts with "<" and messageID ends with ">" and (length of messageID) > 2 then
            set messageID to text 2 thru -2 of messageID
        end if
        return "message://%3C" & my urlEncode(messageID, "") & "%3E"
    else if appKind is "finder" then
        return "file://" & my urlEncode(rawValue, "/")
    else if appKind is "contacts" then
        return "addressbook://" & rawValue
    end if
    return rawValue
end linkFor

on urlEncode(theText, extraSafeChars)
    -- Percent-encodes (as UTF-8) everything except letters, digits and - . _ ~ @ and the extra characters
    set safeChars to "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~@" & extraSafeChars
    set encodedText to ""
    repeat with aChar in characters of theText
        set theChar to contents of aChar
        set codeValue to id of theChar
        if codeValue < 128 and safeChars contains theChar then
            set encodedText to encodedText & theChar
        else if codeValue < 128 then
            set encodedText to encodedText & my percentByte(codeValue)
        else if codeValue < 2048 then
            set encodedText to encodedText & my percentByte(192 + (codeValue div 64)) & my percentByte(128 + (codeValue mod 64))
        else if codeValue < 65536 then
            set encodedText to encodedText & my percentByte(224 + (codeValue div 4096)) & my percentByte(128 + ((codeValue div 64) mod 64)) & my percentByte(128 + (codeValue mod 64))
        else
            set encodedText to encodedText & my percentByte(240 + (codeValue div 262144)) & my percentByte(128 + ((codeValue div 4096) mod 64)) & my percentByte(128 + ((codeValue div 64) mod 64)) & my percentByte(128 + (codeValue mod 64))
        end if
    end repeat
    return encodedText
end urlEncode

on percentByte(byteValue)
    set hexDigits to "0123456789ABCDEF"
    return "%" & (character ((byteValue div 16) + 1) of hexDigits) & (character ((byteValue mod 16) + 1) of hexDigits)
end percentByte
