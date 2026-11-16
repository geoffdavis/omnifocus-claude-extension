on run argv
    -- Show the details of one task
    -- Usage: get_task.applescript "task name or id:<id>"
    
    if (count of argv) = 0 then
        return "❌ Task name is required."
    end if
    set searchTerm to item 1 of argv
    if searchTerm is "" then
        return "❌ Task name cannot be empty."
    end if
    
    tell application "OmniFocus"
        tell default document
            -- "id:<id>" addresses exactly one task; otherwise search open tasks by name
            if searchTerm starts with "id:" and (length of searchTerm) > 3 then
                set wantedID to text 4 thru -1 of searchTerm
                set foundTasks to every flattened task whose id is wantedID
            else
                set foundTasks to every flattened task whose name contains searchTerm and completed is false
            end if
            
            if (count of foundTasks) = 0 then
                return "❌ No matching tasks found for: " & searchTerm
            else if (count of foundTasks) > 1 then
                set taskList to "🔍 Multiple tasks found (" & (count of foundTasks) & "):" & return
                repeat with aTask in foundTasks
                    set taskList to taskList & "• " & name of aTask & " [id:" & (id of aTask) & "]" & return
                end repeat
                set taskList to taskList & return & "Please be more specific or use id:<id>."
                return taskList
            end if
            
            set targetTask to item 1 of foundTasks
            set taskInfo to "📝 " & (name of targetTask) & return
            set taskInfo to taskInfo & "ID: " & (id of targetTask) & return
            
            -- State
            set stateText to "open"
            if effectively dropped of targetTask then set stateText to "dropped"
            if effectively completed of targetTask then set stateText to "completed"
            if flagged of targetTask then set stateText to stateText & ", flagged"
            try
                if stateText starts with "open" and blocked of targetTask then set stateText to stateText & ", blocked"
            end try
            set taskInfo to taskInfo & "State: " & stateText & return
            
            -- Location
            set locationText to "Inbox"
            try
                set taskProject to containing project of targetTask
                if taskProject is not missing value then set locationText to my projectLabel(taskProject)
            end try
            set taskInfo to taskInfo & "Project: " & locationText & return
            try
                set taskParent to parent task of targetTask
                if taskParent is not missing value then
                    set parentName to name of taskParent
                    if parentName is not locationText and locationText does not end with parentName then
                        set taskInfo to taskInfo & "Parent task: " & parentName & return
                    end if
                end if
            end try
            
            -- Tags
            set tagNames to name of every tag of targetTask
            if (count of tagNames) > 0 then
                set oldDelims to AppleScript's text item delimiters
                set AppleScript's text item delimiters to ", "
                set taskInfo to taskInfo & "Tags: " & (tagNames as string) & return
                set AppleScript's text item delimiters to oldDelims
            end if
            
            -- Dates and estimate
            set deferValue to defer date of targetTask
            if deferValue is not missing value then set taskInfo to taskInfo & "Deferred until: " & (deferValue as string) & return
            try
                set plannedValue to planned date of targetTask
                if plannedValue is not missing value then set taskInfo to taskInfo & "Planned: " & (plannedValue as string) & return
            end try
            set dueValue to due date of targetTask
            if dueValue is not missing value then set taskInfo to taskInfo & "Due: " & (dueValue as string) & return
            set estimateValue to estimated minutes of targetTask
            if estimateValue is not missing value then set taskInfo to taskInfo & "Estimate: " & estimateValue & " minutes" & return
            set repeatText to my repetitionText(targetTask)
            if repeatText is not "" then set taskInfo to taskInfo & "Repeats: " & repeatText & return
            set subtaskCount to number of tasks of targetTask
            if subtaskCount > 0 then
                set groupNotes to {}
                try
                    if sequential of targetTask then set end of groupNotes to "one after another"
                end try
                try
                    if completed by children of targetTask then set end of groupNotes to "completes with the last subtask"
                end try
                set taskInfo to taskInfo & "Subtasks: " & subtaskCount
                if (count of groupNotes) > 0 then
                    set oldDelims to AppleScript's text item delimiters
                    set AppleScript's text item delimiters to ", "
                    set taskInfo to taskInfo & " (" & (groupNotes as string) & ")"
                    set AppleScript's text item delimiters to oldDelims
                end if
                set taskInfo to taskInfo & return
            end if
            
            -- Note, shortened if very long
            set taskNote to note of targetTask
            if taskNote is not "" then
                if (length of taskNote) > 2000 then set taskNote to (text 1 thru 2000 of taskNote) & "..."
                set taskInfo to taskInfo & "Note: " & taskNote & return
            end if
            return taskInfo
        end tell
    end tell
end run

on projectFolderNames(aProject)
    -- Folder names from the outermost folder down to the one holding the project; {} at top level
    set folderNames to {}
    tell application "OmniFocus"
        try
            set currentFolder to folder of aProject
            repeat while currentFolder is not missing value
                set beginning of folderNames to name of currentFolder
                set parentContainer to container of currentFolder
                if class of parentContainer is folder then
                    set currentFolder to parentContainer
                else
                    set currentFolder to missing value
                end if
            end repeat
        end try
    end tell
    return folderNames
end projectFolderNames

on projectLabel(aProject)
    -- "Folder > Subfolder > Project", the same form resolveProject accepts
    tell application "OmniFocus" to set projectName to name of aProject
    set labelText to ""
    repeat with folderName in my projectFolderNames(aProject)
        set labelText to labelText & folderName & " > "
    end repeat
    return labelText & projectName
end projectLabel

on parseRepeatRule(ruleText)
    -- Reads a repeat rule: "daily", "weekly", "monthly", "yearly", "3 days", "2 weeks", "1 month", "every 2 weeks".
    -- "fixed" at the end means a fixed schedule instead of "after completion", for example "weekly fixed".
    -- Returns {isValid, ruleString, useFixed, errorText}; ruleString is an iCalendar string such as FREQ=WEEKLY;INTERVAL=2
    set problemText to "❌ Invalid repeat: " & ruleText & ". Use for example \"daily\", \"weekly\", \"2 weeks\", \"3 months\" or \"1 year\", add \"fixed\" for a fixed schedule (\"weekly fixed\"), or \"none\" to stop repeating."
    set wordList to words of ruleText
    set useFixed to false
    ignoring case
        if (count of wordList) > 1 and item 1 of wordList is "every" then set wordList to items 2 thru -1 of wordList
        if (count of wordList) > 1 and item -1 of wordList is "fixed" then
            set useFixed to true
            set wordList to items 1 thru -2 of wordList
        end if
    end ignoring

    set stepCount to 1
    if (count of wordList) = 1 then
        set unitWord to item 1 of wordList
    else if (count of wordList) = 2 then
        try
            set stepCount to (item 1 of wordList) as integer
        on error
            return {isValid:false, ruleString:"", useFixed:false, errorText:problemText}
        end try
        set unitWord to item 2 of wordList
    else
        return {isValid:false, ruleString:"", useFixed:false, errorText:problemText}
    end if
    if stepCount < 1 or stepCount > 999 then return {isValid:false, ruleString:"", useFixed:false, errorText:problemText}

    set frequencyText to ""
    ignoring case
        if unitWord is "daily" then set unitWord to "day"
        if unitWord is "weekly" then set unitWord to "week"
        if unitWord is "monthly" then set unitWord to "month"
        if unitWord is "yearly" or unitWord is "annually" then set unitWord to "year"
        if (length of unitWord) > 1 and unitWord ends with "s" then set unitWord to text 1 thru -2 of unitWord
        if unitWord is "day" then set frequencyText to "DAILY"
        if unitWord is "week" then set frequencyText to "WEEKLY"
        if unitWord is "month" then set frequencyText to "MONTHLY"
        if unitWord is "year" then set frequencyText to "YEARLY"
    end ignoring
    if frequencyText is "" then return {isValid:false, ruleString:"", useFixed:false, errorText:problemText}

    set recurrenceText to "FREQ=" & frequencyText
    if stepCount > 1 then set recurrenceText to recurrenceText & ";INTERVAL=" & stepCount
    return {isValid:true, ruleString:recurrenceText, useFixed:useFixed, errorText:""}
end parseRepeatRule

on describeRecurrence(recurrenceText)
    -- "FREQ=WEEKLY;INTERVAL=2" becomes "every 2 weeks"; rules with more parts are returned unchanged
    set cleanText to recurrenceText
    if cleanText starts with "RRULE:" then set cleanText to text 7 thru -1 of cleanText
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ";"
    set partList to text items of cleanText
    set AppleScript's text item delimiters to oldDelims

    set frequencyText to ""
    set stepCount to 1
    repeat with aPart in partList
        set partText to aPart as text
        if partText starts with "FREQ=" then
            set frequencyText to text 6 thru -1 of partText
        else if partText starts with "INTERVAL=" then
            try
                set stepCount to (text 10 thru -1 of partText) as integer
            on error
                return recurrenceText
            end try
        else
            return recurrenceText
        end if
    end repeat

    set unitName to ""
    if frequencyText is "DAILY" then set unitName to "day"
    if frequencyText is "WEEKLY" then set unitName to "week"
    if frequencyText is "MONTHLY" then set unitName to "month"
    if frequencyText is "YEARLY" then set unitName to "year"
    if unitName is "" or stepCount < 1 then return recurrenceText
    if stepCount is 1 then return "every " & unitName
    return "every " & stepCount & " " & unitName & "s"
end describeRecurrence

on repetitionText(theTask)
    -- Describes how a task repeats, for example "every 2 weeks, due date after completion", "" if it does not repeat
    set recurrenceText to ""
    set methodText to ""
    tell application "OmniFocus"
        try
            set theRule to repetition rule of theTask
        on error
            return ""
        end try
        if theRule is missing value then return ""
        try
            set recurrenceText to recurrence of theRule
        end try
        try
            set methodValue to repetition method of theRule
            if methodValue is fixed repetition then
                set methodText to "fixed schedule"
            else if methodValue is start after completion then
                set methodText to "defer date after completion"
            else if methodValue is due after completion then
                set methodText to "due date after completion"
            end if
        end try
    end tell
    set resultText to "repeats"
    if recurrenceText is not "" then set resultText to my describeRecurrence(recurrenceText)
    if methodText is not "" then set resultText to resultText & ", " & methodText
    return resultText
end repetitionText
