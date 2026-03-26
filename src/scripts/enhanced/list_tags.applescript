on run argv
    -- List all tags in OmniFocus
    -- Usage: list_tags.applescript

    tell application "OmniFocus"
        tell default document
            set allTags to every tag
            if (count of allTags) = 0 then
                return "🏷️ No tags found in OmniFocus."
            end if

            -- Build a tag→count map in a single pass over tasks
            set tagCountRecord to {}
            set activeTasks to every flattened task whose completed is false
            repeat with aTask in activeTasks
                set taskTags to tags of aTask
                repeat with aTag in taskTags
                    set tName to name of aTag
                    set found to false
                    repeat with entry in tagCountRecord
                        if tagLabel of entry is tName then
                            set tagCount of entry to (tagCount of entry) + 1
                            set found to true
                            exit repeat
                        end if
                    end repeat
                    if not found then
                        set end of tagCountRecord to {tagLabel:tName, tagCount:1}
                    end if
                end repeat
            end repeat

            set resultText to "🏷️ Tags (" & (count of allTags) & "):" & return
            repeat with aTag in allTags
                set tagName to name of aTag
                set taggedCount to 0
                repeat with entry in tagCountRecord
                    if tagLabel of entry is tagName then
                        set taggedCount to tagCount of entry
                        exit repeat
                    end if
                end repeat
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
