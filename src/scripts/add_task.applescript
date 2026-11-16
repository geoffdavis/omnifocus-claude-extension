on run argv
  set taskName to item 1 of argv
  set taskNote to ""
  set projectName to ""
  set dueDate to missing value
  set isFlagged to false
  set deferDate to missing value
  set estimatedMinutes to 0
  set tagsString to ""

  if (count of argv) > 1 then set taskNote to item 2 of argv
  if (count of argv) > 2 then set projectName to item 3 of argv
  set skippedDates to ""
  if (count of argv) > 3 then
    set dueDateString to item 4 of argv
    if dueDateString is not "" then
      set dueDate to my parseDate(dueDateString)
      if dueDate is missing value then
        set skippedDates to skippedDates & " due_date"
      end if
    end if
  end if
  if (count of argv) > 4 then
    if item 5 of argv is "true" then set isFlagged to true
  end if
  if (count of argv) > 5 then
    set deferDateString to item 6 of argv
    if deferDateString is not "" then
      set deferDate to my parseDate(deferDateString)
      if deferDate is missing value then
        set skippedDates to skippedDates & " defer_date"
      end if
    end if
  end if
  if (count of argv) > 6 then
    set minutesString to item 7 of argv
    if minutesString is not "" and minutesString is not "0" then
      set minutesTrimmed to my trimText(minutesString)
      try
        set estimatedMinutes to minutesTrimmed as integer
      on error
        return "❌ Invalid estimated_minutes value: " & minutesString & " (must be a whole number)"
      end try
      if estimatedMinutes < 0 then
        return "❌ Invalid estimated_minutes value: " & minutesString & " (must be 0 or greater)"
      end if
    end if
  end if
  if (count of argv) > 7 then
    set tagsString to item 8 of argv
  end if

  tell application "OmniFocus"
    tell default document
      if projectName is not "" and projectName is not "inbox" then
        -- Searches open projects in all folders; accepts "Folder > Subfolder > Project" and "id:<id>"
        set projectLookup to my resolveProject(projectName)
        if foundProject of projectLookup is missing value then
          return errorText of projectLookup & return & "Nothing was created."
        end if
        set targetProject to foundProject of projectLookup
        set newTask to make new task with properties {name:taskName, note:taskNote, flagged:isFlagged} at end of tasks of targetProject
      else
        set newTask to make new inbox task with properties {name:taskName, note:taskNote, flagged:isFlagged}
      end if

      if dueDate is not missing value then
        set due date of newTask to dueDate
      end if
      if deferDate is not missing value then
        set defer date of newTask to deferDate
      end if
      if estimatedMinutes > 0 then
        set estimated minutes of newTask to estimatedMinutes
      end if

      -- Apply tags (comma-separated)
      if tagsString is not "" then
        set oldDelims to AppleScript's text item delimiters
        set AppleScript's text item delimiters to ","
        set tagList to text items of tagsString
        set AppleScript's text item delimiters to oldDelims
        repeat with tagItem in tagList
          set tagName to my trimText(tagItem as string)
          if tagName is not "" then
            set matchingTags to every tag whose name is tagName
            if (count of matchingTags) = 0 then
              set theTag to make new tag with properties {name:tagName}
            else
              set theTag to item 1 of matchingTags
            end if
            add theTag to tags of newTask
          end if
        end repeat
      end if

      if skippedDates is not "" then
        return "✅ Added: " & taskName & " (⚠️ could not parse:" & skippedDates & ")"
      end if
      return "✅ Added: " & taskName
    end tell
  end tell
end run

-- Try to parse dateString into a date. Returns missing value if the string
-- cannot be recognized, so the caller can decide whether to skip or warn.
on parseDate(dateString)
  set todayDate to current date
  set trimmed to my trimText(dateString)
  if trimmed is "today" then
    return todayDate
  else if trimmed is "tomorrow" then
    return todayDate + 1 * days
  else if trimmed is "next week" then
    return todayDate + 7 * days
  else if trimmed is "week" then
    return todayDate + 7 * days
  else if trimmed ends with "week" or trimmed ends with "weeks" then
    try
      set weekCount to word 1 of trimmed as integer
      return todayDate + weekCount * 7 * days
    on error
      return missing value
    end try
  else if trimmed ends with " day" or trimmed ends with " days" then
    try
      set dayCount to word 1 of trimmed as integer
      return todayDate + dayCount * days
    on error
      return missing value
    end try
  else if length of trimmed is 10 and character 5 of trimmed is "-" and character 8 of trimmed is "-" then
    try
      set yearNum to (text 1 thru 4 of trimmed) as integer
      set monthNum to (text 6 thru 7 of trimmed) as integer
      set dayNum to (text 9 thru 10 of trimmed) as integer
      set isoDate to current date
      set day of isoDate to 1
      set month of isoDate to monthNum
      set day of isoDate to dayNum
      set year of isoDate to yearNum
      set time of isoDate to 0
      return isoDate
    on error
      return missing value
    end try
  else
    try
      return date trimmed
    on error
      return missing value
    end try
  end if
end parseDate

on trimText(theText)
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
end trimText

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
