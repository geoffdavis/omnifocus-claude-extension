on run argv
    -- Create a new tag in OmniFocus
    -- Usage: create_tag.applescript "tag name" ["parent tag name"]

    if (count of argv) = 0 then
        return "❌ Tag name is required."
    end if

    set tagName to item 1 of argv
    set parentTagName to ""
    if (count of argv) > 1 then set parentTagName to item 2 of argv

    if tagName is "" then
        return "❌ Tag name cannot be empty."
    end if

    tell application "OmniFocus"
        tell default document
            -- Check if tag already exists
            set existingTags to every tag whose name is tagName
            if (count of existingTags) > 0 then
                return "⚠️ Tag already exists: " & tagName
            end if

            try
                if parentTagName is not "" then
                    -- Create as a child of the parent tag
                    set parentTags to every tag whose name is parentTagName
                    if (count of parentTags) = 0 then
                        return "❌ Parent tag not found: " & parentTagName
                    end if
                    set parentTag to item 1 of parentTags
                    make new tag with properties {name:tagName} at end of tags of parentTag
                    return "✅ Created tag: " & tagName & " (under " & parentTagName & ")"
                else
                    make new tag with properties {name:tagName}
                    return "✅ Created tag: " & tagName
                end if
            on error errMsg
                return "❌ Error creating tag: " & errMsg
            end try
        end tell
    end tell
end run
