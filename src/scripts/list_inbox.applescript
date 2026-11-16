on run
  tell application "OmniFocus"
    tell default document
      -- Open tasks only: not completed and not dropped
      try
        set candidateTasks to every inbox task whose completed is false and dropped is false
      on error
        set candidateTasks to every inbox task whose completed is false
      end try

      -- Check each task again, in case the filter above let a closed task through
      set incompleteTasks to {}
      repeat with aTask in candidateTasks
        set taskIsOpen to true
        try
          if completed of aTask then set taskIsOpen to false
        end try
        try
          if dropped of aTask then set taskIsOpen to false
        end try
        if taskIsOpen then set end of incompleteTasks to contents of aTask
      end repeat

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
