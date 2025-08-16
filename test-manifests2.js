#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

async function buildMinimal() {
    const configs = [
        {
            name: 'test8-node-path.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test8",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "node",
                    "path": "server/index.js"
                }
            }
        },
        {
            name: 'test9-node-script.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test9",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "node",
                    "script": "server/index.js"
                }
            }
        },
        {
            name: 'test10-node-main.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test10",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "node",
                    "main": "server/index.js"
                }
            }
        },
        {
            name: 'test11-node-entry.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test11",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "node",
                    "entry": "server/index.js"
                }
            }
        },
        {
            name: 'test12-node-file.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test12",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "node",
                    "file": "server/index.js"
                }
            }
        },
        {
            name: 'test13-node-module.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test13",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "node",
                    "module": "server/index.js"
                }
            }
        }
    ];
    
    for (const config of configs) {
        const output = fs.createWriteStream(path.join(__dirname, 'dist', config.name));
        const archive = archiver('zip', { zlib: { level: 9 } });
        
        archive.pipe(output);
        archive.append(JSON.stringify(config.manifest, null, 2), { name: 'manifest.json' });
        
        // Add a minimal server file
        archive.append('console.log("test");', { name: 'server/index.js' });
        
        await new Promise((resolve, reject) => {
            output.on('close', resolve);
            archive.on('error', reject);
            archive.finalize();
        });
        
        console.log(`Built ${config.name}`);
    }
    
    console.log('\nTry these as well to find the right field name for the script path.');
}

buildMinimal();
