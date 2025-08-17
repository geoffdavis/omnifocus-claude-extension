#!/usr/bin/env node

/**
 * Build Script for OmniFocus Claude Extension v2.0
 * Creates a DXT package following the official specification
 */

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

// Simple console colors using ANSI codes
const colors = {
    reset: '\x1b[0m',
    bold: '\x1b[1m',
    blue: '\x1b[34m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    cyan: '\x1b[36m',
    white: '\x1b[37m',
    gray: '\x1b[90m'
};

// Helper functions for colored output
const log = {
    blue: (msg) => console.log(colors.blue + msg + colors.reset),
    green: (msg) => console.log(colors.green + msg + colors.reset),
    red: (msg) => console.log(colors.red + msg + colors.reset),
    yellow: (msg) => console.log(colors.yellow + msg + colors.reset),
    cyan: (msg) => console.log(colors.cyan + msg + colors.reset),
    white: (msg) => console.log(colors.white + msg + colors.reset),
    gray: (msg) => console.log(colors.gray + msg + colors.reset),
    bold: {
        cyan: (msg) => console.log(colors.bold + colors.cyan + msg + colors.reset),
        green: (msg) => console.log(colors.bold + colors.green + msg + colors.reset),
        red: (msg) => console.log(colors.bold + colors.red + msg + colors.reset)
    }
};

// Configuration
const BUILD_DIR = path.join(__dirname, 'extension-build');
const DIST_DIR = path.join(__dirname, 'dist');
const OUTPUT_FILE = path.join(DIST_DIR, 'omnifocus-gtd.dxt');

// Official DXT manifest format based on documentation
const MANIFEST = {
    dxt_version: '0.1',  // Official version from docs (not 0.1.0 or 0.0.1)
    name: 'OmniFocus GTD',
    version: '2.0.0',
    description: 'Complete OmniFocus task management with search, batch operations, recurring tasks, and comprehensive GTD features.',
    author: {
        name: 'Community Contributors'
        // email is optional, not required
    },
    server: {
        type: 'node',  // Added type field
        entry_point: 'server/index.js',  // Changed from nested mcp_config
        mcp_config: {
            command: 'node',
            args: ['${__dirname}/server/index.js']  // Use template literal
        }
    }
    // Removed all optional fields to focus on required ones
};

// Clean build directory
function cleanBuildDir() {
    log.blue('🧹 Cleaning build directory...');
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
    log.blue('📁 Copying source files...');
    
    // Create directory structure
    fs.mkdirSync(path.join(BUILD_DIR, 'server'), { recursive: true });
    fs.mkdirSync(path.join(BUILD_DIR, 'scripts'), { recursive: true });
    fs.mkdirSync(path.join(BUILD_DIR, 'scripts', 'enhanced'), { recursive: true });
    
    // Copy server
    fs.copyFileSync(
        path.join(__dirname, 'src', 'server', 'index.js'),
        path.join(BUILD_DIR, 'server', 'index.js')
    );
    log.green('✓ Copied server');
    
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
    log.green(`✓ Copied ${originalCount} original scripts`);
    
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
        log.green(`✓ Copied ${enhancedCount} enhanced scripts`);
    }
    
    return { originalCount, enhancedCount };
}

// Create manifest file
function createManifest() {
    log.blue('📝 Creating manifest...');
    const manifestPath = path.join(BUILD_DIR, 'manifest.json');
    fs.writeFileSync(manifestPath, JSON.stringify(MANIFEST, null, 2));
    log.green('✓ Manifest created');
    log.gray('Manifest content:');
    console.log(JSON.stringify(MANIFEST, null, 2));
}

// Create the DXT archive
async function createArchive() {
    log.blue('📦 Creating DXT archive...');
    
    return new Promise((resolve, reject) => {
        const output = fs.createWriteStream(OUTPUT_FILE);
        const archive = archiver('zip', {
            zlib: { level: 9 }
        });
        
        output.on('close', () => {
            const size = (archive.pointer() / 1024).toFixed(2);
            log.green(`✓ Archive created: ${size} KB`);
            resolve();
        });
        
        archive.on('error', (err) => {
            console.error(colors.red + '✗ Archive error:' + colors.reset, err);
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
    log.blue('🔍 Validating archive...');
    
    if (!fs.existsSync(OUTPUT_FILE)) {
        throw new Error('Output file not created');
    }
    
    const stats = fs.statSync(OUTPUT_FILE);
    if (stats.size < 1000) {
        throw new Error('Archive too small, likely corrupted');
    }
    
    log.green('✓ Archive validated');
    
    // Verify manifest in archive
    try {
        const { execSync } = require('child_process');
        const manifestInZip = execSync(`unzip -p "${OUTPUT_FILE}" manifest.json`, { 
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'ignore'] // Suppress stderr
        });
        log.gray('\nManifest in archive:');
        const manifest = JSON.parse(manifestInZip);
        console.log(JSON.stringify(manifest, null, 2));
    } catch (e) {
        log.yellow('Could not verify manifest in archive (unzip not available)');
    }
    
    return stats.size;
}

// Create build report
function createBuildReport(scriptCounts, fileSize) {
    log.blue('📊 Creating build report...');
    
    const report = {
        version: MANIFEST.version,
        dxt_version: MANIFEST.dxt_version,
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
    
    log.green('✓ Build report created');
    return report;
}

// Main build process
async function build() {
    log.bold.cyan('\n🔧 Building OmniFocus GTD Extension v2.0\n');
    
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
        
        log.bold.green('\n✅ Build completed successfully!\n');
        log.white('📦 Output: ' + colors.yellow + OUTPUT_FILE + colors.reset);
        log.white('📊 Features: ' + colors.cyan + 
            `${report.features.core.length} core, ${report.features.advanced.length} advanced, ${report.features.views.length} views` + 
            colors.reset);
        log.white('📝 Scripts: ' + colors.cyan + 
            `${report.scripts.total} total (${report.scripts.original} original + ${report.scripts.enhanced} enhanced)` + 
            colors.reset);
        log.white('📏 Size: ' + colors.cyan + `${(fileSize / 1024).toFixed(2)} KB` + colors.reset);
        log.gray('\nInstall by dragging the .dxt file to Claude Desktop');
        
    } catch (error) {
        log.bold.red('\n❌ Build failed!\n');
        log.red(error.message);
        process.exit(1);
    }
}

// Run the build
build();
