tell application "OmniFocus"
  tell default document
    set inboxCount to count of inbox tasks
    set flaggedCount to count of (flattened tasks whose flagged is true and completed is false)
    set overdueCount to 0
    set dueThisWeek to 0
    set projectCount to count of projects
    set activeProjectCount to 0
    
    set todayStart to current date
    set weekEnd to todayStart + 7 * days
    
    set allTasks to flattened tasks whose completed is false
    repeat with aTask in allTasks
      set taskDue to due date of aTask
      if taskDue is not missing value then
        if taskDue < todayStart then
          set overdueCount to overdueCount + 1
        else if taskDue < weekEnd then
          set dueThisWeek to dueThisWeek + 1
        end if
      end if
    end repeat
    
    repeat with aProject in projects
      if (count of (flattened tasks of aProject whose completed is false)) > 0 then
        set activeProjectCount to activeProjectCount + 1
      end if
    end repeat
    
    set report to "📊 WEEKLY REVIEW SUMMARY" & return
    set report to report & "════════════════════════" & return & return
    set report to report & "📥 Inbox: " & inboxCount & " items" & return
    set report to report & "🚩 Flagged: " & flaggedCount & " tasks" & return
    set report to report & "⚠️  Overdue: " & overdueCount & " tasks" & return
    set report to report & "📅 Due this week: " & dueThisWeek & " tasks" & return
    set report to report & "📁 Active projects: " & activeProjectCount & " of " & projectCount & return & return
    
    if inboxCount > 0 then
      set report to report & "💡 Action: Process " & inboxCount & " inbox items" & return
    end if
    if overdueCount > 0 then
      set report to report & "💡 Action: Review " & overdueCount & " overdue tasks" & return
    end if
    
    return report
  end tell
end tell