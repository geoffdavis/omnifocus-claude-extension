on run argv
    -- Delete a tag from OmniFocus
    -- Usage: delete_tag.applescript "tag name"

    if (count of argv) = 0 then
        return "❌ Tag name is required."
    end if

    set tagName to item 1 of argv

    if tagName is "" then
        return "❌ Tag name cannot be empty."
    end if

    tell application "OmniFocus"
        tell default document
            set matchingTags to every tag whose name is tagName
            if (count of matchingTags) = 0 then
                return "❌ Tag not found: " & tagName
            end if

            try
                delete item 1 of matchingTags
                return "🗑️ Deleted tag: " & tagName
            on error errMsg
                return "❌ Error deleting tag: " & errMsg
            end try
        end tell
    end tell
end run
