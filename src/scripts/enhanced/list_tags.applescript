on run argv
    -- List all tags in OmniFocus with hierarchy (indentation shows parent/child relationships)
    -- Usage: list_tags.applescript [include_counts]
    -- Pass "true" as first argument to include per-tag task counts (slower on large databases)

    set includeCounts to false
    if (count of argv) > 0 then
        if item 1 of argv is "true" then set includeCounts to true
    end if

    tell application "OmniFocus"
        tell default document
            set topTags to every tag
            if (count of topTags) = 0 then
                return "🏷️ No tags found in OmniFocus."
            end if

            set flatTags to every flattened tag
            set resultText to "🏷️ Tags (" & (count of flatTags) & "):" & return

            if includeCounts then
                -- Build a tag id→count map in a single pass over tasks
                set tagCountRecord to {}
                set activeTasks to every flattened task whose completed is false
                repeat with aTask in activeTasks
                    set taskTags to tags of aTask
                    repeat with aTag in taskTags
                        set tID to id of aTag
                        set found to false
                        repeat with entry in tagCountRecord
                            if tagID of entry is tID then
                                set tagCount of entry to (tagCount of entry) + 1
                                set found to true
                                exit repeat
                            end if
                        end repeat
                        if not found then
                            set end of tagCountRecord to {tagID:tID, tagCount:1}
                        end if
                    end repeat
                end repeat

                set resultText to resultText & my formatTagsWithCounts(topTags, 0, tagCountRecord)
            else
                set resultText to resultText & my formatTags(topTags, 0)
            end if

            return resultText
        end tell
    end tell
end run

-- Recursively format tags with indentation (no counts)
on formatTags(tagList, depth)
    set output to ""
    tell application "OmniFocus"
        repeat with aTag in tagList
            set indent to ""
            repeat depth times
                set indent to indent & "  "
            end repeat
            set output to output & indent & "• " & name of aTag & my tagSuffix(aTag) & return
            set childTags to every tag of aTag
            if (count of childTags) > 0 then
                set output to output & my formatTags(childTags, depth + 1)
            end if
        end repeat
    end tell
    return output
end formatTags

-- Recursively format tags with indentation and task counts
on formatTagsWithCounts(tagList, depth, tagCountRecord)
    set output to ""
    tell application "OmniFocus"
        repeat with aTag in tagList
            set indent to ""
            repeat depth times
                set indent to indent & "  "
            end repeat
            set tagName to name of aTag
            set tID to id of aTag
            set taggedCount to 0
            repeat with entry in tagCountRecord
                if tagID of entry is tID then
                    set taggedCount to tagCount of entry
                    exit repeat
                end if
            end repeat
            set output to output & indent & "• " & tagName
            if taggedCount > 0 then
                set output to output & " (" & taggedCount & " tasks)"
            end if
            set output to output & my tagSuffix(aTag) & return
            set childTags to every tag of aTag
            if (count of childTags) > 0 then
                set output to output & my formatTagsWithCounts(childTags, depth + 1, tagCountRecord)
            end if
        end repeat
    end tell
    return output
end formatTagsWithCounts

-- Flags and id shown behind a tag name: hidden tags, tags that do not allow next actions, the location, "[id:...]"
on tagSuffix(aTag)
    set suffixText to ""
    tell application "OmniFocus"
        try
            if hidden of aTag then set suffixText to suffixText & " ⏸ hidden"
        end try
        try
            if not (allows next action of aTag) then set suffixText to suffixText & " 🚫 no next action"
        end try
        set locationText to my tagLocationText(aTag)
        if locationText is not "" then set suffixText to suffixText & " 📍 " & locationText
        set suffixText to suffixText & " [id:" & (id of aTag) & "]"
    end tell
    return suffixText
end tagSuffix

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
