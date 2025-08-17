#!/usr/bin/env node

/**
 * Build Script for OmniFocus Claude Extension v2.0
 * Creates a single unified DXT package with all features
 */

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');
const chalk = require('chalk');

// Configuration
const BUILD_DIR = path.join(__dirname, 'extension-build');
const DIST_DIR = path.join(__dirname, 'dist');
const OUTPUT_FILE = path.join(DIST_DIR, 'omnifocus-gtd.dxt');

// Unified manifest for the extension
const MANIFEST = {
    id: 'omnifocus-gtd',
    name: 'OmniFocus GTD',
    version: '2.0.0',
    description: 'Complete OmniFocus task management with search, batch operations, recurring tasks, and comprehensive GTD features.',
    author: 'Community Contributors',
    license: 'MIT',
    readme: `# OmniFocus GTD Extension v2.0

Complete OmniFocus integration for Claude Desktop with advanced task management features.

## Features

### Task Management
- **Add Tasks** - Create tasks with notes, projects, due/defer dates, flags, and time estimates
- **Search Tasks** - Search across all projects and contexts
- **Edit Tasks** - Modify any property of existing tasks
- **Batch Operations** - Create multiple tasks with subtasks in one command
- **Recurring Tasks** - Set up tasks with repeat patterns
- **Complete Tasks** - Mark tasks as done by name

### Views & Reviews
- **Inbox** - Process unorganized tasks
- **Today** - Tasks due today
- **Projects** - All active projects with statistics
- **Deferred** - Tasks not yet available
- **Flagged** - Priority tasks
- **Overdue** - Past due tasks
- **Weekly Review** - Comprehensive GTD review

## Usage Examples

### Single Task
"Add task 'Review budget' due Friday to Finance project"

### Batch Tasks
"Create tasks: Research|-Analysis|-Report|Review"

### Search
"Search for tasks about 'meeting'"

### Edit
"Change due date of 'Presentation' to tomorrow"

### Recurring
"Create weekly recurring 'Team meeting' on Mondays"

## Requirements
- macOS 10.15+
- OmniFocus 3+
- Claude Desktop`,
    config: {
        enabled: true
    }
};

// Clean build directory
function cleanBuildDir() {
    console.log(chalk.blue('🧹 Cleaning build directory...'));
    if (fs.existsSync(BUILD_DIR)) {
        fs.rmSync(BUILD_DIR, { recursive: true, force: true });
    }
    fs.mkdirSync(BUILD_DIR, { recursive: true });
}

// Create dist directory
function ensureDistDir() {
    if (!fs.existsSync(DIST_DIR)) {
        fs.mkdirSync(DIST_DIR, { recursive: true });
    }
}

// Copy source files to build directory
function copySourceFiles() {
    console.log(chalk.blue('📁 Copying source files...'));
    
    // Create directory structure
    fs.mkdirSync(path.join(BUILD_DIR, 'server'), { recursive: true });
    fs.mkdirSync(path.join(BUILD_DIR, 'scripts'), { recursive: true });
    fs.mkdirSync(path.join(BUILD_DIR, 'scripts', 'enhanced'), { recursive: true });
    
    // Copy server
    fs.copyFileSync(
        path.join(__dirname, 'src', 'server', 'index.js'),
        path.join(BUILD_DIR, 'server', 'index.js')
    );
    console.log(chalk.green('✓ Copied server'));
    
    // Copy original scripts
    const scriptsDir = path.join(__dirname, 'src', 'scripts');
    const scripts = fs.readdirSync(scriptsDir);
    let originalCount = 0;
    
    scripts.forEach(script => {
        const scriptPath = path.join(scriptsDir, script);
        if (fs.statSync(scriptPath).isFile() && script.endsWith('.applescript')) {
            fs.copyFileSync(
                scriptPath,
                path.join(BUILD_DIR, 'scripts', script)
            );
            originalCount++;
        }
    });
    console.log(chalk.green(`✓ Copied ${originalCount} original scripts`));
    
    // Copy enhanced scripts
    const enhancedScriptsDir = path.join(scriptsDir, 'enhanced');
    let enhancedCount = 0;
    
    if (fs.existsSync(enhancedScriptsDir)) {
        const enhancedScripts = fs.readdirSync(enhancedScriptsDir);
        enhancedScripts.forEach(script => {
            if (script.endsWith('.applescript')) {
                fs.copyFileSync(
                    path.join(enhancedScriptsDir, script),
                    path.join(BUILD_DIR, 'scripts', 'enhanced', script)
                );
                enhancedCount++;
            }
        });
        console.log(chalk.green(`✓ Copied ${enhancedCount} enhanced scripts`));
    }
    
    return { originalCount, enhancedCount };
}

// Create manifest file
function createManifest() {
    console.log(chalk.blue('📝 Creating manifest...'));
    const manifestPath = path.join(BUILD_DIR, 'manifest.json');
    fs.writeFileSync(manifestPath, JSON.stringify(MANIFEST, null, 2));
    console.log(chalk.green('✓ Manifest created'));
}

// Create the DXT archive
async function createArchive() {
    console.log(chalk.blue('📦 Creating DXT archive...'));
    
    return new Promise((resolve, reject) => {
        const output = fs.createWriteStream(OUTPUT_FILE);
        const archive = archiver('zip', {
            zlib: { level: 9 }
        });
        
        output.on('close', () => {
            const size = (archive.pointer() / 1024).toFixed(2);
            console.log(chalk.green(`✓ Archive created: ${size} KB`));
            resolve();
        });
        
        archive.on('error', (err) => {
            console.error(chalk.red('✗ Archive error:'), err);
            reject(err);
        });
        
        archive.pipe(output);
        
        // Add all files from build directory
        archive.directory(BUILD_DIR, false);
        
        archive.finalize();
    });
}

// Validate the created archive
function validateArchive() {
    console.log(chalk.blue('🔍 Validating archive...'));
    
    if (!fs.existsSync(OUTPUT_FILE)) {
        throw new Error('Output file not created');
    }
    
    const stats = fs.statSync(OUTPUT_FILE);
    if (stats.size < 1000) {
        throw new Error('Archive too small, likely corrupted');
    }
    
    console.log(chalk.green('✓ Archive validated'));
    return stats.size;
}

// Create build report
function createBuildReport(scriptCounts, fileSize) {
    console.log(chalk.blue('📊 Creating build report...'));
    
    const report = {
        version: MANIFEST.version,
        buildDate: new Date().toISOString(),
        features: {
            core: ['add_task', 'list_inbox', 'today_tasks', 'complete_task', 'weekly_review'],
            advanced: ['search_tasks', 'edit_task', 'batch_add_tasks', 'create_recurring_task'],
            views: ['list_projects', 'list_deferred_tasks', 'list_flagged_tasks', 'list_overdue_tasks']
        },
        scripts: {
            original: scriptCounts.originalCount,
            enhanced: scriptCounts.enhancedCount,
            total: scriptCounts.originalCount + scriptCounts.enhancedCount
        },
        outputFile: OUTPUT_FILE,
        fileSize: fileSize
    };
    
    fs.writeFileSync(
        path.join(DIST_DIR, 'build-report.json'),
        JSON.stringify(report, null, 2)
    );
    
    console.log(chalk.green('✓ Build report created'));
    return report;
}

// Main build process
async function build() {
    console.log(chalk.cyan.bold('\n🔧 Building OmniFocus GTD Extension v2.0\n'));
    
    try {
        cleanBuildDir();
        ensureDistDir();
        const scriptCounts = copySourceFiles();
        createManifest();
        await createArchive();
        const fileSize = validateArchive();
        const report = createBuildReport(scriptCounts, fileSize);
        
        // Clean up build directory
        fs.rmSync(BUILD_DIR, { recursive: true, force: true });
        
        console.log(chalk.green.bold('\n✅ Build completed successfully!\n'));
        console.log(chalk.white('📦 Output:'), chalk.yellow(OUTPUT_FILE));
        console.log(chalk.white('📊 Features:'), 
            chalk.cyan(`${report.features.core.length} core, ${report.features.advanced.length} advanced, ${report.features.views.length} views`));
        console.log(chalk.white('📝 Scripts:'), 
            chalk.cyan(`${report.scripts.total} total (${report.scripts.original} original + ${report.scripts.enhanced} enhanced)`));
        console.log(chalk.white('📏 Size:'), chalk.cyan(`${(fileSize / 1024).toFixed(2)} KB`));
        console.log(chalk.gray('\nInstall by dragging the .dxt file to Claude Desktop'));
        
    } catch (error) {
        console.error(chalk.red.bold('\n❌ Build failed!\n'));
        console.error(chalk.red(error.message));
        process.exit(1);
    }
}

// Run the build
build();
