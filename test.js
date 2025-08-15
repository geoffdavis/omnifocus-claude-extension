#!/usr/bin/env node

/**
 * Test script for OmniFocus Claude Extension
 * Validates the build and structure
 */

const fs = require('fs');
const path = require('path');
const { loadManifest, loadTools } = require('./build');

const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m'
};

let testsPassed = 0;
let testsFailed = 0;

function test(name, fn) {
    try {
        fn();
        console.log(`${colors.green}✓${colors.reset} ${name}`);
        testsPassed++;
    } catch (error) {
        console.log(`${colors.red}✗${colors.reset} ${name}`);
        console.log(`  ${colors.yellow}${error.message}${colors.reset}`);
        testsFailed++;
    }
}

function assert(condition, message) {
    if (!condition) {
        throw new Error(message || 'Assertion failed');
    }
}

console.log('Running tests...\n');

// Test manifest
test('Manifest exists and is valid', () => {
    const manifest = loadManifest();
    assert(manifest.id === 'omnifocus-gtd', 'ID should be omnifocus-gtd');
    assert(manifest.name, 'Name is required');
    assert(manifest.version, 'Version is required');
    assert(manifest.description, 'Description is required');
});

// Test tools directory
test('Tools directory exists', () => {
    const toolsDir = path.join(__dirname, 'src', 'tools');
    assert(fs.existsSync(toolsDir), 'src/tools directory should exist');
});

// Test scripts directory
test('Scripts directory exists', () => {
    const scriptsDir = path.join(__dirname, 'src', 'scripts');
    assert(fs.existsSync(scriptsDir), 'src/scripts directory should exist');
});

// Test tool loading
test('Tools can be loaded', () => {
    const tools = loadTools();
    assert(Array.isArray(tools), 'Tools should be an array');
    assert(tools.length > 0, 'Should have at least one tool');
});

// Test tool structure
test('Tools have required fields', () => {
    const tools = loadTools();
    for (const tool of tools) {
        assert(tool.name, `Tool should have a name`);
        assert(tool.description, `Tool ${tool.name} should have a description`);
        assert(tool.command === 'osascript', `Tool ${tool.name} should use osascript`);
        assert(Array.isArray(tool.arguments), `Tool ${tool.name} should have arguments array`);
    }
});

// Test AppleScript files
test('AppleScript files exist for each tool', () => {
    const toolsDir = path.join(__dirname, 'src', 'tools');
    const scriptsDir = path.join(__dirname, 'src', 'scripts');
    
    const toolFiles = fs.readdirSync(toolsDir).filter(f => f.endsWith('.json'));
    
    for (const toolFile of toolFiles) {
        const tool = JSON.parse(fs.readFileSync(path.join(toolsDir, toolFile), 'utf8'));
        const scriptPath = path.join(scriptsDir, tool.script);
        assert(fs.existsSync(scriptPath), `Script ${tool.script} should exist for tool ${tool.name}`);
    }
});

// Summary
console.log('\n' + '='.repeat(40));
console.log(`Tests: ${colors.green}${testsPassed} passed${colors.reset}, ${testsFailed > 0 ? colors.red : ''}${testsFailed} failed${colors.reset}`);
console.log('='.repeat(40));

process.exit(testsFailed > 0 ? 1 : 0);