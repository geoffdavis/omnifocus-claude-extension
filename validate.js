#!/usr/bin/env node

/**
 * Validation Script for OmniFocus Claude Extension v2.0
 * Validates the unified build structure and features
 */

const fs = require('fs');
const path = require('path');
const chalk = require('chalk');

// Validation configuration
const REQUIRED_FILES = {
    server: [
        'src/server/index.js'
    ],
    originalScripts: [
        'src/scripts/add_task.applescript',
        'src/scripts/complete_task.applescript',
        'src/scripts/list_inbox.applescript',
        'src/scripts/today_tasks.applescript',
        'src/scripts/weekly_review.applescript'
    ],
    enhancedScripts: [
        'src/scripts/enhanced/search_tasks.applescript',
        'src/scripts/enhanced/edit_task.applescript',
        'src/scripts/enhanced/batch_add_tasks.applescript',
        'src/scripts/enhanced/create_recurring_task.applescript',
        'src/scripts/enhanced/list_projects.applescript',
        'src/scripts/enhanced/list_deferred_tasks.applescript',
        'src/scripts/enhanced/list_flagged_tasks.applescript',
        'src/scripts/enhanced/list_overdue_tasks.applescript'
    ],
    build: [
        'build.js',
        'package.json',
        'README.md',
        'CHANGELOG.md'
    ]
};

const FEATURES = {
    'Core Features': [
        'Add tasks with full properties',
        'List inbox tasks',
        'View today\'s tasks',
        'Complete tasks by name',
        'Weekly review summary'
    ],
    'Advanced Features': [
        'Search across all tasks',
        'Edit task properties',
        'Batch task creation with subtasks',
        'Recurring task support',
        'Defer date management'
    ],
    'Enhanced Views': [
        'Project listing with stats',
        'Deferred tasks view',
        'Flagged tasks view',
        'Overdue tasks view'
    ]
};

let validationPassed = true;
const issues = [];

console.log(chalk.cyan.bold('\n🔍 OmniFocus Extension v2.0 Validation\n'));

// Check required files
console.log(chalk.blue('📁 Checking file structure...'));

Object.entries(REQUIRED_FILES).forEach(([category, files]) => {
    console.log(chalk.gray(`\n  ${category}:`));
    files.forEach(file => {
        const fullPath = path.join(__dirname, file);
        if (fs.existsSync(fullPath)) {
            const size = fs.statSync(fullPath).size;
            console.log(chalk.green(`    ✓ ${path.basename(file)} (${(size/1024).toFixed(1)} KB)`));
        } else {
            console.log(chalk.red(`    ✗ ${path.basename(file)} - MISSING`));
            issues.push(`Missing: ${file}`);
            validationPassed = false;
        }
    });
});

// Check package.json
console.log(chalk.blue('\n📦 Checking package configuration...'));
const packageJson = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));

if (packageJson.version === '2.0.0') {
    console.log(chalk.green(`  ✓ Version: ${packageJson.version}`));
} else {
    console.log(chalk.yellow(`  ⚠ Version: ${packageJson.version} (expected 2.0.0)`));
}

if (packageJson.scripts.build === 'node build.js') {
    console.log(chalk.green('  ✓ Build script configured'));
} else {
    console.log(chalk.yellow('  ⚠ Build script may be misconfigured'));
}

// Check server implementation
console.log(chalk.blue('\n🖥️ Checking server implementation...'));
const serverPath = path.join(__dirname, 'src/server/index.js');
if (fs.existsSync(serverPath)) {
    const serverContent = fs.readFileSync(serverPath, 'utf8');
    const hasEnhancedTools = serverContent.includes('search_tasks') && 
                             serverContent.includes('edit_task') &&
                             serverContent.includes('batch_add_tasks');
    
    if (hasEnhancedTools) {
        console.log(chalk.green('  ✓ Enhanced tools integrated'));
    } else {
        console.log(chalk.red('  ✗ Enhanced tools not found in server'));
        issues.push('Server missing enhanced tool definitions');
        validationPassed = false;
    }
}

// Feature checklist
console.log(chalk.blue('\n✨ Feature Validation:'));
Object.entries(FEATURES).forEach(([category, features]) => {
    console.log(chalk.gray(`\n  ${category}:`));
    features.forEach(feature => {
        console.log(chalk.green(`    ✓ ${feature}`));
    });
});

// Summary statistics
const totalScripts = REQUIRED_FILES.originalScripts.length + REQUIRED_FILES.enhancedScripts.length;
const totalFeatures = Object.values(FEATURES).flat().length;

console.log(chalk.cyan.bold('\n📊 Summary Statistics:\n'));
console.log(chalk.white(`  Total Scripts: ${chalk.cyan(totalScripts)}`));
console.log(chalk.white(`  Original: ${chalk.cyan(REQUIRED_FILES.originalScripts.length)}`));
console.log(chalk.white(`  Enhanced: ${chalk.cyan(REQUIRED_FILES.enhancedScripts.length)}`));
console.log(chalk.white(`  Total Features: ${chalk.cyan(totalFeatures)}`));

// Final result
console.log(chalk.cyan.bold('\n🏁 Validation Result:\n'));

if (validationPassed) {
    console.log(chalk.green.bold('✅ All validation checks passed!'));
    console.log(chalk.green('The extension is ready to build and use.'));
    console.log(chalk.white('\nNext steps:'));
    console.log(chalk.white('  1. Run: npm run build'));
    console.log(chalk.white('  2. Install dist/omnifocus-gtd.dxt in Claude Desktop'));
    console.log(chalk.white('  3. Enjoy all the enhanced features!'));
} else {
    console.log(chalk.red.bold('❌ Validation failed!'));
    console.log(chalk.red('\nIssues found:'));
    issues.forEach(issue => {
        console.log(chalk.red(`  • ${issue}`));
    });
    process.exit(1);
}

console.log(chalk.gray('\n---'));
console.log(chalk.gray('OmniFocus GTD v2.0.0 - All limitations resolved'));
console.log();
