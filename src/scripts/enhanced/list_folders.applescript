on run argv
    -- List the folders of OmniFocus as a hierarchy with ID, number of projects and subfolders, hidden folders and notes
    -- Usage: list_folders.applescript

    -- Every Apple Event costs about 17 ms, a query for one property of all elements about 0.05 s: the properties of all
    -- folders and the folders of all projects are fetched at once (the same position in each list is the same item)
    tell application "OmniFocus"
        tell default document
            set folderIDList to id of every flattened folder
            set folderNameList to name of every flattened folder
            set folderParentIDList to id of container of every flattened folder
            set folderHiddenList to hidden of every flattened folder
            set folderNoteList to note of every flattened folder
            set projectFolderIDList to id of folder of every flattened project
        end tell
    end tell
    set folderCount to count of folderIDList
    if folderCount = 0 then
        return "📁 No folders found in OmniFocus."
    end if

    -- Projects directly in each folder
    set projectCounts to {}
    repeat with i from 1 to folderCount
        set end of projectCounts to 0
    end repeat
    repeat with aFolderID in projectFolderIDList
        if (contents of aFolderID) is not missing value then
            set folderIndex to my indexOfItem(contents of aFolderID, folderIDList)
            if folderIndex > 0 then set item folderIndex of projectCounts to (item folderIndex of projectCounts) + 1
        end if
    end repeat

    set outputText to ""
    repeat with i from 1 to folderCount
        -- Top-level folders: the container is the database, which is not in the list of folders
        if my indexOfItem(item i of folderParentIDList, folderIDList) = 0 then
            set outputText to outputText & my formatFolder(i, 0, folderIDList, folderNameList, folderParentIDList, folderHiddenList, folderNoteList, projectCounts)
        end if
    end repeat
    return "📁 Folders (" & folderCount & "):" & return & outputText
end run

on formatFolder(folderIndex, depth, folderIDList, folderNameList, folderParentIDList, folderHiddenList, folderNoteList, projectCounts)
    -- A folder and, indented below it, its subfolders (recursively); the indentation shows the hierarchy
    set indent to ""
    repeat depth times
        set indent to indent & "  "
    end repeat
    set folderID to item folderIndex of folderIDList
    set subfolderIndexes to {}
    repeat with j from 1 to count of folderIDList
        if (item j of folderParentIDList) is folderID then set end of subfolderIndexes to j
    end repeat
    set hasNote to false
    set noteValue to item folderIndex of folderNoteList
    if noteValue is not missing value then
        if (noteValue as text) is not "" then set hasNote to true
    end if
    set lineText to indent & "• " & (item folderIndex of folderNameList)
    set lineText to lineText & " (" & my countText(item folderIndex of projectCounts, "project", "projects")
    if (count of subfolderIndexes) > 0 then set lineText to lineText & ", " & my countText(count of subfolderIndexes, "subfolder", "subfolders")
    set lineText to lineText & ")"
    if item folderIndex of folderHiddenList then set lineText to lineText & " ⏸ hidden"
    if hasNote then set lineText to lineText & " 📝"
    set lineText to lineText & " [id:" & folderID & "]"
    set output to lineText & return
    repeat with subIndex in subfolderIndexes
        set output to output & my formatFolder(contents of subIndex, depth + 1, folderIDList, folderNameList, folderParentIDList, folderHiddenList, folderNoteList, projectCounts)
    end repeat
    return output
end formatFolder

on indexOfItem(anItem, aList)
    -- Position of anItem in aList, 0 if it is not in the list
    repeat with i from 1 to count of aList
        if (item i of aList) is anItem then return i
    end repeat
    return 0
end indexOfItem

on countText(n, singularWord, pluralWord)
    -- "1 project", "2 projects"
    if n = 1 then return "1 " & singularWord
    return (n as text) & " " & pluralWord
end countText
