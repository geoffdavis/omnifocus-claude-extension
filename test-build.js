#!/usr/bin/env node

/**
 * Test build script to validate the DXT build process
 */

const { spawn } = require('child_process');
const path = require('path');

console.log('🧪 Testing DXT Build Process...\n');

// Run the build
const build = spawn('node', ['build-dxt.js'], {
    cwd: __dirname,
    stdio: 'pipe'
});

let output = '';
let errorOutput = '';

build.stdout.on('data', (data) => {
    output += data.toString();
    process.stdout.write(data);
});

build.stderr.on('data', (data) => {
    errorOutput += data.toString();
    process.stderr.write(data);
});

build.on('close', (code) => {
    console.log('\n' + '='.repeat(50));
    
    if (code !== 0) {
        console.log('❌ Build failed with code:', code);
        if (errorOutput) {
            console.log('\nErrors:');
            console.log(errorOutput);
        }
    } else {
        console.log('✅ Build completed successfully!');
        
        // Now validate the output
        console.log('\n🔍 Running validation...\n');
        
        const validate = spawn('node', ['validate-dxt.js'], {
            cwd: __dirname,
            stdio: 'inherit'
        });
        
        validate.on('close', (validateCode) => {
            if (validateCode === 0) {
                console.log('\n🎉 All validations passed!');
            } else {
                console.log('\n⚠️ Validation found issues');
            }
            process.exit(validateCode);
        });
    }
});
