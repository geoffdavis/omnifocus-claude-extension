on run argv
  set searchName to item 1 of argv
  
  tell application "OmniFocus"
    tell default document
      try
        set targetTask to first flattened task whose name contains searchName and completed is false
        set taskFullName to name of targetTask
        set completed of targetTask to true
        return "✅ Completed: " & taskFullName
      on error
        return "❌ Could not find task containing: " & searchName
      end try
    end tell
  end tell
end run