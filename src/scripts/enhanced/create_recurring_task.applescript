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
                -- Searches open projects in all folders; accepts "Folder > Subfolder > Project" and "id:<id>"
                set projectLookup to my resolveProject(projectName)
                if foundProject of projectLookup is missing value then
                    return errorText of projectLookup & return & "Nothing was created."
                end if
                set targetProject to foundProject of projectLookup
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
            if stepCount < 1 then set stepCount to 1
            if stepCount is 1 then return "FREQ=DAILY"
            return "FREQ=DAILY;INTERVAL=" & stepCount
        on error
            return "FREQ=DAILY"
        end try
    else if cleanRule contains "week" then
        try
            set stepCount to word 1 of cleanRule as integer
            if stepCount < 1 then set stepCount to 1
            if stepCount is 1 then return "FREQ=WEEKLY"
            return "FREQ=WEEKLY;INTERVAL=" & stepCount
        on error
            return "FREQ=WEEKLY"
        end try
    else if cleanRule contains "month" then
        try
            set stepCount to word 1 of cleanRule as integer
            if stepCount < 1 then set stepCount to 1
            if stepCount is 1 then return "FREQ=MONTHLY"
            return "FREQ=MONTHLY;INTERVAL=" & stepCount
        on error
            return "FREQ=MONTHLY"
        end try
    else if cleanRule contains "year" then
        try
            set stepCount to word 1 of cleanRule as integer
            if stepCount < 1 then set stepCount to 1
            if stepCount is 1 then return "FREQ=YEARLY"
            return "FREQ=YEARLY;INTERVAL=" & stepCount
        on error
            return "FREQ=YEARLY"
        end try
    end if

    -- Default to weekly
    return "FREQ=WEEKLY"
end buildRecurrenceString

on replaceText(sourceText, searchText, replacementText)
    set oldDelims to AppleScript's text item delimiters
    try
        set AppleScript's text item delimiters to searchText
        set textItems to text items of sourceText
        set AppleScript's text item delimiters to replacementText
        set resultText to textItems as string
        set AppleScript's text item delimiters to oldDelims
        return resultText
    on error errMsg number errNum
        set AppleScript's text item delimiters to oldDelims
        error errMsg number errNum
    end try
end replaceText

on trimText(sourceText)
    -- Trim leading/trailing spaces, guarding against short/empty strings
    if sourceText is "" then return ""
    set resultText to sourceText
    repeat while resultText starts with " "
        if (length of resultText) ≤ 1 then return ""
        set resultText to text 2 thru -1 of resultText
    end repeat
    repeat while resultText ends with " "
        if (length of resultText) ≤ 1 then return ""
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
    else if length of dateString is 10 and character 5 of dateString is "-" and character 8 of dateString is "-" then
        -- ISO date YYYY-MM-DD (midnight)
        try
            set isoDate to current date
            set day of isoDate to 1
            set year of isoDate to (text 1 thru 4 of dateString) as integer
            set month of isoDate to (text 6 thru 7 of dateString) as integer
            set day of isoDate to (text 9 thru 10 of dateString) as integer
            set time of isoDate to 0
            return isoDate
        on error
            return todayDate + 1 * days
        end try
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

on trimItem(theText)
    set whitespaceChars to {" ", tab}
    set textLength to length of theText
    if textLength is 0 then return ""
    set textStart to 1
    repeat while textStart ≤ textLength and character textStart of theText is in whitespaceChars
        set textStart to textStart + 1
    end repeat
    if textStart > textLength then return ""
    set textEnd to textLength
    repeat while textEnd ≥ textStart and character textEnd of theText is in whitespaceChars
        set textEnd to textEnd - 1
    end repeat
    return text textStart thru textEnd of theText
end trimItem

on resolveProject(queryText)
    -- "id:<id>" addresses exactly one project
    if queryText starts with "id:" and (length of queryText) > 3 then
        tell application "OmniFocus"
            tell default document
                set wantedID to text 4 thru -1 of queryText
                set idMatches to every flattened project whose id is wantedID
            end tell
        end tell
        if (count of idMatches) = 1 then
            return {foundProject:item 1 of idMatches, errorText:""}
        end if
        return {foundProject:missing value, errorText:"❌ Project not found: " & queryText}
    end if
    
    -- Finds an open (active or on hold) project in any folder by name, or by "Folder > Subfolder > Project".
    -- Names match exactly or as a substring, ignoring case.
    -- Returns {foundProject, errorText}; foundProject is missing value if nothing or more than one project fits.
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ">"
    set rawParts to text items of queryText
    set AppleScript's text item delimiters to oldDelims
    
    set queryParts to {}
    repeat with rawPart in rawParts
        set cleanPart to my trimItem(rawPart as string)
        if cleanPart is not "" then set end of queryParts to cleanPart
    end repeat
    if (count of queryParts) = 0 then
        return {foundProject:missing value, errorText:"❌ Project name cannot be empty."}
    end if
    
    set projectQuery to item -1 of queryParts
    set folderQuery to {}
    if (count of queryParts) > 1 then set folderQuery to items 1 thru -2 of queryParts
    
    tell application "OmniFocus"
        tell default document
            set allProjects to every flattened project
        end tell
    end tell
    
    set exactMatches to {}
    set partialMatches to {}
    repeat with aProject in allProjects
        set candidateProject to contents of aProject
        tell application "OmniFocus" to set candidateName to name of candidateProject
        set projectIsOpen to my isOpenProject(candidateProject)
        ignoring case
            if projectIsOpen and candidateName is projectQuery then
                set end of exactMatches to candidateProject
            else if projectIsOpen and candidateName contains projectQuery then
                set end of partialMatches to candidateProject
            end if
        end ignoring
    end repeat
    
    if (count of folderQuery) > 0 then
        set exactMatches to my filterByFolder(exactMatches, folderQuery)
        set partialMatches to my filterByFolder(partialMatches, folderQuery)
    end if
    
    -- A single exact name wins; otherwise every match counts and must be unique
    if (count of exactMatches) = 1 then
        return {foundProject:item 1 of exactMatches, errorText:""}
    end if
    set allMatches to exactMatches & partialMatches
    if (count of allMatches) = 1 then
        return {foundProject:item 1 of allMatches, errorText:""}
    end if
    if (count of allMatches) = 0 then
        return {foundProject:missing value, errorText:"❌ Project not found: " & queryText}
    end if
    
    set matchList to "❌ Ambiguous project \"" & queryText & "\" (" & (count of allMatches) & " matches). Nothing was changed. Use \"Folder > Project\" to pick one:"
    repeat with aMatch in allMatches
        set matchList to matchList & return & "• " & my projectLabel(contents of aMatch)
    end repeat
    return {foundProject:missing value, errorText:matchList}
end resolveProject

on filterByFolder(projectList, folderQuery)
    -- Keeps the projects whose innermost folders match folderQuery (outermost first)
    set keptProjects to {}
    repeat with aProject in projectList
        set candidateProject to contents of aProject
        set folderNames to my projectFolderNames(candidateProject)
        set queryCount to count of folderQuery
        set nameCount to count of folderNames
        set folderFits to (queryCount ≤ nameCount)
        if folderFits then
            ignoring case
                repeat with i from 1 to queryCount
                    set wantedName to item i of folderQuery
                    set actualName to item (nameCount - queryCount + i) of folderNames
                    if actualName does not contain wantedName then set folderFits to false
                end repeat
            end ignoring
        end if
        if folderFits then set end of keptProjects to candidateProject
    end repeat
    return keptProjects
end filterByFolder

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

on isOpenProject(aProject)
    -- Dropped and completed projects are not valid targets for new tasks
    tell application "OmniFocus"
        try
            set projectStatus to effective status of aProject
            return (projectStatus is active status or projectStatus is on hold status)
        end try
    end tell
    return true
end isOpenProject
