#!/usr/bin/env node

/**
 * Build script for OmniFocus Claude Extension
 * Generates a .dxt file from source files
 */

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

// ANSI color codes for terminal output
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    dim: '\x1b[2m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m'
};

// Helper functions for colored output
const log = {
    info: (msg) => console.log(`${colors.blue}ℹ${colors.reset}  ${msg}`),
    success: (msg) => console.log(`${colors.green}✓${colors.reset}  ${msg}`),
    warning: (msg) => console.log(`${colors.yellow}⚠${colors.reset}  ${msg}`),
    error: (msg) => console.log(`${colors.red}✗${colors.reset}  ${msg}`),
    header: (msg) => console.log(`\n${colors.bright}${colors.cyan}${msg}${colors.reset}`),
    item: (msg) => console.log(`  ${colors.dim}•${colors.reset} ${msg}`)
};

// Paths
const BASE_DIR = __dirname;
const SRC_DIR = path.join(BASE_DIR, 'src');
const DIST_DIR = path.join(BASE_DIR, 'dist');
const BUILD_DIR = path.join(BASE_DIR, 'build');

// Watch mode flag
const isWatchMode = process.argv.includes('--watch');

/**
 * Ensure required directories exist
 */
function ensureDirectories() {
    [DIST_DIR, BUILD_DIR].forEach(dir => {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
            log.info(`Created directory: ${path.basename(dir)}/`);
        }
    });
}

/**
 * Load and validate manifest
 */
function loadManifest() {
    const manifestPath = path.join(SRC_DIR, 'manifest.json');
    
    if (!fs.existsSync(manifestPath)) {
        throw new Error(`Manifest not found: ${manifestPath}`);
    }
    
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    
    // Validate required fields
    const required = ['id', 'name', 'version', 'description'];
    for (const field of required) {
        if (!manifest[field]) {
            throw new Error(`Missing required field in manifest: ${field}`);
        }
    }
    
    return manifest;
}

/**
 * Load a tool definition and its script
 */
function loadTool(toolFile) {
    const toolPath = path.join(SRC_DIR, 'tools', toolFile);
    const tool = JSON.parse(fs.readFileSync(toolPath, 'utf8'));
    
    // Load the corresponding AppleScript
    const scriptPath = path.join(SRC_DIR, 'scripts', tool.script);
    
    if (!fs.existsSync(scriptPath)) {
        log.warning(`Script not found for ${tool.name}: ${tool.script}`);
        return null;
    }
    
    const script = fs.readFileSync(scriptPath, 'utf8');
    
    // Build the tool object for the extension
    const extensionTool = {
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters || { type: 'object', properties: {} },
        command: 'osascript',
        arguments: ['-e', script]
    };
    
    // Add parameter placeholders to arguments
    if (tool.parameters && tool.parameters.properties) {
        const params = Object.keys(tool.parameters.properties);
        if (tool.parameters.required) {
            // Add required params first
            for (const param of tool.parameters.required) {
                extensionTool.arguments.push(`{{${param}}}`);
            }
            // Then optional params
            for (const param of params) {
                if (!tool.parameters.required.includes(param)) {
                    extensionTool.arguments.push(`{{${param}}}`);
                }
            }
        } else {
            // Add all params if no required array specified
            for (const param of params) {
                extensionTool.arguments.push(`{{${param}}}`);
            }
        }
    }
    
    return extensionTool;
}

/**
 * Load all tools from the tools directory
 */
function loadTools() {
    const toolsDir = path.join(SRC_DIR, 'tools');
    
    if (!fs.existsSync(toolsDir)) {
        log.warning('No tools directory found');
        return [];
    }
    
    const tools = [];
    const toolFiles = fs.readdirSync(toolsDir).filter(f => f.endsWith('.json'));
    
    log.header('Processing tools:');
    
    for (const toolFile of toolFiles) {
        log.item(`Loading ${toolFile}`);
        const tool = loadTool(toolFile);
        if (tool) {
            tools.push(tool);
            log.success(`  Loaded ${tool.name}`);
        }
    }
    
    return tools;
}

/**
 * Create the .dxt file as a plain JSON (not zipped)
 * Claude Desktop appears to expect plain JSON, not a zip archive
 */
async function createExtensionFile(extension) {
    const outputPath = path.join(DIST_DIR, 'omnifocus-gtd.dxt');
    
    // Write the extension directly as JSON
    fs.writeFileSync(outputPath, JSON.stringify(extension, null, 2));
    
    return {
        path: outputPath,
        size: fs.statSync(outputPath).size
    };
}

/**
 * Create the .dxt archive (alternative method using zip)
 */
async function createArchive(extension) {
    const outputPath = path.join(DIST_DIR, 'omnifocus-gtd.dxt.zip');
    const tempJsonPath = path.join(BUILD_DIR, 'manifest.json');
    
    // Write the extension JSON with proper name
    fs.writeFileSync(tempJsonPath, JSON.stringify(extension, null, 2));
    
    return new Promise((resolve, reject) => {
        const output = fs.createWriteStream(outputPath);
        const archive = archiver('zip', {
            zlib: { level: 9 } // Maximum compression
        });
        
        output.on('close', () => {
            // Rename to .dxt
            const finalPath = outputPath.replace('.zip', '');
            fs.renameSync(outputPath, finalPath);
            resolve({
                path: finalPath,
                size: archive.pointer()
            });
        });
        
        archive.on('error', (err) => {
            reject(err);
        });
        
        archive.pipe(output);
        
        // Add the manifest.json file (not extension.json)
        archive.file(tempJsonPath, { name: 'manifest.json' });
        
        archive.finalize();
    });
}

/**
 * Clean build directory
 */
function cleanBuildDir() {
    if (fs.existsSync(BUILD_DIR)) {
        fs.rmSync(BUILD_DIR, { recursive: true, force: true });
    }
}

/**
 * Main build function
 */
async function build() {
    const startTime = Date.now();
    
    log.header('🔨 Building OmniFocus Claude Extension');
    
    try {
        // Ensure directories exist
        ensureDirectories();
        
        // Load manifest
        log.info('Loading manifest...');
        const manifest = loadManifest();
        log.success(`Extension: ${manifest.name} v${manifest.version}`);
        
        // Load tools
        const tools = loadTools();
        log.success(`Loaded ${tools.length} tools`);
        
        // Build the extension object
        const extension = {
            ...manifest,
            tools: tools
        };
        
        // Create the extension file
        log.header('📦 Creating extension file:');
        log.info('Writing .dxt file...');
        
        // Try plain JSON first (seems to be what Claude expects)
        const result = await createExtensionFile(extension);
        
        // Also create a zipped version for testing
        log.info('Creating zipped version for testing...');
        await createArchive(extension);
        
        // Clean up
        cleanBuildDir();
        
        // Output summary
        const buildTime = Date.now() - startTime;
        const sizeKB = (result.size / 1024).toFixed(2);
        
        log.header('✨ Build Complete!');
        log.success(`Extension: ${manifest.name} v${manifest.version}`);
        log.success(`Tools: ${tools.length}`);
        log.success(`Output: ${result.path}`);
        log.success(`Size: ${sizeKB} KB`);
        log.success(`Time: ${buildTime}ms`);
        log.info('Also created: dist/omnifocus-gtd.dxt.zip (for testing)');
        
        if (isWatchMode) {
            log.header('👁  Watching for changes...');
            watchFiles();
        }
        
    } catch (error) {
        log.error(`Build failed: ${error.message}`);
        console.error(error);
        process.exit(1);
    }
}

/**
 * Watch for file changes
 */
function watchFiles() {
    const chokidar = require('chokidar');
    
    const watcher = chokidar.watch([
        path.join(SRC_DIR, '**/*.json'),
        path.join(SRC_DIR, '**/*.applescript')
    ], {
        ignored: /(^|[\/\\])\../, // ignore dotfiles
        persistent: true
    });
    
    let buildTimeout;
    
    watcher.on('change', (filepath) => {
        log.info(`File changed: ${path.basename(filepath)}`);
        
        // Debounce builds
        clearTimeout(buildTimeout);
        buildTimeout = setTimeout(() => {
            log.header('🔄 Rebuilding...');
            build();
        }, 500);
    });
}

// Run the build
if (require.main === module) {
    build().catch(error => {
        log.error(error.message);
        process.exit(1);
    });
}

module.exports = { build, loadManifest, loadTools };