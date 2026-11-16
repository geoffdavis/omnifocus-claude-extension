on run argv
  -- include_dropped: "true" also counts dropped items and items below dropped (hidden) folders
  set includeDropped to false
  if (count of argv) > 0 then set includeDropped to (item 1 of argv is "true")
  set hiddenProjectIDList to {}
  if not includeDropped then set hiddenProjectIDList to my hiddenFolderProjectIDs()

  -- Every Apple Event costs about 17 ms, a query for one property of all elements about 0.05 s: the properties of all
  -- tasks and projects are fetched at once (the same position in each list is the same item) and counted in the script
  tell application "OmniFocus"
    tell default document
      set inboxCompletedList to effectively completed of every inbox task
      set inboxDroppedList to effectively dropped of every inbox task
      set flaggedList to flagged of every flattened task
      set dueDateList to due date of every flattened task
      set effCompletedList to effectively completed of every flattened task
      set effDroppedList to effectively dropped of every flattened task
      set containerIDList to id of containing project of every flattened task
      set projectIDList to id of every flattened project
      set projectStatusList to effective status of every flattened project
    end tell
    -- Projects in all folders whose effective status is active
    set activeFlagList to {}
    repeat with aStatus in projectStatusList
      set end of activeFlagList to ((contents of aStatus) is active status)
    end repeat
  end tell

  set todayStart to current date
  set weekEnd to todayStart + 7 * days

  -- Open tasks only: not completed or dropped, also not through their project or parent task
  set inboxCount to 0
  repeat with i from 1 to count of inboxCompletedList
    if not (item i of inboxCompletedList) then
      if includeDropped or not (item i of inboxDroppedList) then set inboxCount to inboxCount + 1
    end if
  end repeat

  -- Leave out tasks of projects below hidden (dropped) folders
  set flaggedCount to 0
  set overdueCount to 0
  set dueThisWeek to 0
  repeat with t from 1 to count of effCompletedList
    if not (item t of effCompletedList) then
      if includeDropped or not (item t of effDroppedList) then
        if not my isHiddenProjectID(item t of containerIDList, hiddenProjectIDList) then
          if item t of flaggedList then set flaggedCount to flaggedCount + 1
          set dueDate to item t of dueDateList
          if dueDate is not missing value then
            if dueDate < todayStart then set overdueCount to overdueCount + 1
            if dueDate ≥ todayStart and dueDate < weekEnd then set dueThisWeek to dueThisWeek + 1
          end if
        end if
      end if
    end if
  end repeat

  -- Active projects, without those below hidden folders, and how many of them have open tasks
  set openCountList to my openTaskCounts(projectIDList)
  set projectCount to 0
  set activeProjectCount to 0
  repeat with i from 1 to count of projectIDList
    if item i of activeFlagList then
      if hiddenProjectIDList does not contain (item i of projectIDList) then
        set projectCount to projectCount + 1
        if (item i of openCountList) > 0 then set activeProjectCount to activeProjectCount + 1
      end if
    end if
  end repeat

  set report to "📊 WEEKLY REVIEW SUMMARY" & return
  set report to report & return
  set report to report & "📥 Inbox: " & inboxCount & " items" & return
  set report to report & "🚩 Flagged: " & flaggedCount & " tasks" & return
  set report to report & "⚠️  Overdue: " & overdueCount & " tasks" & return
  set report to report & "📅 Due this week: " & dueThisWeek & " tasks" & return
  set report to report & "📁 Projects with open tasks: " & activeProjectCount & " of " & projectCount & " active" & return & return

  return report
end run

on hiddenFolderProjectIDs()
    -- IDs of all projects below a hidden (dropped) folder, at any depth. One query per list instead of one per project:
    -- every Apple Event costs about 17 ms, a query for all elements about 50 ms.
    set idList to {}
    tell application "OmniFocus"
        tell default document
            try
                set hiddenFlags to effectively hidden of every flattened folder
                if hiddenFlags does not contain true then return {}
                set hiddenFolderIDList to id of every flattened folder whose effectively hidden is true
                set projectIDList to id of every flattened project
                set projectFolderIDList to id of folder of every flattened project
                repeat with i from 1 to count of projectIDList
                    set folderID to item i of projectFolderIDList
                    if folderID is not missing value then
                        if hiddenFolderIDList contains folderID then set end of idList to item i of projectIDList
                    end if
                end repeat
            end try
        end tell
    end tell
    return idList
end hiddenFolderProjectIDs

on isHiddenProjectID(containerID, hiddenProjectIDList)
    -- True if the ID is the ID of a project below a hidden (dropped) folder (tasks outside projects have no project ID)
    if containerID is missing value then return false
    if (count of hiddenProjectIDList) = 0 then return false
    return (hiddenProjectIDList contains containerID)
end isHiddenProjectID

on indexOfID(idText, theID)
    -- Position of an ID in a list that was joined into one text (linefeed & id1 & linefeed & id2 & linefeed ...), 0 if it is
    -- not in it. The search is done by the system and does not loop over the list.
    if theID is missing value then return 0
    set matchPosition to 0
    considering case
        set matchPosition to offset of (linefeed & theID & linefeed) in idText
    end considering
    if matchPosition = 0 then return 0
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to linefeed
    set linefeedCount to (count of text items of (text 1 thru matchPosition of idText)) - 1
    set AppleScript's text item delimiters to oldDelims
    return linefeedCount
end indexOfID

on joinText(textItems, separator)
    -- Joins a list of text items with a separator
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to separator
    set joinedText to textItems as text
    set AppleScript's text item delimiters to oldDelims
    return joinedText
end joinText

on openTaskCounts(projectIDList)
    -- Number of open tasks (not completed, not dropped; all levels) in each project, in the order of projectIDList.
    -- The root task of a project has no parent task and is not counted. Four queries for all tasks instead of
    -- one query per project: every Apple Event costs about 17 ms, a query for all elements about 0.1 s.
    set openCounts to {}
    repeat with i from 1 to count of projectIDList
        set end of openCounts to 0
    end repeat
    tell application "OmniFocus"
        tell default document
            set taskProjectIDList to id of containing project of every flattened task
            set taskParentIDList to id of parent task of every flattened task
            set effCompletedList to effectively completed of every flattened task
            set effDroppedList to effectively dropped of every flattened task
        end tell
    end tell
    set projectIDText to linefeed & my joinText(projectIDList, linefeed) & linefeed
    repeat with t from 1 to count of taskProjectIDList
        set containerID to item t of taskProjectIDList
        if containerID is not missing value then
            if (item t of taskParentIDList) is not missing value then
                if not (item t of effCompletedList) and not (item t of effDroppedList) then
                    set projectIndex to my indexOfID(projectIDText, containerID)
                    if projectIndex > 0 then set item projectIndex of openCounts to (item projectIndex of openCounts) + 1
                end if
            end if
        end if
    end repeat
    return openCounts
end openTaskCounts
