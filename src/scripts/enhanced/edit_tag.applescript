on run argv
    -- Edit an existing tag
    -- Usage: edit_tag.applescript "tag name, Parent > Tag or id:<id>" "property" "new value"
    -- Properties: name, note, parent, hidden, allows_next_action, location
    --   location: "latitude=50.9787; longitude=11.3235; radius=0.5; trigger=arriving; name=Office"
    --     (name, altitude, radius in km and trigger are optional; fields that are not given keep their value;
    --     "none" removes the location)

    if (count of argv) < 3 then
        return "❌ Tag, property and value are required."
    end if

    set tagText to item 1 of argv
    set propertyName to item 2 of argv
    set newValue to item 3 of argv

    -- Exact name, path or id at any level of the tag hierarchy; an ambiguous name changes nothing
    set tagLookup to my resolveTag(tagText, false)
    if foundTag of tagLookup is missing value then
        return errorText of tagLookup
    end if
    set targetTag to foundTag of tagLookup
    set originalLabel to my joinText(my tagPathNames(targetTag), " > ")

    tell application "OmniFocus"
        tell default document
            set targetID to id of targetTag
            set currentName to name of targetTag
            set currentParent to missing value
            set currentContainer to container of targetTag
            if class of currentContainer is tag then set currentParent to currentContainer
        end tell
    end tell

    try
        if propertyName is "name" then
            set newName to my trimItem(newValue)
            if newName is "" then
                return "❌ New tag name cannot be empty."
            end if
            if my hasTagNamed(currentParent, newName, targetID) then
                return "❌ A tag called \"" & newName & "\" already exists at that level. Nothing was changed."
            end if
            tell application "OmniFocus" to set name of targetTag to newName
            return "✏️ Renamed tag: \"" & originalLabel & "\" → \"" & newName & "\""

        else if propertyName is "note" then
            tell application "OmniFocus" to set note of targetTag to newValue
            return "✏️ Updated note for tag: " & originalLabel

        else if propertyName is "parent" then
            if newValue is "none" or newValue is "top level" then
                if currentParent is missing value then
                    return "ℹ️ Tag is already at top level: " & originalLabel
                end if
                if my hasTagNamed(missing value, currentName, targetID) then
                    return "❌ A top-level tag called \"" & currentName & "\" already exists. Nothing was changed."
                end if
                tell application "OmniFocus"
                    tell default document
                        move targetTag to end of tags
                    end tell
                end tell
                return "🏷️ Moved tag to top level: " & originalLabel
            end if

            -- The new parent must exist, be unambiguous and not be the tag itself or one of its child tags
            set parentLookup to my resolveTag(newValue, false)
            if foundTag of parentLookup is missing value then
                return errorText of parentLookup
            end if
            set newParent to foundTag of parentLookup
            tell application "OmniFocus"
                tell default document
                    set newParentID to id of newParent
                    set ownIDs to {targetID}
                    try
                        set ownIDs to ownIDs & (id of every flattened tag of targetTag)
                    end try
                end tell
            end tell
            if ownIDs contains newParentID then
                return "❌ A tag cannot be moved below itself or one of its child tags. Nothing was changed."
            end if
            if currentParent is not missing value then
                tell application "OmniFocus" to set currentParentID to id of currentParent
                if currentParentID is newParentID then
                    return "ℹ️ Tag is already below that parent: " & originalLabel
                end if
            end if
            if my hasTagNamed(newParent, currentName, targetID) then
                return "❌ The new parent already has a child tag called \"" & currentName & "\". Nothing was changed."
            end if
            tell application "OmniFocus"
                tell default document
                    move targetTag to end of tags of newParent
                end tell
            end tell
            return "🏷️ Moved tag \"" & originalLabel & "\" below: " & my joinText(my tagPathNames(newParent), " > ")

        else if propertyName is "hidden" then
            set flagValue to my parseFlag(newValue)
            if flagValue is "" then
                return "❌ Unknown value for hidden: " & newValue & ". Valid values: true, false"
            end if
            if flagValue is "true" then
                tell application "OmniFocus" to set hidden of targetTag to true
                return "🙈 Tag is hidden: " & originalLabel
            end if
            tell application "OmniFocus" to set hidden of targetTag to false
            return "👁️ Tag is visible: " & originalLabel

        else if propertyName is "allows_next_action" then
            set flagValue to my parseFlag(newValue)
            if flagValue is "" then
                return "❌ Unknown value for allows_next_action: " & newValue & ". Valid values: true, false"
            end if
            if flagValue is "true" then
                tell application "OmniFocus" to set allows next action of targetTag to true
                return "▶️ Tasks with this tag can be next actions: " & originalLabel
            end if
            tell application "OmniFocus" to set allows next action of targetTag to false
            return "⏸️ Tasks with this tag are skipped as next actions: " & originalLabel

        else if propertyName is "location" then
            if newValue is "none" or newValue is "clear" or newValue is "remove" then
                if my readTagLocation(targetTag) is missing value then
                    return "ℹ️ The tag has no location: " & originalLabel
                end if
                tell application "OmniFocus" to set location of targetTag to missing value
                return "📍 Removed the location of the tag: " & originalLabel
            end if
            -- Fields that are not given keep the value of the current location
            set parsedLocation to my parseLocationFields(newValue, my readTagLocation(targetTag), currentName)
            if (item 1 of parsedLocation) is not "" then return item 1 of parsedLocation
            my writeTagLocation(targetTag, item 2 of parsedLocation, item 3 of parsedLocation, item 4 of parsedLocation, item 5 of parsedLocation, item 6 of parsedLocation, item 7 of parsedLocation)
            return "📍 Set the location of the tag \"" & originalLabel & "\": " & my tagLocationText(targetTag)

        else
            return "❌ Unknown property: " & propertyName & ". Valid properties: name, note, parent, hidden, allows_next_action, location"
        end if
    on error errMsg
        return "❌ Error updating tag: " & errMsg
    end try
end run

on parseFlag(valueText)
    -- "true" or "false" for the usual spellings, "" for anything else
    ignoring case
        if valueText is "true" or valueText is "yes" or valueText is "1" then return "true"
        if valueText is "false" or valueText is "no" or valueText is "0" then return "false"
    end ignoring
    return ""
end parseFlag

on splitTagPath(queryText)
    -- Splits "Parent > Child" into trimmed, non-empty parts
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ">"
    set rawParts to text items of queryText
    set AppleScript's text item delimiters to oldDelims

    set queryParts to {}
    repeat with rawPart in rawParts
        set cleanPart to my trimItem(rawPart as string)
        if cleanPart is not "" then set end of queryParts to cleanPart
    end repeat
    return queryParts
end splitTagPath

on resolveTag(queryText, allowPartial)
    -- Finds a tag at any level of the tag hierarchy.
    --   queryText:    tag name, path "Parent > Child" or "id:<id>"
    --   allowPartial: also accept a part of a name, but only if no exact name fits and exactly one tag contains it
    -- Names are compared ignoring case.
    -- Returns {foundTag, errorText, notFound}; foundTag is missing value if no tag or more than one tag fits,
    -- notFound is true only if nothing fits by name or path.
    if queryText starts with "id:" and (length of queryText) > 3 then
        set wantedID to my trimItem(text 4 thru -1 of queryText)
        tell application "OmniFocus"
            tell default document
                set idMatches to every flattened tag whose id is wantedID
            end tell
        end tell
        if (count of idMatches) = 1 then
            return {foundTag:item 1 of idMatches, errorText:"", notFound:false}
        end if
        return {foundTag:missing value, errorText:"❌ Tag not found: " & queryText, notFound:false}
    end if

    set queryParts to my splitTagPath(queryText)
    if (count of queryParts) = 0 then
        return {foundTag:missing value, errorText:"❌ Tag name cannot be empty.", notFound:false}
    end if

    set nameQuery to item -1 of queryParts
    set parentQuery to {}
    if (count of queryParts) > 1 then set parentQuery to items 1 thru -2 of queryParts

    -- The names of all tags come with one query (an Apple Event per tag costs about 17 ms)
    tell application "OmniFocus"
        tell default document
            set allTags to every flattened tag
            set allTagNames to name of every flattened tag
        end tell
    end tell

    set exactMatches to {}
    set partialMatches to {}
    repeat with i from 1 to count of allTags
        set candidateTag to item i of allTags
        set candidateName to item i of allTagNames
        ignoring case
            if candidateName is nameQuery then
                set end of exactMatches to candidateTag
            else if allowPartial and candidateName contains nameQuery then
                set end of partialMatches to candidateTag
            end if
        end ignoring
    end repeat

    if (count of parentQuery) > 0 then
        set exactMatches to my filterByParents(exactMatches, parentQuery, not allowPartial)
        set partialMatches to my filterByParents(partialMatches, parentQuery, not allowPartial)
    end if

    -- A single exact name wins; otherwise every match counts and must be unique
    if (count of exactMatches) = 1 then
        return {foundTag:item 1 of exactMatches, errorText:"", notFound:false}
    end if
    set allMatches to exactMatches & partialMatches
    if (count of allMatches) = 1 then
        return {foundTag:item 1 of allMatches, errorText:"", notFound:false}
    end if
    if (count of allMatches) = 0 then
        return {foundTag:missing value, errorText:"❌ Tag not found: " & queryText, notFound:true}
    end if

    set matchList to "❌ Ambiguous tag \"" & queryText & "\" (" & (count of allMatches) & " matches). Use \"Parent > Tag\" or id:<id> to pick one:"
    repeat with aMatch in allMatches
        set matchTag to contents of aMatch
        tell application "OmniFocus" to set matchID to id of matchTag
        set matchList to matchList & return & "• " & my joinText(my tagPathNames(matchTag), " > ") & " [id:" & matchID & "]"
    end repeat
    return {foundTag:missing value, errorText:matchList, notFound:false}
end resolveTag

on filterByParents(tagList, parentQuery, exactParents)
    -- Keeps the tags whose closest parent tags match parentQuery (outermost first).
    -- exactParents: parent names must be equal, otherwise a part of the name is enough.
    set keptTags to {}
    repeat with aTag in tagList
        set candidateTag to contents of aTag
        set pathNames to my tagPathNames(candidateTag)
        set ancestorCount to (count of pathNames) - 1
        set queryCount to count of parentQuery
        set parentsFit to (queryCount ≤ ancestorCount)
        if parentsFit then
            ignoring case
                repeat with i from 1 to queryCount
                    set wantedName to item i of parentQuery
                    set actualName to item (ancestorCount - queryCount + i) of pathNames
                    if exactParents then
                        if actualName is not wantedName then set parentsFit to false
                    else
                        if actualName does not contain wantedName then set parentsFit to false
                    end if
                end repeat
            end ignoring
        end if
        if parentsFit then set end of keptTags to candidateTag
    end repeat
    return keptTags
end filterByParents

on tagPathNames(aTag)
    -- Tag names from the outermost parent tag down to the tag itself
    set pathNames to {}
    tell application "OmniFocus"
        try
            set currentTag to aTag
            repeat while currentTag is not missing value
                set beginning of pathNames to name of currentTag
                set parentContainer to container of currentTag
                if class of parentContainer is tag then
                    set currentTag to parentContainer
                else
                    set currentTag to missing value
                end if
            end repeat
        end try
    end tell
    return pathNames
end tagPathNames

on findOrCreateTag(queryText)
    -- Finds a tag by exact name, path "Parent > Child" or "id:<id>" and creates it if it does not exist
    -- (at top level, or below the parent tag if a path was given). Never creates a tag for an id.
    -- Returns {foundTag, errorText, wasCreated}
    set lookup to my resolveTag(queryText, false)
    set lookedUpTag to foundTag of lookup
    if lookedUpTag is not missing value then
        return {foundTag:lookedUpTag, errorText:"", wasCreated:false}
    end if
    if not (notFound of lookup) then
        return {foundTag:missing value, errorText:errorText of lookup, wasCreated:false}
    end if

    set queryParts to my splitTagPath(queryText)
    set newName to item -1 of queryParts
    set parentTag to missing value
    if (count of queryParts) > 1 then
        set parentLookup to my resolveTag(my joinText(items 1 thru -2 of queryParts, " > "), false)
        set parentTag to foundTag of parentLookup
        if parentTag is missing value then
            return {foundTag:missing value, errorText:errorText of parentLookup, wasCreated:false}
        end if
    end if

    try
        tell application "OmniFocus"
            tell default document
                if parentTag is missing value then
                    set newTag to make new tag with properties {name:newName}
                else
                    set newTag to make new tag with properties {name:newName} at end of tags of parentTag
                end if
            end tell
        end tell
    on error errMsg
        return {foundTag:missing value, errorText:"❌ Error creating tag: " & errMsg, wasCreated:false}
    end try
    return {foundTag:newTag, errorText:"", wasCreated:true}
end findOrCreateTag

on hasTagNamed(parentTag, wantedName, excludeID)
    -- Is there a tag called wantedName directly below parentTag (missing value = top level),
    -- other than the tag with the id excludeID? Names are compared ignoring case.
    tell application "OmniFocus"
        tell default document
            if parentTag is missing value then
                set siblingTags to every tag
            else
                set siblingTags to every tag of parentTag
            end if
            repeat with aTag in siblingTags
                set siblingTag to contents of aTag
                if (id of siblingTag) is not excludeID then
                    ignoring case
                        if (name of siblingTag) is wantedName then return true
                    end ignoring
                end if
            end repeat
        end tell
    end tell
    return false
end hasTagNamed

on joinText(textItems, separator)
    -- Joins a list of text items with a separator
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to separator
    set joinedText to textItems as text
    set AppleScript's text item delimiters to oldDelims
    return joinedText
end joinText

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

on parseDecimal(valueText)
    -- A number with a point or a comma as decimal separator, whatever the language setting of the Mac is;
    -- missing value if the text is not a number
    set signFactor to 1
    set intDigits to ""
    set fracDigits to ""
    set seenPoint to false
    set charIndex to 0
    repeat with aChar in characters of (my trimItem(valueText))
        set theChar to contents of aChar
        set charIndex to charIndex + 1
        if charIndex = 1 and theChar is "-" then
            set signFactor to -1
        else if charIndex = 1 and theChar is "+" then
            -- a plus sign changes nothing
        else if theChar is "." or theChar is "," then
            if seenPoint then return missing value
            set seenPoint to true
        else if "0123456789" contains theChar then
            if seenPoint then
                set fracDigits to fracDigits & theChar
            else
                set intDigits to intDigits & theChar
            end if
        else
            return missing value
        end if
    end repeat
    if intDigits is "" and fracDigits is "" then return missing value
    if (length of intDigits) > 6 or (length of fracDigits) > 9 then return missing value
    if intDigits is "" then set intDigits to "0"
    set numberValue to intDigits as integer
    if fracDigits is not "" then
        set numberValue to numberValue + ((fracDigits as integer) / (10 ^ (length of fracDigits)))
    end if
    return signFactor * numberValue
end parseDecimal

on parseLocationFields(valueText, currentLocation, defaultName)
    -- Reads "latitude=50.9787; longitude=11.3235; radius=0.5; trigger=arriving; name=Office" and checks it.
    -- Fields that are not given keep the value of the current location.
    -- Returns {error text, name, latitude, longitude, altitude, radius, trigger}; the error text is "" if all is well.
    set locName to defaultName
    set latValue to missing value
    set lonValue to missing value
    set altValue to missing value
    set radiusValue to missing value
    set triggerText to ""
    if currentLocation is not missing value then
        if (item 1 of currentLocation) is not "" then set locName to item 1 of currentLocation
        set latValue to item 2 of currentLocation
        set lonValue to item 3 of currentLocation
        set altValue to item 4 of currentLocation
        set radiusValue to item 5 of currentLocation
        set triggerText to item 6 of currentLocation
    end if
    set validKeys to "name, latitude, longitude, altitude, radius, trigger"

    set savedDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ";"
    set fieldTexts to text items of valueText
    set AppleScript's text item delimiters to savedDelimiters

    repeat with aField in fieldTexts
        set fieldText to my trimItem(contents of aField)
        if fieldText is not "" then
            set equalsPosition to offset of "=" in fieldText
            if equalsPosition < 2 then
                return {"❌ Invalid location field: " & fieldText & ". Use field=value pairs separated by semicolons, for example latitude=50.9787; longitude=11.3235; radius=0.5; trigger=arriving. Valid fields: " & validKeys & ". Nothing was changed."}
            end if
            set keyText to my trimItem(text 1 thru (equalsPosition - 1) of fieldText)
            set fieldValue to ""
            if equalsPosition < (length of fieldText) then set fieldValue to my trimItem(text (equalsPosition + 1) thru -1 of fieldText)

            if keyText is "name" then
                if fieldValue is "" then return {"❌ The name of the location cannot be empty. Nothing was changed."}
                set locName to fieldValue
            else if keyText is "latitude" or keyText is "lat" then
                set latValue to my parseDecimal(fieldValue)
                if latValue is missing value then return {"❌ Latitude is not a number: " & fieldValue & ". Nothing was changed."}
                if latValue < -90 or latValue > 90 then return {"❌ Latitude must be between -90 and 90: " & fieldValue & ". Nothing was changed."}
            else if keyText is "longitude" or keyText is "lon" or keyText is "lng" then
                set lonValue to my parseDecimal(fieldValue)
                if lonValue is missing value then return {"❌ Longitude is not a number: " & fieldValue & ". Nothing was changed."}
                if lonValue < -180 or lonValue > 180 then return {"❌ Longitude must be between -180 and 180: " & fieldValue & ". Nothing was changed."}
            else if keyText is "altitude" then
                if fieldValue is "none" or fieldValue is "" then
                    set altValue to missing value
                else
                    set altValue to my parseDecimal(fieldValue)
                    if altValue is missing value then return {"❌ Altitude is not a number: " & fieldValue & ". Nothing was changed."}
                end if
            else if keyText is "radius" then
                if fieldValue is "none" or fieldValue is "" then
                    set radiusValue to missing value
                else
                    set radiusValue to my parseDecimal(fieldValue)
                    if radiusValue is missing value then return {"❌ Radius is not a number: " & fieldValue & ". Nothing was changed."}
                    if radiusValue < 0.1 or radiusValue > 10 then return {"❌ The radius must be between 0.1 and 10 kilometers: " & fieldValue & ". Nothing was changed."}
                end if
            else if keyText is "trigger" then
                if fieldValue is "arriving" or fieldValue is "arrive" then
                    set triggerText to "arriving"
                else if fieldValue is "leaving" or fieldValue is "leave" then
                    set triggerText to "leaving"
                else if fieldValue is "none" or fieldValue is "" then
                    set triggerText to ""
                else
                    return {"❌ Unknown trigger: " & fieldValue & ". Valid values: arriving, leaving, none. Nothing was changed."}
                end if
            else
                return {"❌ Unknown location field: " & keyText & ". Valid fields: " & validKeys & ". Nothing was changed."}
            end if
        end if
    end repeat

    if latValue is missing value or lonValue is missing value then
        return {"❌ A location needs a latitude and a longitude, for example latitude=50.9787; longitude=11.3235. Nothing was changed."}
    end if
    return {"", locName, latValue, lonValue, altValue, radiusValue, triggerText}
end parseLocationFields

on writeTagLocation(aTag, locName, latValue, lonValue, altValue, radiusValue, triggerText)
    -- The record is built inside the tell block so that its labels are the terms of OmniFocus
    tell application "OmniFocus"
        set locationRecord to {name:locName, latitude:latValue, longitude:lonValue}
        if altValue is not missing value then set locationRecord to locationRecord & {altitude:altValue}
        if radiusValue is not missing value then set locationRecord to locationRecord & {radius:radiusValue}
        if triggerText is "arriving" then
            set locationRecord to locationRecord & {trigger:notify when arriving}
        else if triggerText is "leaving" then
            set locationRecord to locationRecord & {trigger:notify when leaving}
        end if
        set location of aTag to locationRecord
    end tell
end writeTagLocation

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
