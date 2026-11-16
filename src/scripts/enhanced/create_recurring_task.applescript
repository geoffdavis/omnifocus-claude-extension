on run argv
    -- Create a recurring task with repeat settings
    -- Usage: create_recurring_task.applescript "task name" "repeat_rule" "project" "due_date"
    -- Repeat rules: "daily", "weekly", "monthly", "yearly", "3 days", "2 weeks", "every monday and thursday", "weekdays",
    --   "monthly on the 15th", "last friday of the month", an iCalendar rule ("FREQ=WEEKLY;BYDAY=MO,TH"), ...
    --   add "fixed" for a fixed schedule or "from completion"
    
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
    
    if taskName is "" then return "❌ A recurring task needs a name. Nothing was created."

    -- The rule is checked before anything is created
    set repeatInfo to my parseRepeatRule(repeatRule)
    if not (isValid of repeatInfo) then return (errorText of repeatInfo) & return & "Nothing was created."

    -- The due date is checked before anything is created; without one the task is due tomorrow
    set dueDateValue to (current date) + 1 * days
    if my trimItem(initialDueDate) is not "" then
        set dueDateValue to my parseDate(initialDueDate)
        if dueDateValue is missing value then return my dateErrorText(initialDueDate, "due_date") & " Nothing was created."
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
            
            set due date of newTask to dueDateValue
            
            -- Configure the repetition; a rule that OmniFocus does not accept removes the new task again
            set problemText to my applyRepetition(newTask, ruleString of repeatInfo, scheduleName of repeatInfo, "due", false)
            if problemText is not "" then
                delete newTask
                return my removeText(problemText, " Nothing was changed.") & return & "Nothing was created."
            end if

            -- Return confirmation
            set resultText to "🔄 Created recurring task: " & taskName
            
            if targetProject is not missing value then
                set resultText to resultText & return & "📁 Project: " & name of targetProject
            end if
            
            set resultText to resultText & return & "🔁 Repeats: " & my repetitionText(newTask)
            
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

on trimItem(theText)
    set whitespaceChars to {" ", tab, return, linefeed}
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

on describeRecurrence(recurrenceText)
    -- "FREQ=WEEKLY;INTERVAL=2" becomes "every 2 weeks", "FREQ=WEEKLY;BYDAY=MO,TH" becomes "every week on Monday and Thursday",
    -- "FREQ=MONTHLY;BYDAY=-1FR" becomes "every month on the last Friday"; rules with other parts are returned unchanged
    set cleanText to recurrenceText
    if cleanText starts with "RRULE:" then set cleanText to text 7 thru -1 of cleanText
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ";"
    set partList to text items of cleanText
    set AppleScript's text item delimiters to oldDelims

    set frequencyText to ""
    set stepCount to 1
    set dayText to ""
    set monthDayText to ""
    set setPositionText to ""
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
        else if partText starts with "BYDAY=" then
            set dayText to text 7 thru -1 of partText
        else if partText starts with "BYMONTHDAY=" then
            set monthDayText to text 12 thru -1 of partText
        else if partText starts with "BYSETPOS=" then
            set setPositionText to text 10 thru -1 of partText
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
    if stepCount is 1 then
        set baseText to "every " & unitName
    else
        set baseText to "every " & stepCount & " " & unitName & "s"
    end if
    if dayText is "" and monthDayText is "" and setPositionText is "" then return baseText

    if frequencyText is "WEEKLY" and dayText is not "" and monthDayText is "" and setPositionText is "" then
        if dayText is "MO,TU,WE,TH,FR" and stepCount is 1 then return "every weekday"
        set dayNames to {}
        set oldDelims to AppleScript's text item delimiters
        set AppleScript's text item delimiters to ","
        set codeList to text items of dayText
        set AppleScript's text item delimiters to oldDelims
        repeat with aCode in codeList
            set dayName to my weekdayName(aCode as text)
            if dayName is "" then return recurrenceText
            set end of dayNames to dayName
        end repeat
        return baseText & " on " & my joinNames(dayNames)
    end if

    if frequencyText is "MONTHLY" and monthDayText is not "" and dayText is "" and setPositionText is "" then
        if monthDayText is "-1" then return baseText & " on the last day"
        if my isDigits(monthDayText) then return baseText & " on day " & monthDayText
        return recurrenceText
    end if

    if frequencyText is "MONTHLY" and dayText is not "" and monthDayText is "" then
        -- "1MO" or "-1FR", or a weekday with BYSETPOS
        set positionText to setPositionText
        set codeText to dayText
        if positionText is "" and (length of dayText) > 2 then
            set positionText to text 1 thru -3 of dayText
            set codeText to text -2 thru -1 of dayText
        end if
        set dayName to my weekdayName(codeText)
        set ordinalWord to my ordinalName(positionText)
        if dayName is "" or ordinalWord is "" then return recurrenceText
        return baseText & " on the " & ordinalWord & " " & dayName
    end if
    return recurrenceText
end describeRecurrence

on weekdayName(codeText)
    if codeText is "MO" then return "Monday"
    if codeText is "TU" then return "Tuesday"
    if codeText is "WE" then return "Wednesday"
    if codeText is "TH" then return "Thursday"
    if codeText is "FR" then return "Friday"
    if codeText is "SA" then return "Saturday"
    if codeText is "SU" then return "Sunday"
    return ""
end weekdayName

on ordinalName(positionText)
    if positionText is "1" or positionText is "+1" then return "first"
    if positionText is "2" or positionText is "+2" then return "second"
    if positionText is "3" or positionText is "+3" then return "third"
    if positionText is "4" or positionText is "+4" then return "fourth"
    if positionText is "5" or positionText is "+5" then return "fifth"
    if positionText is "-1" then return "last"
    return ""
end ordinalName

on joinNames(nameList)
    -- "Monday", "Monday and Thursday", "Monday, Tuesday and Friday"
    set nameCount to count of nameList
    if nameCount = 1 then return item 1 of nameList
    set headText to my joinText(items 1 thru (nameCount - 1) of nameList, ", ")
    return headText & " and " & (item nameCount of nameList)
end joinNames

on joinText(textItems, separator)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to separator
    set joined to textItems as text
    set AppleScript's text item delimiters to oldDelims
    return joined
end joinText

on isDigits(theText)
    -- True if the text is not empty and has only the digits 0 to 9
    if theText is "" then return false
    repeat with aChar in characters of theText
        if "0123456789" does not contain (contents of aChar) then return false
    end repeat
    return true
end isDigits

on readRepetition(theItem)
    -- The repetition of a task or project as {ruleExists, ruleRecurrence, ruleSchedule, ruleBasedOn, ruleCatchUp}
    --   ruleSchedule is "regularly" or "from completion", ruleBasedOn is "due", "defer" or "planned"
    set recurrenceText to ""
    set scheduleName to "from completion"
    set basedOnName to "due"
    set catchValue to false
    tell application "OmniFocus"
        try
            set theRule to repetition rule of theItem
        on error
            return {ruleExists:false, ruleRecurrence:"", ruleSchedule:"", ruleBasedOn:"", ruleCatchUp:false}
        end try
        if theRule is missing value then return {ruleExists:false, ruleRecurrence:"", ruleSchedule:"", ruleBasedOn:"", ruleCatchUp:false}
        try
            set recurrenceText to recurrence of theRule
        end try
        set readSchedule to false
        try
            set scheduleText to (repetition schedule of theRule) as text
            if scheduleText contains "completion" then
                set scheduleName to "from completion"
            else
                set scheduleName to "regularly"
            end if
            set basedOnText to (repetition based on of theRule) as text
            if basedOnText contains "defer" then
                set basedOnName to "defer"
            else if basedOnText contains "planned" then
                set basedOnName to "planned"
            else
                set basedOnName to "due"
            end if
            set readSchedule to true
        end try
        if not readSchedule then
            -- the older way: a repetition method
            try
                set methodText to (repetition method of theRule) as text
                if methodText contains "fixed" then
                    set scheduleName to "regularly"
                else if methodText contains "start" then
                    set basedOnName to "defer"
                end if
            end try
        end if
        try
            set catchValue to catch up automatically of theRule
        end try
    end tell
    return {ruleExists:true, ruleRecurrence:recurrenceText, ruleSchedule:scheduleName, ruleBasedOn:basedOnName, ruleCatchUp:catchValue}
end readRepetition

on repetitionText(theItem)
    -- Describes how a task or project repeats, for example "every 2 weeks, due date after completion" or
    -- "every week on Monday and Thursday, fixed schedule"; "" if it does not repeat
    set ruleInfo to my readRepetition(theItem)
    if not (ruleExists of ruleInfo) then return ""
    set resultText to "repeats"
    if (ruleRecurrence of ruleInfo) is not "" then set resultText to my describeRecurrence(ruleRecurrence of ruleInfo)
    set basedOnName to ruleBasedOn of ruleInfo
    if (ruleSchedule of ruleInfo) is "regularly" then
        set resultText to resultText & ", fixed schedule"
        if basedOnName is not "due" then set resultText to resultText & ", based on the " & basedOnName & " date"
        if ruleCatchUp of ruleInfo then set resultText to resultText & ", catches up automatically"
    else
        set resultText to resultText & ", " & basedOnName & " date after completion"
    end if
    return resultText
end repetitionText

on parseRepeatRule(ruleText)
    -- Reads a repeat rule and returns {isValid, ruleString, scheduleName, errorText}.
    --   ruleString is an iCalendar string such as FREQ=WEEKLY;INTERVAL=2 or FREQ=MONTHLY;BYDAY=-1FR
    --   scheduleName is "regularly" (fixed schedule) or "from completion"
    -- Rules in words: "daily", "weekly", "monthly", "yearly", "3 days", "2 weeks", "every 2 weeks",
    --   "every monday", "monday and thursday", "weekdays", "every 2 weeks on monday",
    --   "monthly on the 15th", "monthly on day 15", "last day of the month",
    --   "first monday of the month", "last friday of the month", "every 3 months on the 2nd tuesday".
    -- An iCalendar rule is accepted as well: "FREQ=WEEKLY;BYDAY=MO,TH".
    -- At the end: "fixed" (fixed schedule) or "from completion". Without it, a rule that only has an interval
    -- follows the completion, a rule with weekdays or days of the month follows the calendar.
    set problemText to "❌ Invalid repeat: " & ruleText & ". Use for example \"daily\", \"weekly\", \"2 weeks\", \"every monday and thursday\", \"weekdays\", \"monthly on the 15th\", \"last friday of the month\", \"first monday of the month\" or an iCalendar rule like \"FREQ=WEEKLY;BYDAY=MO,TH\". Add \"fixed\" for a fixed schedule (\"weekly fixed\") or \"from completion\", or use \"none\" to stop repeating."
    set invalidResult to {isValid:false, ruleString:"", scheduleName:"", errorText:problemText}
    set cleanText to my trimItem(ruleText)
    if cleanText is "" then return invalidResult

    -- "fixed" or "from completion" at the end
    set scheduleName to ""
    if cleanText ends with " fixed" then
        set scheduleName to "regularly"
        set cleanText to my trimItem(text 1 thru -7 of cleanText)
    else if cleanText ends with " from completion" then
        set scheduleName to "from completion"
        set cleanText to my trimItem(text 1 thru -17 of cleanText)
    else if cleanText ends with " after completion" then
        set scheduleName to "from completion"
        set cleanText to my trimItem(text 1 thru -18 of cleanText)
    end if
    if cleanText is "" then return invalidResult

    -- An iCalendar rule
    if cleanText contains "=" then
        set rawText to my upperText(cleanText)
        set rawText to my removeText(rawText, " ")
        if rawText starts with "RRULE:" then set rawText to text 7 thru -1 of rawText
        repeat while (length of rawText) > 0 and rawText ends with ";"
            if (length of rawText) = 1 then
                set rawText to ""
            else
                set rawText to text 1 thru -2 of rawText
            end if
        end repeat
        if not (rawText starts with "FREQ=") then return invalidResult
        if rawText contains ";;" then return invalidResult
        set allowedChars to "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789=;,+-"
        repeat with aChar in characters of rawText
            if allowedChars does not contain (contents of aChar) then return invalidResult
        end repeat
        if scheduleName is "" then
            set scheduleName to "from completion"
            if rawText contains "BYDAY" or rawText contains "BYMONTHDAY" or rawText contains "BYSETPOS" then set scheduleName to "regularly"
        end if
        return {isValid:true, ruleString:rawText, scheduleName:scheduleName, errorText:""}
    end if

    -- A rule in words
    set tokenList to words of cleanText
    set intervalCount to 0
    set unitFound to ""
    set weekdayCodes to {}
    set ordinalFound to 0
    set hasOrdinal to false
    set dayNumber to 0
    set lastDayFlag to false
    set otherFlag to false
    set skipNext to false
    set tokenCount to count of tokenList
    repeat with i from 1 to tokenCount
        if skipNext then
            set skipNext to false
        else
            set tokenText to item i of tokenList
            set nextText to ""
            if i < tokenCount then set nextText to item (i + 1) of tokenList
            set previousText to ""
            if i > 1 then set previousText to item (i - 1) of tokenList
            ignoring case
                if tokenText is "every" or tokenText is "each" or tokenText is "on" or tokenText is "the" or tokenText is "of" or tokenText is "and" or tokenText is "at" or tokenText is "in" or tokenText is "a" or tokenText is "an" then
                    -- filler words
                else if tokenText is "other" then
                    set otherFlag to true
                else if tokenText is "weekday" or tokenText is "weekdays" then
                    repeat with dayCode in {"MO", "TU", "WE", "TH", "FR"}
                        if weekdayCodes does not contain (contents of dayCode) then set end of weekdayCodes to (contents of dayCode)
                    end repeat
                else if tokenText is "weekend" or tokenText is "weekends" then
                    repeat with dayCode in {"SA", "SU"}
                        if weekdayCodes does not contain (contents of dayCode) then set end of weekdayCodes to (contents of dayCode)
                    end repeat
                else if my weekdayCode(tokenText) is not "" then
                    set foundCode to my weekdayCode(tokenText)
                    if weekdayCodes does not contain foundCode then set end of weekdayCodes to foundCode
                else if tokenText is "day" and previousText is "last" then
                    set lastDayFlag to true
                else if tokenText is "day" and my isDigits(nextText) then
                    set dayNumber to nextText as integer
                    set skipNext to true
                else if my unitCode(tokenText) is not "" then
                    set foundUnit to my unitCode(tokenText)
                    if unitFound is not "" and unitFound is not foundUnit then return invalidResult
                    set unitFound to foundUnit
                else if my isDigits(tokenText) then
                    if my unitCode(nextText) is "" then return invalidResult
                    set intervalCount to tokenText as integer
                    if intervalCount < 1 then return invalidResult
                else if my ordinalValue(tokenText) is not 0 then
                    set ordinalFound to my ordinalValue(tokenText)
                    set hasOrdinal to true
                else
                    return invalidResult
                end if
            end ignoring
        end if
    end repeat
    if otherFlag and intervalCount = 0 then set intervalCount to 2
    if intervalCount > 999 then return invalidResult

    set frequencyText to ""
    set extraPart to ""
    if (count of weekdayCodes) > 0 then
        if hasOrdinal then
            -- the first, second, ... or last weekday of the month
            if (count of weekdayCodes) is not 1 then return invalidResult
            if unitFound is not "" and unitFound is not "MONTHLY" then return invalidResult
            if not (ordinalFound is -1 or (ordinalFound ≥ 1 and ordinalFound ≤ 5)) then return invalidResult
            set frequencyText to "MONTHLY"
            set extraPart to "BYDAY=" & (ordinalFound as text) & (item 1 of weekdayCodes)
        else
            if unitFound is not "" and unitFound is not "WEEKLY" then return invalidResult
            set frequencyText to "WEEKLY"
            set extraPart to "BYDAY=" & my joinText(weekdayCodes, ",")
        end if
    else if lastDayFlag then
        if unitFound is not "" and unitFound is not "MONTHLY" then return invalidResult
        set frequencyText to "MONTHLY"
        set extraPart to "BYMONTHDAY=-1"
    else if dayNumber > 0 or hasOrdinal then
        -- a day of the month: "monthly on the 15th", "monthly on day 15"
        if unitFound is not "MONTHLY" then return invalidResult
        if dayNumber = 0 then set dayNumber to ordinalFound
        if not (dayNumber is -1 or (dayNumber ≥ 1 and dayNumber ≤ 31)) then return invalidResult
        set frequencyText to "MONTHLY"
        set extraPart to "BYMONTHDAY=" & (dayNumber as text)
    else
        if unitFound is "" then return invalidResult
        set frequencyText to unitFound
    end if

    set recurrenceText to "FREQ=" & frequencyText
    if intervalCount > 1 then set recurrenceText to recurrenceText & ";INTERVAL=" & intervalCount
    if extraPart is not "" then set recurrenceText to recurrenceText & ";" & extraPart
    if scheduleName is "" then
        set scheduleName to "from completion"
        if extraPart is not "" then set scheduleName to "regularly"
    end if
    return {isValid:true, ruleString:recurrenceText, scheduleName:scheduleName, errorText:""}
end parseRepeatRule

on weekdayCode(wordText)
    -- "monday", "mondays", "mon" become "MO", and so on; "" for any other word
    set cleanWord to wordText
    ignoring case
        if cleanWord ends with "days" and (length of cleanWord) > 4 then set cleanWord to text 1 thru -2 of cleanWord
        if cleanWord is "monday" or cleanWord is "mon" then return "MO"
        if cleanWord is "tuesday" or cleanWord is "tue" or cleanWord is "tues" then return "TU"
        if cleanWord is "wednesday" or cleanWord is "wed" then return "WE"
        if cleanWord is "thursday" or cleanWord is "thu" or cleanWord is "thur" or cleanWord is "thurs" then return "TH"
        if cleanWord is "friday" or cleanWord is "fri" then return "FR"
        if cleanWord is "saturday" or cleanWord is "sat" then return "SA"
        if cleanWord is "sunday" or cleanWord is "sun" then return "SU"
    end ignoring
    return ""
end weekdayCode

on unitCode(wordText)
    -- "day", "days", "daily" become "DAILY", and so on; "" for any other word
    ignoring case
        if wordText is "day" or wordText is "days" or wordText is "daily" then return "DAILY"
        if wordText is "week" or wordText is "weeks" or wordText is "weekly" then return "WEEKLY"
        if wordText is "month" or wordText is "months" or wordText is "monthly" then return "MONTHLY"
        if wordText is "year" or wordText is "years" or wordText is "yearly" or wordText is "annually" then return "YEARLY"
    end ignoring
    return ""
end unitCode

on ordinalValue(wordText)
    -- "first" is 1 ... "fifth" is 5, "last" is -1, "15th" is 15; 0 for any other word
    ignoring case
        if wordText is "first" then return 1
        if wordText is "second" then return 2
        if wordText is "third" then return 3
        if wordText is "fourth" then return 4
        if wordText is "fifth" then return 5
        if wordText is "last" then return -1
        if (length of wordText) > 2 then
            set suffixText to text -2 thru -1 of wordText
            if suffixText is "st" or suffixText is "nd" or suffixText is "rd" or suffixText is "th" then
                set numberPart to text 1 thru -3 of wordText
                if my isDigits(numberPart) then return numberPart as integer
            end if
        end if
    end ignoring
    return 0
end ordinalValue

on upperText(theText)
    set resultText to ""
    repeat with aChar in characters of theText
        set theChar to contents of aChar
        set codeValue to id of theChar
        if codeValue ≥ 97 and codeValue ≤ 122 then
            set resultText to resultText & (character id (codeValue - 32))
        else
            set resultText to resultText & theChar
        end if
    end repeat
    return resultText
end upperText

on removeText(theText, unwantedText)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to unwantedText
    set partList to text items of theText
    set AppleScript's text item delimiters to ""
    set resultText to partList as text
    set AppleScript's text item delimiters to oldDelims
    return resultText
end removeText

on hasRepetitionDate(theItem, basedOnName)
    -- True if the task or project has the date a repetition is based on: "due", "defer" or "planned"
    tell application "OmniFocus"
        try
            if basedOnName is "due" then return ((due date of theItem) is not missing value)
            if basedOnName is "defer" then return ((defer date of theItem) is not missing value)
            if basedOnName is "planned" then return ((planned date of theItem) is not missing value)
        end try
    end tell
    return false
end hasRepetitionDate

on defaultBasedOn(theItem)
    -- The date a new repetition is based on: the due date, else the defer date, else the planned date; "" if there is none
    if my hasRepetitionDate(theItem, "due") then return "due"
    if my hasRepetitionDate(theItem, "defer") then return "defer"
    if my hasRepetitionDate(theItem, "planned") then return "planned"
    return ""
end defaultBasedOn

on applyRepetition(theItem, recurrenceText, scheduleName, basedOnName, catchValue)
    -- Sets the repetition rule of a task or project. Returns "" or the text of an error (nothing is changed then).
    tell application "OmniFocus"
        try
            if scheduleName is "regularly" then
                if basedOnName is "defer" then
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:regularly, repetition based on:based on defer, catch up automatically:catchValue}
                else if basedOnName is "planned" then
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:regularly, repetition based on:based on planned, catch up automatically:catchValue}
                else
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:regularly, repetition based on:based on due, catch up automatically:catchValue}
                end if
            else
                if basedOnName is "defer" then
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:from completion, repetition based on:based on defer, catch up automatically:false}
                else if basedOnName is "planned" then
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:from completion, repetition based on:based on planned, catch up automatically:false}
                else
                    set repetition rule of theItem to {recurrence:recurrenceText, repetition schedule:from completion, repetition based on:based on due, catch up automatically:false}
                end if
            end if
        on error errMsg number errNum
            if errNum is -1702 then
                return "❌ OmniFocus does not understand the repeat rule " & recurrenceText & ". Nothing was changed."
            end if
            return "❌ Could not set the repetition: " & errMsg
        end try
    end tell
    return ""
end applyRepetition

on setRepetition(theItem, kindWord, itemLabel, newValue)
    -- Sets, changes or stops (value "none") the repetition of a task or project; returns the message for the person.
    -- A rule that is replaced keeps the date it is based on (if the item still has it) and the catch-up setting.
    if newValue is "none" or newValue is "clear" or newValue is "off" then
        set oldRepeat to my repetitionText(theItem)
        if oldRepeat is "" then return "ℹ️ " & my capitalWord(kindWord) & " does not repeat: " & itemLabel
        tell application "OmniFocus" to set repetition rule of theItem to missing value
        return "✏️ Stopped repeating: " & itemLabel & " (was: " & oldRepeat & ")"
    end if

    set repeatInfo to my parseRepeatRule(newValue)
    if not (isValid of repeatInfo) then return errorText of repeatInfo

    -- A repeating item needs a date to repeat from
    set basedOnName to my defaultBasedOn(theItem)
    if basedOnName is "" then
        return "❌ A repeating " & kindWord & " needs a due, defer or planned date. Set one first. Nothing was changed: " & itemLabel
    end if
    set catchValue to false
    set oldInfo to my readRepetition(theItem)
    if ruleExists of oldInfo then
        if my hasRepetitionDate(theItem, ruleBasedOn of oldInfo) then set basedOnName to ruleBasedOn of oldInfo
        set catchValue to ruleCatchUp of oldInfo
    end if
    if (scheduleName of repeatInfo) is not "regularly" then set catchValue to false

    set problemText to my applyRepetition(theItem, ruleString of repeatInfo, scheduleName of repeatInfo, basedOnName, catchValue)
    if problemText is not "" then return problemText
    return "🔁 " & itemLabel & ": " & my repetitionText(theItem)
end setRepetition

on changeRepetition(theItem, kindWord, itemLabel, partName, valueText)
    -- Changes one setting of an existing repetition: partName "based_on" (due, defer or planned) or "catch_up" (true or false)
    set oldInfo to my readRepetition(theItem)
    if not (ruleExists of oldInfo) then
        return "❌ This " & kindWord & " does not repeat. Set a repeat rule first. Nothing was changed: " & itemLabel
    end if
    set basedOnName to ruleBasedOn of oldInfo
    set catchValue to ruleCatchUp of oldInfo
    set cleanValue to my trimItem(valueText)
    if partName is "based_on" then
        if cleanValue contains "due" then
            set basedOnName to "due"
        else if cleanValue contains "defer" or cleanValue is "start" then
            set basedOnName to "defer"
        else if cleanValue contains "plan" then
            set basedOnName to "planned"
        else
            return "❌ Invalid value for repeat_based_on: " & valueText & ". Use due, defer or planned."
        end if
        if not my hasRepetitionDate(theItem, basedOnName) then
            return "❌ This " & kindWord & " has no " & basedOnName & " date to repeat from. Set one first. Nothing was changed: " & itemLabel
        end if
    else
        if cleanValue is "true" or cleanValue is "yes" or cleanValue is "1" then
            set catchValue to true
        else if cleanValue is "false" or cleanValue is "no" or cleanValue is "0" then
            set catchValue to false
        else
            return "❌ Invalid value for repeat_catch_up: " & valueText & ". Use true or false."
        end if
        if catchValue and (ruleSchedule of oldInfo) is not "regularly" then
            return "❌ Catching up only works for a fixed schedule. Change the rule to a fixed schedule first (for example \"weekly fixed\"). Nothing was changed: " & itemLabel
        end if
    end if

    set problemText to my applyRepetition(theItem, ruleRecurrence of oldInfo, ruleSchedule of oldInfo, basedOnName, catchValue)
    if problemText is not "" then return problemText
    return "🔁 " & itemLabel & ": " & my repetitionText(theItem)
end changeRepetition

on capitalWord(theWord)
    if theWord is "" then return ""
    set firstChar to character 1 of theWord
    set restText to ""
    if (length of theWord) > 1 then set restText to text 2 thru -1 of theWord
    return my upperText(firstChar) & restText
end capitalWord

on parseDate(dateString)
    -- Reads a date from text. Returns missing value if the text is not a date: nothing is guessed.
    -- Understood: YYYY-MM-DD (midnight), YYYY-MM-DD HH:MM, YYYY-MM-DDTHH:MM, today, tomorrow, next week,
    -- "3 days", "in 3 days", "2 weeks" and, as a last try, the date formats and weekday names of the system language.
    set todayDate to current date
    set trimmed to my trimItem(dateString as text)
    if trimmed is "" then return missing value

    -- ISO dates are built from their numeric parts, independent of the system language
    if my looksLikeISODate(trimmed) then return my parseISODate(trimmed)

    if trimmed is "today" then return todayDate
    if trimmed is "tomorrow" then return todayDate + 1 * days
    if trimmed is "next week" or trimmed is "week" then return todayDate + 7 * days

    -- "3 days", "in 3 days", "1 week", "2 weeks" (no short-circuit in AppleScript: check the number of words first)
    set wordList to words of trimmed
    if (count of wordList) = 3 then
        if (item 1 of wordList) is "in" then set wordList to {item 2 of wordList, item 3 of wordList}
    end if
    if (count of wordList) = 2 then
        if my isDateDigits(item 1 of wordList) and (length of (item 1 of wordList)) ≤ 4 then
            set amountNum to (item 1 of wordList) as integer
            set unitName to item 2 of wordList
            if unitName is "day" or unitName is "days" then return todayDate + amountNum * days
            if unitName is "week" or unitName is "weeks" then return todayDate + amountNum * weeks
        end if
    end if

    -- A dash between digits (2026-12-01, 12-01-2026) in another form than above would be misread by the system parser
    if my hasDigitDash(trimmed) then return missing value

    set systemDate to missing value
    try
        set systemDate to date trimmed
    end try
    if systemDate is missing value then return missing value
    if not my fallbackDateFits(trimmed, systemDate) then return missing value
    return systemDate
end parseDate

on fallbackDateFits(theText, theDate)
    -- The system parser rolls a date that does not exist (31.31.2026) over into a later one. For a date written with
    -- numbers and dots or slashes, the day and the month of the result must be numbers of the text.
    set datePart to theText
    set spacePos to offset of " " in theText
    if spacePos > 1 then set datePart to text 1 thru (spacePos - 1) of theText
    if datePart does not contain "." and datePart does not contain "/" then return true
    repeat with aChar in characters of datePart
        if "abcdefghijklmnopqrstuvwxyzäöüß" contains (contents of aChar) then return true
    end repeat
    set numberList to my numberTokens(datePart)
    if (count of numberList) < 2 then return true
    if numberList does not contain (day of theDate) then return false
    if numberList does not contain ((month of theDate) as integer) then return false
    return true
end fallbackDateFits

on numberTokens(theText)
    -- The whole numbers in a text, in order: "31.12.2026" gives {31, 12, 2026}
    set tokenList to {}
    set currentToken to ""
    repeat with aChar in characters of theText
        if "0123456789" contains (contents of aChar) then
            set currentToken to currentToken & (contents of aChar)
        else if currentToken is not "" then
            set end of tokenList to currentToken as integer
            set currentToken to ""
        end if
    end repeat
    if currentToken is not "" then set end of tokenList to currentToken as integer
    return tokenList
end numberTokens

on looksLikeISODate(theText)
    -- True if the text starts like an ISO date: four digits and a dash
    if (length of theText) < 5 then return false
    if not my isDateDigits(text 1 thru 4 of theText) then return false
    return (character 5 of theText) is "-"
end looksLikeISODate

on parseISODate(dateString)
    -- Reads "YYYY-MM-DD" (midnight), "YYYY-MM-DD HH:MM", "YYYY-MM-DDTHH:MM" or the same with ":SS".
    -- Returns missing value if the text has another form or the date does not exist (2026-02-30, month 13, 25:00).
    set isoText to my trimItem(dateString)
    set isoLength to length of isoText
    if isoLength is not 10 and isoLength is not 16 and isoLength is not 19 then return missing value
    if (character 5 of isoText) is not "-" or (character 8 of isoText) is not "-" then return missing value
    if not my isDateDigits(text 1 thru 4 of isoText) or not my isDateDigits(text 6 thru 7 of isoText) or not my isDateDigits(text 9 thru 10 of isoText) then return missing value

    set hourNum to 0
    set minuteNum to 0
    set secondNum to 0
    if isoLength ≥ 16 then
        if (character 11 of isoText) is not " " and (character 11 of isoText) is not "T" then return missing value
        if (character 14 of isoText) is not ":" then return missing value
        if not my isDateDigits(text 12 thru 13 of isoText) or not my isDateDigits(text 15 thru 16 of isoText) then return missing value
        set hourNum to (text 12 thru 13 of isoText) as integer
        set minuteNum to (text 15 thru 16 of isoText) as integer
    end if
    if isoLength is 19 then
        if (character 17 of isoText) is not ":" then return missing value
        if not my isDateDigits(text 18 thru 19 of isoText) then return missing value
        set secondNum to (text 18 thru 19 of isoText) as integer
    end if
    set yearNum to (text 1 thru 4 of isoText) as integer
    set monthNum to (text 6 thru 7 of isoText) as integer
    set dayNum to (text 9 thru 10 of isoText) as integer
    if yearNum < 1000 or monthNum < 1 or monthNum > 12 or dayNum < 1 or dayNum > 31 then return missing value
    if hourNum > 23 or minuteNum > 59 or secondNum > 59 then return missing value

    try
        set isoDate to current date
        set day of isoDate to 1
        set year of isoDate to yearNum
        set month of isoDate to monthNum
        set day of isoDate to dayNum
        set time of isoDate to hourNum * hours + minuteNum * minutes + secondNum
        -- A day that does not exist in that month (2026-02-30) rolls over into the next one; refuse it
        if (day of isoDate) is not dayNum then return missing value
    on error
        return missing value
    end try
    return isoDate
end parseISODate

on hasDigitDash(theText)
    -- True if a dash stands between two digits
    set textLength to length of theText
    if textLength < 3 then return false
    repeat with i from 2 to textLength - 1
        if (character i of theText) is "-" then
            if "0123456789" contains (character (i - 1) of theText) and "0123456789" contains (character (i + 1) of theText) then return true
        end if
    end repeat
    return false
end hasDigitDash

on isDateDigits(theText)
    -- True if the text is not empty and has only the digits 0 to 9
    if theText is "" then return false
    repeat with aChar in characters of theText
        if "0123456789" does not contain (contents of aChar) then return false
    end repeat
    return true
end isDateDigits

on dateErrorText(valueText, fieldName)
    -- The message for a date that cannot be read; the caller adds what was not done
    return "❌ Invalid date for " & fieldName & ": " & valueText & ". Use YYYY-MM-DD, YYYY-MM-DD HH:MM, today, tomorrow, next week, \"3 days\" or \"2 weeks\"."
end dateErrorText
