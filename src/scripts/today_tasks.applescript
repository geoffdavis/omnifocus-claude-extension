on run argv
  -- include_dropped: "true" also shows dropped tasks and tasks below dropped (hidden) folders
  set includeDropped to false
  if (count of argv) > 0 then set includeDropped to (item 1 of argv is "true")
  set hiddenIDs to {}
  if not includeDropped then set hiddenIDs to my hiddenFolderTaskIDs()

  tell application "OmniFocus"
    tell default document
      set todayStart to current date
      set hours of todayStart to 0
      set minutes of todayStart to 0
      set seconds of todayStart to 0

      set todayEnd to todayStart + 1 * days

      -- Open tasks only: not completed or dropped, also not through their project or parent task
      if includeDropped then
        set candidateTasks to every flattened task whose due date ≥ todayStart and due date < todayEnd and effectively completed is false
      else
        set candidateTasks to every flattened task whose due date ≥ todayStart and due date < todayEnd and effectively completed is false and effectively dropped is false
      end if

      set todayTasks to {}
      repeat with aTask in candidateTasks
        -- Leave out tasks of projects below hidden (dropped) folders
        if not (my isHiddenItem(contents of aTask, hiddenIDs)) then
          set taskName to name of aTask
          set projectName to "Inbox"
          try
            set projectName to name of container of aTask
          end try
          set end of todayTasks to "• " & taskName & " (" & projectName & ")"
        end if
      end repeat

      if (count of todayTasks) > 0 then
        set AppleScript's text item delimiters to return
        set taskList to todayTasks as string
        set AppleScript's text item delimiters to ""
        return "📅 Today's Tasks (" & (count of todayTasks) & "):" & return & taskList
      else
        return "✅ No tasks due today!"
      end if
    end tell
  end tell
end run

on hiddenFolderProjectIDs()
    -- IDs of all projects below a hidden (dropped) folder, at any depth
    set idList to {}
    tell application "OmniFocus"
        tell default document
            try
                set hiddenFolders to every flattened folder whose hidden is true
                repeat with aFolder in hiddenFolders
                    set idList to idList & (id of every flattened project of (contents of aFolder))
                end repeat
            end try
        end tell
    end tell
    return idList
end hiddenFolderProjectIDs

on hiddenFolderTaskIDs()
    -- IDs of all tasks in projects below a hidden (dropped) folder
    set idList to {}
    tell application "OmniFocus"
        tell default document
            try
                set hiddenFolders to every flattened folder whose hidden is true
                repeat with aFolder in hiddenFolders
                    set folderProjects to every flattened project of (contents of aFolder)
                    repeat with aProject in folderProjects
                        try
                            set idList to idList & (id of every flattened task of root task of (contents of aProject))
                        on error
                            set idList to idList & (id of every flattened task of (contents of aProject))
                        end try
                    end repeat
                end repeat
            end try
        end tell
    end tell
    return idList
end hiddenFolderTaskIDs

on isHiddenItem(anItem, hiddenIDs)
    -- True if the task or project is one of the items below a hidden folder
    if (count of hiddenIDs) = 0 then return false
    tell application "OmniFocus" to set itemID to id of anItem
    return (hiddenIDs contains itemID)
end isHiddenItem

on countVisible(idList, hiddenIDs)
    -- Number of IDs that are not below a hidden folder
    if (count of hiddenIDs) = 0 then return count of idList
    set visibleCount to 0
    repeat with anID in idList
        if hiddenIDs does not contain (contents of anID) then set visibleCount to visibleCount + 1
    end repeat
    return visibleCount
end countVisible
