on run argv
  set searchName to item 1 of argv
  
  tell application "OmniFocus"
    tell default document
      try
        -- Get all matching incomplete tasks (includes inbox tasks)
        set foundTasks to every flattened task whose name contains searchName and completed is false
        
        if (count of foundTasks) = 0 then
          return "❌ No matching tasks found for: " & searchName
        else if (count of foundTasks) = 1 then
          set targetTask to item 1 of foundTasks
          set taskName to name of targetTask
          set completed of targetTask to true
          return "✅ Completed: " & taskName
        else
          -- Multiple matches - show them
          set taskList to "🔍 Multiple tasks found (" & (count of foundTasks) & "):" & return
          repeat with aTask in foundTasks
            set taskList to taskList & "• " & name of aTask & return
          end repeat
          set taskList to taskList & return & "Please be more specific."
          return taskList
        end if
      on error errMsg
        return "❌ Error searching for task: " & errMsg
      end try
    end tell
  end tell
end run
