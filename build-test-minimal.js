#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

async function buildMinimal() {
    const output = fs.createWriteStream(path.join(__dirname, 'dist', 'test-minimal.dxt'));
    const archive = archiver('zip', { zlib: { level: 9 } });
    
    archive.pipe(output);
    
    // Add minimal manifest
    const manifest = {
        "dxt_version": "0.1",
        "name": "Test Extension",
        "version": "1.0.0",
        "description": "Test",
        "server": {
            "type": "node",
            "command": "node",
            "args": ["server/index.js"]
        }
    };
    
    archive.append(JSON.stringify(manifest, null, 2), { name: 'manifest.json' });
    
    // Add minimal server
    const server = `
console.log(JSON.stringify({jsonrpc: "2.0", id: 1, result: {protocolVersion: "2025-06-18"}}));
    `;
    
    archive.append(server, { name: 'server/index.js' });
    
    await archive.finalize();
    console.log('Built test-minimal.dxt');
}

buildMinimal();
