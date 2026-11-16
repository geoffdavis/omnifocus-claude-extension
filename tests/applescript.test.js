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
                'edit_tag.applescript',
                'reopen_task.applescript',
                'get_project.applescript',
                'list_due_soon.applescript',
                'parse_tasks.applescript',
                'list_perspectives.applescript'
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

    describe('Recurring Task Recurrence Strings', () => {
        const scriptPath = path.join(enhancedScriptsDir, 'create_recurring_task.applescript');

        test('uses repetition rule with ICS recurrence strings instead of repetition interval', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            // Should set repetition rule on the task with a recurrence string
            expect(content).toMatch(/set repetition rule of newTask to \{repetition method:.+, recurrence:/);
            // Should NOT use the old broken approach
            expect(content).not.toContain('repetition interval');
            expect(content).not.toContain('{unit:');
        });

        test('buildRecurrenceString handles all standard repeat rules', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toMatch(/return "FREQ=DAILY"/);
            expect(content).toMatch(/return "FREQ=WEEKLY"/);
            expect(content).toMatch(/return "FREQ=MONTHLY"/);
            expect(content).toMatch(/return "FREQ=YEARLY"/);
        });

        test('buildRecurrenceString supports custom intervals with INTERVAL parameter', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            // Should build FREQ=...;INTERVAL= strings for custom patterns like "3 days", "2 weeks"
            expect(content).toMatch(/return "FREQ=DAILY;INTERVAL=" & stepCount/);
            expect(content).toMatch(/return "FREQ=WEEKLY;INTERVAL=" & stepCount/);
        });

        test('supports both fixed and due-after-completion repetition methods', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toMatch(/repetition method:fixed repetition, recurrence:recurrenceString/);
            expect(content).toMatch(/repetition method:due after completion, recurrence:recurrenceString/);
        });
    });

    describe('list_tags Hierarchy Support', () => {
        const scriptPath = path.join(enhancedScriptsDir, 'list_tags.applescript');

        test('uses recursive formatTags handler for hierarchical output', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toMatch(/on formatTags\(tagList, depth\)/);
            expect(content).toMatch(/my formatTags\(childTags, depth \+ 1\)/);
        });

        test('uses recursive formatTagsWithCounts handler for hierarchical output with counts', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toMatch(/on formatTagsWithCounts\(tagList, depth, tagCountRecord\)/);
            expect(content).toMatch(/my formatTagsWithCounts\(childTags, depth \+ 1, tagCountRecord\)/);
        });

        test('indents child tags based on depth', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            // Both handlers should build indent strings by repeating spaces per depth level
            expect(content).toMatch(/repeat depth times/);
            expect(content).toMatch(/set indent to indent & "  "/);
        });

        test('fetches child tags for recursion', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toMatch(/set childTags to every tag of aTag/);
        });

        test('uses every flattened tag for total count', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toMatch(/set flatTags to every flattened tag/);
            expect(content).toMatch(/count of flatTags/);
        });

        test('uses tag id instead of name for count map', () => {
            const content = fs.readFileSync(scriptPath, 'utf8');
            expect(content).toMatch(/set tID to id of aTag/);
            expect(content).toMatch(/tagID:tID/);
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
            expect(content).toContain('effectively completed is false and effectively dropped is false');
            expect(content).toContain('every flattened folder whose hidden is true');
        });

        test('list_tasks_filtered.applescript does not list a project without tasks as a task', () => {
            const content = read('list_tasks_filtered.applescript');
            expect(content).toContain('(id of theProject) is taskID');
        });

        test('list_tasks_filtered.applescript reports ambiguous tags instead of guessing', () => {
            const content = read('list_tasks_filtered.applescript');
            expect(content).toContain('Ambiguous tag');
            expect(content).toContain('Tag not found');
        });

        test('list_tasks_filtered.applescript filters by estimated minutes', () => {
            const content = read('list_tasks_filtered.applescript');
            expect(content).toContain('item 7 of argv');
            expect(content).toContain('estimated minutes of theTask');
            expect(content).toContain('estimateValue > maxMinutes');
            expect(content).toContain('includeUnestimated');
        });

        test('list_tasks_filtered.applescript shows the age and sorts oldest first', () => {
            const content = read('list_tasks_filtered.applescript');
            expect(content).toContain('item 9 of argv');
            expect(content).toContain('creation date of theTask');
            expect(content).toContain('on ageText(');
            expect(content).toContain('oldest first');
            // the limit applies after sorting
            expect(content).toContain('matchCount ≥ maxResults and not showAge');
        });

        test('list_completed_tasks.applescript filters by completion date', () => {
            const content = read('list_completed_tasks.applescript');
            expect(content).toContain('completion date');
            expect(content).toContain('every flattened folder whose hidden is true');
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
            expect(content).toContain('Valid properties: name, note, folder, status, type, review_interval, next_review_date, due_date, defer_date, planned_date, flagged, complete_with_last_item');
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
            expect(content).toContain('reviewIntervalText(theProject)');
            expect(content).toContain('every " & stepCount');
        });

        test('the review interval parser knows all units', () => {
            const content = read('edit_project.applescript');
            ['"day"', '"week"', '"month"', '"year"', '"weekly"', '"monthly"'].forEach(word => {
                expect(content).toContain(word);
            });
        });
    });

    describe('Due soon', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('list_due_soon.applescript lists open tasks due between now and the end of the last day', () => {
            const content = read('list_due_soon.applescript');
            expect(content).toContain('due date ≥ nowDate and due date ≤ endDate');
            expect(content).toContain('effectively completed is false and effectively dropped is false');
            expect(content).toContain('set hours of endDate to 23');
            expect(content).toContain('hiddenFolderTaskIDs()');
        });

        test('list_due_soon.applescript groups by tag, day or project and sorts by due date', () => {
            const content = read('list_due_soon.applescript');
            expect(content).toContain('groupMode is "tag"');
            expect(content).toContain('groupMode is "day"');
            expect(content).toContain('Unknown grouping');
            expect(content).toContain('(no tag)');
            expect(content).toContain('(item i of sortedDates) > taskDue');
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
            expect((server.match(/args\.project \|\| ''\n                \]\);/g) || []).length).toBeGreaterThanOrEqual(2);
        });

        test('list_perspectives.applescript separates built-in and custom perspectives', () => {
            const content = read('list_perspectives.applescript');
            expect(content).toContain('set perspectiveList to every perspective');
            expect(content).toContain('(class of thePerspective) is custom perspective');
            expect(content).toContain('set end of customNames to perspectiveName');
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
            expect(content).toContain('Valid properties: name, note, due_date, defer_date, planned_date, flagged, project, estimated_minutes, tags, repeat, parent_task, sequential, complete_with_last_item');
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
            expect(server).toContain("'repeat', 'parent_task', 'sequential', 'complete_with_last_item'");
        });
    });

    describe('Task repetition', () => {
        const read = name => fs.readFileSync(path.join(enhancedScriptsDir, name), 'utf8');

        test('edit_task.applescript sets and removes the repetition', () => {
            const content = read('edit_task.applescript');
            expect(content).toContain('propertyName is "repeat"');
            expect(content).toContain('set repetition rule of targetTask to missing value');
            expect(content).toContain('repetition method:fixed repetition, recurrence:ruleString of repeatInfo');
            expect(content).toContain('repetition method:due after completion, recurrence:ruleString of repeatInfo');
            expect(content).toContain('Valid properties: name, note, due_date, defer_date, planned_date, flagged, project, estimated_minutes, tags, repeat');
        });

        test('edit_task.applescript refuses to repeat a task without a date and rejects unknown rules', () => {
            const content = read('edit_task.applescript');
            expect(content).toContain('A repeating task needs a due, defer or planned date');
            expect(content).toContain('Invalid repeat');
            expect(content).toContain('on parseRepeatRule(');
        });

        test('parseRepeatRule builds the iCalendar strings for all units', () => {
            const content = read('edit_task.applescript');
            ['"DAILY"', '"WEEKLY"', '"MONTHLY"', '"YEARLY"', '";INTERVAL=" & stepCount'].forEach(part => {
                expect(content).toContain(part);
            });
        });

        test('get_task.applescript shows how a task repeats', () => {
            const content = read('get_task.applescript');
            expect(content).toContain('my repetitionText(targetTask)');
            expect(content).toContain('"Repeats: "');
            expect(content).toContain('repetition rule of theTask');
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

        test('edit_tag.applescript does not move a tag below itself and resolves names exactly', () => {
            const content = read('edit_tag.applescript');
            expect(content).toContain('ownIDs contains newParentID');
            expect(content).toContain('my resolveTag(tagText, false)');
        });

        test('list_tags.applescript shows IDs, hidden tags and tags without next actions', () => {
            const content = read('list_tags.applescript');
            expect(content).toContain('on tagSuffix(aTag)');
            expect(content).toContain('hidden of aTag');
            expect(content).toContain('allows next action of aTag');
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
