#!/usr/bin/env node

/**
 * Enhanced Build Script for OmniFocus Claude Extension
 * Creates a DXT package with all enhanced features
 */

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');
const chalk = require('chalk');

// Configuration
const BUILD_DIR = path.join(__dirname, 'extension-build');
const DIST_DIR = path.join(__dirname, 'dist');
const OUTPUT_FILE = path.join(DIST_DIR, 'omnifocus-gtd-enhanced.dxt');

// Enhanced manifest for the extension
const MANIFEST = {
    id: 'omnifocus-gtd-enhanced',
    name: 'OmniFocus GTD Enhanced',
    version: '2.0.0',
    description: 'Advanced OmniFocus task management with search, batch operations, recurring tasks, and comprehensive GTD features.',
    author: 'Community Contributors',
    license: 'MIT',
    readme: `# OmniFocus GTD Enhanced Extension

An advanced OmniFocus integration for Claude Desktop with powerful features for GTD practitioners.

## 🚀 New Enhanced Features

### Advanced Task Management
- **Search Tasks** - Search across all projects and contexts
- **Edit Tasks** - Modify any property of existing tasks
- **Batch Operations** - Create multiple tasks with subtasks in one command
- **Recurring Tasks** - Set up tasks with repeat patterns

### Comprehensive Views
- **List Projects** - View all active projects with statistics
- **Deferred Tasks** - See tasks that aren't available yet
- **Flagged Tasks** - Quick access to all flagged items
- **Overdue Tasks** - Track tasks past their due date

### Original Features
- Add tasks with natural language
- Process inbox items
- View today's tasks
- Complete tasks by name
- Weekly review summaries

## Usage Examples

### Batch Task Creation
"Create tasks: Research options|-Compare prices|-Make decision|Follow up with team"

### Search
"Search for tasks containing 'budget'"

### Edit Tasks
"Change the due date of 'Review proposal' to next Friday"

### Recurring Tasks
"Create a weekly recurring task 'Weekly team meeting'"

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
    
    // Copy enhanced server
    const enhancedServerPath = path.join(__dirname, 'src', 'server', 'index-enhanced.js');
    const targetServerPath = path.join(BUILD_DIR, 'server', 'index.js');
    
    if (fs.existsSync(enhancedServerPath)) {
        fs.copyFileSync(enhancedServerPath, targetServerPath);
        console.log(chalk.green('✓ Copied enhanced server'));
    } else {
        // Fall back to original server
        fs.copyFileSync(
            path.join(__dirname, 'src', 'server', 'index.js'),
            targetServerPath
        );
        console.log(chalk.yellow('⚠ Using original server (enhanced not found)'));
    }
    
    // Copy original scripts
    const scriptsDir = path.join(__dirname, 'src', 'scripts');
    const scripts = fs.readdirSync(scriptsDir);
    
    scripts.forEach(script => {
        const scriptPath = path.join(scriptsDir, script);
        if (fs.statSync(scriptPath).isFile() && script.endsWith('.applescript')) {
            fs.copyFileSync(
                scriptPath,
                path.join(BUILD_DIR, 'scripts', script)
            );
        }
    });
    console.log(chalk.green(`✓ Copied ${scripts.filter(s => s.endsWith('.applescript')).length} original scripts`));
    
    // Copy enhanced scripts
    const enhancedScriptsDir = path.join(scriptsDir, 'enhanced');
    if (fs.existsSync(enhancedScriptsDir)) {
        const enhancedScripts = fs.readdirSync(enhancedScriptsDir);
        enhancedScripts.forEach(script => {
            if (script.endsWith('.applescript')) {
                fs.copyFileSync(
                    path.join(enhancedScriptsDir, script),
                    path.join(BUILD_DIR, 'scripts', 'enhanced', script)
                );
            }
        });
        console.log(chalk.green(`✓ Copied ${enhancedScripts.filter(s => s.endsWith('.applescript')).length} enhanced scripts`));
    }
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
}

// Create build report
function createBuildReport() {
    console.log(chalk.blue('📊 Creating build report...'));
    
    const report = {
        version: MANIFEST.version,
        buildDate: new Date().toISOString(),
        features: {
            original: ['add_task', 'list_inbox', 'today_tasks', 'complete_task', 'weekly_review'],
            enhanced: ['search_tasks', 'edit_task', 'batch_add_tasks', 'create_recurring_task', 
                      'list_projects', 'list_deferred_tasks', 'list_flagged_tasks', 'list_overdue_tasks']
        },
        files: {
            scripts: fs.readdirSync(path.join(BUILD_DIR, 'scripts')).filter(f => f.endsWith('.applescript')),
            enhancedScripts: fs.existsSync(path.join(BUILD_DIR, 'scripts', 'enhanced')) 
                ? fs.readdirSync(path.join(BUILD_DIR, 'scripts', 'enhanced')).filter(f => f.endsWith('.applescript'))
                : []
        },
        outputFile: OUTPUT_FILE,
        fileSize: fs.statSync(OUTPUT_FILE).size
    };
    
    fs.writeFileSync(
        path.join(DIST_DIR, 'build-report-enhanced.json'),
        JSON.stringify(report, null, 2)
    );
    
    console.log(chalk.green('✓ Build report created'));
    return report;
}

// Main build process
async function build() {
    console.log(chalk.cyan.bold('\n🔧 Building OmniFocus GTD Enhanced Extension\n'));
    
    try {
        cleanBuildDir();
        ensureDistDir();
        copySourceFiles();
        createManifest();
        await createArchive();
        validateArchive();
        const report = createBuildReport();
        
        console.log(chalk.green.bold('\n✅ Build completed successfully!\n'));
        console.log(chalk.white('📦 Output:'), chalk.yellow(OUTPUT_FILE));
        console.log(chalk.white('📊 Features:'), 
            chalk.cyan(`${report.features.original.length} original, ${report.features.enhanced.length} enhanced`));
        console.log(chalk.white('📏 Size:'), chalk.cyan(`${(report.fileSize / 1024).toFixed(2)} KB`));
        console.log(chalk.gray('\nInstall by dragging the .dxt file to Claude Desktop'));
        
    } catch (error) {
        console.error(chalk.red.bold('\n❌ Build failed!\n'));
        console.error(chalk.red(error.message));
        process.exit(1);
    }
}

// Run the build
build();
