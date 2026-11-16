on run argv
    -- List the folders of OmniFocus as a hierarchy with ID, number of projects and subfolders, hidden folders and notes
    -- Usage: list_folders.applescript

    set folderCount to 0
    set outputText to ""
    tell application "OmniFocus"
        tell default document
            set topFolders to every folder
        end tell
    end tell
    if (count of topFolders) = 0 then
        return "📁 No folders found in OmniFocus."
    end if
    set outputText to my formatFolders(topFolders, 0)
    tell application "OmniFocus"
        tell default document
            set folderCount to count of (every flattened folder)
        end tell
    end tell
    return "📁 Folders (" & folderCount & "):" & return & outputText
end run

on formatFolders(folderList, depth)
    -- Recursively lists folders; indentation shows the hierarchy
    set output to ""
    set indent to ""
    repeat depth times
        set indent to indent & "  "
    end repeat
    tell application "OmniFocus"
        repeat with aFolder in folderList
            set projectCount to 0
            set subfolderList to {}
            set folderHidden to false
            set hasNote to false
            try
                set projectCount to count of (every project of aFolder)
            end try
            try
                set subfolderList to every folder of aFolder
            end try
            try
                set folderHidden to hidden of aFolder
            end try
            try
                if (note of aFolder as text) is not "" then set hasNote to true
            end try
            set lineText to indent & "• " & (name of aFolder)
            set lineText to lineText & " (" & my countText(projectCount, "project", "projects")
            if (count of subfolderList) > 0 then set lineText to lineText & ", " & my countText(count of subfolderList, "subfolder", "subfolders")
            set lineText to lineText & ")"
            if folderHidden then set lineText to lineText & " ⏸ hidden"
            if hasNote then set lineText to lineText & " 📝"
            set lineText to lineText & " [id:" & (id of aFolder) & "]"
            set output to output & lineText & return
            if (count of subfolderList) > 0 then
                set output to output & my formatFolders(subfolderList, depth + 1)
            end if
        end repeat
    end tell
    return output
end formatFolders

on countText(n, singularWord, pluralWord)
    -- "1 project", "2 projects"
    if n = 1 then return "1 " & singularWord
    return (n as text) & " " & pluralWord
end countText
