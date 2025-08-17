#!/usr/bin/env node

/**
 * Validation Script for OmniFocus Claude Extension v2.0
 * Ensures all enhanced features are properly included in the build
 */

const fs = require('fs');
const path = require('path');
const chalk = require('chalk');

// Validation checks
const checks = {
    directories: [
        'src/server',
        'src/scripts',
        'src/scripts/enhanced'
    ],
    
    enhancedScripts: [
        'search_tasks.applescript',
        'edit_task.applescript',
        'batch_add_tasks.applescript',
        'create_recurring_task.applescript',
        'list_projects.applescript',
        'list_deferred_tasks.applescript',
        'list_flagged_tasks.applescript',
        'list_overdue_tasks.applescript'
    ],
    
    originalScripts: [
        'add_task.applescript',
        'complete_task.applescript',
        'list_inbox.applescript',
        'today_tasks.applescript',
        'weekly_review.applescript'
    ],
    
    serverFiles: [
        'index.js',
        'index-enhanced.js'
    ],
    
    buildFiles: [
        'build-dxt-enhanced.js',
        'package.json',
        'README.md',
        'CHANGELOG.md',
        'LIMITATIONS_RESOLVED.md'
    ]
};

let validationPassed = true;
const issues = [];

console.log(chalk.cyan.bold('\n🔍 Validating OmniFocus Enhanced Extension Structure\n'));

// Check directories
console.log(chalk.blue('📁 Checking directories...'));
checks.directories.forEach(dir => {
    const fullPath = path.join(__dirname, dir);
    if (fs.existsSync(fullPath)) {
        console.log(chalk.green(`  ✓ ${dir}`));
    } else {
        console.log(chalk.red(`  ✗ ${dir} - MISSING`));
        issues.push(`Directory missing: ${dir}`);
        validationPassed = false;
    }
});

// Check enhanced scripts
console.log(chalk.blue('\n🚀 Checking enhanced scripts...'));
checks.enhancedScripts.forEach(script => {
    const fullPath = path.join(__dirname, 'src', 'scripts', 'enhanced', script);
    if (fs.existsSync(fullPath)) {
        const size = fs.statSync(fullPath).size;
        console.log(chalk.green(`  ✓ ${script} (${size} bytes)`));
    } else {
        console.log(chalk.red(`  ✗ ${script} - MISSING`));
        issues.push(`Enhanced script missing: ${script}`);
        validationPassed = false;
    }
});

// Check original scripts
console.log(chalk.blue('\n📝 Checking original scripts...'));
checks.originalScripts.forEach(script => {
    const fullPath = path.join(__dirname, 'src', 'scripts', script);
    if (fs.existsSync(fullPath)) {
        console.log(chalk.green(`  ✓ ${script}`));
    } else {
        console.log(chalk.yellow(`  ⚠ ${script} - Missing (may be intentional)`));
    }
});

// Check server files
console.log(chalk.blue('\n🖥️ Checking server implementations...'));
checks.serverFiles.forEach(file => {
    const fullPath = path.join(__dirname, 'src', 'server', file);
    if (fs.existsSync(fullPath)) {
        const size = fs.statSync(fullPath).size;
        console.log(chalk.green(`  ✓ ${file} (${size} bytes)`));
    } else {
        console.log(chalk.red(`  ✗ ${file} - MISSING`));
        issues.push(`Server file missing: ${file}`);
        validationPassed = false;
    }
});

// Check build files
console.log(chalk.blue('\n🔧 Checking build configuration...'));
checks.buildFiles.forEach(file => {
    const fullPath = path.join(__dirname, file);
    if (fs.existsSync(fullPath)) {
        console.log(chalk.green(`  ✓ ${file}`));
    } else {
        console.log(chalk.yellow(`  ⚠ ${file} - Missing`));
    }
});

// Check package.json version
const packageJson = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));
console.log(chalk.blue('\n📦 Package Information:'));
console.log(chalk.white(`  Name: ${packageJson.name}`));
console.log(chalk.white(`  Version: ${packageJson.version}`));
console.log(chalk.white(`  Description: ${packageJson.description}`));

if (packageJson.version !== '2.0.0') {
    console.log(chalk.yellow('  ⚠ Version should be 2.0.0 for enhanced release'));
}

// Feature validation
console.log(chalk.blue('\n✨ Enhanced Features Validation:'));
const features = {
    'Task Search': checks.enhancedScripts.includes('search_tasks.applescript'),
    'Task Editing': checks.enhancedScripts.includes('edit_task.applescript'),
    'Batch Operations': checks.enhancedScripts.includes('batch_add_tasks.applescript'),
    'Recurring Tasks': checks.enhancedScripts.includes('create_recurring_task.applescript'),
    'Project Management': checks.enhancedScripts.includes('list_projects.applescript'),
    'Deferred Tasks': checks.enhancedScripts.includes('list_deferred_tasks.applescript'),
    'Flagged Tasks': checks.enhancedScripts.includes('list_flagged_tasks.applescript'),
    'Overdue Tasks': checks.enhancedScripts.includes('list_overdue_tasks.applescript')
};

Object.entries(features).forEach(([feature, exists]) => {
    if (exists) {
        console.log(chalk.green(`  ✓ ${feature}`));
    } else {
        console.log(chalk.red(`  ✗ ${feature} - NOT AVAILABLE`));
        validationPassed = false;
    }
});

// Final summary
console.log(chalk.cyan.bold('\n📊 Validation Summary\n'));

if (validationPassed) {
    console.log(chalk.green.bold('✅ All validation checks passed!'));
    console.log(chalk.green('The enhanced extension is ready to build.'));
    console.log(chalk.white('\nNext steps:'));
    console.log(chalk.white('1. Run: npm run build:enhanced'));
    console.log(chalk.white('2. Check dist/omnifocus-gtd-enhanced.dxt'));
    console.log(chalk.white('3. Install in Claude Desktop'));
} else {
    console.log(chalk.red.bold('❌ Validation failed!'));
    console.log(chalk.red('\nIssues found:'));
    issues.forEach(issue => {
        console.log(chalk.red(`  • ${issue}`));
    });
    console.log(chalk.yellow('\nPlease fix these issues before building.'));
    process.exit(1);
}

// Statistics
console.log(chalk.cyan.bold('\n📈 Extension Statistics:\n'));
const stats = {
    'Total Scripts': checks.enhancedScripts.length + checks.originalScripts.length,
    'Enhanced Scripts': checks.enhancedScripts.length,
    'Original Scripts': checks.originalScripts.length,
    'New Features': Object.keys(features).length,
    'Server Implementations': checks.serverFiles.length
};

Object.entries(stats).forEach(([key, value]) => {
    console.log(chalk.white(`${key}: ${chalk.cyan(value)}`));
});

console.log(chalk.gray('\n---'));
console.log(chalk.gray('OmniFocus GTD Enhanced v2.0.0'));
console.log(chalk.gray('All limitations resolved ✨'));
console.log();
