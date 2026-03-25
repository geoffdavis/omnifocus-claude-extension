on run argv
  set taskName to item 1 of argv
  set taskNote to ""
  set projectName to ""
  set dueDate to missing value
  set isFlagged to false
  set deferDate to missing value
  set estimatedMinutes to 0

  if (count of argv) > 1 then set taskNote to item 2 of argv
  if (count of argv) > 2 then set projectName to item 3 of argv
  if (count of argv) > 3 then
    set dueDateString to item 4 of argv
    if dueDateString is not "" then
      set dueDate to my parseDate(dueDateString)
    end if
  end if
  if (count of argv) > 4 then
    if item 5 of argv is "true" then set isFlagged to true
  end if
  if (count of argv) > 5 then
    set deferDateString to item 6 of argv
    if deferDateString is not "" then
      set deferDate to my parseDate(deferDateString)
    end if
  end if
  if (count of argv) > 6 then
    set minutesString to item 7 of argv
    if minutesString is not "" and minutesString is not "0" then
      try
        set estimatedMinutes to minutesString as integer
      end try
    end if
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
      if deferDate is not missing value then
        set defer date of newTask to deferDate
      end if
      if estimatedMinutes > 0 then
        set estimated minutes of newTask to estimatedMinutes
      end if

      return "✅ Added: " & taskName
    end tell
  end tell
end run

on parseDate(dateString)
  set todayDate to current date
  if dateString is "today" then
    return todayDate
  else if dateString is "tomorrow" then
    return todayDate + 1 * days
  else if dateString is "next week" then
    return todayDate + 7 * days
  else if dateString contains "days" then
    try
      set dayCount to word 1 of dateString as integer
      return todayDate + dayCount * days
    on error
      return todayDate
    end try
  else
    try
      return date dateString
    on error
      return todayDate
    end try
  end if
end parseDate