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
  set skippedDates to ""
  if (count of argv) > 3 then
    set dueDateString to item 4 of argv
    if dueDateString is not "" then
      set dueDate to my parseDate(dueDateString)
      if dueDate is missing value then
        set skippedDates to skippedDates & " due_date"
      end if
    end if
  end if
  if (count of argv) > 4 then
    if item 5 of argv is "true" then set isFlagged to true
  end if
  if (count of argv) > 5 then
    set deferDateString to item 6 of argv
    if deferDateString is not "" then
      set deferDate to my parseDate(deferDateString)
      if deferDate is missing value then
        set skippedDates to skippedDates & " defer_date"
      end if
    end if
  end if
  if (count of argv) > 6 then
    set minutesString to item 7 of argv
    if minutesString is not "" and minutesString is not "0" then
      set minutesTrimmed to my trimText(minutesString)
      try
        set estimatedMinutes to minutesTrimmed as integer
      on error
        return "❌ Invalid estimated_minutes value: " & minutesString & " (must be a whole number)"
      end try
      if estimatedMinutes < 0 then
        return "❌ Invalid estimated_minutes value: " & minutesString & " (must be 0 or greater)"
      end if
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

      if skippedDates is not "" then
        return "✅ Added: " & taskName & " (⚠️ could not parse:" & skippedDates & ")"
      end if
      return "✅ Added: " & taskName
    end tell
  end tell
end run

on parseDate(dateString)
  set todayDate to current date
  set trimmed to my trimText(dateString)
  if trimmed is "today" then
    return todayDate
  else if trimmed is "tomorrow" then
    return todayDate + 1 * days
  else if trimmed is "next week" then
    return todayDate + 7 * days
  else if trimmed is "week" then
    return todayDate + 7 * days
  else if trimmed ends with "week" or trimmed ends with "weeks" then
    try
      set weekCount to word 1 of trimmed as integer
      return todayDate + weekCount * 7 * days
    on error
      return missing value
    end try
  else if trimmed contains "day" then
    try
      set dayCount to word 1 of trimmed as integer
      return todayDate + dayCount * days
    on error
      return missing value
    end try
  else if length of trimmed is 10 and character 5 of trimmed is "-" and character 8 of trimmed is "-" then
    try
      set yearNum to (text 1 thru 4 of trimmed) as integer
      set monthNum to (text 6 thru 7 of trimmed) as integer
      set dayNum to (text 9 thru 10 of trimmed) as integer
      set isoDate to current date
      set day of isoDate to 1
      set month of isoDate to monthNum
      set day of isoDate to dayNum
      set year of isoDate to yearNum
      set time of isoDate to 0
      return isoDate
    on error
      return missing value
    end try
  else
    try
      return date trimmed
    on error
      return missing value
    end try
  end if
end parseDate

on trimText(theText)
  set whitespaceChars to {" ", tab, return, linefeed}
  set textLength to length of theText
  if textLength is 0 then return ""
  set textStart to 1
  repeat while textStart ≤ textLength and character textStart of theText is in whitespaceChars
    set textStart to textStart + 1
  end repeat
  if textStart > textLength then return ""
  set textEnd to textLength
  repeat while textEnd ≥ textStart and character textEnd of theText is in whitespaceChars
    set textEnd to textEnd - 1
  end repeat
  return text textStart thru textEnd of theText
end trimText