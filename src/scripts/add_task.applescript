on run argv
  set taskName to item 1 of argv
  set taskNote to ""
  set projectName to ""
  set dueDate to missing value
  set isFlagged to false
  
  if (count of argv) > 1 then set taskNote to item 2 of argv
  if (count of argv) > 2 then set projectName to item 3 of argv
  if (count of argv) > 3 then
    set dueDateString to item 4 of argv
    if dueDateString is not "" then
      if dueDateString contains "tomorrow" then
        set dueDate to (current date) + 1 * days
      else if dueDateString contains "today" then
        set dueDate to current date
      else if dueDateString contains "week" then
        set dueDate to (current date) + 7 * days
      end if
    end if
  end if
  if (count of argv) > 4 then
    if item 5 of argv is "true" then set isFlagged to true
  end if
  
  tell application "OmniFocus"
    tell default document
      if projectName is not "" then
        try
          set targetProject to first project whose name contains projectName
          set newTask to make new task with properties {name:taskName, note:taskNote, flagged:isFlagged} at end of tasks of targetProject
        on error
          set newTask to make new inbox task with properties {name:taskName, note:taskNote, flagged:isFlagged}
        end try
      else
        set newTask to make new inbox task with properties {name:taskName, note:taskNote, flagged:isFlagged}
      end if
      
      if dueDate is not missing value then
        set due date of newTask to dueDate
      end if
      
      return "✅ Added: " & taskName
    end tell
  end tell
end run