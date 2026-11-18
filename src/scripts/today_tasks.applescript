on run argv
  -- include_dropped: "true" also shows dropped tasks and tasks below dropped (hidden) folders
  set includeDropped to false
  if (count of argv) > 0 then set includeDropped to (item 1 of argv is "true")
  set hiddenProjectIDList to {}
  if not includeDropped then set hiddenProjectIDList to my hiddenFolderProjectIDs()

  -- Every Apple Event costs about 17 ms, a query for one property of all tasks about 0.1 s: the properties of all tasks
  -- are fetched at once (the same position in each list is the same task) and filtered in the script
  tell application "OmniFocus"
    tell default document
      set taskIDList to id of every flattened task
      set taskNameList to name of every flattened task
      set dueDateList to due date of every flattened task
      set effCompletedList to effectively completed of every flattened task
      set effDroppedList to effectively dropped of every flattened task
      set parentIDList to id of parent task of every flattened task
      set containerIDList to id of containing project of every flattened task
      set containerNameList to name of containing project of every flattened task
    end tell
  end tell

  set todayStart to current date
  set hours of todayStart to 0
  set minutes of todayStart to 0
  set seconds of todayStart to 0
  set todayEnd to todayStart + 1 * days

  -- Open tasks only: not completed or dropped, also not through their project or parent task
  set todayTasks to {}
  set taskIDText to ""
  repeat with t from 1 to count of taskIDList
    set dueDate to item t of dueDateList
    if dueDate is not missing value then
      if dueDate ≥ todayStart and dueDate < todayEnd and not (item t of effCompletedList) then
        if includeDropped or not (item t of effDroppedList) then
          -- Leave out tasks of projects below hidden (dropped) folders
          -- The root task of a project has the ID of its project and is no task
          if (not my isHiddenProjectID(item t of containerIDList, hiddenProjectIDList)) and ((item t of taskIDList) is not (item t of containerIDList)) then
            -- The name of what holds the task: the parent task, the project, or the inbox
            set holderName to "Inbox"
            set parentID to item t of parentIDList
            set projectID to item t of containerIDList
            if parentID is missing value then
              if projectID is not missing value then set holderName to item t of containerNameList
            else if parentID is projectID then
              set holderName to item t of containerNameList
            else
              if taskIDText is "" then set taskIDText to linefeed & my joinText(taskIDList, linefeed) & linefeed
              set parentIndex to my indexOfID(taskIDText, parentID)
              if parentIndex > 0 then set holderName to item parentIndex of taskNameList
            end if
            set end of todayTasks to "• " & (item t of taskNameList) & " (" & holderName & ")"
          end if
        end if
      end if
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
