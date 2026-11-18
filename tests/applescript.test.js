const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

describe('AppleScript Integration', () => {
    const scriptsDir = path.join(__dirname, '..', 'src', 'scripts');
    const enhancedScriptsDir = path.join(scriptsDir, 'enhanced');

    describe('Script Files', () => {
        test('string literals are well formed in every script', () => {
            // osacompile only runs on a Mac; this catches a lost backslash in an escaped quote
            // (an unterminated string, or two string literals glued together)
            const findProblem = line => {
                let inString = false;
                for (let i = 0; i < line.length; i++) {
                    const ch = line[i];
                    if (inString) {
                        if (ch === '\\') i++;
                        else if (ch === '"') {
                            inString = false;
                            if (line[i + 1] === '"') return 'two string literals without an operator between them';
                        }
                    } else if (ch === '"') inString = true;
                    else if (ch === '-' && line[i + 1] === '-') return null;
                }
                return inString ? 'unterminated string' : null;
            };
            const problems = [];
            [scriptsDir, enhancedScriptsDir].forEach(dir => {
                fs.readdirSync(dir).filter(f => f.endsWith('.applescript')).forEach(file => {
                    fs.readFileSync(path.join(dir, file), 'utf8').split('\n').forEach((line, index) => {
                        const problem = findProblem(line);
                        if (problem) problems.push(`${file}:${index + 1} ${problem}`);
                    });
                });
            });
            expect(problems).toEqual([]);
        });

        test('scripts directory exists', () => {
            expect(fs.existsSync(scriptsDir)).toBe(true);
        });

        test('enhanced scripts directory exists', () => {
            expect(fs.existsSync(enhancedScriptsDir)).toBe(true);
        });

        test('core scripts exist', () => {
            const coreScripts = [
                'add_task.applescript',
                'complete_task.applescript',
                'list_inbox.applescript',
                'today_tasks.applescript',
                'weekly_review.applescript'
            ];

            coreScripts.forEach(script => {
                const scriptPath = path.join(scriptsDir, script);
                expect(fs.existsSync(scriptPath)).toBe(true);
            });
        });

        test('enhanced scripts exist', () => {
            const enhancedScripts = [
                'batch_add_tasks.applescript',
                'create_recurring_task.applescript',
                'edit_task.applescript',
                'list_deferred_tasks.applescript',
                'list_flagged_tasks.applescript',
                'list_overdue_tasks.applescript',
                'list_projects.applescript',
                'search_tasks.applescript',
                'list_tags.applescript',
                'create_tag.applescript',
                'add_tag_to_task.applescript',
                'remove_tag_from_task.applescript',
                'create_project.applescript',
                'edit_project.applescript',
                'create_folder.applescript',
                'rename_folder.applescript',
                'drop_task.applescript',
                'get_task.applescript',
                'list_projects_for_review.applescript',
                'mark_project_reviewed.applescript',
                'list_stalled_projects.applescript',
                'list_tasks_filtered.applescript',
                'list_completed_tasks.applescript',
                'list_tasks_by_date.applescript',
                'get_settings.applescript',
                'create_backup.applescript',
                'edit_tag.applescript',
                'reopen_task.applescript',
                'get_project.applescript',
                'list_due_soon.applescript',
                'parse_tasks.applescript',
                'list_perspectives.applescript',
                'get_selected_link.applescript',
                'synchronize.applescript',
                'save_attachment.applescript',
                'format_note.applescript',
                'get_selection.applescript',
                'get_forecast.applescript',
                'set_view.applescript',
                'show_item.applescript',
                'duplicate_item.applescript',
                'clean_up.applescript',
                'undo.applescript',
                'list_folders.applescript',
                'edit_folder.applescript',
                'delete_folder.applescript',
                'purge_tasks.applescript'
            ];

            enhancedScripts.forEach(script => {
                const scriptPath = path.join(enhancedScriptsDir, script);
                expect(fs.existsSync(scriptPath)).toBe(true);
            });
        });
    });

    describe('Script Syntax', () => {
        test('all AppleScript files compile without syntax errors', () => {
            // Check if osacompile is available (macOS only) AND OmniFocus is
            // installed. Scripts use OmniFocus-specific dictionary terms
            // (e.g. `tell default document`) that cause osacompile to fail
            // with "Expected end of line but found class name" when OmniFocus
            // is not installed on the machine running the test.
            let osacompileAvailable = false;
            try {
                execSync('which osacompile', { stdio: 'pipe' });
                execSync('test -d "/Applications/OmniFocus.app"', { stdio: 'pipe' });
                osacompileAvailable = true;
            } catch { /* not in this environment or OmniFocus not installed */ }

            const scriptFiles = fs.readdirSync(scriptsDir)
                .filter(f => f.endsWith('.applescript'))
                .map(f => path.join(scriptsDir, f));

            if (fs.existsSync(enhancedScriptsDir)) {
                const enhancedFiles = fs.readdirSync(enhancedScriptsDir)
                    .filter(f => f.endsWith('.applescript'))
                    .map(f => path.join(enhancedScriptsDir, f));
                scriptFiles.push(...enhancedFiles);
            }

            if (osacompileAvailable) {
                // Compile each script to a temp file to catch syntax errors
                scriptFiles.forEach(scriptPath => {
                    const outFile = path.join(
                        os.tmpdir(),
                        `osatest-${Date.now()}-${Math.random().toString(36).slice(2)}.scpt`
                    );
                    try {
                        execSync(`osacompile -o "${outFile}" "${scriptPath}"`, { stdio: 'pipe' });
                    } catch (error) {
                        const stderr = error.stderr ? error.stderr.toString() : error.message;
                        throw new Error(`Syntax error in ${path.basename(scriptPath)}: ${stderr}`);
                    } finally {
                        if (fs.existsSync(outFile)) fs.unlinkSync(outFile);
                    }
                });
            } else {
                // Fallback: verify non-empty and have basic AppleScript structure
                scriptFiles.forEach(scriptPath => {
                    const content = fs.readFileSync(scriptPath, 'utf8');
                    expect(content.length).toBeGreaterThan(0);
                    expect(content).toMatch(/on run|tell application/i);
                });
            }
        });

        test('scripts have proper structure', () => {
            const scriptFiles = fs.readdirSync(scriptsDir)
                .filter(f => f.endsWith('.applescript'))
                .map(f => path.join(scriptsDir, f));

            scriptFiles.forEach(scriptPath => {
                const content = fs.readFileSync(scriptPath, 'utf8');
                // Check for basic AppleScript structure
                expect(content).toMatch(/on run|tell application/i);
            });
        });
    });

    describe('Script Parameters', () => {
        test('add_task.applescript parses all 7 arguments including defer_date and estimated_minutes', () => {
            const scriptPath = path.join(scriptsDir, 'add_task.applescript');
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toContain('item 6 of argv');
            expect(content).toContain('item 7 of argv');
        });

        test('add_task.applescript parses argument 8 for tags', () => {
            const scriptPath = path.join(scriptsDir, 'add_task.applescript');
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toContain('item 8 of argv');
        });

        test('scripts handle input parameters correctly', () => {
            // Check that scripts that expect parameters have proper handling
            const parameterizedScripts = [
                { file: 'add_task.applescript', expects: 'run argv' },
                { file: 'complete_task.applescript', expects: 'run argv' },
                { file: 'enhanced/search_tasks.applescript', expects: 'run argv' },
                { file: 'enhanced/edit_task.applescript', expects: 'run argv' },
                { file: 'enhanced/batch_add_tasks.applescript', expects: 'run argv' },
                { file: 'enhanced/create_recurring_task.applescript', expects: 'run argv' }
            ];

            parameterizedScripts.forEach(({ file, expects }) => {
                const scriptPath = path.join(scriptsDir, file);
                if (fs.existsSync(scriptPath)) {
                    const content = fs.readFileSync(scriptPath, 'utf8');
                    expect(content).toContain(expects);
                }
            });
        });
    });

    describe('Script Output', () => {
        test('scripts return structured output', () => {
            const scriptFiles = [
                'list_inbox.applescript',
                'today_tasks.applescript',
                'weekly_review.applescript'
            ];

            scriptFiles.forEach(file => {
                const scriptPath = path.join(scriptsDir, file);
                if (fs.existsSync(scriptPath)) {
                    const content = fs.readFileSync(scriptPath, 'utf8');
                    // Check for return statements
                    expect(content).toContain('return');
                }
            });
        });
    });

    describe('OmniFocus Integration', () => {
        test('scripts use correct OmniFocus application identifier', () => {
            const scriptFiles = fs.readdirSync(scriptsDir)
                .filter(f => f.endsWith('.applescript'))
                .map(f => path.join(scriptsDir, f));

            scriptFiles.forEach(scriptPath => {
                const content = fs.readFileSync(scriptPath, 'utf8');
                expect(content).toContain('tell application "OmniFocus"');
            });
        });

        test('scripts handle default document correctly', () => {
            const scriptFiles = fs.readdirSync(scriptsDir)
                .filter(f => f.endsWith('.applescript'))
                .map(f => path.join(scriptsDir, f));

            scriptFiles.forEach(scriptPath => {
                const content = fs.readFileSync(scriptPath, 'utf8');
                if (content.includes('default document')) {
                    // Ensure proper document handling
                    expect(content).toMatch(/tell\s+(front document|default document)/);
                }
            });
        });
    });

    describe('edit_task estimate', () => {
        const scriptPath = path.join(enhancedScriptsDir, 'edit_task.applescript');

        test('checks the number of minutes and clears the estimate with none', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toContain('set estimated minutes of targetTask to missing value');
            expect(content).toContain('Cleared the estimate for:');
            expect(content).toContain('Invalid value for estimated_minutes:');
            expect(content).toContain('my isDigits(minutesText)');
            expect(content).not.toContain('(newValue as integer)');
        });
    });

    describe('Date parsing', () => {
        const dateScripts = [
            path.join(scriptsDir, 'add_task.applescript'),
            path.join(enhancedScriptsDir, 'batch_add_tasks.applescript'),
            path.join(enhancedScriptsDir, 'create_recurring_task.applescript'),
            path.join(enhancedScriptsDir, 'create_project.applescript'),
            path.join(enhancedScriptsDir, 'edit_project.applescript'),
            path.join(enhancedScriptsDir, 'edit_task.applescript')
        ];

        test('every script that reads dates uses the same parser, which never guesses', () => {
            for (const scriptPath of dateScripts) {
                const content = fs.readFileSync(scriptPath, 'utf8');
                expect(content).toContain('on parseDate(dateString)');
                expect(content).toContain('on parseISODate(dateString)');
                expect(content).toContain('on hasDigitDash(theText)');
                expect(content).toContain('on dateErrorText(valueText, fieldName)');
                // an unreadable date gives missing value, never today or tomorrow
                expect(content).not.toMatch(/on error\s+return todayDate/);
                expect(content).not.toContain('return date dateString');
            }
        });

        test('an unreadable date is refused before anything is changed or created', () => {
            const read = (dir, name) => fs.readFileSync(path.join(dir, name), 'utf8');
            const editTask = read(enhancedScriptsDir, 'edit_task.applescript');
            expect(editTask).toContain('my dateErrorText(newValue, "due_date") & " Nothing was changed."');
            expect(editTask).toContain('my dateErrorText(newValue, "defer_date") & " Nothing was changed."');
            expect(editTask).toContain('my dateErrorText(newValue, "planned_date") & " Nothing was changed."');
            const editProject = read(enhancedScriptsDir, 'edit_project.applescript');
            expect(editProject).toContain('my dateErrorText(newValue, "next_review_date") & " Nothing was changed."');
            expect(editProject).toContain('my dateErrorText(newValue, "due_date") & " Nothing was changed."');
            const createProject = read(enhancedScriptsDir, 'create_project.applescript');
            expect(createProject).toContain('my dateErrorText(dueText, "due_date") & " Nothing was created."');
            expect(createProject).toContain('my dateErrorText(deferText, "defer_date") & " Nothing was created."');
            const batch = read(enhancedScriptsDir, 'batch_add_tasks.applescript');
            expect(batch).toContain('my dateErrorText(dueDate, "due_date") & " Nothing was created."');
            const recurring = read(enhancedScriptsDir, 'create_recurring_task.applescript');
            expect(recurring).toContain('my dateErrorText(initialDueDate, "due_date") & " Nothing was created."');
            expect(recurring).toContain('set due date of newTask to dueDateValue');
            // add_task skips a date it cannot read and says so
            const addTask = read(scriptsDir, 'add_task.applescript');
            expect(addTask).toContain('set skippedDates to skippedDates & " due_date"');
        });

        test('the parser reads ISO dates with a time from their parts and weeks and days as numbers', () => {
            const content = fs.readFileSync(path.join(enhancedScriptsDir, 'edit_task.applescript'), 'utf8');
            expect(content).toContain('set time of isoDate to hourNum * hours + minuteNum * minutes + secondNum');
            expect(content).toContain('if unitName is "week" or unitName is "weeks" then return todayDate + amountNum * weeks');
            expect(content).toContain('if my hasDigitDash(trimmed) then return missing value');
            // the system parser rolls 31.31.2026 over into a later date; the result must fit the numbers of the text
            expect(content).toContain('if not my fallbackDateFits(trimmed, systemDate) then return missing value');
        });
    });

    describe('Recurring Task Recurrence Strings', () => {
        const scriptPath = path.join(enhancedScriptsDir, 'create_recurring_task.applescript');

        test('sets the repetition with the shared handlers and checks the rule before it creates anything', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toContain('set repeatInfo to my parseRepeatRule(repeatRule)');
            expect(content).toContain('my applyRepetition(newTask, ruleString of repeatInfo, scheduleName of repeatInfo, "due", false)');
            expect(content).toContain('Nothing was created.');
            // Should NOT use the old broken approach
            expect(content).not.toContain('repetition interval');
            expect(content).not.toContain('{unit:');
            expect(content).not.toContain('buildRecurrenceString');
        });

        test('refuses an empty name and does not report "changed" and "created" at once', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toContain('A recurring task needs a name. Nothing was created.');
            expect(content).toContain('my removeText(problemText, " Nothing was changed.")');
        });

        test('parseRepeatRule builds the iCalendar strings for the standard repeat rules', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            ['"DAILY"', '"WEEKLY"', '"MONTHLY"', '"YEARLY"'].forEach(part => expect(content).toContain(part));
            expect(content).toContain('";INTERVAL=" & my plainNumberText(intervalCount)');
        });

        test('applyRepetition uses the schedule and the date a repetition is based on', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toContain('repetition schedule:regularly, repetition based on:based on due, catch up automatically:catchValue');
            expect(content).toContain('repetition schedule:from completion, repetition based on:based on defer');
            expect(content).toContain('repetition based on:based on planned');
        });
    });

    describe('list_tags Hierarchy Support', () => {
        const scriptPath = path.join(enhancedScriptsDir, 'list_tags.applescript');

        test('builds the hierarchy from the parent IDs of all tags (no recursion with one query per tag)', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toMatch(/set tagParentIDList to id of container of every flattened tag/);
            expect(content).toMatch(/set parentIndex to my indexOfID\(tagIDText, parentID\)/);
            expect(content).not.toMatch(/on formatTags\(/);
            expect(content).not.toMatch(/every tag of aTag/);
        });

        test('indents child tags based on depth', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toMatch(/repeat depth times/);
            expect(content).toMatch(/set indent to indent & "  "/);
        });

        test('reads the properties of all tags with one query each', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toMatch(/set tagIDList to id of every flattened tag/);
            expect(content).toMatch(/set tagNameList to name of every flattened tag/);
            expect(content).toMatch(/set tagHiddenList to hidden of every flattened tag/);
            expect(content).toMatch(/set tagAllowsList to allows next action of every flattened tag/);
        });

        test('counts the open tasks of all tags in one pass with the tag IDs of all tasks', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toMatch(/set taskTagIDLists to id of tags of every flattened task/);
            expect(content).toMatch(/set taskCompletedList to completed of every flattened task/);
            expect(content).toMatch(/set item tagIndex of tagTaskCounts to/);
        });
    });

    describe('GTD query tools', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('list_tasks_filtered.applescript reads all 6 arguments', () => {
            const content = read('list_tasks_filtered.applescript');
            for (let i = 1; i <= 6; i++) {
                expect(content).toContain(`item ${i} of argv`);
            }
        });

        test('list_tasks_filtered.applescript leaves out completed, dropped and hidden-folder tasks', () => {
            const content = read('list_tasks_filtered.applescript');
            expect(content).toContain('effectively completed of every flattened task');
            expect(content).toContain('effectively dropped of every flattened task');
            expect(content).toContain('hiddenProjectIDList contains projectID');
            expect(content).toContain('effectively hidden of every flattened folder');
        });

        test('list_tasks_filtered.applescript does not list a project without tasks as a task', () => {
            const content = read('list_tasks_filtered.applescript');
            expect(content).toContain('projectID is taskID');
        });

        test('list_tasks_filtered.applescript reports ambiguous tags instead of guessing', () => {
            const content = read('list_tasks_filtered.applescript');
            expect(content).toContain('Ambiguous tag');
            expect(content).toContain('Tag not found');
        });

        test('list_tasks_filtered.applescript filters by estimated minutes', () => {
            const content = read('list_tasks_filtered.applescript');
            expect(content).toContain('item 7 of argv');
            expect(content).toContain('estimated minutes of every flattened task');
            expect(content).toContain('estimateValue > maxMinutes');
            expect(content).toContain('includeUnestimated');
        });

        test('list_tasks_filtered.applescript shows the age and sorts oldest first', () => {
            const content = read('list_tasks_filtered.applescript');
            expect(content).toContain('item 9 of argv');
            expect(content).toContain('creation date of every flattened task');
            expect(content).toContain('on ageText(');
            expect(content).toContain('oldest first');
            // the limit applies after sorting
            expect(content).toContain('matchCount ≥ maxResults and not showAge');
        });

        test('list_completed_tasks.applescript filters by completion date', () => {
            const content = read('list_completed_tasks.applescript');
            expect(content).toContain('completion date of every flattened task');
            expect(content).toContain('effectively hidden of every flattened folder');
        });

        test('list_tasks_by_date.applescript queries by creation, modification and drop date', () => {
            const content = read('list_tasks_by_date.applescript');
            // bulk queries (one per property) instead of one query per item
            expect(content).toContain('creation date of every flattened task of scopeRef');
            expect(content).toContain('modification date of every flattened task of scopeRef');
            expect(content).toContain('dropped date of every flattened task of scopeRef');
            expect(content).toContain('whenDate ≥ sinceDate and whenDate < untilDate');
            // tasks and projects, one project as scope
            expect(content).toContain('every flattened task of scopeRef');
            expect(content).toContain('status of every flattened project');
            expect(content).toContain('changed while the');
            expect(content).toContain('on resolveProject(');
            // hidden folders are left out, newest first, the limit applies after sorting
            expect(content).toContain('hiddenProjectIDList contains theProjectID');
            // the root task of a project (same ID as the project) is not a task of the list
            expect(content).toContain('projectIDs contains (item i of idList)');
            expect(content).toContain('on sortPositions(');
            expect(content).toContain('shownCount ≥ maxResults');
            // every value is checked before OmniFocus is read; read errors are reported
            expect(content).toContain('Invalid date_field');
            expect(content).toContain('Dropped items are never open');
            expect(content).toContain('since must be before until');
            expect(content).toContain('could not read the');
        });

        test('edit_task.applescript sets the primary tag, the time zone setting and the assigned container', () => {
            const content = read('edit_task.applescript');
            // primary tag: an existing tag moves to the front, none removes the first tag
            expect(content).toContain('propertyName is "primary_tag"');
            expect(content).toContain('return my setItemPrimaryTag(targetTask, "task", originalName, newValue)');
            expect(content).toContain('return my setItemTags(targetTask, "task", originalName, newValue)');
            expect(content).toContain('set primary tag of theItem to theTag');
            expect(content).toContain('set primary tag of theItem to missing value');
            // setting the primary tag replaces all tags in OmniFocus, so the old ones are added again
            expect(content).toContain('set oldTagIDs to id of every tag of theItem');
            expect(content).toContain('add (item 1 of oldTagMatches) to tags of theItem');
            // floating time zone with a checked flag
            expect(content).toContain('set should use floating time zone of targetTask to (flagValue is "true")');
            expect(content).toContain('Invalid value for floating_time_zone');
            // assigned container only for inbox tasks, a project or "task:<task>", checked before it is set
            expect(content).toContain('on setAssignedContainer(');
            expect(content).toContain('in inbox of targetTask');
            expect(content).toContain('Only inbox tasks have an assigned container');
            expect(content).toContain('set assigned container of targetTask to containerRef');
            expect(content).toContain('A task cannot be assigned to itself');
        });

        test('edit_project.applescript sets the time zone setting', () => {
            const content = read('edit_project.applescript');
            expect(content).toContain('set should use floating time zone of targetProject to (flagValue is "true")');
            expect(content).toContain('Invalid value for floating_time_zone');
        });

        test('get_task, get_project and list_inbox show the new properties', () => {
            const task = read('get_task.applescript');
            expect(task).toContain('Primary tag: ');
            expect(task).toContain('Time zone: floating');
            expect(task).toContain('Assigned to: ');
            expect(fs.readFileSync(path.join(enhancedScriptsDir, 'get_project.applescript'), 'utf8')).toContain('Time zone: floating');
            expect(fs.readFileSync(path.join(enhancedScriptsDir, '..', 'list_inbox.applescript'), 'utf8')).toContain('assigned container of aTask');
        });

        test('get_settings.applescript reads settings and preferences with a filter', () => {
            const content = read('get_settings.applescript');
            // only the IDs are read in bulk (OmniFocus cannot return all values at once); values one by one by ID
            expect(content).toContain('id of every setting');
            expect(content).toContain('id of every preference');
            expect(content).not.toContain('value of every setting');
            expect(content).toContain('set theEntry to setting id idText of default document');
            expect(content).toContain('set theEntry to preference id idText');
            expect(content).toContain('cannot be read: a list or data');
            expect(content).toContain('Invalid scope');
            expect(content).toContain('Invalid limit');
            // the first line shows the version and the build number of OmniFocus
            // read inside a tell block: "build number" is a term of the OmniFocus dictionary and does not compile outside of it
            expect(content).toMatch(/tell application "OmniFocus"\s+set versionText to \(version\) as text/);
            expect(content).toMatch(/tell application "OmniFocus"\s+set buildText to \(build number\) as text/);
            expect(content).toContain('set reportText to versionLine & return & return & reportText');
            // nothing is written
            expect(content).not.toMatch(/set value of/);
        });

        test('create_backup.applescript writes an archive only to a new path', () => {
            const content = read('create_backup.applescript');
            expect(content).toContain('archive default document in (POSIX file archivePath) compression compressionFlag');
            expect(content).toContain('exists already. Nothing was written');
            expect(content).toContain('The folder of the archive does not exist');
            expect(content).toContain('Give the full path of the archive');
            expect(content).toContain('Invalid value for compression');
            expect(content).toContain('Invalid wait_seconds');
        });

        test('create_backup.applescript runs the archive command in its own process and reports its state by path and size', () => {
            const content = read('create_backup.applescript');
            // The archive command does not run inside the script that the server waits for: a slow archive must not block the
            // call (the connection of the app gives up after about 80 seconds) or be cut off by the timeout of the server
            expect(content).toContain('/usr/bin/nohup /usr/bin/osascript');
            expect(content).toContain('> /dev/null 2>&1 & echo $!');
            const runHandler = content.slice(content.indexOf('on run argv'), content.indexOf('on startArchive'));
            expect(runHandler).not.toContain('tell application "OmniFocus"');
            // wait at most wait_seconds (70 at most), then say how to check
            expect(content).toContain('if waitSeconds > 70 then set waitSeconds to 70');
            expect(content).toContain('Check it with create_backup, the same path and status_only true');
            // the state: running, done, error, interrupted or unknown, with the size of the archive
            expect(content).toContain('on backupState(markerPath)');
            expect(content).toContain('/bin/kill -0');
            expect(content).toContain('/usr/bin/du -sk');
            expect(content).toContain('The backup is still being written');
            expect(content).toContain('Wrote a backup archive of the database');
            expect(content).toContain('OmniFocus could not write the archive');
            expect(content).toContain('ended without a result');
            // the foreground script does not talk to OmniFocus, so it does not wait for the scripts in front of it in the queue
            const serverContent = fs.readFileSync(path.join(__dirname, '..', 'src', 'server', 'index.js'), 'utf8');
            expect(serverContent).toContain('if (options.queued === false) return run();');
            const backupCase = serverContent.slice(serverContent.indexOf("case 'create_backup':"), serverContent.indexOf("case 'reopen_task':"));
            expect(backupCase).toContain('], { queued: false });');
            // status_only starts nothing and is checked before the folder and the path are looked at
            expect(content.indexOf('if statusOnly then return my statusReport')).toBeGreaterThan(-1);
            expect(content.indexOf('if statusOnly then return my statusReport')).toBeLessThan(content.indexOf('startArchive(archivePath'));
            // a backup that is already being written is waited for, a second one is not started
            expect(content).toContain('if stateName is not "running" then');
        });

        test('edit_project.applescript supports the project types', () => {
            const content = read('edit_project.applescript');
            expect(content).toContain('propertyName is "type"');
            expect(content).toContain('singleton action holder');
            expect(content).toContain('set sequential of targetProject');
        });
    });

    describe('Project review properties', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('edit_project.applescript sets the review interval and the next review date', () => {
            const content = read('edit_project.applescript');
            expect(content).toContain('propertyName is "review_interval"');
            expect(content).toContain('set review interval of aProject to {unit:week, steps:stepCount, fixed:true}');
            expect(content).toContain('propertyName is "next_review_date"');
            expect(content).toContain('set next review date of targetProject to missing value');
            expect(content).toContain('Invalid review interval');
        });

        test('edit_project.applescript sets dates, flag and completion behaviour of a project', () => {
            const content = read('edit_project.applescript');
            expect(content).toContain('set due date of targetProject');
            expect(content).toContain('set defer date of targetProject');
            expect(content).toContain('set planned date of targetProject');
            expect(content).toContain('set flagged of targetProject');
            expect(content).toContain('set completed by children of targetProject');
            expect(content).toContain('Valid properties: name, note, append_note, folder, status, type, review_interval, next_review_date, due_date, defer_date, planned_date, flagged, complete_with_last_item, floating_time_zone, default_single_action_list, tags, primary_tag, repeat, repeat_based_on, repeat_catch_up');
        });

        test('edit_project.applescript sets the tags and the primary tag through the shared tag handlers', () => {
            const content = read('edit_project.applescript');
            expect(content).toContain('propertyName is "tags"');
            expect(content).toContain('return my setItemTags(targetProject, "project", originalLabel, newValue)');
            expect(content).toContain('propertyName is "primary_tag"');
            expect(content).toContain('return my setItemPrimaryTag(targetProject, "project", originalLabel, newValue)');
            // the handlers work on any task or project
            expect(content).toContain('on resolveTagList(listText)');
            expect(content).toContain('on setItemTags(theItem, itemWord, itemLabel, newValue)');
            expect(content).toContain('on setItemPrimaryTag(theItem, itemWord, itemLabel, newValue)');
            expect(content).toContain('on tagNameList(theItem)');
        });

        test('the tag handlers look all tags up before the first one is changed', () => {
            ['edit_task.applescript', 'edit_project.applescript', 'create_project.applescript'].forEach(name => {
                const content = read(name);
                const handler = content.slice(content.indexOf('on setItemTags('), content.indexOf('end setItemTags'));
                expect(handler).toContain('Tags were not changed.');
                expect(handler).toContain('No tag name given');
                expect(handler.indexOf('resolveTagList(newValue)')).toBeLessThan(handler.lastIndexOf('remove existingTag from tags of theItem'));
            });
        });

        test('create_project.applescript sets tags from the eighth argument after all tags were looked up', () => {
            const content = read('create_project.applescript');
            expect(content).toContain('item 8 of argv');
            expect(content).toContain('resolveTagList(tagsText)');
            expect(content.indexOf('resolveTagList(tagsText)')).toBeLessThan(content.indexOf('make new project'));
            expect(content).toContain('The tags could not be set');
        });

        test('get_project.applescript shows tags and primary tag', () => {
            const content = fs.readFileSync(path.join(enhancedScriptsDir, 'get_project.applescript'), 'utf8');
            expect(content).toContain('Tags: ');
            expect(content).toContain('Primary tag: ');
        });

        test('create_project.applescript checks the optional settings before it creates anything', () => {
            const content = read('create_project.applescript');
            expect(content).toContain('item 4 of argv');
            expect(content).toContain('item 7 of argv');
            expect(content).toContain('Nothing was created.');
            expect(content.indexOf('parseReviewInterval(intervalText)')).toBeLessThan(content.indexOf('make new project'));
            expect(content).toContain('set singleton action holder of newProject to true');
        });

        test('list_projects_for_review.applescript shows the review interval', () => {
            const content = read('list_projects_for_review.applescript');
            expect(content).toContain('review interval of every flattened project');
            expect(content).toContain('reviewIntervalText(item (contents of i) of reviewIntervalList)');
            expect(content).toContain('every " & stepCount');
        });

        test('the review interval parser knows all units', () => {
            const content = read('edit_project.applescript');
            ['"day"', '"week"', '"month"', '"year"', '"weekly"', '"monthly"'].forEach(word => {
                expect(content).toContain(word);
            });
        });
    });

    describe('Numbers typed as text', () => {
        const scriptsDir = path.join(enhancedScriptsDir, '..');
        const read = name => fs.readFileSync(path.join(scriptsDir, name), 'utf8');

        test('attachment numbers are whole numbers or nothing, never a rounded or failing coercion', () => {
            ['enhanced/edit_task.applescript', 'enhanced/edit_project.applescript', 'enhanced/edit_folder.applescript', 'enhanced/save_attachment.applescript'].forEach(name => {
                const content = read(name);
                expect(content).toContain('on isDigits(theText)');
                expect(content).toContain('if my isDigits(numberClean) and (length of numberClean) < 6 then set attachmentNumber to numberClean as integer');
                expect(content).not.toContain('set attachmentNumber to numberText as integer');
            });
        });

        test('search_tasks takes the limit only from a whole number', () => {
            const content = read('enhanced/search_tasks.applescript');
            expect(content).toContain('on isDigits(theText)');
            expect(content).toContain('if my isDigits(limitText) and (length of limitText) < 6 and limitText is not "0" then set resultLimit to limitText as integer');
            expect(content).not.toContain('item 3 of argv as integer');
        });

        test('a long run of digits is no integer: dates and repeat rules do not convert it', () => {
            ['add_task.applescript', 'enhanced/batch_add_tasks.applescript', 'enhanced/create_recurring_task.applescript',
                'enhanced/edit_task.applescript', 'enhanced/edit_project.applescript', 'enhanced/create_project.applescript'].forEach(name => {
                const content = read(name);
                expect(content).toContain('on digitsValue(digitText)');
                expect(content).toContain('set end of tokenList to my digitsValue(currentToken)');
                expect(content).not.toContain('tokenList to currentToken as integer');
            });
            ['enhanced/edit_task.applescript', 'enhanced/edit_project.applescript', 'enhanced/create_recurring_task.applescript'].forEach(name => {
                const content = read(name);
                expect(content).toContain('if my unitCode(nextText) is "" or (length of tokenText) > 6 then return invalidResult');
                expect(content).toContain('my isDigits(nextText) and (length of nextText) < 3');
                expect(content).toContain('if my isDigits(numberPart) and (length of numberPart) < 3 then return numberPart as integer');
            });
            ['enhanced/edit_project.applescript', 'enhanced/create_project.applescript'].forEach(name => {
                expect(read(name)).toContain('or (length of (item 1 of wordList)) > 6 then return {isValid:false');
            });
        });

        test('add_task refuses estimated_minutes that is not a whole number of minutes', () => {
            const content = read('add_task.applescript');
            expect(content).toContain('if not my isDigits(minutesTrimmed) or (length of minutesTrimmed) > 7 then');
            expect(content).toContain('Invalid estimated_minutes value');
            expect(content).not.toContain('set estimatedMinutes to minutesTrimmed as integer\n      on error');
        });
    });

    describe('Language and region of the Mac', () => {
        const scriptsDir = path.join(enhancedScriptsDir, '..');
        const allScripts = () => [
            ...fs.readdirSync(scriptsDir).filter(f => f.endsWith('.applescript')).map(f => path.join(scriptsDir, f)),
            ...fs.readdirSync(enhancedScriptsDir).filter(f => f.endsWith('.applescript')).map(f => path.join(enhancedScriptsDir, f))
        ];
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('numbers inside iCalendar rules are written with the digits 0 to 9', () => {
            // "as text" writes the digits of the region (Eastern Arabic digits on an Arabic Mac)
            ['create_recurring_task.applescript', 'edit_task.applescript', 'edit_project.applescript'].forEach(name => {
                const content = read(name);
                expect(content).toContain('on plainNumberText(theNumber)');
                expect(content).toContain('"BYDAY=" & my plainNumberText(ordinalFound)');
                expect(content).toContain('"BYMONTHDAY=" & my plainNumberText(dayNumber)');
                expect(content).toContain('";INTERVAL=" & my plainNumberText(intervalCount)');
                expect(content).not.toContain('"BYMONTHDAY=" & (dayNumber as text)');
            });
        });

        test('keywords are compared in lower case with a fold that does not depend on the region', () => {
            // the comparison of the system folds the letter I by the rules of the region (Turkish)
            ['add_task.applescript', 'enhanced/batch_add_tasks.applescript', 'enhanced/create_recurring_task.applescript',
                'enhanced/edit_task.applescript', 'enhanced/parse_tasks.applescript', 'enhanced/duplicate_item.applescript'].forEach(name => {
                const content = fs.readFileSync(path.join(scriptsDir, name), 'utf8');
                expect(content).toContain('on lowerText(theText)');
                expect(content).toMatch(/my lowerText\(\w+\) is (not )?"inbox"/);
            });
            const date = read('edit_task.applescript');
            expect(date).toContain('set keywordText to my lowerText(trimmed)');
            expect(date).toContain('if cleanText does not contain "=" then set cleanText to my lowerText(cleanText)');
            expect(read('edit_project.applescript')).toContain('set cleanText to my lowerText(my trimItem(valueText))');
            expect(read('create_project.applescript')).toContain('set cleanText to my lowerText(my trimItem(valueText))');
        });

        test('the check of a date from the system parser knows no language and checks the time', () => {
            ['edit_task.applescript', 'edit_project.applescript', 'create_project.applescript'].forEach(name => {
                const content = read(name);
                const handler = content.slice(content.indexOf('on fallbackDateFits'), content.indexOf('end fallbackDateFits'));
                // month names in any language: everything but digits, dots and slashes
                expect(handler).toContain('"0123456789./" does not contain (contents of aChar)');
                // a time of the text has to be the time of the result
                expect(handler).toContain('(minutes of theDate) is not (minuteText as integer)');
                expect(handler).toContain('((hours of theDate) mod 12) is not (hourNumber mod 12)');
                // a PM marker that the system does not know is dropped by the parser: such a time is refused
                expect(handler).toContain('if hasMarker and not my systemKnowsPM() then return false');
                expect(content).toContain('set testDate to date pmText');
            });
        });

        test('no script has a date written as a literal', () => {
            // a date literal is read when the script is compiled: where the system cannot read it, the whole script does not run
            allScripts().forEach(file => {
                const code = fs.readFileSync(file, 'utf8').split('\n').filter(line => !line.trim().startsWith('--')).join('\n');
                expect(code).not.toMatch(/\bdate\s+"/);
            });
        });

        test('no script has letters of one language in its code', () => {
            allScripts().forEach(file => {
                const code = fs.readFileSync(file, 'utf8').split('\n').filter(line => !line.trim().startsWith('--')).join('\n');
                expect(code).not.toContain('äöü');
                expect(code).not.toContain('ß"');
            });
        });

        test('the review interval takes only whole numbers', () => {
            ['edit_project.applescript', 'create_project.applescript'].forEach(name => {
                const content = read(name);
                expect(content).toContain('if not my isDateDigits(item 1 of wordList) or (length of (item 1 of wordList)) > 6 then return {isValid:false, stepCount:0, unitName:"", errorText:problemText}');
            });
        });
    });

    describe('Mass data: one query per property, not per item', () => {
        // Every Apple Event costs about 17 ms; a query for one property of all elements costs about 0.05 s.
        // The read scripts therefore fetch the properties of all tasks and projects at once and work on lists.
        const readScripts = [
            ['today_tasks.applescript', scriptsDir],
            ['weekly_review.applescript', scriptsDir],
            ['list_projects.applescript', enhancedScriptsDir],
            ['list_projects_for_review.applescript', enhancedScriptsDir],
            ['list_stalled_projects.applescript', enhancedScriptsDir],
            ['list_folders.applescript', enhancedScriptsDir],
            ['list_tags.applescript', enhancedScriptsDir],
            ['list_overdue_tasks.applescript', enhancedScriptsDir],
            ['list_deferred_tasks.applescript', enhancedScriptsDir],
            ['list_flagged_tasks.applescript', enhancedScriptsDir],
            ['list_due_soon.applescript', enhancedScriptsDir],
            ['list_completed_tasks.applescript', enhancedScriptsDir],
            ['list_tasks_by_date.applescript', enhancedScriptsDir],
            ['list_tasks_filtered.applescript', enhancedScriptsDir],
            ['search_tasks.applescript', enhancedScriptsDir]
        ];
        const read = (name, dir) => fs.readFileSync(path.join(dir, name), 'utf8');

        test.each(readScripts)('%s has no filter query over all tasks or projects and no hidden-task ID list', (name, dir) => {
            const content = read(name, dir);
            // "whose" and "where" are evaluated for every element, about 10 ms each
            // (a lookup of one project by its ID is allowed)
            expect(content).not.toMatch(/every flattened (task|project) (whose|where)(?! id is)/);
            expect(content).not.toMatch(/\b(tasks|flattened tasks) of aProject whose/);
            // a task is hidden through the ID of its project, not through a list of all its task IDs
            expect(content).not.toContain('hiddenFolderTaskIDs');
            expect(content).not.toContain('isHiddenItem');
        });

        test.each(readScripts)('%s does not sort with Apple Events', (name, dir) => {
            const content = read(name, dir);
            expect(content).not.toMatch(/due date of item j of/);
            expect(content).not.toMatch(/defer date of item j of/);
        });

        test('the task lists are filtered and sorted in the script (merge sort, equal dates keep their order)', () => {
            ['list_overdue_tasks.applescript', 'list_deferred_tasks.applescript', 'list_due_soon.applescript'].forEach(name => {
                const content = read(name, enhancedScriptsDir);
                expect(content).toContain('on sortPositionsAscending(positionList, keyList)');
                expect(content).toContain('on isHiddenProjectID(containerID, hiddenProjectIDList)');
                expect(content).toContain('effectively completed of every flattened task');
                expect(content).toContain('due date of every flattened task');
            });
            expect(read('list_flagged_tasks.applescript', enhancedScriptsDir)).toContain('flagged of every flattened task');
            expect(read('today_tasks.applescript', scriptsDir)).toContain('parent task of every flattened task');
        });

        test('the open tasks of all projects are counted in one pass, without the root task of a project', () => {
            ['list_projects_for_review.applescript', 'list_stalled_projects.applescript', 'weekly_review.applescript'].forEach(name => {
                const content = read(name, name === 'weekly_review.applescript' ? scriptsDir : enhancedScriptsDir);
                expect(content).toContain('my openTaskCounts(projectIDList)');
                expect(content).toContain('on openTaskCounts(projectIDList)');
                // the root task of a project has no parent task
                expect(content).toContain('id of parent task of every flattened task');
            });
            expect(read('list_stalled_projects.applescript', enhancedScriptsDir)).toContain('id of next task of every flattened project');
            expect(read('list_stalled_projects.applescript', enhancedScriptsDir)).toContain('singleton action holder of every flattened project');
        });

        test('list_projects counts the tasks directly below each project from the lists of all tasks', () => {
            const content = read('list_projects.applescript', enhancedScriptsDir);
            expect(content).toContain('id of parent task of every flattened task');
            expect(content).toContain('blocked of every flattened task');
            expect(content).toContain('defer date of every flattened task');
            expect(content).toContain('my indexOfID(activeIDText, parentID)');
            expect(content).not.toContain('countAvailable');
            // the totals are added up from the counts of the projects, not queried a second time
            expect(content).toContain('totalRemaining + (item n of remainingCounts)');
        });

        test('list_folders builds the hierarchy from the parent IDs and counts projects from the folder of each project', () => {
            const content = read('list_folders.applescript', enhancedScriptsDir);
            expect(content).toContain('id of container of every flattened folder');
            expect(content).toContain('id of folder of every flattened project');
            expect(content).not.toContain('every project of aFolder');
        });

        test('the hidden-folder lookup asks once per list, not once per folder or project', () => {
            const content = read('list_overdue_tasks.applescript', enhancedScriptsDir);
            expect(content).toContain('effectively hidden of every flattened folder');
            expect(content).toContain('id of folder of every flattened project');
        });
    });

    describe('Compact output (few tokens for the reader)', () => {
        const read = (name, dir = enhancedScriptsDir) => fs.readFileSync(path.join(dir, name), 'utf8');
        const listTools = [
            'list_completed_tasks.applescript', 'list_deferred_tasks.applescript', 'list_due_soon.applescript',
            'list_flagged_tasks.applescript', 'list_overdue_tasks.applescript', 'list_projects_for_review.applescript',
            'list_tasks_by_date.applescript', 'list_tasks_filtered.applescript', 'search_tasks.applescript'
        ];

        test.each(listTools)('%s writes dates as 2026-11-18, not as the long date text of the Mac', name => {
            const content = read(name);
            // "date string", "time string" and "as string" give long text that depends on the language and region
            expect(content).not.toMatch(/date string of/);
            expect(content).not.toMatch(/time string of/);
            expect(content).not.toMatch(/[dD]ate as string/);
            expect(content).toMatch(/my short(Date|Time|DateTime)\(/);
            expect(content).toContain('on shortDate(aDate)');
            // the digits 0 to 9 on every Mac
            expect(content).toContain('on plainNumberText(theNumber)');
        });

        test('the short date has a fixed order and two-digit month and day', () => {
            const content = read('list_overdue_tasks.applescript');
            expect(content).toContain('set monthNumber to (month of aDate) as integer');
            expect(content).toContain('text -2 thru -1 of ("0" & my plainNumberText(monthNumber))');
            expect(content).toContain('text -2 thru -1 of ("0" & my plainNumberText(day of aDate))');
            expect(read('search_tasks.applescript')).toContain('on shortDateTime(aDate)');
        });

        test('the reports have no decoration lines and no advice blocks (the counts are in the headings)', () => {
            ['list_overdue_tasks.applescript', 'list_flagged_tasks.applescript', 'list_deferred_tasks.applescript', 'list_projects.applescript'].forEach(name => {
                expect(read(name)).not.toContain('════');
            });
            expect(read('weekly_review.applescript', scriptsDir)).not.toContain('════');
            expect(read('list_overdue_tasks.applescript')).not.toContain('Recommended Actions');
            expect(read('list_flagged_tasks.applescript')).not.toContain('Summary:');
            expect(read('weekly_review.applescript', scriptsDir)).not.toContain('Action:');
        });

        test('a list that was cut at the limit says so and how to get fewer results', () => {
            expect(read('search_tasks.applescript')).toContain('Limit of " & resultLimit & " tasks reached, more tasks may match. Use a more specific search or a higher limit.');
            ['list_tasks_filtered.applescript', 'list_due_soon.applescript'].forEach(name => {
                expect(read(name)).toContain('Limit of');
            });
            expect(read('list_completed_tasks.applescript')).toContain('more not shown (limit');
            expect(read('list_tasks_by_date.applescript')).toContain('more not shown (limit');
        });
    });

    describe('Due soon', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('list_due_soon.applescript lists open tasks due between now and the end of the last day', () => {
            const content = read('list_due_soon.applescript');
            expect(content).toContain('taskDue ≥ nowDate and taskDue ≤ endDate');
            expect(content).toContain('not (item t of effCompletedList) and not (item t of effDroppedList)');
            expect(content).toContain('set hours of endDate to 23');
            expect(content).toContain('isHiddenProjectID(item t of containerIDList, hiddenProjectIDList)');
        });

        test('list_due_soon.applescript groups by tag, day or project and sorts by due date', () => {
            const content = read('list_due_soon.applescript');
            expect(content).toContain('groupMode is "tag"');
            expect(content).toContain('groupMode is "day"');
            expect(content).toContain('Unknown grouping');
            expect(content).toContain('(no tag)');
            expect(content).toContain('my sortPositionsAscending(dueIndexes, dueDateList)');
        });

        test('list_due_soon.applescript passes through the days, grouping and limit arguments', () => {
            const content = read('list_due_soon.applescript');
            expect(content).toContain('item 1 of argv');
            expect(content).toContain('item 2 of argv');
            expect(content).toContain('item 3 of argv');
        });
    });

    describe('Project filter and perspectives', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('list_tasks_filtered.applescript can be limited to one project', () => {
            const content = read('list_tasks_filtered.applescript');
            expect(content).toContain('set projectQuery to my trimItem(item 10 of argv)');
            expect(content).toContain('my resolveProject(projectQuery)');
            expect(content).toContain('projectTaskIDs does not contain taskID');
            expect(content).toContain('in the project');
        });

        test('the server passes the project to both task list tools', () => {
            const server = fs.readFileSync(path.join(__dirname, '..', 'src', 'server', 'index.js'), 'utf8');
            expect((server.match(/args\.project \|\| ''(,\n\s+String\(args\.include_projects !== false\))?\n\s+\]\);/g) || []).length).toBeGreaterThanOrEqual(2);
        });

        test('list_perspectives.applescript separates built-in and custom perspectives', () => {
            const content = read('list_perspectives.applescript');
            expect(content).toContain('set perspectiveList to every perspective');
            expect(content).toContain('(class of thePerspective) is custom perspective');
            expect(content).toContain('set end of customNames to perspectiveName');
        });
    });

    describe('Links for tasks', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('edit_task.applescript and edit_project.applescript can add to the note', () => {
            ['edit_task.applescript', 'edit_project.applescript'].forEach(file => {
                const content = read(file);
                expect(content).toContain('propertyName is "append_note"');
                expect(content).toContain('currentNote & linefeed & newValue');
                expect(content).toContain('my noteFormattingProblem(');
                expect(content).toContain('on noteFormattingProblem(theItem)');
                expect(content).toContain('The note contains attachments that would be lost.');
                expect(content).toContain('The note contains formatting that would be lost.');
                expect(content).toContain('append_note needs a text to add');
                expect(content).toContain('Valid properties: name, note, append_note,');
                expect(content).not.toContain('insert (linefeed');
            });
        });

        test('get_task.applescript and get_project.applescript show the omnifocus:// link', () => {
            expect(read('get_task.applescript')).toContain('"Link: omnifocus:///task/" & (id of targetTask)');
            expect(read('get_project.applescript')).toContain('"Link: omnifocus:///task/" & (id of targetProject)');
        });

        test('get_selected_link.applescript supports several apps without starting them or reading content', () => {
            const content = read('get_selected_link.applescript');
            ['Mail', 'Safari', 'Google Chrome', 'Finder', 'Contacts'].forEach(app => expect(content).toContain(app));
            expect(content).toContain('/usr/bin/pgrep -x');
            expect(content).toContain('run script sourceText with parameters');
            expect(content).toContain('"message://%3C"');
            expect(content).toContain('"file://"');
            expect(content).toContain('"addressbook://"');
            expect(content).toContain('Apple Notes cannot be linked');
            expect(content).toContain('Automation');
            expect(content).not.toContain('content of m');
        });
    });

    describe('Attachments in notes', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('save_attachment.applescript saves an embedded attachment to a new file and never overwrites', () => {
            const content = read('save_attachment.applescript');
            expect(content).toContain('save (file attachment attachmentNumber of (note of targetItem)) in (POSIX file destinationPath)');
            expect(content).toContain('/bin/test -e');
            expect(content).toContain('exists already. Nothing was saved.');
            expect(content).toContain('/bin/test -d');
            expect(content).toContain('starting with / or ~');
            expect(content).toContain('it is not copied');
            ['resolveTask', 'resolveProject', 'resolveFolder', 'attachmentPath', 'attachmentSizeText'].forEach(handler => {
                expect(content).toContain(`on ${handler}(`);
            });
            ['task', 'project', 'folder'].forEach(type => expect(content).toContain(`itemType is "${type}"`));
        });

        test('edit_task, edit_project and edit_folder attach, link and remove files', () => {
            ['edit_task.applescript', 'edit_project.applescript', 'edit_folder.applescript'].forEach(file => {
                const content = read(file);
                ['attach_file', 'link_file', 'remove_attachment'].forEach(property => {
                    expect(content).toContain(`propertyName is "${property}"`);
                });
                expect(content).toContain('my attachFileToNote(');
                expect(content).toContain('my removeAttachmentFromNote(');
                expect(content).toContain('on attachFileToNote(theItem, itemLabel, pathText, embedFile)');
                expect(content).toContain('on removeAttachmentFromNote(theItem, itemLabel, numberText)');
                expect(content).toContain('make new file attachment at after last character of (note of theItem) with properties {file name:theFile, embedded:embedFile}');
                expect(content).toContain('/bin/test -f');
                expect(content).toContain('starting with / or ~');
                expect(content).toContain('delete (file attachment attachmentNumber of (note of theItem))');
                expect(content).toContain('attach_file, link_file, remove_attachment');
            });
        });

        test('attachFileToNote starts a new line only when the note can be rewritten as plain text', () => {
            const content = read('edit_task.applescript');
            expect(content).toContain('if my noteFormattingProblem(theItem) is "" then');
            expect(content).toContain('set note of theItem to noteText & linefeed');
            expect(content).toContain('OmniFocus did not attach the file.');
        });

        test('get_task.applescript and get_project.applescript list the attachments and mark them in the note', () => {
            ['get_task.applescript', 'get_project.applescript'].forEach(file => {
                const content = read(file);
                expect(content).toContain('my attachmentLines(');
                expect(content).toContain('my markAttachments(noteText of noteInfo)');
                expect(content).toContain('on attachmentLines(theItem)');
                expect(content).toContain('embedded of (file attachment i of (note of theItem))');
                expect(content).toContain('set fileReference to file name of (file attachment i of (note of theItem))');
                expect(content).toContain('set thePath to POSIX path of fileReference');
                expect(content).toContain('character id 65532');
                expect(content).toContain('"Attachments: " & attachmentCount');
            });
        });
    });

    describe('Selection and view', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('get_selection.applescript reads the view and the selected rows without changing anything', () => {
            const content = read('get_selection.applescript');
            expect(content).toContain('every selected tree of (content of theWindow)');
            expect(content).toContain('every selected tree of (sidebar of theWindow)');
            expect(content).toContain('perspective name of theWindow');
            expect(content).toContain('search term of theWindow');
            expect(content).toContain('focus of theWindow');
            expect(content).toContain('OmniFocus has no open window');
            expect(content).toContain('[id:');
            expect(content).not.toMatch(/set (perspective name|search term|focus) of/);
        });

        test('set_view.applescript checks the perspective, the search term and the focus after setting them', () => {
            const content = read('set_view.applescript');
            expect(content).toContain('set perspective name of theWindow to wantedName');
            expect(content).toContain('set search term of theWindow to searchText');
            expect(content).toContain('set focus of theWindow to {focusItem}');
            expect(content).toContain('set focus of theWindow to {}');
            expect(content).toContain('Perspective not found');
            expect(content).toContain('on waitForFocus(');
            expect(content).toContain('on itemStateNote(');
            expect(content).toContain('on withEarlier(');
            expect(content).toContain('did not switch to the perspective');
            expect(content).toContain('No project or folder found');
            ['resolveProject', 'resolveFolder', 'focusItemCount'].forEach(handler => {
                expect(content).toContain(`on ${handler}(`);
            });
        });

        test('show_item.applescript opens the link of the item and checks the selection', () => {
            const content = read('show_item.applescript');
            expect(content).toContain('"omnifocus:///" & itemType & "/" & itemID');
            expect(content).toContain('open location linkText');
            expect(content).toContain('on isItemSelected(');
            expect(content).toContain('on itemStateNote(');
            expect(content).toContain('hidden of currentFolder');
            ['resolveTask', 'resolveProject', 'resolveFolder', 'resolveTag'].forEach(handler => {
                expect(content).toContain(`on ${handler}(`);
            });
            ['task', 'project', 'folder', 'tag'].forEach(type => expect(content).toContain(`itemType is "${type}"`));
        });

        test('duplicate_item.applescript checks everything first, duplicates and restores the dropped tasks', () => {
            const content = read('duplicate_item.applescript');
            ['resolveTask', 'resolveProject', 'resolveFolder', 'itemStateNote', 'restoreStates', 'copyLocation', 'projectNameTaken', 'firstOf'].forEach(handler => {
                expect(content).toContain(`on ${handler}(`);
            });
            expect(content).toContain('duplicate sourceItem to after sourceItem');
            expect(content).toContain('duplicate sourceItem to end of inbox tasks');
            expect(content).toContain('duplicate sourceItem to end of tasks of destItem');
            expect(content).toContain('duplicate sourceItem to end of projects of destItem');
            expect(content).toContain('duplicate sourceItem to end of projects');
            expect(content).toContain('mark dropped copyTask');
            expect(content).toContain('mark incomplete copyTask');
            expect(content).toContain('Nothing was duplicated.');
            expect(content).toContain('Folders cannot be duplicated');
            expect(content).toContain('sourceName & " copy"');
            // The checks come before the first change
            expect(content.indexOf('Nothing was duplicated.')).toBeLessThan(content.indexOf('set dupResult to duplicate'));
        });

        test('set_view passes the search term and a flag, so that an empty term can clear the search', () => {
            const serverContent = fs.readFileSync(path.join(__dirname, '..', 'src', 'server', 'index.js'), 'utf8');
            expect(serverContent).toContain("executeAppleScriptFile('set_view', [");
            expect(serverContent).toContain("args.search === undefined || args.search === null ? 'no' : 'yes'");
        });

        test('set_view sets grouping, sorting, filters and the smart group only to identifiers that OmniFocus offers, and checks them', () => {
            const content = read('set_view.applescript');
            ['viewOptionList', 'viewOptionValue', 'setViewOption'].forEach(handler => {
                expect(content).toContain(`on ${handler}(`);
            });
            [
                ['available grouping identifiers of (content of theWindow)', 'set selected grouping identifier of (content of theWindow) to newValue', 'selected grouping identifier of (content of theWindow)'],
                ['available sorting identifiers of (content of theWindow)', 'set selected sorting identifier of (content of theWindow) to newValue', 'selected sorting identifier of (content of theWindow)'],
                ['available task state filter identifiers of (content of theWindow)', 'set selected task state filter identifier of (content of theWindow) to newValue', 'selected task state filter identifier of (content of theWindow)'],
                ['available task duration filter identifiers of (content of theWindow)', 'set selected task duration filter identifier of (content of theWindow) to newValue', 'selected task duration filter identifier of (content of theWindow)'],
                ['available task flagged filter identifiers of (content of theWindow)', 'set selected task flagged filter identifier of (content of theWindow) to newValue', 'selected task flagged filter identifier of (content of theWindow)'],
                ['available smart group identifiers of (sidebar of theWindow)', 'set selected smart group identifier of (sidebar of theWindow) to newValue', 'selected smart group identifier of (sidebar of theWindow)']
            ].forEach(([available, setter, current]) => {
                expect(content).toContain(available);
                expect(content).toContain(setter);
                expect(content).toContain(current);
            });
            expect(content).toContain('is not available in this view. Available: ');
            expect(content).toContain('The current view has no ');
            expect(content).toContain('but OmniFocus shows ');
            // optional arguments 5 to 10, the perspective is switched first, then the options, then search and focus
            expect(content).toContain('if (count of argv) ≥ 4 + k then');
            expect(content.indexOf('set perspective name of theWindow to wantedName')).toBeLessThan(content.indexOf('my setViewOption(theWindow, optionKind, canonicalValue)'));
            expect(content.indexOf('my setViewOption(theWindow, optionKind, canonicalValue)')).toBeLessThan(content.indexOf('set search term of theWindow to searchText'));
        });

        test('get_selection shows the grouping, sorting and filters of the list', () => {
            const content = read('get_selection.applescript');
            expect(content).toContain('on viewOptionsText(');
            expect(content).toContain('"List view: "');
            ['grouping', 'sorting', 'tasks', 'duration', 'flagged', 'smart group'].forEach(label => {
                expect(content).toContain(`"${label} " & `);
            });
            expect(content).not.toMatch(/set selected [a-z ]+ identifier/);
        });

        test('set_view expands, collapses and shows notes for all rows at once and reads the numbers back', () => {
            const content = read('set_view.applescript');
            expect(content).toContain('set expanded of every descendant tree of (content of theWindow) to (expandText is "all")');
            // OmniFocus refuses the change for a row that cannot show a note, so each row is set on its own
            expect(content).toContain('set note expanded of descendant tree i of (content of theWindow) to (notesText is "true")');
            expect(content).not.toContain('set note expanded of every descendant tree');
            expect(content).toContain('on rowStateCounts(');
            expect(content).toContain('expand takes all or none');
            expect(content).toContain('show_notes takes true or false');
            // after the search and the focus, which change the rows
            expect(content.indexOf('set focus of theWindow to {focusItem}')).toBeLessThan(content.indexOf('set expanded of every descendant tree'));
        });

        test('get_selection shows how many rows the list has, expanded and with notes', () => {
            const content = read('get_selection.applescript');
            expect(content).toContain('on rowsSummary(');
            expect(content).toContain('"List rows: "');
            expect(content).toContain('expanded of every descendant tree of (content of theWindow)');
            expect(content).toContain('note expanded of every descendant tree of (content of theWindow)');
        });

        test('get_forecast reads the days of the forecast sidebar and returns to the perspective of before', () => {
            const content = read('get_forecast.applescript');
            expect(content).toContain('count of forecast day of (sidebar of theWindow)');
            expect(content).toContain('badge count of forecast day i of (sidebar of theWindow)');
            expect(content).toContain('set selected sidebar tab of theWindow to forecast tab');
            expect(content).toContain('set perspective name of theWindow to originalName');
            expect(content).toContain('OmniFocus did not show the Forecast');
            expect(content).toContain('if maxDays > 35 then set maxDays to 35');
            // the window goes back before the answer is built
            expect(content.indexOf('set perspective name of theWindow to originalName')).toBeLessThan(content.indexOf('set reportText to "📅 Forecast: "'));
            const serverContent = fs.readFileSync(path.join(__dirname, '..', 'src', 'server', 'index.js'), 'utf8');
            expect(serverContent).toContain("executeAppleScriptFile('get_forecast', [");
            expect(serverContent).toContain('String(sanitizeLimit(args.days, 14, 35))');
            expect(serverContent).toContain("args.show_notes === undefined || args.show_notes === null ? '' : String(args.show_notes === true)");
        });

        test('set_view passes the view options to the script in the order of its arguments', () => {
            const serverContent = fs.readFileSync(path.join(__dirname, '..', 'src', 'server', 'index.js'), 'utf8');
            const order = ['args.focus || \'\',', 'args.grouping || \'\',', 'args.sorting || \'\',', 'args.task_filter || \'\',', 'args.duration_filter || \'\',', 'args.flagged_filter || \'\',', 'args.smart_group || \'\''];
            let position = serverContent.indexOf("executeAppleScriptFile('set_view', [");
            order.forEach(part => {
                const next = serverContent.indexOf(part, position);
                expect(next).toBeGreaterThan(position);
                position = next;
            });
        });
    });

    describe('Synchronize and clean up', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('synchronize.applescript starts the sync and waits for it with a limit', () => {
            const content = read('synchronize.applescript');
            expect(content).toContain('synchronize default document');
            expect(content).toContain('syncing of default document');
            expect(content).toContain('if waitSeconds > 120 then set waitSeconds to 120');
            expect(content).toContain('Could not synchronize');
            expect(content).toContain('A synchronization is already running');
        });

        test('synchronize.applescript reports the last sync date and error, and can only report', () => {
            const content = read('synchronize.applescript');
            expect(content).toContain('last sync date of default document');
            expect(content).toContain('last sync error of default document');
            expect(content).toContain('Last synchronization: ');
            expect(content).toContain('Error of the last synchronization');
            // status_only starts nothing
            expect(content).toContain('if statusOnly then');
            expect(content.indexOf('if statusOnly then')).toBeLessThan(content.indexOf('synchronize default document'));
            // a finished sync with an error is not reported as success
            expect(content).toContain('finished, but OmniFocus reports an error');
        });

        test('clean_up.applescript compacts the document and reports the inbox change', () => {
            const content = read('clean_up.applescript');
            expect(content).toContain('compact default document');
            expect(content).toContain('every inbox task of default document whose completed is false');
            expect(content).not.toContain('tell default document');
            expect(content).toContain('moved into projects');
        });
    });

    describe('Folder actions', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('every script that takes a folder finds it by id too', () => {
            ['rename_folder', 'create_folder', 'create_project', 'edit_project', 'edit_folder', 'delete_folder'].forEach(name => {
                const content = read(`${name}.applescript`);
                expect(content).toContain('if queryText starts with "id:" then');
                expect(content).toContain('every flattened folder whose id is wantedID');
            });
        });

        test('list_folders.applescript shows the hierarchy with IDs, hidden folders and notes', () => {
            const content = read('list_folders.applescript');
            expect(content).toContain('on formatFolder(');
            expect(content).toContain('hidden of every flattened folder');
            expect(content).toContain('" [id:" & folderID & "]"');
        });

        test('edit_folder.applescript supports all properties and does not create a loop or a duplicate name', () => {
            const content = read('edit_folder.applescript');
            ['name', 'note', 'append_note', 'parent', 'hidden'].forEach(property => {
                expect(content).toContain(`propertyName is "${property}"`);
            });
            expect(content).toContain('move targetFolder to end of folders of newParent');
            expect(content).toContain('move targetFolder to end of folders');
            expect(content).toContain('ownIDs contains newParentID');
            expect(content).toContain('on hasFolderNamed(parentFolder, wantedName, ignoreID)');
            expect(content).toContain('my noteFormattingProblem(targetFolder)');
            expect(content).toContain('Valid properties: name, note, append_note, parent, hidden');
        });

        test('delete_folder.applescript needs a confirmation and refuses a folder with content by default', () => {
            const content = read('delete_folder.applescript');
            expect(content).toContain('if not confirmDelete then');
            expect(content).toContain('not deleteContents');
            expect(content).toContain('delete targetFolder');
            expect(content).toContain('every flattened project of targetFolder');
            expect(content).toContain('my countText(projectCount');
        });
    });

    describe('Purge tasks', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('purge_tasks.applescript only previews unless dry_run is false and confirm_delete is true', () => {
            const content = read('purge_tasks.applescript');
            expect(content).toContain('set dryRun to true');
            expect(content).toContain('((my trimItem(item 5 of argv)) is not "false")');
            expect(content).toContain('((my trimItem(item 6 of argv)) is "true")');
            expect(content).toContain('if not dryRun and not confirmDelete then');
            expect(content).toContain('Deleting is permanent and needs confirm_delete true. Nothing was deleted');
            expect(content).toContain('Preview, nothing was deleted');
            // deleting happens in one place only, after the preview branch has returned
            expect([...content.matchAll(/\bdelete theTask\b/g)].length).toBe(1);
            expect(content.indexOf('if dryRun then')).toBeLessThan(content.indexOf('delete theTask'));
            expect(content).toContain('This cannot be undone');
        });

        test('purge_tasks.applescript checks every value before anything is read', () => {
            const content = read('purge_tasks.applescript');
            expect(content).toContain('Invalid scope');
            expect(content).toContain('Invalid older_than_days');
            expect(content).toContain('Invalid limit');
            expect(content.indexOf('Invalid scope')).toBeLessThan(content.indexOf('set taskIDList to id of every flattened task'));
            expect(content).toContain('The project " & (my projectLabel(targetProject)) & " is not in the folder');
        });

        test('purge_tasks.applescript touches only completed or dropped tasks, never open ones or project root tasks', () => {
            const content = read('purge_tasks.applescript');
            expect(content).toContain('set isOpen to (not isDone and not isEffDropped)');
            expect(content).toContain('kindText is "completed" and includeCompleted');
            expect(content).toContain('kindText is "dropped" and includeDropped');
            expect(content).toContain('if inScope and not isRoot then');
            // the state is checked again right before a task is deleted
            expect(content).toContain('if kindText is "completed" and not isDone then');
            expect(content).toContain('if kindText is "dropped" and not isOwnDropped then');
            expect(content).toContain('if (id of theTask) is not theID then');
        });

        test('purge_tasks.applescript skips a task whose subtasks are not all part of the purge, and deletes subtasks first', () => {
            const content = read('purge_tasks.applescript');
            expect(content).toContain('set openBelow to {}');
            expect(content).toContain('set otherBelow to {}');
            expect(content).toContain('has open subtasks');
            expect(content).toContain('has subtasks that are not part of this purge');
            // deepest first: the sort key puts a task after all its subtasks
            expect(content).toContain('set item i of keyList to (1000 - depthValue) * 3000000000 + (2000000000 - ageSeconds)');
            expect(content).toContain('on sortPositionsAscending(positionList, keyList)');
            // a parent is skipped when one of its subtasks could not be deleted
            expect(content).toContain('set failedBelow to {}');
            expect(content).toContain('a subtask could not be deleted');
        });

        test('purge_tasks.applescript works in the time that the app allows and reports the rest', () => {
            const content = read('purge_tasks.applescript');
            expect(content).toContain('set timeBudgetSeconds to 50');
            expect(content).toContain('((current date) - startedAt) > timeBudgetSeconds');
            expect(content).toContain('left to delete. Call again to continue.');
            expect(content).toContain('Stopped after about');
            // errors are collected per task, the loop goes on
            expect(content).toContain('Not deleted (');
            // at most 200 tasks by default
            expect(content).toContain('set maxCount to 200');
        });

        test('purge_tasks.applescript counts tasks in hidden folders and the inbox, and marks them', () => {
            const content = read('purge_tasks.applescript');
            expect(content).toContain('(hidden folder)');
            expect(content).toContain('hiddenProjectIDList contains theProjectID');
            expect(content).toContain('set labelText to "Inbox"');
            // without folder and project the whole database counts, also tasks without a project
            expect(content).toContain('if scopeProjectIDList is not missing value then');
        });

        test('purge_tasks.applescript reads each property of all tasks once, not task by task', () => {
            const content = read('purge_tasks.applescript');
            ['id of every flattened task', 'completed of every flattened task', 'dropped of every flattened task',
                'effectively dropped of every flattened task', 'completion date of every flattened task',
                'dropped date of every flattened task', 'id of parent task of every flattened task',
                'id of containing project of every flattened task'].forEach(query => {
                expect(content).toContain(query);
            });
            // the only Apple Events per task are those of deleteOneTask (one task at a time, right before it is deleted)
            const runHandler = content.slice(content.indexOf('on run argv'), content.indexOf('on deleteOneTask'));
            expect(runHandler).not.toMatch(/repeat with[^\n]*\n(?:(?!end repeat)[\s\S])*tell application "OmniFocus"/);
        });
    });

    describe('Undo', () => {
        test('undo.applescript undoes and redoes only while the document can and limits the steps', () => {
            const content = fs.readFileSync(path.join(enhancedScriptsDir, 'undo.applescript'), 'utf8');
            expect(content).toContain('undo default document');
            expect(content).toContain('redo default document');
            expect(content).toContain('can undo of default document');
            expect(content).toContain('can redo of default document');
            expect(content).toContain('if stepCount > 20 then set stepCount to 20');
            expect(content).toContain('Nothing to undo');
            expect(content).not.toContain('tell default document');
        });
    });

    describe('Text to tasks', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('parse_tasks.applescript lets OmniFocus parse every line as one task', () => {
            const content = read('parse_tasks.applescript');
            expect(content).toContain('parse tasks into default document with transport text lineText as single task true');
            // OmniFocus makes one task out of a multi-line text, so the lines are split in the script
            expect(content).toContain('on splitIntoLines(sourceText)');
            expect(content).toContain('repeat with aLine in (paragraphs of sourceText)');
        });

        test('parse_tasks.applescript checks everything before it creates tasks', () => {
            const content = read('parse_tasks.applescript');
            expect(content).toContain('Give either text or from_note');
            expect(content).toContain('Use either text or from_note, not both');
            expect(content).toContain('Use either project or parent_task, not both');
            expect(content).toContain('clear_note only works together with from_note');
            expect(content).toContain('has no note. Nothing was created.');
            const firstParse = content.indexOf('parse tasks into default document');
            expect(content.indexOf('my resolveProject(projectQuery)')).toBeLessThan(firstParse);
            expect(content.indexOf('my resolveTask(parentQuery)')).toBeLessThan(firstParse);
        });

        test('parse_tasks.applescript builds the hierarchy from the indentation', () => {
            const content = read('parse_tasks.applescript');
            expect(content).toContain('set indentWidth to indentWidth + 4');
            expect(content).toContain('set end of levelList to (count of openWidths) - 1');
            expect(content).toContain('move newTask to end of tasks of levelParent');
            expect(content).toContain('move newTask to end of tasks of destinationProject');
            expect(content).toContain('move newTask to end of tasks of destinationTask');
        });

        test('parse_tasks.applescript removes list markers and can use the note of a task', () => {
            const content = read('parse_tasks.applescript');
            expect(content).toContain('cleanLine starts with "- " or cleanLine starts with "* " or cleanLine starts with "• "');
            expect(content).toContain('set sourceText to (note of sourceTask) as text');
            expect(content).toContain('set note of sourceTask to ""');
        });
    });

    describe('Project contents', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('get_project.applescript lists the tasks recursively, including blocked and deferred ones', () => {
            const content = read('get_project.applescript');
            expect(content).toContain('on taskTree(');
            expect(content).toContain('my taskTree(theTask, depth + 1');
            expect(content).toContain('effective defer date');
            expect(content).toContain('blocked of theTask');
            expect(content).toContain('number of tasks of theTask');
        });

        test('get_project.applescript hides completed and dropped tasks unless asked and has a limit', () => {
            const content = read('get_project.applescript');
            expect(content).toContain('(isDone or isDropped) and not includeDone');
            expect(content).toContain('Limit of');
            expect(content).toContain('item 3 of argv');
        });

        test('get_project.applescript finds projects in all folders and by id', () => {
            const content = read('get_project.applescript');
            expect(content).toContain('on resolveProject(');
            expect(content).toContain('every flattened project whose id is wantedID');
        });
    });

    describe('Action groups and moving tasks', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('edit_task.applescript moves a task below another open task', () => {
            const content = read('edit_task.applescript');
            expect(content).toContain('propertyName is "parent_task"');
            expect(content).toContain('my resolveTask(newValue)');
            expect(content).toContain('move targetTask to end of tasks of newParent');
            expect(content).toContain('Nothing was moved.');
        });

        test('edit_task.applescript refuses to move a task below itself or its own subtasks', () => {
            const content = read('edit_task.applescript');
            expect(content).toContain('set walkTask to parent task of walkTask');
            expect(content).toContain('A task cannot be moved below itself or one of its own subtasks');
        });

        test('edit_task.applescript sets sequential and completed by children with a validated flag', () => {
            const content = read('edit_task.applescript');
            expect(content).toContain('propertyName is "sequential"');
            expect(content).toContain('set sequential of targetTask to (flagValue is "true")');
            expect(content).toContain('propertyName is "complete_with_last_item"');
            expect(content).toContain('set completed by children of targetTask to (flagValue is "true")');
            expect(content).toContain('Invalid value for sequential');
            expect(content).toContain('on parseFlag(');
            expect(content).toContain('Valid properties: name, note, append_note, due_date, defer_date, planned_date, flagged, project, estimated_minutes, tags, primary_tag, repeat, repeat_based_on, repeat_catch_up, parent_task, sequential, complete_with_last_item');
        });

        test('get_task and get_project show how the subtasks of a task behave', () => {
            const task = read('get_task.applescript');
            expect(task).toContain('one after another');
            expect(task).toContain('completes with the last subtask');
            const project = read('get_project.applescript');
            expect(project).toContain('", sequential"');
        });

        test('the server offers the new edit_task properties', () => {
            const server = fs.readFileSync(path.join(__dirname, '..', 'src', 'server', 'index.js'), 'utf8');
            expect(server).toContain("'repeat', 'repeat_based_on', 'repeat_catch_up', 'parent_task', 'sequential', 'complete_with_last_item'");
        });
    });

    describe('Inherited dates, next dates and tag counts', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('get_task shows the dates a task gets from its surroundings only when they differ from its own', () => {
            const task = read('get_task.applescript');
            expect(task).toContain('effective defer date of targetTask');
            expect(task).toContain('effective planned date of targetTask');
            expect(task).toContain('effective due date of targetTask');
            expect(task).toContain('effectiveDueValue is not dueValue');
            expect(task).toContain('effectiveDeferValue is not deferValue');
            expect(task).toContain('effectivePlannedValue is not ownPlannedValue');
            expect(task).toContain('"Effective due: "');
            expect(task).toContain('" (inherited)"');
        });

        test('get_task shows the dates of the next occurrence only for a repeating task', () => {
            const task = read('get_task.applescript');
            expect(task).toContain('next due date of targetTask');
            expect(task).toContain('next defer date of targetTask');
            expect(task).toContain('next planned date of targetTask');
            expect(task).toContain('"Next occurrence: "');
            // inside the branch of the "Repeats:" line
            expect(task.indexOf('"Repeats: "')).toBeLessThan(task.indexOf('next due date of targetTask'));
        });

        test('get_task shows how many subtasks are available', () => {
            const task = read('get_task.applescript');
            expect(task).toContain('number of available tasks of targetTask');
            expect(task).toContain('"Available subtasks: "');
            // the line "Subtasks: N (...)" keeps its form
            expect(task).toContain('"Subtasks: " & subtaskCount');
        });

        test('list_tasks_by_tag lists the open projects that carry the tag in a block of their own', () => {
            const script = read('list_tasks_filtered.applescript');
            // the tags of a project sit on its root task (the task ID equals the project ID)
            expect(script).toContain('if includeProjects and (count of tagObjects) > 0 and not availableOnly and maxMinutes = 0 and projectFilterLabel is "" then');
            expect(script).toContain('if rootID is (item i of taskProjectIDList) and (seenProjectIDs does not contain rootID) then');
            // only open projects (active or on hold), not those below hidden folders, with the folder filter
            expect(script).toContain('(item projectIndex of projectActiveList) or (item projectIndex of projectOnHoldList)');
            expect(script).toContain('set projectHeading to "📂 Projects tagged');
            // projects alone are a result, the block comes after the tasks
            expect(script).toContain('if matchCount = 0 and projectCount = 0 then');
            expect(script.indexOf('set projectHeading to')).toBeGreaterThan(script.indexOf('Limit of '));
            // the tasks keep leaving out the root task
            expect(script).toContain('A project without tasks is returned like a task and has the same id');
            // the parameter is the 11th argument and defaults to off for the other tools
            expect(script).toContain('set includeProjects to false');
            expect(script).toContain('if (count of argv) > 10 then set includeProjects to (item 11 of argv is "true")');
            const server = fs.readFileSync(path.join(__dirname, '..', 'src', 'server', 'index.js'), 'utf8');
            expect(server).toContain("String(args.include_projects !== false)");
            expect(server).toContain('include_projects: {');
            expect(server).toContain('a project that carries the tag counts as one task');
        });

        test('format_note styles ranges of the note and checks the position before anything is changed', () => {
            const script = read('format_note.applescript');
            // bold is the weight of the font set on the style (the command bold does nothing on italic text), on each run
            // of text of its own (a style on a range over several runs replaces their other styles), italic and underline
            // are commands of OmniFocus, on the whole note or on ranges of characters
            expect(script).toContain('set runLengths to {}');
            expect(script).toContain('set runTexts to text of every attribute run of (note of targetItem)');
            expect(script).not.toContain('length of (text of attribute run');
            expect(script).toContain('if runSum is not (length of noteText) then');
            expect(script).toContain('set value of attribute "font-weight" of (style of attribute run r of (note of targetItem)) to 12');
            expect(script).toContain('clear (attribute "font-weight" of (style of attribute run r of (note of targetItem)))');
            expect(script).toContain('set value of attribute "font-weight" of (style of (characters partStart thru partEnd of (note of targetItem))) to 12');
            expect(script).toContain('clear (attribute "font-weight" of (style of (characters partStart thru partEnd of (note of targetItem))))');
            expect(script).toContain('bold (characters partStart thru partEnd of (note of targetItem))');
            expect(script).toContain('unbold (characters rangeStart thru rangeEnd of (note of targetItem))');
            expect(script).not.toContain('style of (note of targetItem)');
            ['italicize (note of targetItem)', 'unitalicize (note of targetItem)', 'underline (note of targetItem)', 'ununderline (note of targetItem)',
                'italicize (characters rangeStart thru rangeEnd of (note of targetItem))', 'unitalicize (characters rangeStart thru rangeEnd of (note of targetItem))',
                'underline (characters rangeStart thru rangeEnd of (note of targetItem))', 'ununderline (characters rangeStart thru rangeEnd of (note of targetItem))'].forEach(command => {
                expect(script).toContain(command);
            });
            // task, project and folder like save_attachment, and the root task of a project is refused
            expect(script).toContain('else if itemType is "folder" then');
            expect(script).toContain('is a project, not a task: ');
            // text is searched with case, ranges come from positions and are compared with the note before the first change
            expect(script).toContain('considering case');
            expect(script).toContain('set foundAt to offset of searchText in remainderText');
            expect(script).toContain('set actualText to ((characters rangeStart thru rangeEnd of (note of targetItem)) as text)');
            expect(script).toContain('could not be matched safely');
            expect(script.indexOf('could not be matched safely')).toBeLessThan(script.indexOf('set value of attribute "font-weight"'));
            // whole numbers only, a style is true, false or nothing
            expect(script).toContain('if my isDigits(occurrenceText) and (length of occurrenceText) < 6 then');
            expect(script).toContain('At least one of bold, italic and underline is required');
            // the number is turned into text before it is put in front of a text
            expect(script).toContain('set placeText to ((count of rangeStarts) as text) & " place(s) of');
        });

        test('format_note is a tool and passes the styles only when they are set', () => {
            const server = fs.readFileSync(path.join(__dirname, '..', 'src', 'server', 'index.js'), 'utf8');
            expect(server).toContain("name: 'format_note'");
            expect(server).toContain("case 'format_note':");
            expect(server).toContain("args.bold === undefined ? '' : String(args.bold === true)");
            expect(server).toContain("args.underline === undefined ? '' : String(args.underline === true)");
            expect(server).toContain("At least one of bold, italic and underline is required (true sets the style, false removes it).");
            expect(server).toContain('**bold**, *italic* and __underlined__');
        });

        test('get_task and get_project show bold, italic and underline of the note as markers', () => {
            ['get_task.applescript', 'get_project.applescript'].forEach(file => {
                const script = read(file);
                expect(script).toContain('on styledNote(theItem)');
                expect(script).toContain('on splitRunSpace(runText)');
                expect(script).toContain('set noteInfo to my styledNote(');
                expect(script).toContain('Note styles: **bold**, *italic*, __underlined__');
                // the styles come from the font name and underline of the runs, a link is left as it is
                expect(script).toContain('set isBold to (fontName contains "bold") or (fontName contains "black") or (fontName contains "heavy")');
                expect(script).toContain('set isItalic to (fontName contains "italic") or (fontName contains "oblique")');
                expect(script).toContain('if runText contains "://" then');
                // one query for all runs, one at a time as the fallback
                expect(script).toContain('set runFonts to font of every attribute run of (note of theItem)');
                expect(script).toContain('set end of runFonts to (font of attribute run i of (note of theItem))');
                // the runs must make up the note, otherwise the plain text is shown
                expect(script).toContain('if joinedText is not plainText then return {noteText:plainText, styled:false}');
                // attachments are marked afterwards, the shortening comes last
                expect(script.indexOf('my markAttachments(noteText of noteInfo)')).toBeGreaterThan(script.indexOf('set noteInfo to my styledNote('));
            });
        });

        test('get_task names a task with a future start "deferred" and keeps "blocked" for the others', () => {
            const task = read('get_task.applescript');
            // same word as get_project, taken from the effective defer date (own or inherited)
            expect(task).toContain('set stateDeferValue to effective defer date of targetTask');
            expect(task).toContain('stateDeferValue > (current date)');
            expect(task).toContain('set stateText to stateText & ", deferred"');
            // "blocked" only when the task is not deferred
            expect(task.indexOf('", deferred"')).toBeLessThan(task.indexOf('", blocked"'));
            expect(task).toContain('if blocked of targetTask then set stateText to stateText & ", blocked"');
        });

        test('get_task treats the root task of a project as no task', () => {
            const task = read('get_task.applescript');
            // the project IDs come from one query for all projects and are compared with case
            expect(task).toContain('set projectIDs to id of every flattened project');
            expect(task).toContain('considering case');
            // an ID of a project points to get_project and finds nothing else
            expect(task).toContain('is a project, not a task: ');
            expect(task).toContain('Use get_project with project \\"id:');
            expect(task.indexOf('is a project, not a task: ')).toBeLessThan(task.indexOf('set foundTasks to every flattened task whose id is wantedID'));
            // the name search leaves the root tasks out and says so when only projects match
            expect(task).toContain('set skippedProjects to skippedProjects + 1');
            expect(task).toContain('project(s) match this name. Use get_project to see a project.');
            // the hit list and the IDs come from the same bulk queries
            expect(task).toContain('set allNames to name of every flattened task');
            expect(task).toContain('set allIDs to id of every flattened task');
        });

        test('get_task finds a task by name among open, completed and dropped tasks', () => {
            const task = read('get_task.applescript');
            // no condition on the state in a query: the comparison is done in the script, so case does not matter
            // and no special character or emoji of the name reaches a query
            expect(task).not.toContain('whose name contains');
            expect(task).not.toContain('completed is false');
            expect(task).toContain('set allCompleted to effectively completed of every flattened task');
            expect(task).toContain('set allDropped to effectively dropped of every flattened task');
            expect(task).toContain('if nameText contains searchTerm then');
            expect(task).toContain('if nameText is searchTerm then set end of exactIdx to i');
            // the name is searched without the spaces around it and without the 📝 that the first line of the answer shows
            expect(task).toContain('set searchTerm to my cleanTerm(item 1 of argv)');
            expect(task).toContain('if cleaned starts with "📝" then');
            expect(task).toContain('set whiteChars to {" ", tab, return, linefeed}');
        });

        test('get_task lists all hits with ID, state and project, and lets an exact name win', () => {
            const task = read('get_task.applescript');
            // open tasks come first, then completed ones (also a dropped one inside a completed one), then dropped ones
            expect(task).toContain('repeat with wantedRank from 1 to 3');
            expect(task).toContain('if completedValue then return 2');
            expect(task).toContain('if droppedValue then return 3');
            expect(task).toContain('"🔍 Multiple tasks found ("');
            expect(task).toContain('" open, " & (item 2 of stateCounts) & " completed, " & (item 3 of stateCounts) & " dropped):"');
            expect(task).toContain('"• " & (item i of allNames) & " [id:" & (item i of allIDs) & "] (" & my stateWord(rankValue) & ", " & my locationOfTask(item i of allIDs) & ")"');
            expect(task).toContain('"project " & my projectLabel(hitProject)');
            expect(task).toContain('set locationText to "Inbox"');
            // a task with exactly this name wins over tasks that only contain the text; the others are named
            expect(task).toContain('if (count of exactIdx) > 0 then');
            expect(task).toContain('more task(s) contain this text. search_tasks lists them.');
            // several tasks with the same name and one open one (history of a repeating task): the open one is shown, the others named
            expect(task).toContain('if isExact and (item 1 of stateCounts) = 1 then');
            expect(task).toContain('other task(s) have the same name:');
            expect(task).toContain('if pickNote is not "" then set taskInfo to taskInfo & return & pickNote');
            // the list is limited and says how many hits it leaves out
            expect(task).toContain('my hitLines(orderedIdx, 1, 20, allNames, allIDs, allCompleted, allDropped)');
            expect(task).toContain('"… and " & hiddenCount & " more"');
            // the ID lookup is not changed
            expect(task).toContain('set foundTasks to every flattened task whose id is wantedID');
        });

        test('the tools that change a task refuse the ID of a project and leave project root tasks out of the name search', () => {
            ['complete_task.applescript', 'enhanced/drop_task.applescript', 'enhanced/edit_task.applescript',
                'enhanced/add_tag_to_task.applescript', 'enhanced/remove_tag_from_task.applescript',
                'enhanced/reopen_task.applescript'].forEach(file => {
                const script = file.startsWith('enhanced/') ? read(file.slice('enhanced/'.length)) : fs.readFileSync(path.join(scriptsDir, file), 'utf8');
                expect(script).toContain('set projectIDs to id of every flattened project');
                expect(script).toContain('considering case');
                expect(script).toContain('is a project, not a task: ');
                expect(script).toContain('Nothing was changed. Projects are handled by the project tools (get_project, edit_project).');
                expect(script).toContain('set skippedProjects to skippedProjects + 1');
                expect(script).toContain('project(s) match this name.');
                // the refusal comes before the task is looked up by its ID
                expect(script.indexOf('is a project, not a task: ')).toBeLessThan(script.indexOf('set foundTasks to every flattened task whose id is wantedID'));
            });
        });

        test('the tools that resolve a task for another tool refuse the ID of a project and leave project root tasks out of the name search', () => {
            ['add_task.applescript', 'parse_tasks.applescript', 'edit_task.applescript', 'show_item.applescript',
                'save_attachment.applescript', 'duplicate_item.applescript'].forEach(file => {
                const script = file === 'add_task.applescript' ? fs.readFileSync(path.join(scriptsDir, file), 'utf8') : read(file);
                expect(script).toContain('on projectNameForID(wantedID)');
                expect(script).toContain('on withoutProjectRoots(taskList, searchText)');
                expect(script).toContain('set nameMatches to my withoutProjectRoots(nameMatches, searchText)');
                expect(script).toContain('set projectNameText to my projectNameForID(wantedID)');
                expect(script).toContain('is a project, not a task: ');
                // the refusal comes before the single ID hit is returned as the task
                expect(script.indexOf('set projectNameText to my projectNameForID(wantedID)')).toBeLessThan(script.indexOf('return {foundTask:item 1 of idMatches, errorText:""}'));
            });
        });

        test('the list and search tools leave the root task of a project out', () => {
            const lists = ['list_overdue_tasks.applescript', 'list_flagged_tasks.applescript', 'list_deferred_tasks.applescript', 'list_due_soon.applescript'];
            lists.forEach(file => {
                const script = read(file);
                expect(script).toContain('set taskIDList to id of every flattened task');
                expect(script).toContain('((item t of taskIDList) is not (item t of containerIDList))');
            });
            ['today_tasks.applescript', 'weekly_review.applescript'].forEach(file => {
                const script = fs.readFileSync(path.join(scriptsDir, file), 'utf8');
                expect(script).toContain('set taskIDList to id of every flattened task');
                expect(script).toContain('((item t of taskIDList) is not (item t of containerIDList))');
            });
            expect(read('list_completed_tasks.applescript')).toContain('((item i of taskIDList) is not (item i of taskProjectIDList))');
            const search = read('search_tasks.applescript');
            expect(search).toContain('set projectIDList to id of containing project of every flattened task');
            expect(search).toContain('((item i of taskIDList) is (item i of projectIDList)) then set taskMatches to false');
        });

        test('every new read is guarded, so an OmniFocus without the property does not break the tool', () => {
            const task = read('get_task.applescript');
            ['effective due date of targetTask', 'effective defer date of targetTask', 'next due date of targetTask', 'number of available tasks of targetTask'].forEach(term => {
                const before = task.slice(0, task.indexOf(term));
                const lastTry = before.lastIndexOf('try\n');
                const lastEnd = before.lastIndexOf('end try');
                expect(lastTry).toBeGreaterThan(lastEnd);
            });
        });

        test('list_tags takes the counts of OmniFocus with one query each and keeps the old count as fallback', () => {
            const tags = read('list_tags.applescript');
            expect(tags).toContain('set tagRemainingCounts to remaining task count of every flattened tag');
            expect(tags).toContain('set tagAvailableCounts to available task count of every flattened tag');
            expect(tags).toContain('" remaining, "');
            expect(tags).toContain('" available)"');
            expect(tags).toContain('if includeCounts and not hasOmniFocusCounts then');
            expect(tags).toContain('set taskTagIDLists to id of tags of every flattened task');
            expect(tags).toContain('" tasks)"');
        });

        test('the server describes the new output', () => {
            const server = fs.readFileSync(path.join(__dirname, '..', 'src', 'server', 'index.js'), 'utf8');
            expect(server).toContain('the remaining and the available tasks as OmniFocus counts them');
            expect(server).toContain('the dates of the next occurrence of a repeating task');
        });

        test('get_project shows the next occurrence, the available tasks and the default project for single actions, each guarded', () => {
            const project = fs.readFileSync(path.join(enhancedScriptsDir, 'get_project.applescript'), 'utf8');
            expect(project).toContain('next due date of targetProject');
            expect(project).toContain('next defer date of targetProject');
            expect(project).toContain('next planned date of targetProject');
            expect(project).toContain('"Next occurrence: "');
            expect(project.indexOf('"Repeats: "')).toBeLessThan(project.indexOf('next due date of targetProject'));
            expect(project).toContain('number of available tasks of targetProject');
            expect(project).toContain('available at top level');
            expect(project).toContain('default singleton action holder of targetProject');
            expect(project).toContain('default project for single actions');
            ['next due date of targetProject', 'number of available tasks of targetProject', 'default singleton action holder of targetProject'].forEach(term => {
                const before = project.slice(0, project.indexOf(term));
                expect(before.lastIndexOf('try\n')).toBeGreaterThan(before.lastIndexOf('end try'));
            });
        });

        test('edit_project sets the default project for single actions, tells which project lost the flag and checks the result', () => {
            const edit = fs.readFileSync(path.join(enhancedScriptsDir, 'edit_project.applescript'), 'utf8');
            expect(edit).toContain('propertyName is "default_single_action_list"');
            expect(edit).toContain('Invalid value for default_single_action_list');
            expect(edit).toContain('Nothing was changed.');
            // the previous holder is found with one query for each property of all projects, not with a filter query
            expect(edit).toContain('set holderFlagList to default singleton action holder of every flattened project');
            expect(edit).not.toMatch(/flattened projects? whose default singleton action holder/);
            expect(edit).toContain('set default singleton action holder of targetProject to true');
            expect(edit).toContain('set default singleton action holder of targetProject to false');
            expect(edit).toContain('OmniFocus did not make the project the default for single actions');
            expect(edit).toContain('it is now a single action list');
            expect(edit).toContain('no longer the default: ');
        });

        test('the server offers default_single_action_list for edit_project and describes the new get_project output', () => {
            const server = fs.readFileSync(path.join(__dirname, '..', 'src', 'server', 'index.js'), 'utf8');
            expect(server).toContain("'floating_time_zone', 'default_single_action_list', 'tags', 'primary_tag'");
            expect(server).toContain('For default_single_action_list: ');
            expect(server).toContain('also the available tasks at top level');
        });
    });

    describe('Task repetition', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('edit_task.applescript sets, changes and removes the repetition', () => {
            const content = read('edit_task.applescript');
            expect(content).toContain('propertyName is "repeat"');
            expect(content).toContain('my setRepetition(targetTask, "task", originalName, newValue)');
            expect(content).toContain('propertyName is "repeat_based_on"');
            expect(content).toContain('my changeRepetition(targetTask, "task", originalName, "based_on", newValue)');
            expect(content).toContain('propertyName is "repeat_catch_up"');
            expect(content).toContain('my changeRepetition(targetTask, "task", originalName, "catch_up", newValue)');
            expect(content).toContain('set repetition rule of theItem to missing value');
            expect(content).toContain('Valid properties: name, note, append_note, due_date, defer_date, planned_date, flagged, project, estimated_minutes, tags, primary_tag, repeat, repeat_based_on, repeat_catch_up');
        });

        test('edit_project.applescript repeats projects as well', () => {
            const content = read('edit_project.applescript');
            expect(content).toContain('my setRepetition(targetProject, "project", originalLabel, newValue)');
            expect(content).toContain('my changeRepetition(targetProject, "project", originalLabel, "based_on", newValue)');
            expect(content).toContain('my changeRepetition(targetProject, "project", originalLabel, "catch_up", newValue)');
        });

        test('setRepetition refuses an item without a date and rejects unknown rules', () => {
            const content = read('edit_task.applescript');
            expect(content).toContain('needs a due, defer or planned date');
            expect(content).toContain('Invalid repeat');
            expect(content).toContain('on parseRepeatRule(');
            expect(content).toContain('does not understand the repeat rule');
            expect(content).toContain('Catching up only works for a fixed schedule');
        });

        test('parseRepeatRule understands weekdays, days of the month and iCalendar rules', () => {
            const content = read('edit_task.applescript');
            ['"BYDAY="', '"BYMONTHDAY=-1"', '"BYMONTHDAY="', 'on weekdayCode(', 'on unitCode(', 'on ordinalValue(', 'on upperText(',
                '"MO", "TU", "WE", "TH", "FR"', 'starts with "FREQ="', 'starts with "RRULE:"'].forEach(part => {
                expect(content).toContain(part);
            });
        });

        test('describeRecurrence puts weekdays and days of the month into words', () => {
            const content = read('get_task.applescript');
            ['every weekday', ' on the last day', ' on day ', ' on the ', 'on weekdayName(', 'on ordinalName(', 'on joinNames('].forEach(part => {
                expect(content).toContain(part);
            });
        });

        test('get_task and get_project show how an item repeats', () => {
            const task = read('get_task.applescript');
            expect(task).toContain('my repetitionText(targetTask)');
            expect(task).toContain('"Repeats: "');
            expect(task).toContain('repetition rule of theItem');
            expect(task).toContain('repetition schedule of theRule');
            const project = read('get_project.applescript');
            expect(project).toContain('my repetitionText(targetProject)');
            expect(project).toContain('"Repeats: "');
        });
    });

    describe('Task lifecycle tools', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('reopen_task.applescript reopens completed and dropped tasks and checks the result', () => {
            const content = read('reopen_task.applescript');
            expect(content).toContain('mark incomplete');
            expect(content).toContain('completed is true');
            expect(content).toContain('dropped is true');
            expect(content).toContain('Please be more specific or use id:<id>');
            expect(content).toContain('Task is already open');
        });

        test('edit_task.applescript supports the planned date', () => {
            const content = read('edit_task.applescript');
            expect(content).toContain('propertyName is "planned_date"');
            expect(content).toContain('set planned date of targetTask');
        });

        test('add_task.applescript reads planned_date and parent_task and never combines parent_task with a project', () => {
            const content = fs.readFileSync(path.join(scriptsDir, 'add_task.applescript'), 'utf8');
            expect(content).toContain('item 9 of argv');
            expect(content).toContain('item 10 of argv');
            expect(content).toContain('set planned date of newTask');
            expect(content).toContain('at end of tasks of parentTaskObject');
            expect(content).toContain('Use either project or parent_task, not both');
        });
    });

    describe('Tag hierarchy tools', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');
        const tagScripts = [
            path.join('..', 'add_task.applescript'),
            'batch_add_tasks.applescript',
            'edit_task.applescript',
            'add_tag_to_task.applescript',
            'remove_tag_from_task.applescript',
            'create_tag.applescript',
            'edit_tag.applescript',
            'list_tasks_filtered.applescript'
        ];

        test('tags are looked up at every level, not only at top level', () => {
            tagScripts.forEach(script => {
                const content = read(script);
                expect(content).toContain('on resolveTag(queryText, allowPartial)');
                expect(content).toContain('every flattened tag');
                // The old lookup only saw top-level tags and created duplicates of nested ones
                expect(content).not.toContain('every tag whose name is');
            });
        });

        test('scripts that attach tags create missing tags only through findOrCreateTag', () => {
            ['add_task.applescript', 'batch_add_tasks.applescript', 'edit_task.applescript', 'add_tag_to_task.applescript'].forEach(script => {
                const content = script === 'add_task.applescript'
                    ? fs.readFileSync(path.join(enhancedScriptsDir, '..', script), 'utf8')
                    : read(script);
                expect(content).toContain('my findOrCreateTag(');
                expect(content).not.toContain('make new tag with properties {name:tagName}');
            });
        });

        test('create_tag.applescript checks for duplicates below the same parent', () => {
            const content = read('create_tag.applescript');
            expect(content).toContain('my hasTagNamed(parentTag, tagName');
            expect(content).toContain('Parent tag not found');
        });

        test('edit_tag.applescript supports all properties', () => {
            const content = read('edit_tag.applescript');
            ['name', 'note', 'parent', 'hidden', 'allows_next_action'].forEach(property => {
                expect(content).toContain(`propertyName is "${property}"`);
            });
            expect(content).toContain('set hidden of targetTag');
            expect(content).toContain('set allows next action of targetTag');
        });

        test('edit_tag.applescript sets and removes the location with checked values', () => {
            const content = read('edit_tag.applescript');
            expect(content).toContain('propertyName is "location"');
            expect(content).toContain('set location of targetTag to missing value');
            expect(content).toContain('set location of aTag to locationRecord');
            ['name:locName', 'latitude:latValue', 'longitude:lonValue', 'altitude:altValue', 'radius:radiusValue', 'trigger:notify when arriving', 'trigger:notify when leaving'].forEach(term => {
                expect(content).toContain(term);
            });
            expect(content).toContain('Latitude must be between -90 and 90');
            expect(content).toContain('Longitude must be between -180 and 180');
            expect(content).toContain('The radius must be between 0.1 and 10 kilometers');
            expect(content).toContain('A location needs a latitude and a longitude');
            expect(content).toContain('Valid properties: name, note, parent, hidden, allows_next_action, location');
            // numbers are parsed and written by the script, not by the language setting of the Mac
            expect(content).toContain('on parseDecimal(valueText)');
            expect(content).toContain('on formatDecimal(numberValue)');
        });

        test('edit_tag.applescript does not move a tag below itself and resolves names exactly', () => {
            const content = read('edit_tag.applescript');
            expect(content).toContain('ownIDs contains newParentID');
            expect(content).toContain('my resolveTag(tagText, false)');
        });

        test('list_tags.applescript shows IDs, hidden tags and tags without next actions', () => {
            const content = read('list_tags.applescript');
            expect(content).toContain('hidden of every flattened tag');
            expect(content).toContain('allows next action of every flattened tag');
            expect(content).toContain('⏸ hidden');
            expect(content).toContain('🚫 no next action');
        });

        test('list_tags.applescript shows the location of a tag', () => {
            const content = read('list_tags.applescript');
            expect(content).toContain('location of every flattened tag');
            expect(content).toContain('my locationTextOfTagID(item i of tagIDList)');
            expect(content).toContain('my tagLocationText(item 1 of tagMatches)');
            expect(content).toContain('📍');
            expect(content).toContain('on singleLineText(theText)');
        });
    });

    describe('Tool-Script Coverage', () => {
        const serverPath = path.join(__dirname, '..', 'src', 'server', 'index.js');

        test('every tool in server index.js has a matching .applescript file', () => {
            const serverContent = fs.readFileSync(serverPath, 'utf8');

            // Extract tool names from the const tools = [...] block
            const toolsBlockMatch = serverContent.match(/const tools\s*=\s*\[(.*?)\n\];/s);
            expect(toolsBlockMatch).not.toBeNull();
            const toolsSection = toolsBlockMatch[1];
            const toolNames = [...toolsSection.matchAll(/\bname:\s*'([^']+)'/g)].map(m => m[1]);

            expect(toolNames.length).toBeGreaterThan(0);

            // Tools that share one script are mapped here
            const sharedScripts = {
                list_available_tasks: 'list_tasks_filtered',
                list_tasks_by_tag: 'list_tasks_filtered'
            };

            toolNames.forEach(toolName => {
                const scriptName = sharedScripts[toolName] || toolName;
                const enhancedPath = path.join(enhancedScriptsDir, `${scriptName}.applescript`);
                const corePath = path.join(scriptsDir, `${scriptName}.applescript`);
                const found = fs.existsSync(enhancedPath) || fs.existsSync(corePath);
                expect(found).toBe(true);
            });
        });

        test('every tool name in the tools array has a case in executeTool switch', () => {
            const serverContent = fs.readFileSync(serverPath, 'utf8');

            // Extract tool names from the const tools = [...] block
            const toolsBlockMatch = serverContent.match(/const tools\s*=\s*\[(.*?)\n\];/s);
            expect(toolsBlockMatch).not.toBeNull();
            const toolsSection = toolsBlockMatch[1];
            const toolNames = [...toolsSection.matchAll(/\bname:\s*'([^']+)'/g)].map(m => m[1]);

            // Extract case labels from the switch(name) in executeTool
            const caseNames = [...serverContent.matchAll(/case\s+'([^']+)':/g)].map(m => m[1]);

            toolNames.forEach(toolName => {
                expect(caseNames).toContain(toolName);
            });
        });
    });
});
