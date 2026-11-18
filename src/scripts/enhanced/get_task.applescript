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
            -- The hidden root task of a project is part of the flattened tasks and has the ID of its project. It is no task:
            -- the project IDs are left out of the search, and an ID that belongs to a project points to get_project
            set projectIDs to {}
            try
                set projectIDs to id of every flattened project
            end try

            -- "id:<id>" addresses exactly one task; otherwise search open tasks by name
            set skippedProjects to 0
            if searchTerm starts with "id:" and (length of searchTerm) > 3 then
                set wantedID to text 4 thru -1 of searchTerm
                set isProjectID to false
                considering case
                    if projectIDs contains wantedID then set isProjectID to true
                end considering
                if isProjectID then
                    set projectMatches to every flattened project whose id is wantedID
                    set projectLabelText to wantedID
                    if (count of projectMatches) > 0 then set projectLabelText to my projectLabel(item 1 of projectMatches)
                    return "ℹ️ id:" & wantedID & " is a project, not a task: " & projectLabelText & return & "Use get_project with project \"id:" & wantedID & "\"."
                end if
                set foundTasks to every flattened task whose id is wantedID
            else
                set foundTasks to every flattened task whose name contains searchTerm and completed is false
                if (count of foundTasks) > 0 and (count of projectIDs) > 0 then
                    -- Same condition, same order: the IDs tell which hits are root tasks of projects
                    set foundIDs to id of every flattened task whose name contains searchTerm and completed is false
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
                set notFoundText to "❌ No matching tasks found for: " & searchTerm
                if skippedProjects > 0 then set notFoundText to notFoundText & return & "ℹ️ " & skippedProjects & " project(s) match this name. Use get_project to see a project."
                return notFoundText
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
            set taskInfo to taskInfo & "Link: omnifocus:///task/" & (id of targetTask) & return
            
            -- State
            set stateText to "open"
            if effectively dropped of targetTask then set stateText to "dropped"
            if effectively completed of targetTask then set stateText to "completed"
            if flagged of targetTask then set stateText to stateText & ", flagged"
            -- A task that starts in the future is "deferred" (same word as get_project); "blocked" is kept for
            -- tasks that wait for an earlier task or for their subtasks
            set isDeferred to false
            try
                set stateDeferValue to effective defer date of targetTask
                if stateDeferValue is missing value then set stateDeferValue to defer date of targetTask
                if stateDeferValue is not missing value and stateDeferValue > (current date) then set isDeferred to true
            end try
            if stateText starts with "open" then
                if isDeferred then
                    set stateText to stateText & ", deferred"
                else
                    try
                        if blocked of targetTask then set stateText to stateText & ", blocked"
                    end try
                end if
            end if
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
                -- With several tags the first one is the primary tag
                if (count of tagNames) > 1 then
                    try
                        set primaryTag to primary tag of targetTask
                        if primaryTag is not missing value then set taskInfo to taskInfo & "Primary tag: " & (name of primaryTag) & return
                    end try
                end if
            end if

            -- An inbox task can have a provisional project or parent task (Clean Up moves it there)
            try
                if in inbox of targetTask then
                    set assignedItem to assigned container of targetTask
                    if assignedItem is not missing value then
                        if class of assignedItem is project then
                            set taskInfo to taskInfo & "Assigned to: " & my projectLabel(assignedItem) & " (stays in the inbox until Clean Up)" & return
                        else
                            set taskInfo to taskInfo & "Assigned to the task: " & (name of assignedItem) & " (stays in the inbox until Clean Up)" & return
                        end if
                    end if
                end if
            end try
            
            -- Dates and estimate
            set deferValue to defer date of targetTask
            if deferValue is not missing value then set taskInfo to taskInfo & "Deferred until: " & (deferValue as string) & return
            try
                set plannedValue to planned date of targetTask
                if plannedValue is not missing value then set taskInfo to taskInfo & "Planned: " & (plannedValue as string) & return
            end try
            set dueValue to due date of targetTask
            if dueValue is not missing value then set taskInfo to taskInfo & "Due: " & (dueValue as string) & return
            -- The time zone setting only matters for a task with a due or defer date
            if dueValue is not missing value or deferValue is not missing value then
                try
                    if should use floating time zone of targetTask then
                        set taskInfo to taskInfo & "Time zone: floating (the same clock time in every time zone)" & return
                    else
                        set taskInfo to taskInfo & "Time zone: fixed" & return
                    end if
                end try
            end if
            -- Dates of the task as OmniFocus works them out, counting the containing tasks and the project too. Only shown when
            -- they differ from the dates of the task itself.
            try
                set effectiveDeferValue to effective defer date of targetTask
                if effectiveDeferValue is not missing value then
                    if deferValue is missing value or effectiveDeferValue is not deferValue then set taskInfo to taskInfo & "Effective deferred until: " & (effectiveDeferValue as string) & " (inherited)" & return
                end if
            end try
            try
                set ownPlannedValue to planned date of targetTask
                set effectivePlannedValue to effective planned date of targetTask
                if effectivePlannedValue is not missing value then
                    if ownPlannedValue is missing value or effectivePlannedValue is not ownPlannedValue then set taskInfo to taskInfo & "Effective planned: " & (effectivePlannedValue as string) & " (inherited)" & return
                end if
            end try
            try
                set effectiveDueValue to effective due date of targetTask
                if effectiveDueValue is not missing value then
                    if dueValue is missing value or effectiveDueValue is not dueValue then set taskInfo to taskInfo & "Effective due: " & (effectiveDueValue as string) & " (inherited)" & return
                end if
            end try
            set estimateValue to estimated minutes of targetTask
            if estimateValue is not missing value then set taskInfo to taskInfo & "Estimate: " & estimateValue & " minutes" & return
            set repeatText to my repetitionText(targetTask)
            if repeatText is not "" then
                set taskInfo to taskInfo & "Repeats: " & repeatText & return
                -- OmniFocus knows the dates of the next occurrence for a task that repeats on a fixed schedule
                set nextParts to {}
                try
                    set nextDeferValue to next defer date of targetTask
                    if nextDeferValue is not missing value then set end of nextParts to "defer " & (nextDeferValue as string)
                end try
                try
                    set nextPlannedValue to next planned date of targetTask
                    if nextPlannedValue is not missing value then set end of nextParts to "planned " & (nextPlannedValue as string)
                end try
                try
                    set nextDueValue to next due date of targetTask
                    if nextDueValue is not missing value then set end of nextParts to "due " & (nextDueValue as string)
                end try
                if (count of nextParts) > 0 then set taskInfo to taskInfo & "Next occurrence: " & my joinText(nextParts, ", ") & return
            end if
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
                -- How many of the subtasks can be worked on now (not blocked, not deferred, not completed)
                try
                    set availableCount to number of available tasks of targetTask
                    set taskInfo to taskInfo & "Available subtasks: " & availableCount & return
                end try
            end if
            
            -- Note, shortened if very long
            set attachmentText to my attachmentLines(targetTask)
            if attachmentText is not "" then set taskInfo to taskInfo & attachmentText & return
            set noteInfo to my styledNote(targetTask)
            set taskNote to my markAttachments(noteText of noteInfo)
            if taskNote is not "" then
                if (length of taskNote) > 2000 then set taskNote to (text 1 thru 2000 of taskNote) & "..."
                if styled of noteInfo then set taskInfo to taskInfo & "Note styles: **bold**, *italic*, __underlined__" & return
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

on attachmentLines(theItem)
    -- Returns "" when the note has no attachment, otherwise the lines that describe the attachments.
    -- OmniFocus gives scripts the path of a linked file, but not the name of an embedded file.
    set attachmentCount to 0
    set embeddedFlags to {}
    set filePaths to {}
    tell application "OmniFocus"
        try
            set attachmentCount to count of file attachment of (note of theItem)
        end try
        repeat with i from 1 to attachmentCount
            set isEmbedded to true
            set thePath to ""
            try
                set isEmbedded to embedded of (file attachment i of (note of theItem))
            end try
            if not isEmbedded then
                try
                    -- two steps: the path of the file is made by AppleScript, not by OmniFocus
                    set fileReference to file name of (file attachment i of (note of theItem))
                    set thePath to POSIX path of fileReference
                end try
            end if
            set end of embeddedFlags to isEmbedded
            set end of filePaths to thePath
        end repeat
    end tell
    if attachmentCount = 0 then return ""
    set reportText to "Attachments: " & attachmentCount
    repeat with i from 1 to attachmentCount
        if item i of embeddedFlags then
            set reportText to reportText & return & "  " & i & ". embedded file"
        else if (item i of filePaths) is not "" then
            set reportText to reportText & return & "  " & i & ". linked file: " & (item i of filePaths)
        else
            set reportText to reportText & return & "  " & i & ". linked file (path unknown)"
        end if
    end repeat
    return reportText
end attachmentLines

on styledNote(theItem)
    -- The note as text with the styles of its runs marked as **bold**, *italic* and __underlined__ (a link is left
    -- as it is). Returns {noteText:..., styled:true or false}; a note without styles comes back unchanged.
    set plainText to ""
    tell application "OmniFocus"
        try
            set plainText to (note of theItem) as text
        end try
    end tell
    if plainText is "" then return {noteText:"", styled:false}
    set runTexts to {}
    set runFonts to {}
    set runUnderlines to {}
    set runCount to 0
    tell application "OmniFocus"
        try
            set runCount to count of attribute run of (note of theItem)
            -- a very long chain of runs is shown as plain text
            if runCount < 1 or runCount > 150 then return {noteText:plainText, styled:false}
            try
                set runTexts to text of every attribute run of (note of theItem)
                set runFonts to font of every attribute run of (note of theItem)
                set runUnderlines to underlined of every attribute run of (note of theItem)
            end try
            if (class of runTexts is not list) or (class of runFonts is not list) or (class of runUnderlines is not list) or (count of runTexts) is not runCount or (count of runFonts) is not runCount or (count of runUnderlines) is not runCount then
                set runTexts to {}
                set runFonts to {}
                set runUnderlines to {}
                repeat with i from 1 to runCount
                    set end of runTexts to (text of attribute run i of (note of theItem))
                    set end of runFonts to (font of attribute run i of (note of theItem))
                    set end of runUnderlines to (underlined of attribute run i of (note of theItem))
                end repeat
            end if
        on error
            return {noteText:plainText, styled:false}
        end try
    end tell

    -- The runs must make up the same text as the note
    set joinedText to ""
    repeat with i from 1 to runCount
        set joinedText to joinedText & (item i of runTexts)
    end repeat
    if joinedText is not plainText then return {noteText:plainText, styled:false}

    set composedText to ""
    set anyStyled to false
    repeat with i from 1 to runCount
        set runText to item i of runTexts
        set fontName to ""
        try
            set fontName to (item i of runFonts) as text
        end try
        set isBold to (fontName contains "bold") or (fontName contains "black") or (fontName contains "heavy")
        set isItalic to (fontName contains "italic") or (fontName contains "oblique")
        set isUnderlined to false
        try
            set isUnderlined to ((item i of runUnderlines) is true)
        end try
        if runText contains "://" then
            set isBold to false
            set isItalic to false
            set isUnderlined to false
        end if
        if isBold or isItalic or isUnderlined then
            set runParts to my splitRunSpace(runText)
            if (coreText of runParts) is "" then
                set composedText to composedText & runText
            else
                set openMarks to ""
                set closeMarks to ""
                if isBold then
                    set openMarks to openMarks & "**"
                    set closeMarks to "**" & closeMarks
                end if
                if isItalic then
                    set openMarks to openMarks & "*"
                    set closeMarks to "*" & closeMarks
                end if
                if isUnderlined then
                    set openMarks to openMarks & "__"
                    set closeMarks to "__" & closeMarks
                end if
                set composedText to composedText & (leadText of runParts) & openMarks & (coreText of runParts) & closeMarks & (trailText of runParts)
                set anyStyled to true
            end if
        else
            set composedText to composedText & runText
        end if
    end repeat
    if not anyStyled then return {noteText:plainText, styled:false}
    return {noteText:composedText, styled:true}
end styledNote

on splitRunSpace(runText)
    -- Splits a text into the white space in front, the text itself and the white space behind it
    set spaceChars to {" ", tab, linefeed, return}
    set textLength to length of runText
    set startPos to 1
    repeat while startPos ≤ textLength
        if (character startPos of runText) is not in spaceChars then exit repeat
        set startPos to startPos + 1
    end repeat
    if startPos > textLength then return {leadText:runText, coreText:"", trailText:""}
    set endPos to textLength
    repeat while endPos > startPos
        if (character endPos of runText) is not in spaceChars then exit repeat
        set endPos to endPos - 1
    end repeat
    set leadPart to ""
    if startPos > 1 then set leadPart to text 1 thru (startPos - 1) of runText
    set trailPart to ""
    if endPos < textLength then set trailPart to text (endPos + 1) thru textLength of runText
    return {leadText:leadPart, coreText:text startPos thru endPos of runText, trailText:trailPart}
end splitRunSpace

on markAttachments(noteText)
    -- The note text holds one special character for each attachment; show it as a paperclip
    set marker to character id 65532
    if noteText does not contain marker then return noteText
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to marker
    set pieces to text items of noteText
    set AppleScript's text item delimiters to "📎"
    set markedText to pieces as text
    set AppleScript's text item delimiters to oldDelims
    return markedText
end markAttachments

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
