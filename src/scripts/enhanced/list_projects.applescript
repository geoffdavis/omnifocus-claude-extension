on run argv
    -- List all active projects with optional task statistics
    -- Usage: list_projects.applescript ["true"|"false"]
    
    set includeStats to false
    
    if (count of argv) > 0 then
        set includeStats to (item 1 of argv is "true")
    end if
    
    tell application "OmniFocus"
        tell default document
            set activeProjects to every flattened project where its status is active status
            set onHoldProjects to every flattened project where its status is on hold status
            set droppedProjects to every flattened project where its status is dropped status
            
            set totalActive to count of activeProjects
            set totalOnHold to count of onHoldProjects
            set totalDropped to count of droppedProjects
            
            if totalActive = 0 then
                return "📁 No active projects" & return & "(" & totalOnHold & " on hold, " & totalDropped & " dropped)"
            end if
            
            set projectList to "📁 Projects Overview" & return
            set projectList to projectList & "════════════════════" & return
            set projectList to projectList & "Active: " & totalActive & " | On Hold: " & totalOnHold & " | Dropped: " & totalDropped & return & return
            
            set projectList to projectList & "📂 Active Projects:" & return
            
            repeat with aProject in activeProjects
                set projectName to name of aProject
                set projectNote to note of aProject
                
                if includeStats then
                    -- Count various task states
                    set allTasks to tasks of aProject
                    set remainingCount to count of (tasks of aProject whose completed is false)
                    try
                        set availableCount to count of (available tasks of aProject)
                    on error
                        set availableCount to 0
                    end try
                    set flaggedCount to count of (tasks of aProject whose flagged is true and completed is false)
                    
                    -- Check for due soon tasks (next 7 days)
                    set weekFromNow to (current date) + 7 * days
                    set dueSoonCount to count of (tasks of aProject whose due date ≤ weekFromNow and due date ≥ (current date) and completed is false)
                    
                    set projectList to projectList & "• " & projectName
                    set projectList to projectList & " (" & remainingCount & " remaining"
                    
                    if availableCount > 0 then
                        set projectList to projectList & ", " & availableCount & " available"
                    end if
                    
                    if flaggedCount > 0 then
                        set projectList to projectList & ", " & flaggedCount & " flagged"
                    end if
                    
                    if dueSoonCount > 0 then
                        set projectList to projectList & ", " & dueSoonCount & " due soon"
                    end if
                    
                    set projectList to projectList & ")"
                    
                    -- Add project note preview if exists
                    if projectNote is not "" then
                        set noteLength to length of projectNote
                        set previewLength to my minValue(50, noteLength)
                        set notePreview to text 1 thru previewLength of projectNote
                        if noteLength > 50 then set notePreview to notePreview & "..."
                        set projectList to projectList & return & "  💬 " & notePreview
                    end if
                else
                    set projectList to projectList & "• " & projectName
                end if
                
                set projectList to projectList & return
            end repeat
            
            -- Add summary statistics if requested
            if includeStats then
                set projectList to projectList & return & "📊 Summary Statistics:" & return
                
                -- Calculate totals across all active projects
                set totalRemaining to 0
                set totalAvailable to 0
                set totalFlagged to 0
                
                repeat with aProject in activeProjects
                    set totalRemaining to totalRemaining + (count of (tasks of aProject whose completed is false))
                    try
                        set totalAvailable to totalAvailable + (count of (available tasks of aProject))
                    on error
                        -- Skip projects that don't support available tasks
                    end try
                    set totalFlagged to totalFlagged + (count of (tasks of aProject whose flagged is true and completed is false))
                end repeat
                
                set projectList to projectList & "• Total remaining tasks: " & totalRemaining & return
                set projectList to projectList & "• Total available tasks: " & totalAvailable & return
                set projectList to projectList & "• Total flagged tasks: " & totalFlagged
            end if
            
            return projectList
        end tell
    end tell
end run

on minValue(x, y)
    if x < y then
        return x
    else
        return y
    end if
end minValue
