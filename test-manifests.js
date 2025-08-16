#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

async function buildMinimal() {
    const configs = [
        {
            name: 'test1-node-basic.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test1",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "node"
                }
            }
        },
        {
            name: 'test2-node-command.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test2",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "node",
                    "command": "node"
                }
            }
        },
        {
            name: 'test3-node-command-args.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test3",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "node",
                    "command": "node",
                    "args": ["index.js"]
                }
            }
        },
        {
            name: 'test4-python-basic.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test4",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "python"
                }
            }
        },
        {
            name: 'test5-python-command.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test5",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "python",
                    "command": "python3"
                }
            }
        },
        {
            name: 'test6-binary-basic.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test6",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "binary"
                }
            }
        },
        {
            name: 'test7-binary-command.dxt',
            manifest: {
                "dxt_version": "0.1",
                "name": "Test7",
                "version": "1.0.0",
                "description": "Test",
                "server": {
                    "type": "binary",
                    "command": "echo"
                }
            }
        }
    ];
    
    for (const config of configs) {
        const output = fs.createWriteStream(path.join(__dirname, 'dist', config.name));
        const archive = archiver('zip', { zlib: { level: 9 } });
        
        archive.pipe(output);
        archive.append(JSON.stringify(config.manifest, null, 2), { name: 'manifest.json' });
        
        await new Promise((resolve, reject) => {
            output.on('close', resolve);
            archive.on('error', reject);
            archive.finalize();
        });
        
        console.log(`Built ${config.name}`);
    }
    
    console.log('\nNow try each file in Claude Desktop to see which error each gives.');
}

buildMinimal();
