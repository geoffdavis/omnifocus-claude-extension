on run argv
    -- Delete completed and/or dropped tasks permanently. Nothing is deleted unless dry_run is false AND confirm_delete is true.
    -- Usage: purge_tasks.applescript scope older_than_days folder project dry_run confirm_delete limit
    --   scope:           "completed", "dropped" or "both" (default)
    --   older_than_days: only tasks whose completion or drop date is more than this many days ago (default 0 = all)
    --   folder:          only tasks in projects below this folder (name, "Folder > Subfolder" or "id:<id>")
    --   project:         only tasks of this project (name, "Folder > Project" or "id:<id>")
    --   dry_run:         "true" (default) only lists what would be deleted; "false" deletes (with confirm_delete "true")
    --   confirm_delete:  must be "true" to delete
    --   limit:           maximum number of tasks per call (default 200); the rest is reported
    -- A task is only deleted if all its subtasks are deleted with it: a task with open subtasks, or with subtasks that are
    -- not part of this purge (too young, other state), is skipped. Open tasks (also recurring ones) are never touched.
    -- Deleting needs a time of its own: the loop stops after about 50 seconds and reports what is left.

    set startedAt to current date
    set timeBudgetSeconds to 50
    set scopeText to "both"
    set olderText to ""
    set folderText to ""
    set projectText to ""
    set dryRun to true
    set confirmDelete to false
    set limitText to ""
    if (count of argv) > 0 and my trimItem(item 1 of argv) is not "" then set scopeText to my trimItem(item 1 of argv)
    if (count of argv) > 1 then set olderText to my trimItem(item 2 of argv)
    if (count of argv) > 2 then set folderText to my trimItem(item 3 of argv)
    if (count of argv) > 3 then set projectText to my trimItem(item 4 of argv)
    if (count of argv) > 4 and my trimItem(item 5 of argv) is not "" then set dryRun to ((my trimItem(item 5 of argv)) is not "false")
    if (count of argv) > 5 then set confirmDelete to ((my trimItem(item 6 of argv)) is "true")
    if (count of argv) > 6 then set limitText to my trimItem(item 7 of argv)

    -- Check every value before anything is read
    if scopeText is not "completed" and scopeText is not "dropped" and scopeText is not "both" then
        return "❌ Invalid scope: " & scopeText & ". Use completed, dropped or both. Nothing was deleted."
    end if
    set olderDays to 0
    if olderText is not "" then
        if not my isDigits(olderText) or (length of olderText) > 5 then
            return "❌ Invalid older_than_days: " & olderText & ". Use a whole number of days, 0 or more. Nothing was deleted."
        end if
        set olderDays to olderText as integer
    end if
    set maxCount to 200
    if limitText is not "" then
        if not my isDigits(limitText) or (length of limitText) > 5 or (limitText as integer) < 1 then
            return "❌ Invalid limit: " & limitText & ". Use a whole number, 1 or more. Nothing was deleted."
        end if
        set maxCount to limitText as integer
    end if
    set includeCompleted to (scopeText is "completed" or scopeText is "both")
    set includeDropped to (scopeText is "dropped" or scopeText is "both")

    -- Where to look: the whole database (with the inbox), the projects below a folder, or one project
    set scopeProjectIDList to missing value
    set folderProjectIDList to missing value
    set scopeLabel to ""
    if folderText is not "" then
        set folderLookup to my resolveFolder(folderText)
        if foundFolder of folderLookup is missing value then return errorText of folderLookup
        set targetFolder to foundFolder of folderLookup
        try
            tell application "OmniFocus" to set folderProjectIDList to id of every flattened project of targetFolder
        on error errMsg
            return "❌ OmniFocus could not read the folder: " & errMsg
        end try
        set scopeProjectIDList to folderProjectIDList
        set scopeLabel to "folder " & my folderLabel(targetFolder)
    end if
    if projectText is not "" then
        set projectLookup to my resolveProject(projectText)
        if foundProject of projectLookup is missing value then return errorText of projectLookup
        set targetProject to foundProject of projectLookup
        tell application "OmniFocus" to set targetProjectID to id of targetProject
        if folderProjectIDList is not missing value then
            if folderProjectIDList does not contain targetProjectID then
                return "❌ The project " & (my projectLabel(targetProject)) & " is not in the folder " & (my folderLabel(targetFolder)) & ". Nothing was deleted."
            end if
        end if
        set scopeProjectIDList to {targetProjectID}
        set scopeLabel to "project " & my projectLabel(targetProject)
    end if
    set scopeIDText to ""
    if scopeProjectIDList is not missing value then set scopeIDText to my idTextOf(scopeProjectIDList)

    -- Read everything with a few bulk queries (one per property, not one per task), then decide here
    set taskIDList to {}
    set nameList to {}
    set doneList to {}
    set droppedList to {}
    set effDroppedList to {}
    set doneDateList to {}
    set dropDateList to {}
    set taskProjectIDList to {}
    set parentIDList to {}
    set allProjectIDList to {}
    try
        tell application "OmniFocus"
            tell default document
                set taskIDList to id of every flattened task
                set nameList to name of every flattened task
                set doneList to completed of every flattened task
                set droppedList to dropped of every flattened task
                set effDroppedList to effectively dropped of every flattened task
                set doneDateList to completion date of every flattened task
                set dropDateList to dropped date of every flattened task
                set taskProjectIDList to id of containing project of every flattened task
                set parentIDList to id of parent task of every flattened task
                set allProjectIDList to id of every flattened project
                set allProjectNameList to name of every flattened project
                set allProjectFolderIDList to id of folder of every flattened project
                set folderIDList to id of every flattened folder
                set folderNameList to name of every flattened folder
                set folderParentIDList to id of container of every flattened folder
            end tell
        end tell
    on error errMsg
        return "❌ OmniFocus could not read the tasks: " & errMsg
    end try
    set taskCount to count of taskIDList
    if (count of nameList) is not taskCount or (count of doneList) is not taskCount or (count of droppedList) is not taskCount or (count of effDroppedList) is not taskCount then
        return "❌ OmniFocus changed while the tasks were read. Nothing was deleted. Try again."
    end if
    if (count of doneDateList) is not taskCount or (count of dropDateList) is not taskCount or (count of taskProjectIDList) is not taskCount or (count of parentIDList) is not taskCount then
        return "❌ OmniFocus changed while the tasks were read. Nothing was deleted. Try again."
    end if
    set allTaskIDText to my idTextOf(taskIDList)
    set projectIDText to my idTextOf(allProjectIDList)
    set hiddenProjectIDList to my hiddenFolderProjectIDs()

    -- State of every task. The root task of a project is part of the flattened tasks and has the ID of its project.
    set nowDate to current date
    set cutoffDate to nowDate - olderDays * days
    set inScopeList to {}
    set rootList to {}
    set eligibleList to {}
    set acceptableList to {}
    set openList to {}
    set kindList to {}
    set whenList to {}
    set undatedCount to 0
    repeat with i from 1 to taskCount
        set isRoot to my idInText(projectIDText, item i of taskIDList)
        set inScope to true
        if scopeProjectIDList is not missing value then
            set inScope to false
            set containerID to item i of taskProjectIDList
            if containerID is not missing value then set inScope to my idInText(scopeIDText, containerID)
        end if
        set isDone to item i of doneList
        set isOwnDropped to item i of droppedList
        set isEffDropped to item i of effDroppedList
        set isOpen to (not isDone and not isEffDropped)
        set kindText to "open"
        set whenDate to missing value
        if isDone then
            set kindText to "completed"
            set whenDate to item i of doneDateList
        else if isOwnDropped then
            set kindText to "dropped"
            set whenDate to item i of dropDateList
        else if isEffDropped then
            set kindText to "dropped with its parent"
        end if

        -- Eligible: completed or dropped itself, as asked, old enough
        set isEligible to false
        if inScope and not isRoot then
            if (kindText is "completed" and includeCompleted) or (kindText is "dropped" and includeDropped) then
                set isEligible to true
                if olderDays > 0 then
                    if whenDate is missing value then
                        set isEligible to false
                        set undatedCount to undatedCount + 1
                    else if not (whenDate < cutoffDate) then
                        set isEligible to false
                    end if
                end if
            end if
        end if
        -- Acceptable as part of the subtree of a deleted task: eligible, or dropped only because of a dropped parent
        set isAcceptable to isEligible
        if not isAcceptable and kindText is "dropped with its parent" and includeDropped then set isAcceptable to true

        set end of inScopeList to inScope
        set end of rootList to isRoot
        set end of eligibleList to isEligible
        set end of acceptableList to isAcceptable
        set end of openList to isOpen
        set end of kindList to kindText
        set end of whenList to whenDate
    end repeat

    -- The position of the parent task of every task (0 = none). Deleting a task deletes its subtasks as well.
    set parentPosList to {}
    repeat with i from 1 to taskCount
        set parentID to item i of parentIDList
        if parentID is missing value then
            set end of parentPosList to 0
        else
            set end of parentPosList to my indexOfID(allTaskIDText, parentID)
        end if
    end repeat

    -- Mark the tasks above a task that is not part of the purge: open tasks and tasks that are not eligible block their parents
    set openBelow to {}
    set otherBelow to {}
    repeat with i from 1 to taskCount
        set end of openBelow to false
        set end of otherBelow to false
    end repeat
    repeat with i from 1 to taskCount
        if (item i of inScopeList) and not (item i of rootList) and not (item i of acceptableList) then
            set isOpenTask to (item i of openList)
            set k to item i of parentPosList
            repeat while k > 0
                if isOpenTask then
                    if item k of openBelow then exit repeat
                    set item k of openBelow to true
                else
                    if item k of otherBelow then exit repeat
                    set item k of otherBelow to true
                end if
                set k to item k of parentPosList
            end repeat
        end if
    end repeat

    -- Sort the tasks of the purge: subtasks before their parents (deepest first), then oldest first
    set eligibleCount to 0
    set purgePositions to {}
    set skippedOpenPositions to {}
    set skippedOtherPositions to {}
    set keyList to {}
    repeat with i from 1 to taskCount
        set end of keyList to 0
        if item i of eligibleList then
            set eligibleCount to eligibleCount + 1
            if item i of openBelow then
                set end of skippedOpenPositions to i
            else if item i of otherBelow then
                set end of skippedOtherPositions to i
            else
                set end of purgePositions to i
                set depthValue to 1
                set k to item i of parentPosList
                repeat while k > 0 and depthValue < 500
                    set depthValue to depthValue + 1
                    set k to item k of parentPosList
                end repeat
                set ageSeconds to 0
                set whenDate to item i of whenList
                if whenDate is not missing value then
                    set ageSeconds to nowDate - whenDate
                    if ageSeconds < 0 then set ageSeconds to 0
                    if ageSeconds > 2000000000 then set ageSeconds to 2000000000
                end if
                set item i of keyList to (1000 - depthValue) * 3000000000 + (2000000000 - ageSeconds)
            end if
        end if
    end repeat
    set purgeCount to count of purgePositions
    set skippedCount to (count of skippedOpenPositions) + (count of skippedOtherPositions)

    -- What was asked for, in words
    set whatText to "completed or dropped"
    if scopeText is "completed" then set whatText to "completed"
    if scopeText is "dropped" then set whatText to "dropped"
    set filterText to ""
    if olderDays > 0 then set filterText to " older than " & my countText(olderDays, "day", "days")
    if scopeLabel is not "" then set filterText to filterText & " in " & scopeLabel

    if purgeCount = 0 and skippedCount = 0 then
        set emptyText to "🔍 No " & whatText & " tasks" & filterText & " to delete."
        if undatedCount > 0 then set emptyText to emptyText & return & "ℹ️ " & my countText(undatedCount, "task", "tasks") & " without a date left out."
        return emptyText
    end if

    set sortedPositions to my sortPositionsAscending(purgePositions, keyList)
    set batchSize to purgeCount
    if batchSize > maxCount then set batchSize to maxCount

    set projectCacheIDs to {}
    set projectCacheLabels to {}

    -- Without dry_run false and confirm_delete true nothing is deleted: show what would be deleted
    set refusedText to ""
    if not dryRun and not confirmDelete then
        set refusedText to "⚠️ Deleting is permanent and needs confirm_delete true. Nothing was deleted; this is the preview."
        set dryRun to true
    end if

    if dryRun then
        set reportText to ""
        if refusedText is not "" then set reportText to refusedText & return
        set reportText to reportText & "🔍 Preview, nothing was deleted: " & my countText(purgeCount, "task", "tasks") & " (" & whatText & ")" & filterText & " can be deleted permanently."
        set shownCount to 0
        repeat with p from 1 to batchSize
            set fullIndex to item p of sortedPositions
            set reportText to reportText & return & my entryLine(fullIndex, nameList, taskIDList, taskProjectIDList, kindList, whenList, hiddenProjectIDList, allProjectIDList, allProjectNameList, allProjectFolderIDList, folderIDList, folderNameList, folderParentIDList, projectCacheIDs, projectCacheLabels)
            set shownCount to shownCount + 1
        end repeat
        if purgeCount > batchSize then
            set reportText to reportText & return & "… " & my countText(purgeCount - batchSize, "more task", "more tasks") & " not shown (limit " & maxCount & "). A real call deletes at most " & maxCount & " per call; call it again for the rest."
        end if
        set reportText to reportText & my skippedReport(skippedOpenPositions, skippedOtherPositions, nameList, taskIDList, taskProjectIDList, kindList, whenList, hiddenProjectIDList, allProjectIDList, allProjectNameList, allProjectFolderIDList, folderIDList, folderNameList, folderParentIDList, projectCacheIDs, projectCacheLabels)
        if undatedCount > 0 then set reportText to reportText & return & "ℹ️ " & my countText(undatedCount, "task", "tasks") & " without a date left out (older_than_days needs a date)."
        if purgeCount > 0 then set reportText to reportText & return & "To delete them, call again with dry_run false and confirm_delete true. This cannot be undone."
        return reportText
    end if

    -- Delete: subtasks first, one by one, until the time is up. Every task is checked again right before it is deleted.
    set deletedLines to {}
    set errorLines to {}
    set deletedCount to 0
    set failedBelow to {}
    repeat with i from 1 to taskCount
        set end of failedBelow to false
    end repeat
    set processedCount to 0
    set timedOut to false
    repeat with p from 1 to batchSize
        if ((current date) - startedAt) > timeBudgetSeconds then
            set timedOut to true
            exit repeat
        end if
        set fullIndex to item p of sortedPositions
        set processedCount to processedCount + 1
        set entryText to my entryLine(fullIndex, nameList, taskIDList, taskProjectIDList, kindList, whenList, hiddenProjectIDList, allProjectIDList, allProjectNameList, allProjectFolderIDList, folderIDList, folderNameList, folderParentIDList, projectCacheIDs, projectCacheLabels)
        set deleteResult to {wasDeleted:false, reasonText:"a subtask could not be deleted"}
        if not (item fullIndex of failedBelow) then
            set deleteResult to my deleteOneTask(item fullIndex of taskIDList, item fullIndex of kindList)
        end if
        if wasDeleted of deleteResult then
            set deletedCount to deletedCount + 1
            set end of deletedLines to entryText
        else
            set end of errorLines to entryText & " — " & (reasonText of deleteResult)
            set k to item fullIndex of parentPosList
            repeat while k > 0
                if item k of failedBelow then exit repeat
                set item k of failedBelow to true
                set k to item k of parentPosList
            end repeat
        end if
    end repeat

    set reportText to "🗑️ Permanently deleted " & my countText(deletedCount, "task", "tasks") & " (" & whatText & ")" & filterText & "."
    set shownCount to 0
    repeat with aLine in deletedLines
        if shownCount ≥ 30 then exit repeat
        set reportText to reportText & return & (contents of aLine)
        set shownCount to shownCount + 1
    end repeat
    if deletedCount > shownCount then set reportText to reportText & return & "… and " & (deletedCount - shownCount) & " more."
    if (count of errorLines) > 0 then
        set reportText to reportText & return & return & "❌ Not deleted (" & (count of errorLines) & "):"
        set shownCount to 0
        repeat with aLine in errorLines
            if shownCount ≥ 20 then exit repeat
            set reportText to reportText & return & (contents of aLine)
            set shownCount to shownCount + 1
        end repeat
        if (count of errorLines) > shownCount then set reportText to reportText & return & "… and " & ((count of errorLines) - shownCount) & " more."
    end if
    set reportText to reportText & my skippedReport(skippedOpenPositions, skippedOtherPositions, nameList, taskIDList, taskProjectIDList, kindList, whenList, hiddenProjectIDList, allProjectIDList, allProjectNameList, allProjectFolderIDList, folderIDList, folderNameList, folderParentIDList, projectCacheIDs, projectCacheLabels)
    set restCount to purgeCount - processedCount
    if timedOut then
        set reportText to reportText & return & "⏱️ Stopped after about " & timeBudgetSeconds & " seconds to stay within the time limit."
    end if
    if restCount > 0 then
        set reportText to reportText & return & "… " & my countText(restCount, "more task", "more tasks") & " left to delete. Call again to continue."
    end if
    if undatedCount > 0 then set reportText to reportText & return & "ℹ️ " & my countText(undatedCount, "task", "tasks") & " without a date left out (older_than_days needs a date)."
    return reportText
end run

on deleteOneTask(theID, kindText)
    -- Deletes one task, found by its ID, after checking that it is still the task that was meant and still completed
    -- or dropped. Returns {wasDeleted, reasonText}; an error for one task never stops the others.
    set failureText to ""
    tell application "OmniFocus"
        tell default document
            set theTask to missing value
            try
                set theTask to flattened task id theID
                set checkID to id of theTask
            on error
                set theTask to missing value
            end try
            if theTask is missing value then
                try
                    set foundTasks to every flattened task whose id is theID
                    if (count of foundTasks) = 1 then set theTask to item 1 of foundTasks
                end try
            end if
            if theTask is missing value then
                set failureText to "the task was not found any more"
            else
                try
                    if (id of theTask) is not theID then
                        set failureText to "the task was not found any more"
                    else
                        set isDone to completed of theTask
                        set isOwnDropped to dropped of theTask
                        if kindText is "completed" and not isDone then
                            set failureText to "no longer completed, left alone"
                        else if kindText is "dropped" and not isOwnDropped then
                            set failureText to "no longer dropped, left alone"
                        else
                            delete theTask
                        end if
                    end if
                on error errMsg
                    set failureText to errMsg
                end try
            end if
        end tell
    end tell
    if failureText is not "" then return {wasDeleted:false, reasonText:failureText}
    return {wasDeleted:true, reasonText:""}
end deleteOneTask

on entryLine(fullIndex, nameList, taskIDList, taskProjectIDList, kindList, whenList, hiddenProjectIDList, allProjectIDList, allProjectNameList, allProjectFolderIDList, folderIDList, folderNameList, folderParentIDList, projectCacheIDs, projectCacheLabels)
    -- "• Name [Folder > Project] ✓ 2026-03-04 [id:...]", with (hidden folder) for tasks below a hidden folder.
    -- The project label is built once per project (projectCacheIDs and projectCacheLabels are filled on the way).
    set theProjectID to item fullIndex of taskProjectIDList
    set labelText to "Inbox"
    set isHidden to false
    if theProjectID is not missing value then
        set cacheIndex to my indexOfItem(theProjectID, projectCacheIDs)
        if cacheIndex = 0 then
            set labelText to "?"
            set projectIndex to my indexOfItem(theProjectID, allProjectIDList)
            if projectIndex > 0 then
                set labelText to item projectIndex of allProjectNameList
                set folderPathText to my folderPathOf(item projectIndex of allProjectFolderIDList, folderIDList, folderNameList, folderParentIDList)
                if folderPathText is not "" then set labelText to folderPathText & " > " & labelText
            end if
            set end of projectCacheIDs to theProjectID
            set end of projectCacheLabels to labelText
        else
            set labelText to item cacheIndex of projectCacheLabels
        end if
        set isHidden to (hiddenProjectIDList contains theProjectID)
    end if
    set markText to "✓"
    if (item fullIndex of kindList) is "dropped" then set markText to "🚫"
    set entryText to "• " & (item fullIndex of nameList) & " [" & labelText & "] " & markText
    set whenDate to item fullIndex of whenList
    if whenDate is not missing value then set entryText to entryText & " " & (my shortDate(whenDate))
    if isHidden then set entryText to entryText & " (hidden folder)"
    return entryText & " [id:" & (item fullIndex of taskIDList) & "]"
end entryLine

on skippedReport(skippedOpenPositions, skippedOtherPositions, nameList, taskIDList, taskProjectIDList, kindList, whenList, hiddenProjectIDList, allProjectIDList, allProjectNameList, allProjectFolderIDList, folderIDList, folderNameList, folderParentIDList, projectCacheIDs, projectCacheLabels)
    -- The tasks that were left alone because of their subtasks, with the reason (at most 20 lines)
    set skippedCount to (count of skippedOpenPositions) + (count of skippedOtherPositions)
    if skippedCount = 0 then return ""
    set reportText to return & return & "⏭️ Skipped " & skippedCount & " (a task is only deleted together with all its subtasks):"
    set shownCount to 0
    repeat with aPosition in skippedOpenPositions
        if shownCount ≥ 20 then exit repeat
        set reportText to reportText & return & my entryLine(contents of aPosition, nameList, taskIDList, taskProjectIDList, kindList, whenList, hiddenProjectIDList, allProjectIDList, allProjectNameList, allProjectFolderIDList, folderIDList, folderNameList, folderParentIDList, projectCacheIDs, projectCacheLabels) & " — has open subtasks"
        set shownCount to shownCount + 1
    end repeat
    repeat with aPosition in skippedOtherPositions
        if shownCount ≥ 20 then exit repeat
        set reportText to reportText & return & my entryLine(contents of aPosition, nameList, taskIDList, taskProjectIDList, kindList, whenList, hiddenProjectIDList, allProjectIDList, allProjectNameList, allProjectFolderIDList, folderIDList, folderNameList, folderParentIDList, projectCacheIDs, projectCacheLabels) & " — has subtasks that are not part of this purge (younger or in another state)"
        set shownCount to shownCount + 1
    end repeat
    if skippedCount > shownCount then set reportText to reportText & return & "… and " & (skippedCount - shownCount) & " more."
    return reportText
end skippedReport

on idTextOf(idList)
    -- The IDs of a list joined into one text (linefeed & id1 & linefeed & id2 & linefeed ...), so that the system can search it
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to linefeed
    set joinedText to linefeed & (idList as text) & linefeed
    set AppleScript's text item delimiters to oldDelims
    return joinedText
end idTextOf

on idInText(idText, theID)
    -- True if the ID is in a text made by idTextOf
    considering case
        return (offset of (linefeed & theID & linefeed) in idText) > 0
    end considering
end idInText

on indexOfID(idText, theID)
    -- Position of an ID in a list that was joined into one text (linefeed & id1 & linefeed & id2 & linefeed ...), 0 if it is
    -- not in it. The search is done by the system and does not loop over the list.
    set matchPosition to 0
    considering case
        set matchPosition to offset of (linefeed & theID & linefeed) in idText
    end considering
    if matchPosition = 0 then return 0
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to linefeed
    set linefeedCount to (count of text items of (text 1 thru matchPosition of idText)) - 1
    set AppleScript's text item delimiters to oldDelims
    return linefeedCount
end indexOfID

on indexOfItem(anItem, aList)
    -- Position of anItem in aList, 0 if it is not in the list
    repeat with i from 1 to count of aList
        if (item i of aList) is anItem then return i
    end repeat
    return 0
end indexOfItem

on countText(amount, singularWord, pluralWord)
    -- "1 day", "5 days"
    if amount is 1 then return "1 " & singularWord
    return (my plainNumberText(amount)) & " " & pluralWord
end countText

on folderPathOf(folderID, folderIDList, folderNameList, folderParentIDList)
    -- "Folder > Subfolder" of the folder with this ID, from the lists of all folders ("" without a folder)
    set pathNames to {}
    set currentID to folderID
    repeat while currentID is not missing value
        set folderIndex to my indexOfItem(currentID, folderIDList)
        if folderIndex = 0 then exit repeat
        set beginning of pathNames to item folderIndex of folderNameList
        set currentID to item folderIndex of folderParentIDList
    end repeat
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to " > "
    set pathText to pathNames as text
    set AppleScript's text item delimiters to oldDelims
    return pathText
end folderPathOf

on sortPositionsAscending(positionList, keyList)
    -- The positions in positionList ordered by the key at each position (keyList), smallest key first
    -- (bottom-up merge sort, equal keys keep their order). No Apple Events: the keys are values in a list.
    set itemCount to count of positionList
    set orderList to positionList
    set blockSize to 1
    repeat while blockSize < itemCount
        set mergedList to {}
        set blockStart to 1
        repeat while blockStart ≤ itemCount
            set leftPos to blockStart
            set leftEnd to blockStart + blockSize - 1
            if leftEnd > itemCount then set leftEnd to itemCount
            set rightPos to blockStart + blockSize
            set rightEnd to blockStart + 2 * blockSize - 1
            if rightEnd > itemCount then set rightEnd to itemCount
            repeat while leftPos ≤ leftEnd and rightPos ≤ rightEnd
                if (item (item leftPos of orderList) of keyList) ≤ (item (item rightPos of orderList) of keyList) then
                    set end of mergedList to item leftPos of orderList
                    set leftPos to leftPos + 1
                else
                    set end of mergedList to item rightPos of orderList
                    set rightPos to rightPos + 1
                end if
            end repeat
            repeat while leftPos ≤ leftEnd
                set end of mergedList to item leftPos of orderList
                set leftPos to leftPos + 1
            end repeat
            repeat while rightPos ≤ rightEnd
                set end of mergedList to item rightPos of orderList
                set rightPos to rightPos + 1
            end repeat
            set blockStart to blockStart + 2 * blockSize
        end repeat
        set orderList to mergedList
        set blockSize to blockSize * 2
    end repeat
    return orderList
end sortPositionsAscending

on isDigits(theText)
    -- True if the text is not empty and has only the digits 0 to 9
    if theText is "" then return false
    repeat with aChar in characters of theText
        if "0123456789" does not contain (contents of aChar) then return false
    end repeat
    return true
end isDigits

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

on resolveFolder(queryText)
    -- Finds a folder at any depth by name, or by "Folder > Subfolder".
    -- Names match exactly or as a substring, ignoring case.
    -- "id:<id>" finds a folder by the ID shown by list_folders.
    -- Returns {foundFolder, errorText}; foundFolder is missing value if nothing or more than one folder fits.
    if queryText starts with "id:" then
        set wantedID to ""
        if (length of queryText) > 3 then set wantedID to my trimItem(text 4 thru -1 of queryText)
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
        set cleanPart to my trimItem(rawPart as string)
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

on hiddenFolderProjectIDs()
    -- IDs of all projects below a hidden (dropped) folder, at any depth. One query per list instead of one per project:
    -- every Apple Event costs about 17 ms, a query for all elements about 50 ms.
    set idList to {}
    tell application "OmniFocus"
        tell default document
            try
                set hiddenFlags to effectively hidden of every flattened folder
                if hiddenFlags does not contain true then return {}
                set hiddenFolderIDList to id of every flattened folder whose effectively hidden is true
                set projectIDList to id of every flattened project
                set projectFolderIDList to id of folder of every flattened project
                repeat with i from 1 to count of projectIDList
                    set folderID to item i of projectFolderIDList
                    if folderID is not missing value then
                        if hiddenFolderIDList contains folderID then set end of idList to item i of projectIDList
                    end if
                end repeat
            end try
        end tell
    end tell
    return idList
end hiddenFolderProjectIDs

on shortDate(aDate)
    -- "2026-11-18": year, month and day with the digits 0 to 9 in a fixed order, independent of the language and the date
    -- format of the Mac
    set monthNumber to (month of aDate) as integer
    return (my plainNumberText(year of aDate)) & "-" & (text -2 thru -1 of ("0" & my plainNumberText(monthNumber))) & "-" & (text -2 thru -1 of ("0" & my plainNumberText(day of aDate)))
end shortDate

on plainNumberText(theNumber)
    -- A whole number as text with the digits 0 to 9. "as text" and "&" write the digits of the region instead
    -- (Eastern Arabic digits on a Mac with an Arabic or Persian region).
    set wholeNumber to theNumber as integer
    if wholeNumber < 0 then return "-" & my plainNumberText(0 - wholeNumber)
    if wholeNumber < 10 then return character (wholeNumber + 1) of "0123456789"
    return (my plainNumberText(wholeNumber div 10)) & (character ((wholeNumber mod 10) + 1) of "0123456789")
end plainNumberText
