on run argv
    -- Set or remove bold, italic and underline in the note of a task, project or folder
    -- Usage: format_note.applescript "task|project|folder" "task, project or folder" "text" "occurrence" "paragraph" "bold" "italic" "underline"
    --   text:       the text to style (case sensitive, every occurrence); "" = the whole note or the whole paragraph
    --   occurrence: "" or 0 = every occurrence of the text, n = only the n-th one
    --   paragraph:  "" or 0 = the whole note, n = only the n-th paragraph (lines are separated by a line feed)
    --   bold, italic, underline: "true" sets the style, "false" removes it, "" leaves it as it is
    -- The text of the note is not changed. A style is set on a range of characters of the note; before anything is
    -- changed, the text at every range is compared with the text that was searched for.

    if (count of argv) < 8 then
        return "❌ Item type, item and at least one style are required."
    end if
    set itemType to item 1 of argv
    set itemText to item 2 of argv
    set searchText to item 3 of argv
    set occurrenceText to my trimItem(item 4 of argv)
    set paragraphText to my trimItem(item 5 of argv)
    set boldText to my trimItem(item 6 of argv)
    set italicText to my trimItem(item 7 of argv)
    set underlineText to my trimItem(item 8 of argv)

    if itemText is "" then
        return "❌ The task, project or folder is required."
    end if
    repeat with styleValue in {boldText, italicText, underlineText}
        if (contents of styleValue) is not in {"", "true", "false"} then
            return "❌ Bold, italic and underline are true (set the style) or false (remove it)."
        end if
    end repeat
    if boldText is "" and italicText is "" and underlineText is "" then
        return "❌ At least one of bold, italic and underline is required (true sets the style, false removes it)."
    end if
    -- Only whole numbers: a text like 1.5 would be rounded by the coercion (or fail, depending on the region)
    set occurrenceNumber to 0
    if occurrenceText is not "" then
        if my isDigits(occurrenceText) and (length of occurrenceText) < 6 then
            set occurrenceNumber to occurrenceText as integer
        else
            return "❌ The occurrence must be a whole number (1 is the first one, 0 or nothing is every occurrence)."
        end if
    end if
    set paragraphNumber to 0
    if paragraphText is not "" then
        if my isDigits(paragraphText) and (length of paragraphText) < 6 then
            set paragraphNumber to paragraphText as integer
        else
            return "❌ The paragraph must be a whole number (1 is the first one)."
        end if
    end if
    if searchText is "" and occurrenceNumber > 0 then
        return "❌ An occurrence needs the text to look for."
    end if

    -- Find the task, project or folder
    set targetItem to missing value
    set itemLabel to ""
    if itemType is "task" then
        set lookup to my resolveTask(itemText)
        if foundTask of lookup is missing value then return errorText of lookup
        set targetItem to foundTask of lookup
        tell application "OmniFocus" to set itemLabel to name of targetItem
    else if itemType is "project" then
        set lookup to my resolveProject(itemText)
        if foundProject of lookup is missing value then return errorText of lookup
        set targetItem to foundProject of lookup
        set itemLabel to my projectLabel(targetItem)
    else if itemType is "folder" then
        set lookup to my resolveFolder(itemText)
        if foundFolder of lookup is missing value then return errorText of lookup
        set targetItem to foundFolder of lookup
        set itemLabel to my folderLabel(targetItem)
    else
        return "❌ Unknown item type: " & itemType & ". Valid types: task, project, folder"
    end if

    -- The note as text (an attachment is one special character)
    set noteText to ""
    tell application "OmniFocus"
        try
            set noteText to (note of targetItem) as text
        on error errMsg
            return "❌ The note could not be read: " & errMsg
        end try
    end tell
    if noteText is "" then
        return "❌ The note of " & itemLabel & " is empty."
    end if

    -- The part of the note that is searched: the whole note or one paragraph
    set scopeStart to 1
    set scopeEnd to length of noteText
    set scopeLabel to "the whole note"
    if paragraphNumber > 0 then
        set oldDelims to AppleScript's text item delimiters
        set AppleScript's text item delimiters to linefeed
        set paragraphList to text items of noteText
        set AppleScript's text item delimiters to oldDelims
        if paragraphNumber > (count of paragraphList) then
            return "❌ The note of " & itemLabel & " has only " & (count of paragraphList) & " paragraph(s)."
        end if
        repeat with k from 1 to paragraphNumber - 1
            set scopeStart to scopeStart + (length of (item k of paragraphList)) + 1
        end repeat
        set paragraphLength to length of (item paragraphNumber of paragraphList)
        if paragraphLength = 0 then
            return "❌ Paragraph " & paragraphNumber & " of the note of " & itemLabel & " is empty."
        end if
        set scopeEnd to scopeStart + paragraphLength - 1
        set scopeLabel to "paragraph " & paragraphNumber
    end if

    -- The ranges to style (positions of characters in the note)
    set rangeStarts to {}
    set rangeEnds to {}
    set styleWholeNote to false
    if searchText is "" then
        if paragraphNumber = 0 then
            set styleWholeNote to true
        else
            set end of rangeStarts to scopeStart
            set end of rangeEnds to scopeEnd
        end if
    else
        set scopeText to text scopeStart thru scopeEnd of noteText
        set searchLength to length of searchText
        set searchPosition to 1
        set occurrenceCount to 0
        repeat while searchPosition ≤ (length of scopeText)
            set remainderText to text searchPosition thru -1 of scopeText
            set foundAt to 0
            considering case
                set foundAt to offset of searchText in remainderText
            end considering
            if foundAt = 0 then exit repeat
            set matchStart to searchPosition + foundAt - 1
            set occurrenceCount to occurrenceCount + 1
            if occurrenceNumber = 0 or occurrenceNumber = occurrenceCount then
                set end of rangeStarts to scopeStart + matchStart - 1
                set end of rangeEnds to scopeStart + matchStart + searchLength - 2
            end if
            if occurrenceNumber > 0 and occurrenceCount ≥ occurrenceNumber then exit repeat
            if (count of rangeStarts) ≥ 500 then exit repeat
            set searchPosition to matchStart + searchLength
        end repeat
        if (count of rangeStarts) = 0 then
            set scopeWhere to "the note of " & itemLabel
            if paragraphNumber > 0 then set scopeWhere to scopeLabel & " of the note of " & itemLabel
            if occurrenceCount > 0 then
                return "ℹ️ The text occurs only " & occurrenceCount & " time(s) in " & scopeWhere & ". Nothing was changed."
            end if
            return "ℹ️ The text was not found in " & scopeWhere & ". Nothing was changed."
        end if
    end if

    -- Compare the text at every range with the text that was found, before anything is changed
    repeat with k from 1 to count of rangeStarts
        set rangeStart to item k of rangeStarts
        set rangeEnd to item k of rangeEnds
        set expectedText to text rangeStart thru rangeEnd of noteText
        set actualText to ""
        tell application "OmniFocus"
            try
                set actualText to ((characters rangeStart thru rangeEnd of (note of targetItem)) as text)
            end try
        end tell
        if actualText is not expectedText then
            return "❌ The position of the text in the note of " & itemLabel & " could not be matched safely (special characters or attachments before it?). Nothing was changed."
        end if
    end repeat

    -- Bold is the weight of the font (12 is what the OmniFocus window sets): the command "bold" does nothing on italic
    -- text, a value set on the style works for every text. A style set on a range that covers several runs of text
    -- replaces the other styles of these runs, so the weight is set on each run (or part of a run) of its own.
    set runLengths to {}
    if boldText is not "" then
        tell application "OmniFocus"
            try
                set runTotal to count of attribute run of (note of targetItem)
                set runTexts to text of every attribute run of (note of targetItem)
                if (class of runTexts is not list) or (count of runTexts) is not runTotal then
                    return "❌ The runs of the note could not be read. Nothing was changed."
                end if
                set runSum to 0
                repeat with r from 1 to runTotal
                    set end of runLengths to (length of ((item r of runTexts) as text))
                    set runSum to runSum + (length of ((item r of runTexts) as text))
                end repeat
                if runSum is not (length of noteText) then
                    return "❌ The runs of the note do not match its text (special characters or attachments?). Nothing was changed."
                end if
            on error errMsg
                return "❌ The runs of the note could not be read: " & errMsg
            end try
        end tell
    end if

    -- Italic and underline use the commands of OmniFocus
    tell application "OmniFocus"
        try
            if styleWholeNote then
                if boldText is "true" then
                    repeat with r from 1 to count of runLengths
                        try
                            set value of attribute "font-weight" of (style of attribute run r of (note of targetItem)) to 12
                        on error
                            bold (attribute run r of (note of targetItem))
                        end try
                    end repeat
                end if
                if boldText is "false" then
                    repeat with r from 1 to count of runLengths
                        try
                            clear (attribute "font-weight" of (style of attribute run r of (note of targetItem)))
                        end try
                    end repeat
                    try
                        unbold (note of targetItem)
                    end try
                end if
                if italicText is "true" then italicize (note of targetItem)
                if italicText is "false" then unitalicize (note of targetItem)
                if underlineText is "true" then underline (note of targetItem)
                if underlineText is "false" then ununderline (note of targetItem)
            else
                repeat with k from 1 to count of rangeStarts
                    set rangeStart to item k of rangeStarts
                    set rangeEnd to item k of rangeEnds
                    if boldText is not "" then
                        -- the parts of the range, each inside one run of text
                        set runStart to 1
                        repeat with r from 1 to count of runLengths
                            set runEnd to runStart + (item r of runLengths) - 1
                            set partStart to runStart
                            if rangeStart > partStart then set partStart to rangeStart
                            set partEnd to runEnd
                            if rangeEnd < partEnd then set partEnd to rangeEnd
                            if partStart ≤ partEnd then
                                if boldText is "true" then
                                    try
                                        set value of attribute "font-weight" of (style of (characters partStart thru partEnd of (note of targetItem))) to 12
                                    on error
                                        bold (characters partStart thru partEnd of (note of targetItem))
                                    end try
                                else
                                    try
                                        clear (attribute "font-weight" of (style of (characters partStart thru partEnd of (note of targetItem))))
                                    end try
                                end if
                            end if
                            set runStart to runEnd + 1
                            if runStart > rangeEnd then exit repeat
                        end repeat
                        if boldText is "false" then
                            try
                                unbold (characters rangeStart thru rangeEnd of (note of targetItem))
                            end try
                        end if
                    end if
                    if italicText is "true" then italicize (characters rangeStart thru rangeEnd of (note of targetItem))
                    if italicText is "false" then unitalicize (characters rangeStart thru rangeEnd of (note of targetItem))
                    if underlineText is "true" then underline (characters rangeStart thru rangeEnd of (note of targetItem))
                    if underlineText is "false" then ununderline (characters rangeStart thru rangeEnd of (note of targetItem))
                end repeat
            end if
        on error errMsg
            return "❌ The style could not be set (some of the changes may be done): " & errMsg
        end try
    end tell

    -- The answer
    set changeList to {}
    if boldText is "true" then set end of changeList to "bold"
    if boldText is "false" then set end of changeList to "no bold"
    if italicText is "true" then set end of changeList to "italic"
    if italicText is "false" then set end of changeList to "no italic"
    if underlineText is "true" then set end of changeList to "underline"
    if underlineText is "false" then set end of changeList to "no underline"
    set placeText to scopeLabel
    if searchText is not "" then
        set shownText to searchText
        if (length of shownText) > 40 then set shownText to (text 1 thru 40 of shownText) & "..."
        set placeText to ((count of rangeStarts) as text) & " place(s) of \"" & shownText & "\" in " & scopeLabel
    end if
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ", "
    set changeText to changeList as text
    set AppleScript's text item delimiters to oldDelims
    return "✅ Note of " & itemLabel & ": " & changeText & " for " & placeText

end run

on resolveTask(queryText)
  -- Finds one open task: "id:<id>", or a name (an exact name wins, otherwise part of a name; case is ignored).
  -- Returns {foundTask, errorText}; foundTask is missing value if nothing or more than one task fits.
  set searchText to my trimItem(queryText)
  if searchText is "" then
    return {foundTask:missing value, errorText:"❌ Parent task cannot be empty."}
  end if

  if searchText starts with "id:" and (length of searchText) > 3 then
    set wantedID to my trimItem(text 4 thru -1 of searchText)
    tell application "OmniFocus"
      tell default document
        set idMatches to every flattened task whose id is wantedID and effectively completed is false and effectively dropped is false
      end tell
    end tell
    if (count of idMatches) = 1 then
      set projectNameText to my projectNameForID(wantedID)
      if projectNameText is not "" then
        return {foundTask:missing value, errorText:"❌ id:" & wantedID & " is a project, not a task: " & projectNameText & "." & " Use the item type project."}
      end if
      return {foundTask:item 1 of idMatches, errorText:""}
    end if
    return {foundTask:missing value, errorText:"❌ Open task not found: " & searchText}
  end if

  tell application "OmniFocus"
    tell default document
      set nameMatches to every flattened task whose name contains searchText and effectively completed is false and effectively dropped is false
    end tell
  end tell
  set nameMatches to my withoutProjectRoots(nameMatches, searchText)

  set exactMatches to {}
  repeat with aMatch in nameMatches
    set matchTask to contents of aMatch
    tell application "OmniFocus" to set matchName to name of matchTask
    ignoring case
      if matchName is searchText then set end of exactMatches to matchTask
    end ignoring
  end repeat

  if (count of exactMatches) = 1 then
    return {foundTask:item 1 of exactMatches, errorText:""}
  end if
  if (count of nameMatches) = 1 then
    return {foundTask:item 1 of nameMatches, errorText:""}
  end if
  if (count of nameMatches) = 0 then
    return {foundTask:missing value, errorText:"❌ Open task not found: " & searchText}
  end if

  set matchList to "🔍 Several open tasks match \"" & searchText & "\" (" & (count of nameMatches) & "). Use id:<id> to pick one:"
  set shownCount to 0
  repeat with aMatch in nameMatches
    if shownCount ≥ 15 then
      set matchList to matchList & return & "… more not shown"
      exit repeat
    end if
    set matchTask to contents of aMatch
    tell application "OmniFocus"
      set matchLabel to name of matchTask
      try
        set matchProject to containing project of matchTask
        if matchProject is not missing value then set matchLabel to matchLabel & " [" & (name of matchProject) & "]"
      end try
      set matchLabel to matchLabel & " [id:" & (id of matchTask) & "]"
    end tell
    set matchList to matchList & return & "• " & matchLabel
    set shownCount to shownCount + 1
  end repeat
  return {foundTask:missing value, errorText:matchList}
end resolveTask
on projectNameForID(wantedID)
  -- The name of the project with this ID, or "" if the ID belongs to no project (the root task of a project has the ID
  -- of its project and is no task)
  tell application "OmniFocus"
    tell default document
      try
        set projectIDs to id of every flattened project
        set isProjectID to false
        considering case
          if projectIDs contains wantedID then set isProjectID to true
        end considering
        if isProjectID then
          set projectMatches to every flattened project whose id is wantedID
          if (count of projectMatches) > 0 then return name of item 1 of projectMatches
          return wantedID
        end if
      end try
    end tell
  end tell
  return ""
end projectNameForID

on withoutProjectRoots(taskList, searchText)
  -- Leaves the root tasks of projects out of the name hits of resolveTask (same condition and order for the IDs)
  if (count of taskList) = 0 then return taskList
  tell application "OmniFocus"
    tell default document
      set projectIDs to {}
      try
        set projectIDs to id of every flattened project
      end try
      if (count of projectIDs) = 0 then return taskList
      set hitIDs to id of every flattened task whose name contains searchText and effectively completed is false and effectively dropped is false
    end tell
  end tell
  set keptTasks to {}
  repeat with i from 1 to count of taskList
    set isProjectID to false
    considering case
      if projectIDs contains (item i of hitIDs) then set isProjectID to true
    end considering
    if not isProjectID then set end of keptTasks to item i of taskList
  end repeat
  return keptTasks
end withoutProjectRoots

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
    
    -- Finds a project in any folder by name, or by "Folder > Subfolder > Project".
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
    
    -- The names of all projects come with one query (an Apple Event per project costs about 17 ms)
    tell application "OmniFocus"
        tell default document
            set allProjects to every flattened project
            set allProjectNames to name of every flattened project
        end tell
    end tell
    
    set exactMatches to {}
    set partialMatches to {}
    repeat with projectIndex from 1 to count of allProjects
        set candidateProject to item projectIndex of allProjects
        set candidateName to item projectIndex of allProjectNames
        ignoring case
            if candidateName is projectQuery then
                set end of exactMatches to candidateProject
            else if candidateName contains projectQuery then
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

on resolveFolder(queryText)
    -- Finds a folder at any depth by name, or by "Folder > Subfolder".
    -- Names match exactly or as a substring, ignoring case.
    -- "id:<id>" finds a folder by the ID shown by list_folders.
    -- Returns {foundFolder, errorText}; foundFolder is missing value if nothing or more than one folder fits.
    if queryText starts with "id:" then
        set wantedID to ""
        if (length of queryText) > 3 then set wantedID to my trimText(text 4 thru -1 of queryText)
        set idMatches to {}
        if wantedID is not "" then
            tell application "OmniFocus"
                tell default document
                    set idMatches to every flattened folder whose id is wantedID
                end tell
            end tell
        end if
        if (count of idMatches) = 1 then return {foundFolder:item 1 of idMatches, errorText:""}
        return {foundFolder:missing value, errorText:"❌ Folder not found: " & queryText}
    end if
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ">"
    set rawParts to text items of queryText
    set AppleScript's text item delimiters to oldDelims

    set queryParts to {}
    repeat with rawPart in rawParts
        set cleanPart to my trimText(rawPart as string)
        if cleanPart is not "" then set end of queryParts to cleanPart
    end repeat
    if (count of queryParts) = 0 then
        return {foundFolder:missing value, errorText:"❌ Folder name cannot be empty."}
    end if

    set folderQuery to item -1 of queryParts
    set parentQuery to {}
    if (count of queryParts) > 1 then set parentQuery to items 1 thru -2 of queryParts

    -- The names and parents of all folders come with one query each (an Apple Event per folder costs about 17 ms)
    tell application "OmniFocus"
        tell default document
            set allFolders to every flattened folder
            set allFolderIDs to id of every flattened folder
            set allFolderNames to name of every flattened folder
            set allFolderParentIDs to id of container of every flattened folder
        end tell
    end tell

    set exactMatches to {}
    set partialMatches to {}
    repeat with folderIndex from 1 to count of allFolders
        set candidateFolder to item folderIndex of allFolders
        set folderNames to my folderNamesFromLists(folderIndex, allFolderIDs, allFolderNames, allFolderParentIDs)
        set candidateName to item -1 of folderNames
        set parentNames to {}
        if (count of folderNames) > 1 then set parentNames to items 1 thru -2 of folderNames

        -- The parent folders given in the query must match the innermost parents
        set queryCount to count of parentQuery
        set nameCount to count of parentNames
        set parentFits to (queryCount ≤ nameCount)
        ignoring case
            if parentFits then
                repeat with i from 1 to queryCount
                    set wantedName to item i of parentQuery
                    set actualName to item (nameCount - queryCount + i) of parentNames
                    if actualName does not contain wantedName then set parentFits to false
                end repeat
            end if
            if parentFits then
                if candidateName is folderQuery then
                    set end of exactMatches to candidateFolder
                else if candidateName contains folderQuery then
                    set end of partialMatches to candidateFolder
                end if
            end if
        end ignoring
    end repeat

    -- A single exact name wins; otherwise every match counts and must be unique
    if (count of exactMatches) = 1 then
        return {foundFolder:item 1 of exactMatches, errorText:""}
    end if
    set allMatches to exactMatches & partialMatches
    if (count of allMatches) = 1 then
        return {foundFolder:item 1 of allMatches, errorText:""}
    end if
    if (count of allMatches) = 0 then
        return {foundFolder:missing value, errorText:"❌ Folder not found: " & queryText}
    end if

    set matchList to "❌ Ambiguous folder \"" & queryText & "\" (" & (count of allMatches) & " matches). Nothing was changed. Use \"Folder > Subfolder\" to pick one:"
    repeat with aMatch in allMatches
        set matchList to matchList & return & "• " & my folderLabel(contents of aMatch)
    end repeat
    return {foundFolder:missing value, errorText:matchList}
end resolveFolder

on folderNamePath(aFolder)
    -- Folder names from the outermost folder down to aFolder itself
    set folderNames to {}
    tell application "OmniFocus"
        set beginning of folderNames to name of aFolder
        try
            set parentContainer to container of aFolder
            repeat while class of parentContainer is folder
                set beginning of folderNames to name of parentContainer
                set parentContainer to container of parentContainer
            end repeat
        end try
    end tell
    return folderNames
end folderNamePath

on folderLabel(aFolder)
    -- "Folder > Subfolder", the same form resolveFolder accepts
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to " > "
    set labelText to (my folderNamePath(aFolder)) as string
    set AppleScript's text item delimiters to oldDelims
    return labelText
end folderLabel

on trimText(theText)
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
end trimText

on isDigits(theText)
    -- True if the text is not empty and has only the digits 0 to 9
    if theText is "" then return false
    repeat with aChar in characters of theText
        if "0123456789" does not contain (contents of aChar) then return false
    end repeat
    return true
end isDigits

on folderNamesFromLists(folderIndex, idList, nameList, parentIDList)
    -- Folder names from the outermost folder down to the folder at this position, from the lists of all folders
    set pathNames to {item folderIndex of nameList}
    set parentID to item folderIndex of parentIDList
    repeat
        set parentIndex to 0
        repeat with k from 1 to count of idList
            if (item k of idList) is parentID then
                set parentIndex to k
                exit repeat
            end if
        end repeat
        if parentIndex = 0 then exit repeat
        set beginning of pathNames to item parentIndex of nameList
        set parentID to item parentIndex of parentIDList
    end repeat
    return pathNames
end folderNamesFromLists
