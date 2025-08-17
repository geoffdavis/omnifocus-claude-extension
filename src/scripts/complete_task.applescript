on run argv
  set searchName to item 1 of argv
  
  tell application "OmniFocus"
    tell default document
      -- First try to find in inbox tasks
      set inboxMatches to {}
      repeat with aTask in (every inbox task)
        if name of aTask contains searchName and completed of aTask is false then
          set end of inboxMatches to aTask
        end if
      end repeat
      
      -- Then try to find in project tasks
      set projectMatches to {}
      try
        set projectMatches to every flattened task whose name contains searchName and completed is false
      end try
      
      -- Combine results
      set allMatches to inboxMatches & projectMatches
      
      if (count of allMatches) = 0 then
        return "❌ No matching tasks found for: " & searchName
      else if (count of allMatches) = 1 then
        set targetTask to item 1 of allMatches
        set taskName to name of targetTask
        set completed of targetTask to true
        return "✅ Completed: " & taskName
      else
        set taskList to "🔍 Multiple tasks found:" & return
        repeat with aTask in allMatches
          set taskList to taskList & "• " & name of aTask & return
        end repeat
        set taskList to taskList & return & "Please be more specific."
        return taskList
      end if
    end tell
  end tell
end run
