#!/usr/bin/env node

/**
 * Build script for OmniFocus DXT Extension (Working Version)
 * Creates a minimal .dxt file with embedded MCP server
 */

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

// Paths
const BASE_DIR = __dirname;
const DIST_DIR = path.join(BASE_DIR, 'dist');
const BUILD_DIR = path.join(BASE_DIR, 'build-temp-fixed');

// Ensure directories exist
[DIST_DIR, BUILD_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
});

console.log('🔨 Building Fixed OmniFocus DXT Extension...\n');

// Clean previous build
if (fs.existsSync(BUILD_DIR)) {
    fs.rmSync(BUILD_DIR, { recursive: true, force: true });
}
fs.mkdirSync(BUILD_DIR, { recursive: true });

// Create manifest.json for the DXT format
const manifest = {
    "dxt_version": "0.1",
    "name": "OmniFocus GTD",
    "version": "1.0.0", 
    "description": "Complete OmniFocus task management integration for Claude Desktop",
    "author": {
        "name": "Geoff Davis",
        "email": "geoff@geoffdavis.com"
    },
    "server": {
        "type": "stdio",
        "run": {
            "command": "node",
            "args": ["server.js"]
        }
    },
    "tools": [
        {
            "name": "add_task",
            "description": "Add a new task to OmniFocus inbox or specific project",
            "parameters": {
                "type": "object",
                "properties": {
                    "name": { "type": "string", "description": "The task name/title" },
                    "note": { "type": "string", "description": "Optional note or description for the task" },
                    "project": { "type": "string", "description": "Optional project name to add the task to" },
                    "due_date": { "type": "string", "description": "Optional due date (e.g., 'tomorrow', 'next week', 'Friday')" },
                    "flagged": { "type": "boolean", "description": "Whether to flag this task as important", "default": false }
                },
                "required": ["name"]
            }
        },
        {
            "name": "list_inbox",
            "description": "List all tasks currently in the OmniFocus inbox",
            "parameters": { "type": "object", "properties": {} }
        },
        {
            "name": "today_tasks", 
            "description": "List all tasks due today",
            "parameters": { "type": "object", "properties": {} }
        },
        {
            "name": "complete_task",
            "description": "Mark a task as complete by searching for it by name",
            "parameters": {
                "type": "object",
                "properties": {
                    "task_name": { "type": "string", "description": "Name or partial name of the task to complete" }
                },
                "required": ["task_name"]
            }
        },
        {
            "name": "weekly_review",
            "description": "Get a comprehensive weekly review summary", 
            "parameters": { "type": "object", "properties": {} }
        }
    ]
};

// Copy the MCP server we just created
const serverSource = path.join(BASE_DIR, 'mcp-server.js');
const serverDest = path.join(BUILD_DIR, 'server.js');

if (!fs.existsSync(serverSource)) {
    console.error('❌ mcp-server.js not found. Please create it first.');
    process.exit(1);
}

fs.copyFileSync(serverSource, serverDest);

// Write the manifest
fs.writeFileSync(path.join(BUILD_DIR, 'manifest.json'), JSON.stringify(manifest, null, 2));

// Create the .dxt archive
async function createDxtArchive() {
    return new Promise((resolve, reject) => {
        const outputPath = path.join(DIST_DIR, 'omnifocus-gtd-fixed.dxt');
        const output = fs.createWriteStream(outputPath);
        const archive = archiver('zip', {
            zlib: { level: 9 }
        });

        output.on('close', () => {
            console.log(`✅ Fixed extension built: ${outputPath}`);
            console.log(`   Size: ${(archive.pointer() / 1024).toFixed(2)} KB`);
            console.log(`   Tools: ${manifest.tools.length}`);
            resolve();
        });

        archive.on('error', reject);
        archive.pipe(output);
        
        // Add files to archive
        archive.file(path.join(BUILD_DIR, 'manifest.json'), { name: 'manifest.json' });
        archive.file(serverDest, { name: 'server.js' });
        
        archive.finalize();
    });
}

// Build the extension
createDxtArchive()
    .then(() => {
        // Clean up
        fs.rmSync(BUILD_DIR, { recursive: true, force: true });
        console.log('\n🎉 Fixed build complete!');
        console.log('📦 Install by dragging dist/omnifocus-gtd-fixed.dxt onto Claude Desktop');
        console.log('\n💡 If it still crashes, check that:');
        console.log('   • OmniFocus is installed and accessible');
        console.log('   • Node.js is available in your PATH');
        console.log('   • The extension has permissions to run AppleScript');
    })
    .catch((error) => {
        console.error('❌ Build failed:', error);
        process.exit(1);
    });
