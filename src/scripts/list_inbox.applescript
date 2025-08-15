tell application "OmniFocus"
  tell default document
    set inboxTasks to inbox tasks
    set taskList to {}
    
    repeat with aTask in inboxTasks
      set taskName to name of aTask
      set taskFlagged to flagged of aTask
      
      set taskInfo to "• " & taskName
      if taskFlagged then
        set taskInfo to taskInfo & " 🚩"
      end if
      
      set end of taskList to taskInfo
    end repeat
    
    if (count of taskList) is 0 then
      return "📥 Inbox is empty!"
    else
      set AppleScript's text item delimiters to return
      set taskListText to taskList as string
      set AppleScript's text item delimiters to ""
      return "📥 Inbox (" & (count of taskList) & " items):" & return & taskListText
    end if
  end tell
end tell