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
            set output to output & indent & "• " & name of aTag & return
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
            set output to output & return
            set childTags to every tag of aTag
            if (count of childTags) > 0 then
                set output to output & my formatTagsWithCounts(childTags, depth + 1, tagCountRecord)
            end if
        end repeat
    end tell
    return output
end formatTagsWithCounts
