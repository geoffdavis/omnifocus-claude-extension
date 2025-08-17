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
            
            -- Configure repetition
            tell newTask
                try
                    set repetition rule to my parseRepeatRule(repeatRule)
                    
                    -- Set the repetition method (fixed or due)
                    if repeatRule contains "fixed" then
                        set repetition method to fixed repetition
                    else
                        set repetition method to due after completion
                    end if
                    
                on error errMsg
                    return "⚠️ Created task but couldn't set repeat: " & errMsg
                end try
            end tell
            
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

on parseRepeatRule(ruleString)
    -- Create a repetition rule record based on the input string
    set ruleRecord to {unit:week, steps:1}
    
    if ruleString is "daily" then
        set ruleRecord to {unit:day, steps:1}
    else if ruleString is "weekly" then
        set ruleRecord to {unit:week, steps:1}
    else if ruleString is "monthly" then
        set ruleRecord to {unit:month, steps:1}
    else if ruleString is "yearly" or ruleString is "annually" then
        set ruleRecord to {unit:year, steps:1}
    else if ruleString contains "day" then
        try
            set stepCount to word 1 of ruleString as integer
            set ruleRecord to {unit:day, steps:stepCount}
        end try
    else if ruleString contains "week" then
        try
            set stepCount to word 1 of ruleString as integer
            set ruleRecord to {unit:week, steps:stepCount}
        end try
    else if ruleString contains "month" then
        try
            set stepCount to word 1 of ruleString as integer
            set ruleRecord to {unit:month, steps:stepCount}
        end try
    else if ruleString contains "year" then
        try
            set stepCount to word 1 of ruleString as integer
            set ruleRecord to {unit:year, steps:stepCount}
        end try
    end if
    
    return ruleRecord
end parseRepeatRule

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
