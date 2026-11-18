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
        -- The hidden root task of a project has the ID of its project. It is no task: the project IDs are left out of the
        -- search, and an ID that belongs to a project is refused
        set projectIDs to {}
        try
            set projectIDs to id of every flattened project
        end try

        -- "id:<id>" addresses exactly one task; otherwise search open tasks by name
        set skippedProjects to 0
        if searchName starts with "id:" and (length of searchName) > 3 then
            set wantedID to text 4 thru -1 of searchName
            set isProjectID to false
            considering case
                if projectIDs contains wantedID then set isProjectID to true
            end considering
            if isProjectID then
                set projectMatches to every flattened project whose id is wantedID
                set projectNameText to wantedID
                if (count of projectMatches) > 0 then set projectNameText to name of item 1 of projectMatches
                return "❌ id:" & wantedID & " is a project, not a task: " & projectNameText & return & "Nothing was changed. Projects are handled by the project tools (get_project, edit_project)."
            end if
            set foundTasks to every flattened task whose id is wantedID
        else
            set foundTasks to every flattened task whose name contains searchName and completed is false
            if (count of foundTasks) > 0 and (count of projectIDs) > 0 then
                -- Same condition, same order: the IDs tell which hits are root tasks of projects
                set foundIDs to id of every flattened task whose name contains searchName and completed is false
                set keptTasks to {}
                repeat with i from 1 to count of foundTasks
                    set isProjectID to false
                    considering case
                        if projectIDs contains (item i of foundIDs) then set isProjectID to true
                    end considering
                    if isProjectID then
                        set skippedProjects to skippedProjects + 1
                    else
                        set end of keptTasks to item i of foundTasks
                    end if
                end repeat
                set foundTasks to keptTasks
            end if
        end if
        
        if (count of foundTasks) = 0 then
          set notFoundText to "❌ No matching tasks found for: " & searchName
          if skippedProjects > 0 then set notFoundText to notFoundText & return & "ℹ️ " & skippedProjects & " project(s) match this name. Projects are handled by the project tools (get_project, edit_project)."
          return notFoundText
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
            set taskList to taskList & "• " & name of aTask & " [id:" & (id of aTask) & "]" & return
          end repeat
          set taskList to taskList & return & "Please be more specific or use id:<id>."
          return taskList
        end if
      on error errMsg
        return "❌ Error: " & errMsg
      end try
    end tell
  end tell
end run
