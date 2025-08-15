#!/usr/bin/env node

/**
 * Test suite for OmniFocus Claude Extension
 * Runs various tests to ensure the extension is properly built
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Console colors
const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m'
};

const log = {
    info: (msg) => console.log(`${colors.blue}[INFO]${colors.reset} ${msg}`),
    success: (msg) => console.log(`${colors.green}[PASS]${colors.reset} ${msg}`),
    error: (msg) => console.log(`${colors.red}[FAIL]${colors.reset} ${msg}`),
    warning: (msg) => console.log(`${colors.yellow}[WARN]${colors.reset} ${msg}`)
};

// Test suite
const tests = {
    // Check if required files exist
    checkRequiredFiles: () => {
        log.info('Checking required files...');
        const requiredFiles = [
            'package.json',
            'src/manifest-dxt.json',
            'src/server/index.js',
            'build-dxt-new.js'
        ];
        
        let passed = true;
        for (const file of requiredFiles) {
            const filePath = path.join(__dirname, file);
            if (fs.existsSync(filePath)) {
                log.success(`Found: ${file}`);
            } else {
                log.error(`Missing: ${file}`);
                passed = false;
            }
        }
        return passed;
    },
    
    // Validate manifest structure
    validateManifest: () => {
        log.info('Validating manifest...');
        const manifestPath = path.join(__dirname, 'src', 'manifest-dxt.json');
        
        try {
            const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
            
            // Check required fields
            const requiredFields = ['dxt_version', 'name', 'version', 'server', 'tools'];
            let passed = true;
            
            for (const field of requiredFields) {
                if (manifest[field]) {
                    log.success(`Manifest has ${field}`);
                } else {
                    log.error(`Manifest missing ${field}`);
                    passed = false;
                }
            }
            
            // Validate tools
            if (manifest.tools && Array.isArray(manifest.tools)) {
                log.success(`Found ${manifest.tools.length} tools`);
                
                for (const tool of manifest.tools) {
                    if (!tool.name || !tool.description) {
                        log.error(`Invalid tool: ${JSON.stringify(tool)}`);
                        passed = false;
                    }
                }
            } else {
                log.error('Tools not properly defined');
                passed = false;
            }
            
            return passed;
        } catch (error) {
            log.error(`Failed to parse manifest: ${error.message}`);
            return false;
        }
    },
    
    // Check AppleScript files
    checkAppleScripts: () => {
        log.info('Checking AppleScript files...');
        const scriptsDir = path.join(__dirname, 'src', 'scripts');
        
        if (!fs.existsSync(scriptsDir)) {
            log.warning('Scripts directory not found (optional)');
            return true;
        }
        
        const scriptFiles = fs.readdirSync(scriptsDir).filter(f => f.endsWith('.applescript'));
        
        if (scriptFiles.length === 0) {
            log.warning('No AppleScript files found');
            return true;
        }
        
        let passed = true;
        for (const scriptFile of scriptFiles) {
            const scriptPath = path.join(scriptsDir, scriptFile);
            const content = fs.readFileSync(scriptPath, 'utf8');
            
            if (content.length > 0) {
                log.success(`Valid script: ${scriptFile}`);
            } else {
                log.error(`Empty script: ${scriptFile}`);
                passed = false;
            }
        }
        
        return passed;
    },
    
    // Test server syntax
    testServerSyntax: () => {
        log.info('Testing server syntax...');
        const serverPath = path.join(__dirname, 'src', 'server', 'index.js');
        
        try {
            // Use the same node that's running this script
            const nodePath = process.execPath;
            execSync(`"${nodePath}" -c "${serverPath}"`, { stdio: 'pipe' });
            log.success('Server syntax is valid');
            return true;
        } catch (error) {
            log.error(`Server syntax error: ${error.message}`);
            return false;
        }
    },
    
    // Test build script
    testBuildScript: () => {
        log.info('Testing build script...');
        const buildScriptPath = path.join(__dirname, 'build-dxt-new.js');
        
        try {
            // Use the same node that's running this script
            const nodePath = process.execPath;
            execSync(`"${nodePath}" -c "${buildScriptPath}"`, { stdio: 'pipe' });
            log.success('Build script syntax is valid');
            return true;
        } catch (error) {
            log.error(`Build script syntax error: ${error.message}`);
            return false;
        }
    }
};

// Run all tests
async function runTests() {
    console.log('');
    log.info('🧪 Running OmniFocus Extension Tests');
    console.log('');
    
    const results = [];
    
    for (const [name, test] of Object.entries(tests)) {
        try {
            const passed = await test();
            results.push({ name, passed });
        } catch (error) {
            log.error(`Test ${name} failed with error: ${error.message}`);
            results.push({ name, passed: false });
        }
        console.log('');
    }
    
    // Summary
    const passed = results.filter(r => r.passed).length;
    const failed = results.filter(r => !r.passed).length;
    
    console.log('='.repeat(50));
    log.info('Test Summary:');
    log.info(`  Total: ${results.length}`);
    log.success(`  Passed: ${passed}`);
    if (failed > 0) {
        log.error(`  Failed: ${failed}`);
    }
    console.log('='.repeat(50));
    
    if (failed > 0) {
        log.error('❌ Tests failed!');
        process.exit(1);
    } else {
        log.success('✅ All tests passed!');
        process.exit(0);
    }
}

// Run tests if executed directly
if (require.main === module) {
    runTests().catch(error => {
        log.error(`Test runner failed: ${error.message}`);
        process.exit(1);
    });
}

module.exports = { runTests };
