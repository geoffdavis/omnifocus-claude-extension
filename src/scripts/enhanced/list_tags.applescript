on run argv
    -- List all tags in OmniFocus with hierarchy (indentation shows parent/child relationships)
    -- Usage: list_tags.applescript [include_counts]
    -- Pass "true" as first argument to include per-tag task counts (remaining and available, child tags included)

    set includeCounts to false
    if (count of argv) > 0 then
        if item 1 of argv is "true" then set includeCounts to true
    end if

    -- Every Apple Event costs about 17 ms, a query for one property of all tags about 0.05 s: the properties of all tags
    -- are fetched at once (the same position in each list is the same tag) and the hierarchy is built from them.
    tell application "OmniFocus"
        tell default document
            set tagIDList to id of every flattened tag
            if (count of tagIDList) = 0 then return "🏷️ No tags found in OmniFocus."
            set tagNameList to name of every flattened tag
            set tagParentIDList to id of container of every flattened tag
            set tagHiddenList to hidden of every flattened tag
            set tagAllowsList to allows next action of every flattened tag
            set tagLocationList to {}
            try
                set tagLocationList to location of every flattened tag
            end try
        end tell
    end tell
    set tagCount to count of tagIDList
    set tagIDText to linefeed & my joinText(tagIDList, linefeed) & linefeed

    -- Counts per tag as OmniFocus works them out (tasks of the tag and of its active child tags): the remaining tasks and the
    -- available ones (not blocked, not deferred). One query each for all tags.
    set tagRemainingCounts to {}
    set tagAvailableCounts to {}
    set hasOmniFocusCounts to false
    if includeCounts then
        try
            tell application "OmniFocus"
                tell default document
                    set tagRemainingCounts to remaining task count of every flattened tag
                    set tagAvailableCounts to available task count of every flattened tag
                end tell
            end tell
            if (count of tagRemainingCounts) = tagCount and (count of tagAvailableCounts) = tagCount then
                -- only numbers are used; anything else means the counts are not usable
                if (class of item 1 of tagRemainingCounts) is integer and (class of item 1 of tagAvailableCounts) is integer then set hasOmniFocusCounts to true
            end if
        end try
    end if

    -- Without those counts (an older OmniFocus): the number of open tasks per tag (the tasks that are not completed),
    -- counted in one pass over all tasks
    set tagTaskCounts to {}
    if includeCounts and not hasOmniFocusCounts then
        repeat with i from 1 to tagCount
            set end of tagTaskCounts to 0
        end repeat
        tell application "OmniFocus"
            tell default document
                set taskTagIDLists to id of tags of every flattened task
                set taskCompletedList to completed of every flattened task
            end tell
        end tell
        repeat with t from 1 to count of taskCompletedList
            if not (item t of taskCompletedList) then
                set idsOfTask to item t of taskTagIDLists
                if class of idsOfTask is not list then set idsOfTask to {idsOfTask}
                repeat with aTagID in idsOfTask
                    set tagIndex to my indexOfID(tagIDText, contents of aTagID)
                    if tagIndex > 0 then set item tagIndex of tagTaskCounts to (item tagIndex of tagTaskCounts) + 1
                end repeat
            end if
        end repeat
    end if

    set resultText to "🏷️ Tags (" & tagCount & "):" & return
    repeat with i from 1 to tagCount
        -- Depth in the hierarchy: the number of parent tags (the container of a top level tag is the document)
        set depth to 0
        set parentID to item i of tagParentIDList
        repeat
            set parentIndex to my indexOfID(tagIDText, parentID)
            if parentIndex = 0 then exit repeat
            set depth to depth + 1
            set parentID to item parentIndex of tagParentIDList
        end repeat
        set indent to ""
        repeat depth times
            set indent to indent & "  "
        end repeat

        set lineText to indent & "• " & (item i of tagNameList)
        if includeCounts then
            if hasOmniFocusCounts then
                if (item i of tagRemainingCounts) > 0 then set lineText to lineText & " (" & (item i of tagRemainingCounts) & " remaining, " & (item i of tagAvailableCounts) & " available)"
            else if (item i of tagTaskCounts) > 0 then
                set lineText to lineText & " (" & (item i of tagTaskCounts) & " tasks)"
            end if
        end if
        if item i of tagHiddenList then set lineText to lineText & " ⏸ hidden"
        if not (item i of tagAllowsList) then set lineText to lineText & " 🚫 no next action"
        if (count of tagLocationList) = tagCount then
            if (item i of tagLocationList) is not missing value then
                set locationText to my locationTextOfTagID(item i of tagIDList)
                if locationText is not "" then set lineText to lineText & " 📍 " & locationText
            end if
        end if
        set resultText to resultText & lineText & " [id:" & (item i of tagIDList) & "]" & return
    end repeat
    return resultText
end run

on indexOfID(idText, theID)
    -- Position of an ID in a list that was joined into one text (linefeed & id1 & linefeed & id2 & linefeed ...), 0 if it is
    -- not in it. The search is done by the system and does not loop over the list.
    if theID is missing value then return 0
    set matchPosition to 0
    considering case
        set matchPosition to offset of (linefeed & theID & linefeed) in idText
    end considering
    if matchPosition = 0 then return 0
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to linefeed
    set linefeedCount to (count of text items of (text 1 thru matchPosition of idText)) - 1
    set AppleScript's text item delimiters to oldDelims
    return linefeedCount
end indexOfID

on joinText(textItems, separator)
    -- Joins a list of text items with a separator
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to separator
    set joinedText to textItems as text
    set AppleScript's text item delimiters to oldDelims
    return joinedText
end joinText

on locationTextOfTagID(tagID)
    -- The location text of the tag with this ID (only asked for tags that have a location)
    tell application "OmniFocus"
        tell default document
            set tagMatches to every flattened tag whose id is tagID
        end tell
    end tell
    if (count of tagMatches) = 0 then return ""
    return my tagLocationText(item 1 of tagMatches)
end locationTextOfTagID

on readTagLocation(aTag)
    -- The location of a tag as {name, latitude, longitude, altitude, radius in km, trigger}, or missing value.
    -- Values that are not set are missing value; the trigger is "arriving", "leaving" or "".
    set locName to ""
    set latValue to missing value
    set lonValue to missing value
    set altValue to missing value
    set radiusValue to missing value
    set triggerText to ""
    tell application "OmniFocus"
        try
            set theLocation to location of aTag
        on error
            return missing value
        end try
        if theLocation is missing value then return missing value
        try
            set locName to name of theLocation
        end try
        try
            set latValue to latitude of theLocation
        end try
        try
            set lonValue to longitude of theLocation
        end try
        try
            set altValue to altitude of theLocation
        end try
        try
            set radiusValue to radius of theLocation
        end try
        try
            set triggerValue to trigger of theLocation
            if triggerValue is notify when arriving then
                set triggerText to "arriving"
            else if triggerValue is notify when leaving then
                set triggerText to "leaving"
            end if
        end try
    end tell
    if latValue is missing value or lonValue is missing value then return missing value
    return {locName, latValue, lonValue, altValue, radiusValue, triggerText}
end readTagLocation

on tagLocationText(aTag)
    -- "Name (50.9787, 11.3235), radius 0.5 km, arriving" or "" for a tag without a location
    set locationInfo to my readTagLocation(aTag)
    if locationInfo is missing value then return ""
    set locationText to ""
    -- Location names are often addresses with line breaks
    if (item 1 of locationInfo) is not "" then set locationText to my singleLineText(item 1 of locationInfo) & " "
    set locationText to locationText & "(" & my formatDecimal(item 2 of locationInfo) & ", " & my formatDecimal(item 3 of locationInfo) & ")"
    if (item 4 of locationInfo) is not missing value then set locationText to locationText & ", altitude " & my formatDecimal(item 4 of locationInfo) & " m"
    if (item 5 of locationInfo) is not missing value then set locationText to locationText & ", radius " & my formatDecimal(item 5 of locationInfo) & " km"
    if (item 6 of locationInfo) is not "" then set locationText to locationText & ", " & (item 6 of locationInfo)
    return locationText
end tagLocationText

on formatDecimal(numberValue)
    -- A number with up to 6 decimals and a point, whatever the language setting of the Mac is
    set scaled to round (numberValue * 1000000) rounding to nearest
    set signText to ""
    if scaled < 0 then
        set signText to "-"
        set scaled to -scaled
    end if
    set intPart to scaled div 1000000
    set fracPart to (scaled mod 1000000) as text
    repeat while (length of fracPart) < 6
        set fracPart to "0" & fracPart
    end repeat
    repeat while (length of fracPart) > 0 and fracPart ends with "0"
        if (length of fracPart) = 1 then
            set fracPart to ""
        else
            set fracPart to text 1 thru -2 of fracPart
        end if
    end repeat
    if fracPart is "" then return signText & (intPart as text)
    return signText & (intPart as text) & "." & fracPart
end formatDecimal

on singleLineText(theText)
    -- Line breaks replaced by ", "
    set savedDelimiters to AppleScript's text item delimiters
    repeat with breakText in {return & linefeed, linefeed, return}
        set AppleScript's text item delimiters to (contents of breakText)
        set textParts to text items of theText
        set AppleScript's text item delimiters to ", "
        set theText to textParts as text
    end repeat
    set AppleScript's text item delimiters to savedDelimiters
    return theText
end singleLineText
