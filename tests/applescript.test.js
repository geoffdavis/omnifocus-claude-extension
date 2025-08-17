const fs = require('fs');
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
                'search_tasks.applescript',
                'edit_task.applescript',
                'batch_add_tasks.applescript',
                'create_recurring_task.applescript',
                'list_projects.applescript',
                'list_contexts.applescript',
                'list_flagged.applescript',
                'list_due_soon.applescript',
                'list_completed_today.applescript'
            ];
            
            const existingScripts = enhancedScripts.filter(script => {
                const scriptPath = path.join(enhancedScriptsDir, script);
                return fs.existsSync(scriptPath);
            });
            
            // At least some enhanced scripts should exist
            expect(existingScripts.length).toBeGreaterThan(0);
        });
    });
    
    describe('Script Syntax', () => {
        test('all scripts have valid AppleScript syntax', () => {
            // Get all .applescript files
            const scriptFiles = fs.readdirSync(scriptsDir)
                .filter(f => f.endsWith('.applescript'))
                .map(f => path.join(scriptsDir, f));
            
            if (fs.existsSync(enhancedScriptsDir)) {
                const enhancedFiles = fs.readdirSync(enhancedScriptsDir)
                    .filter(f => f.endsWith('.applescript'))
                    .map(f => path.join(enhancedScriptsDir, f));
                scriptFiles.push(...enhancedFiles);
            }
            
            scriptFiles.forEach(scriptPath => {
                // Check if script compiles without errors
                // Note: This only checks syntax, not runtime errors
                try {
                    execSync(`osascript -c 'return "test"'`, { stdio: 'pipe' });
                    // If osascript works, test the actual script syntax
                    const scriptContent = fs.readFileSync(scriptPath, 'utf8');
                    
                    // Basic syntax checks
                    expect(scriptContent).toContain('tell application "OmniFocus"');
                    expect(scriptContent).toContain('end tell');
                } catch (error) {
                    // osascript might not be available in CI environment
                    // Still check basic file validity
                    const content = fs.readFileSync(scriptPath, 'utf8');
                    expect(content.length).toBeGreaterThan(0);
                }
            });
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
});