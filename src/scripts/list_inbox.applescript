on run argv
  -- include_dropped: "true" also shows dropped tasks
  set includeDropped to false
  if (count of argv) > 0 then set includeDropped to (item 1 of argv is "true")

  tell application "OmniFocus"
    tell default document
      -- Open tasks only: not completed and, by default, not dropped
      if includeDropped then
        set candidateTasks to every inbox task whose effectively completed is false
      else
        set candidateTasks to every inbox task whose effectively completed is false and effectively dropped is false
      end if

      -- Check each task again, in case the filter above let a closed task through
      set incompleteTasks to {}
      repeat with aTask in candidateTasks
        set taskIsOpen to true
        try
          if completed of aTask then set taskIsOpen to false
        end try
        if not includeDropped then
          try
            if dropped of aTask then set taskIsOpen to false
          end try
        end if
        if taskIsOpen then set end of incompleteTasks to contents of aTask
      end repeat

      if (count of incompleteTasks) = 0 then
        return "📥 Inbox is empty"
      else
        set taskList to "📥 Inbox (" & (count of incompleteTasks) & " items):"
        repeat with aTask in incompleteTasks
          set taskName to name of aTask
          -- A task that already has a provisional project or parent task (it stays here until Clean Up)
          set assignedText to ""
          try
            set assignedItem to assigned container of aTask
            if assignedItem is not missing value then set assignedText to " → " & (name of assignedItem)
          end try
          if flagged of aTask then
            set taskList to taskList & return & "• " & taskName & " 🚩" & assignedText & " [id:" & (id of aTask) & "]"
          else
            set taskList to taskList & return & "• " & taskName & assignedText & " [id:" & (id of aTask) & "]"
          end if
        end repeat
        return taskList
      end if
    end tell
  end tell
end run
