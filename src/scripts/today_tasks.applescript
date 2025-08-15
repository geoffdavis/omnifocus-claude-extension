tell application "OmniFocus"
  tell default document
    set todayStart to current date
    set hours of todayStart to 0
    set minutes of todayStart to 0
    set seconds of todayStart to 0
    
    set todayEnd to todayStart + 1 * days
    
    set todayTasks to {}
    set allTasks to flattened tasks whose completed is false
    
    repeat with aTask in allTasks
      set taskDue to due date of aTask
      if taskDue is not missing value then
        if taskDue ≥ todayStart and taskDue < todayEnd then
          set taskName to name of aTask
          set projectName to "Inbox"
          try
            set projectName to name of container of aTask
          end try
          set end of todayTasks to "• " & taskName & " (" & projectName & ")"
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
  end tell
end tell