on run argv
    -- List all tags in OmniFocus
    -- Usage: list_tags.applescript

    tell application "OmniFocus"
        tell default document
            set allTags to every tag
            if (count of allTags) = 0 then
                return "🏷️ No tags found in OmniFocus."
            end if

            set resultText to "🏷️ Tags (" & (count of allTags) & "):" & return
            repeat with aTag in allTags
                set tagName to name of aTag
                -- Count tasks with this tag
                set taggedCount to count of (flattened tasks where tag names contains tagName and completed is false)
                set resultText to resultText & "• " & tagName
                if taggedCount > 0 then
                    set resultText to resultText & " (" & taggedCount & " tasks)"
                end if
                set resultText to resultText & return
            end repeat

            return resultText
        end tell
    end tell
end run
