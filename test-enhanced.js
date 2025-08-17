#!/usr/bin/env node

/**
 * Test Suite for OmniFocus Claude Extension Enhanced Features
 * Validates that all enhanced functionality works correctly
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const chalk = require('chalk');

// Test configuration
const SCRIPTS_DIR = path.join(__dirname, 'src', 'scripts', 'enhanced');
const TESTS_PASSED = [];
const TESTS_FAILED = [];

// Test helper
function runTest(name, scriptFile, args, expectedPattern) {
    process.stdout.write(chalk.blue(`Testing ${name}... `));
    
    try {
        const scriptPath = path.join(SCRIPTS_DIR, scriptFile);
        
        if (!fs.existsSync(scriptPath)) {
            throw new Error(`Script not found: ${scriptFile}`);
        }
        
        const command = `osascript "${scriptPath}" ${args.map(a => `"${a}"`).join(' ')}`;
        const result = execSync(command, { encoding: 'utf8', timeout: 10000 });
        
        if (expectedPattern && !result.includes(expectedPattern)) {
            throw new Error(`Output doesn't match expected pattern. Got: ${result.substring(0, 100)}`);
        }
        
        console.log(chalk.green('✓'));
        TESTS_PASSED.push(name);
        return true;
    } catch (error) {
        console.log(chalk.red('✗'));
        console.log(chalk.red(`  Error: ${error.message}`));
        TESTS_FAILED.push({ name, error: error.message });
        return false;
    }
}

// Run tests
function runAllTests() {
    console.log(chalk.cyan.bold('\n🧪 Running Enhanced Feature Tests\n'));
    
    // Test 1: Search functionality
    runTest(
        'Search Tasks',
        'search_tasks.applescript',
        ['task', 'all', '10'],
        '🔍'
    );
    
    // Test 2: Edit task (we'll test with a safe operation)
    runTest(
        'Edit Task Script',
        'edit_task.applescript',
        ['NonExistentTaskForTesting123', 'name', 'NewName'],
        'No matching tasks found'
    );
    
    // Test 3: Batch add tasks
    runTest(
        'Batch Add Tasks',
        'batch_add_tasks.applescript',
        ['Test1|Test2|-Subtask|Test3', '', '', 'false'],
        '✅'
    );
    
    // Test 4: Create recurring task
    runTest(
        'Create Recurring Task',
        'create_recurring_task.applescript',
        ['Test Recurring Task', 'weekly', '', ''],
        '🔄'
    );
    
    // Print results
    console.log(chalk.cyan.bold('\n📊 Test Results\n'));
    
    if (TESTS_PASSED.length > 0) {
        console.log(chalk.green(`✅ Passed: ${TESTS_PASSED.length}`));
        TESTS_PASSED.forEach(test => {
            console.log(chalk.green(`   • ${test}`));
        });
    }
    
    if (TESTS_FAILED.length > 0) {
        console.log(chalk.red(`\n❌ Failed: ${TESTS_FAILED.length}`));
        TESTS_FAILED.forEach(({ name, error }) => {
            console.log(chalk.red(`   • ${name}`));
            console.log(chalk.gray(`     ${error}`));
        });
    }
    
    // Overall result
    const totalTests = TESTS_PASSED.length + TESTS_FAILED.length;
    const successRate = ((TESTS_PASSED.length / totalTests) * 100).toFixed(1);
    
    console.log(chalk.cyan.bold('\n📈 Summary\n'));
    console.log(chalk.white(`Total Tests: ${totalTests}`));
    console.log(chalk.white(`Success Rate: ${successRate}%`));
    
    if (TESTS_FAILED.length === 0) {
        console.log(chalk.green.bold('\n✨ All tests passed! The enhanced features are working correctly.\n'));
        process.exit(0);
    } else {
        console.log(chalk.yellow.bold('\n⚠️  Some tests failed. Please check the AppleScript implementations.\n'));
        process.exit(1);
    }
}

// Check if OmniFocus is running
function checkOmniFocus() {
    try {
        execSync('osascript -e "tell application \\"System Events\\" to (name of processes) contains \\"OmniFocus\\""');
        return true;
    } catch {
        return false;
    }
}

// Main execution
console.log(chalk.cyan.bold('OmniFocus Enhanced Extension Test Suite\n'));

if (!checkOmniFocus()) {
    console.log(chalk.yellow('⚠️  OmniFocus is not running. Starting it...'));
    try {
        execSync('osascript -e "tell application \\"OmniFocus\\" to activate"');
        console.log(chalk.green('✓ OmniFocus started\n'));
        // Wait a moment for it to fully launch
        execSync('sleep 2');
    } catch {
        console.log(chalk.red('❌ Could not start OmniFocus. Please start it manually.\n'));
        process.exit(1);
    }
}

// Check if enhanced scripts exist
if (!fs.existsSync(SCRIPTS_DIR)) {
    console.log(chalk.red('❌ Enhanced scripts directory not found!'));
    console.log(chalk.yellow('Please ensure you have built the enhanced version.\n'));
    process.exit(1);
}

const enhancedScripts = fs.readdirSync(SCRIPTS_DIR).filter(f => f.endsWith('.applescript'));
console.log(chalk.green(`✓ Found ${enhancedScripts.length} enhanced scripts\n`));

// Run the tests
runAllTests();
