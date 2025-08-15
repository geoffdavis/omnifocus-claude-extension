#!/usr/bin/env node

/**
 * Simple build script that creates a plain JSON .dxt file
 */

const fs = require('fs');
const path = require('path');

// Paths
const SRC_DIR = path.join(__dirname, 'src');
const DIST_DIR = path.join(__dirname, 'dist');

// Ensure dist directory exists
if (!fs.existsSync(DIST_DIR)) {
    fs.mkdirSync(DIST_DIR, { recursive: true });
}

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

// Write as plain JSON with .dxt extension
const outputPath = path.join(DIST_DIR, 'omnifocus-gtd.dxt');
fs.writeFileSync(outputPath, JSON.stringify(extension, null, 2));

console.log(`✅ Built extension: ${outputPath}`);
console.log(`   Tools: ${tools.length}`);
console.log(`   Size: ${(fs.statSync(outputPath).size / 1024).toFixed(2)} KB`);