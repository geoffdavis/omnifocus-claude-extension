#!/usr/bin/env node

/**
 * Minimal Build Script for OmniFocus Claude Extension
 * Testing minimal manifest requirements
 */

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

const BUILD_DIR = path.join(__dirname, 'test-build');
const OUTPUT_FILE = path.join(__dirname, 'dist', 'omnifocus-test.dxt');

// Test with absolute minimal manifest
const MANIFEST = {
    dxt_version: '0.0.1',
    name: 'OmniFocus GTD',
    author: {
        name: 'Test'
    },
    server: {
        command: 'node',
        args: ['server/index.js']
    }
};

console.log('Building with minimal manifest:');
console.log(JSON.stringify(MANIFEST, null, 2));

// Clean and create build dir
if (fs.existsSync(BUILD_DIR)) {
    fs.rmSync(BUILD_DIR, { recursive: true, force: true });
}
fs.mkdirSync(BUILD_DIR, { recursive: true });
fs.mkdirSync(path.join(BUILD_DIR, 'server'), { recursive: true });

// Write manifest
fs.writeFileSync(
    path.join(BUILD_DIR, 'manifest.json'),
    JSON.stringify(MANIFEST, null, 2)
);

// Copy minimal server
fs.copyFileSync(
    path.join(__dirname, 'src', 'server', 'index.js'),
    path.join(BUILD_DIR, 'server', 'index.js')
);

// Create archive
const output = fs.createWriteStream(OUTPUT_FILE);
const archive = archiver('zip', { zlib: { level: 9 } });

output.on('close', () => {
    console.log(`Archive created: ${OUTPUT_FILE}`);
    console.log(`Size: ${(archive.pointer() / 1024).toFixed(2)} KB`);
    
    // Clean up
    fs.rmSync(BUILD_DIR, { recursive: true, force: true });
    
    // Verify manifest in archive
    const { execSync } = require('child_process');
    const manifestInZip = execSync(`unzip -p "${OUTPUT_FILE}" manifest.json`, { encoding: 'utf8' });
    console.log('\nManifest in archive:');
    console.log(manifestInZip);
});

archive.on('error', (err) => {
    console.error('Archive error:', err);
    process.exit(1);
});

archive.pipe(output);
archive.directory(BUILD_DIR, false);
archive.finalize();
