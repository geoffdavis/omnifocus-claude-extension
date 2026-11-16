on run argv
    -- Edit an existing tag
    -- Usage: edit_tag.applescript "tag name, Parent > Tag or id:<id>" "property" "new value"
    -- Properties: name, note, parent, hidden, allows_next_action

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

        else
            return "❌ Unknown property: " & propertyName & ". Valid properties: name, note, parent, hidden, allows_next_action"
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

    tell application "OmniFocus"
        tell default document
            set allTags to every flattened tag
        end tell
    end tell

    set exactMatches to {}
    set partialMatches to {}
    repeat with aTag in allTags
        set candidateTag to contents of aTag
        tell application "OmniFocus" to set candidateName to name of candidateTag
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
