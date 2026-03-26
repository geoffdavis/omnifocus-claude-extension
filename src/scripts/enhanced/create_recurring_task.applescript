on run argv
    -- Create a recurring task with repeat settings
    -- Usage: create_recurring_task.applescript "task name" "repeat_rule" "project" "due_date"
    -- Repeat rules: "daily", "weekly", "monthly", "yearly", "3 days", "2 weeks", etc.
    
    set taskName to item 1 of argv
    set repeatRule to "weekly" -- default
    set projectName to ""
    set initialDueDate to ""
    
    if (count of argv) > 1 then
        set repeatRule to item 2 of argv
    end if
    
    if (count of argv) > 2 then
        set projectName to item 3 of argv
    end if
    
    if (count of argv) > 3 then
        set initialDueDate to item 4 of argv
    end if
    
    tell application "OmniFocus"
        tell default document
            -- Find target project if specified
            set targetProject to missing value
            if projectName is not "" and projectName is not "inbox" then
                try
                    set matchingProjects to every project whose name contains projectName
                    if (count of matchingProjects) > 0 then
                        set targetProject to item 1 of matchingProjects
                    end if
                end try
            end if
            
            -- Create the task
            if targetProject is not missing value then
                tell targetProject
                    set newTask to make new task with properties {name:taskName}
                end tell
            else
                set newTask to make new inbox task with properties {name:taskName}
            end if
            
            -- Set initial due date if specified
            if initialDueDate is not "" then
                set due date of newTask to my parseDate(initialDueDate)
            else
                set due date of newTask to (current date) + 1 * days
            end if
            
            -- Configure repetition using repetition rule with ICS/RFC 5545 recurrence strings
            try
                set recurrenceString to my buildRecurrenceString(repeatRule)
                if repeatRule contains "fixed" then
                    set repetition rule of newTask to {repetition method:fixed repetition, recurrence:recurrenceString}
                else
                    set repetition rule of newTask to {repetition method:due after completion, recurrence:recurrenceString}
                end if
            on error errMsg
                return "⚠️ Created task but couldn't set repeat: " & errMsg
            end try
            
            -- Return confirmation
            set resultText to "🔄 Created recurring task: " & taskName
            
            if targetProject is not missing value then
                set resultText to resultText & return & "📁 Project: " & name of targetProject
            end if
            
            set resultText to resultText & return & "🔁 Repeats: " & repeatRule
            
            try
                set nextDue to due date of newTask
                if nextDue is not missing value then
                    set resultText to resultText & return & "📅 First due: " & (nextDue as string)
                end if
            end try
            
            return resultText
        end tell
    end tell
end run

on buildRecurrenceString(ruleString)
    -- Build an ICS/RFC 5545 recurrence string from the user's repeat rule input
    -- Returns strings like "FREQ=WEEKLY", "FREQ=DAILY;INTERVAL=3", etc.

    -- Strip "fixed" modifier if present (handled separately for repetition method)
    set cleanRule to ruleString
    if cleanRule contains "fixed" then
        set cleanRule to my replaceText(cleanRule, "fixed", "")
        set cleanRule to my trimText(cleanRule)
    end if

    if cleanRule is "daily" then
        return "FREQ=DAILY"
    else if cleanRule is "weekly" then
        return "FREQ=WEEKLY"
    else if cleanRule is "monthly" then
        return "FREQ=MONTHLY"
    else if cleanRule is "yearly" or cleanRule is "annually" then
        return "FREQ=YEARLY"
    else if cleanRule contains "day" then
        try
            set stepCount to word 1 of cleanRule as integer
            return "FREQ=DAILY;INTERVAL=" & stepCount
        on error
            return "FREQ=DAILY"
        end try
    else if cleanRule contains "week" then
        try
            set stepCount to word 1 of cleanRule as integer
            return "FREQ=WEEKLY;INTERVAL=" & stepCount
        on error
            return "FREQ=WEEKLY"
        end try
    else if cleanRule contains "month" then
        try
            set stepCount to word 1 of cleanRule as integer
            return "FREQ=MONTHLY;INTERVAL=" & stepCount
        on error
            return "FREQ=MONTHLY"
        end try
    else if cleanRule contains "year" then
        try
            set stepCount to word 1 of cleanRule as integer
            return "FREQ=YEARLY;INTERVAL=" & stepCount
        on error
            return "FREQ=YEARLY"
        end try
    end if

    -- Default to weekly
    return "FREQ=WEEKLY"
end buildRecurrenceString

on replaceText(sourceText, searchText, replacementText)
    set AppleScript's text item delimiters to searchText
    set textItems to text items of sourceText
    set AppleScript's text item delimiters to replacementText
    set resultText to textItems as string
    set AppleScript's text item delimiters to ""
    return resultText
end replaceText

on trimText(sourceText)
    -- Simple trim: remove leading/trailing spaces
    set resultText to sourceText
    repeat while resultText starts with " "
        set resultText to text 2 thru -1 of resultText
    end repeat
    repeat while resultText ends with " "
        set resultText to text 1 thru -2 of resultText
    end repeat
    return resultText
end trimText

on parseDate(dateString)
    set todayDate to current date
    
    if dateString is "today" then
        return todayDate
    else if dateString is "tomorrow" then
        return todayDate + 1 * days
    else if dateString is "next week" then
        return todayDate + 7 * days
    else if dateString contains "days" then
        try
            set dayCount to word 1 of dateString as integer
            return todayDate + dayCount * days
        on error
            return todayDate
        end try
    else
        try
            return date dateString
        on error
            return todayDate + 1 * days
        end try
    end if
end parseDate
