on run
  tell application "OmniFocus"
    tell default document
      set incompleteTasks to every inbox task whose completed is false
      
      if (count of incompleteTasks) = 0 then
        return "📥 Inbox is empty"
      else
        set taskList to "📥 Inbox (" & (count of incompleteTasks) & " items):"
        repeat with aTask in incompleteTasks
          set taskName to name of aTask
          if flagged of aTask then
            set taskList to taskList & return & "• " & taskName & " 🚩"
          else
            set taskList to taskList & return & "• " & taskName
          end if
        end repeat
        return taskList
      end if
    end tell
  end tell
end run
