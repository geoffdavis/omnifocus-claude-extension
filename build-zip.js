#!/usr/bin/env node

/**
 * Build script that creates a properly structured ZIP archive for Claude Desktop
 */

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

// Paths
const SRC_DIR = path.join(__dirname, 'src');
const DIST_DIR = path.join(__dirname, 'dist');
const BUILD_DIR = path.join(__dirname, 'build');

// Ensure directories exist
if (!fs.existsSync(DIST_DIR)) {
    fs.mkdirSync(DIST_DIR, { recursive: true });
}
if (!fs.existsSync(BUILD_DIR)) {
    fs.mkdirSync(BUILD_DIR, { recursive: true });
}

// Clean build directory
if (fs.existsSync(BUILD_DIR)) {
    fs.rmSync(BUILD_DIR, { recursive: true, force: true });
    fs.mkdirSync(BUILD_DIR);
}

console.log('Building OmniFocus Claude Extension...\n');

// Load manifest
const manifest = JSON.parse(fs.readFileSync(path.join(SRC_DIR, 'manifest.json'), 'utf8'));

// Load tools
const toolsDir = path.join(SRC_DIR, 'tools');
const scriptsDir = path.join(SRC_DIR, 'scripts');
const tools = [];

const toolFiles = fs.readdirSync(toolsDir).filter(f => f.endsWith('.json'));

for (const toolFile of toolFiles) {
    console.log(`Processing ${toolFile}...`);
    const tool = JSON.parse(fs.readFileSync(path.join(toolsDir, toolFile), 'utf8'));
    
    // Load the script
    const scriptPath = path.join(scriptsDir, tool.script);
    if (!fs.existsSync(scriptPath)) {
        console.warn(`Script not found: ${tool.script}`);
        continue;
    }
    
    const script = fs.readFileSync(scriptPath, 'utf8');
    
    // Build tool object
    const extensionTool = {
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters || { type: 'object', properties: {} },
        command: 'osascript',
        arguments: ['-e', script]
    };
    
    // Add parameter placeholders
    if (tool.parameters && tool.parameters.properties) {
        for (const param of Object.keys(tool.parameters.properties)) {
            extensionTool.arguments.push(`{{${param}}}`);
        }
    }
    
    tools.push(extensionTool);
}

// Build final extension object
const extension = {
    ...manifest,
    tools: tools
};

// Create the extension package structure in build directory
const extensionDir = path.join(BUILD_DIR, 'omnifocus-gtd');
fs.mkdirSync(extensionDir, { recursive: true });

// Write manifest.json (not extension.json)
fs.writeFileSync(
    path.join(extensionDir, 'manifest.json'),
    JSON.stringify(extension, null, 2)
);

// Also try with package.json name
fs.writeFileSync(
    path.join(extensionDir, 'package.json'),
    JSON.stringify({
        name: extension.id,
        version: extension.version,
        description: extension.description,
        author: extension.author,
        license: extension.license
    }, null, 2)
);

// Also write the full extension.json
fs.writeFileSync(
    path.join(extensionDir, 'extension.json'),
    JSON.stringify(extension, null, 2)
);

// Create README if it exists
if (extension.readme) {
    fs.writeFileSync(
        path.join(extensionDir, 'README.md'),
        extension.readme
    );
}

// Create the archive
async function createZip() {
    return new Promise((resolve, reject) => {
        const outputPath = path.join(DIST_DIR, 'omnifocus-gtd.dxt');
        const output = fs.createWriteStream(outputPath);
        const archive = archiver('zip', {
            zlib: { level: 9 }
        });

        output.on('close', () => {
            console.log(`\n✅ Extension built: ${outputPath}`);
            console.log(`   Size: ${(archive.pointer() / 1024).toFixed(2)} KB`);
            console.log(`   Tools: ${tools.length}`);
            resolve();
        });

        archive.on('error', (err) => {
            reject(err);
        });

        archive.pipe(output);
        
        // Add the entire extension directory
        archive.directory(extensionDir, false);
        
        archive.finalize();
    });
}

// Also create a version with just the files at root level
async function createFlatZip() {
    return new Promise((resolve, reject) => {
        const outputPath = path.join(DIST_DIR, 'omnifocus-gtd-flat.dxt');
        const output = fs.createWriteStream(outputPath);
        const archive = archiver('zip', {
            zlib: { level: 9 }
        });

        output.on('close', () => {
            console.log(`\n✅ Flat extension built: ${outputPath}`);
            console.log(`   Size: ${(archive.pointer() / 1024).toFixed(2)} KB`);
            resolve();
        });

        archive.on('error', (err) => {
            reject(err);
        });

        archive.pipe(output);
        
        // Add files directly at root
        archive.file(path.join(extensionDir, 'manifest.json'), { name: 'manifest.json' });
        archive.file(path.join(extensionDir, 'extension.json'), { name: 'extension.json' });
        archive.file(path.join(extensionDir, 'package.json'), { name: 'package.json' });
        if (fs.existsSync(path.join(extensionDir, 'README.md'))) {
            archive.file(path.join(extensionDir, 'README.md'), { name: 'README.md' });
        }
        
        archive.finalize();
    });
}

// Run both builds
Promise.all([createZip(), createFlatZip()])
    .then(() => {
        // Clean up
        fs.rmSync(BUILD_DIR, { recursive: true, force: true });
        console.log('\n🎉 Build complete! Created two versions to test:');
        console.log('1. dist/omnifocus-gtd.dxt (nested structure)');
        console.log('2. dist/omnifocus-gtd-flat.dxt (flat structure)');
        console.log('\nTry both with Claude Desktop to see which works.');
    })
    .catch(err => {
        console.error('Build failed:', err);
        process.exit(1);
    });