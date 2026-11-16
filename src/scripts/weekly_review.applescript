on run argv
  -- include_dropped: "true" also counts dropped items and items below dropped (hidden) folders
  set includeDropped to false
  if (count of argv) > 0 then set includeDropped to (item 1 of argv is "true")
  set hiddenTaskIDs to {}
  set hiddenProjectIDs to {}
  if not includeDropped then
    set hiddenTaskIDs to my hiddenFolderTaskIDs()
    set hiddenProjectIDs to my hiddenFolderProjectIDs()
  end if

  tell application "OmniFocus"
    tell default document
      set todayStart to current date
      set weekEnd to todayStart + 7 * days

      -- Open tasks only: not completed or dropped, also not through their project or parent task
      if includeDropped then
        set inboxCount to count of (every inbox task whose effectively completed is false)
        set flaggedIDs to id of every flattened task whose flagged is true and effectively completed is false
        set overdueIDs to id of every flattened task whose due date < todayStart and effectively completed is false
        set weekIDs to id of every flattened task whose due date ≥ todayStart and due date < weekEnd and effectively completed is false
      else
        set inboxCount to count of (every inbox task whose effectively completed is false and effectively dropped is false)
        set flaggedIDs to id of every flattened task whose flagged is true and effectively completed is false and effectively dropped is false
        set overdueIDs to id of every flattened task whose due date < todayStart and effectively completed is false and effectively dropped is false
        set weekIDs to id of every flattened task whose due date ≥ todayStart and due date < weekEnd and effectively completed is false and effectively dropped is false
      end if

      -- Leave out tasks of projects below hidden (dropped) folders
      set flaggedCount to my countVisible(flaggedIDs, hiddenTaskIDs)
      set overdueCount to my countVisible(overdueIDs, hiddenTaskIDs)
      set dueThisWeek to my countVisible(weekIDs, hiddenTaskIDs)

      -- Projects in all folders whose effective status is active, without those below hidden folders
      set candidateProjects to every flattened project where its effective status is active status
      set projectCount to 0
      set activeProjectCount to 0
      repeat with aProject in candidateProjects
        if not (my isHiddenItem(contents of aProject, hiddenProjectIDs)) then
          set projectCount to projectCount + 1
          if (count of (flattened tasks of aProject whose effectively completed is false and effectively dropped is false)) > 0 then
            set activeProjectCount to activeProjectCount + 1
          end if
        end if
      end repeat

      set report to "📊 WEEKLY REVIEW SUMMARY" & return
      set report to report & "════════════════════════" & return & return
      set report to report & "📥 Inbox: " & inboxCount & " items" & return
      set report to report & "🚩 Flagged: " & flaggedCount & " tasks" & return
      set report to report & "⚠️  Overdue: " & overdueCount & " tasks" & return
      set report to report & "📅 Due this week: " & dueThisWeek & " tasks" & return
      set report to report & "📁 Projects with open tasks: " & activeProjectCount & " of " & projectCount & " active" & return & return

      if inboxCount > 0 then
        set report to report & "💡 Action: Process " & inboxCount & " inbox items" & return
      end if
      if overdueCount > 0 then
        set report to report & "💡 Action: Review " & overdueCount & " overdue tasks" & return
      end if

      return report
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
