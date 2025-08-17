on run argv
  set searchName to item 1 of argv
  
  tell application "OmniFocus"
    tell default document
      -- First check inbox tasks separately
      set foundInInbox to false
      set inboxTask to missing value
      
      repeat with aTask in (every inbox task)
        if name of aTask contains searchName and completed of aTask is false then
          if foundInInbox then
            -- Multiple matches, need to check all tasks
            set foundInInbox to false
            exit repeat
          else
            set foundInInbox to true
            set inboxTask to aTask
          end if
        end if
      end repeat
      
      -- If we found exactly one inbox task, complete it
      if foundInInbox and inboxTask is not missing value then
        set taskName to name of inboxTask
        mark complete inboxTask
        return "✅ Completed: " & taskName
      end if
      
      -- Otherwise, search all tasks to show options or find in projects
      try
        set foundTasks to every flattened task whose name contains searchName and completed is false
        
        if (count of foundTasks) = 0 then
          return "❌ No matching tasks found for: " & searchName
        else if (count of foundTasks) = 1 then
          set targetTask to item 1 of foundTasks
          set taskName to name of targetTask
          
          -- Try to mark complete (works for project tasks)
          try
            set completed of targetTask to true
          on error
            -- If that fails, use mark complete (works for inbox tasks)
            mark complete targetTask
          end try
          
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
        return "❌ Error: " & errMsg
      end try
    end tell
  end tell
end run
