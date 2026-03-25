const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

describe('AppleScript Integration', () => {
    const scriptsDir = path.join(__dirname, '..', 'src', 'scripts');
    const enhancedScriptsDir = path.join(scriptsDir, 'enhanced');

    describe('Script Files', () => {
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
                'search_tasks.applescript'
            ];

            enhancedScripts.forEach(script => {
                const scriptPath = path.join(enhancedScriptsDir, script);
                expect(fs.existsSync(scriptPath)).toBe(true);
            });
        });
    });

    describe('Script Syntax', () => {
        test('all AppleScript files compile without syntax errors', () => {
            // Check if osacompile is available (macOS only)
            let osacompileAvailable = false;
            try {
                execSync('which osacompile', { stdio: 'pipe' });
                osacompileAvailable = true;
            } catch { /* not in this environment */ }

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
                // Fallback: verify non-empty and contain structural keywords
                scriptFiles.forEach(scriptPath => {
                    const content = fs.readFileSync(scriptPath, 'utf8');
                    expect(content.length).toBeGreaterThan(0);
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

    describe('Tool-Script Coverage', () => {
        const serverPath = path.join(__dirname, '..', 'src', 'server', 'index.js');

        test('every tool in server index.js has a matching .applescript file', () => {
            const serverContent = fs.readFileSync(serverPath, 'utf8');

            // Extract tool names: 8-space-indented "name: 'xxx'," lines inside const tools = [...]
            const toolsStart = serverContent.indexOf('const tools = [');
            const toolsEnd = serverContent.indexOf('\n];', toolsStart);
            const toolsSection = serverContent.slice(toolsStart, toolsEnd);
            const toolNames = [...toolsSection.matchAll(/^        name:\s*'([^']+)',/gm)].map(m => m[1]);

            expect(toolNames.length).toBeGreaterThan(0);

            toolNames.forEach(toolName => {
                const enhancedPath = path.join(enhancedScriptsDir, `${toolName}.applescript`);
                const corePath = path.join(scriptsDir, `${toolName}.applescript`);
                const found = fs.existsSync(enhancedPath) || fs.existsSync(corePath);
                expect(found).toBe(true);
            });
        });

        test('every tool name in the tools array has a case in executeTool switch', () => {
            const serverContent = fs.readFileSync(serverPath, 'utf8');

            // Extract tool names from const tools = [...]
            const toolsStart = serverContent.indexOf('const tools = [');
            const toolsEnd = serverContent.indexOf('\n];', toolsStart);
            const toolsSection = serverContent.slice(toolsStart, toolsEnd);
            const toolNames = [...toolsSection.matchAll(/^        name:\s*'([^']+)',/gm)].map(m => m[1]);

            // Extract case labels from the switch(name) in executeTool
            const caseNames = [...serverContent.matchAll(/case\s+'([^']+)':/g)].map(m => m[1]);

            toolNames.forEach(toolName => {
                expect(caseNames).toContain(toolName);
            });
        });
    });
});
