#!/usr/bin/env node

/**
 * Build script that creates a minimal working extension
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const DIST_DIR = path.join(__dirname, 'dist');

// Ensure dist exists
if (!fs.existsSync(DIST_DIR)) {
    fs.mkdirSync(DIST_DIR);
}

// Create a minimal test extension
const minimalExtension = {
  "identifier": "omnifocus-minimal",
  "name": "OmniFocus Minimal",
  "version": "1.0.0",
  "description": "Minimal OmniFocus extension for testing",
  "author": "Test",
  "tools": [
    {
      "name": "test",
      "description": "Test command",
      "inputSchema": {
        "type": "object",
        "properties": {}
      },
      "command": "echo",
      "args": ["Hello from OmniFocus extension"]
    }
  ]
};

// Write as JSON with different possible names
const outputPath1 = path.join(DIST_DIR, 'omnifocus-minimal.dxt');
fs.writeFileSync(outputPath1, JSON.stringify(minimalExtension, null, 2));

// Try with a simple zip containing just the JSON
const tempFile = path.join(DIST_DIR, 'temp.json');
fs.writeFileSync(tempFile, JSON.stringify(minimalExtension, null, 2));

try {
    execSync(`cd ${DIST_DIR} && zip -q omnifocus-minimal-zipped.dxt temp.json && rm temp.json`);
    console.log('Created omnifocus-minimal-zipped.dxt');
} catch (e) {
    console.log('Could not create zipped version');
}

console.log(`\nCreated test extensions in ${DIST_DIR}:`);
console.log('1. omnifocus-minimal.dxt (plain JSON)');
console.log('2. omnifocus-minimal-zipped.dxt (zipped JSON)');
console.log('\nThese use different field names that might be expected by Claude Desktop.');