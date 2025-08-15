#!/usr/bin/env node

/**
 * Test script for OmniFocus MCP Server
 * Simulates Claude Desktop communication to verify the server works
 */

const { spawn } = require('child_process');
const path = require('path');

// Console colors
const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m'
};

const log = {
    info: (msg) => console.log(`${colors.blue}[TEST]${colors.reset} ${msg}`),
    success: (msg) => console.log(`${colors.green}[PASS]${colors.reset} ${msg}`),
    error: (msg) => console.log(`${colors.red}[FAIL]${colors.reset} ${msg}`),
    warning: (msg) => console.log(`${colors.yellow}[WARN]${colors.reset} ${msg}`)
};

// Test cases
const tests = [
    {
        name: 'Initialize',
        request: {
            jsonrpc: '2.0',
            id: 1,
            method: 'initialize',
            params: {
                protocolVersion: '2025-06-18',
                capabilities: {},
                clientInfo: {
                    name: 'test-client',
                    version: '1.0.0'
                }
            }
        },
        validate: (response) => {
            return response.result && 
                   response.result.protocolVersion === '2025-06-18' &&
                   response.result.serverInfo.name === 'omnifocus-gtd';
        }
    },
    {
        name: 'List Tools',
        request: {
            jsonrpc: '2.0',
            id: 2,
            method: 'tools/list',
            params: {}
        },
        validate: (response) => {
            return response.result && 
                   response.result.tools &&
                   response.result.tools.length === 5;
        }
    },
    {
        name: 'Call Tool - List Inbox',
        request: {
            jsonrpc: '2.0',
            id: 3,
            method: 'tools/call',
            params: {
                name: 'list_inbox',
                arguments: {}
            }
        },
        validate: (response) => {
            return response.result && 
                   response.result.content &&
                   response.result.content[0].type === 'text';
        }
    }
];

// Run tests
async function runTests() {
    log.info('Starting MCP Server tests...\n');
    
    const serverPath = path.join(__dirname, 'src', 'server', 'index.js');
    
    // Check if server exists
    const fs = require('fs');
    if (!fs.existsSync(serverPath)) {
        log.error(`Server not found at ${serverPath}`);
        process.exit(1);
    }
    
    // Spawn server process
    // Use full path to node for compatibility
    const nodePath = process.execPath || '/opt/homebrew/bin/node';
    const server = spawn(nodePath, [serverPath], {
        stdio: ['pipe', 'pipe', 'pipe']
    });
    
    let responseBuffer = '';
    let testIndex = 0;
    let passedTests = 0;
    let failedTests = 0;
    
    // Handle server output
    server.stdout.on('data', (data) => {
        responseBuffer += data.toString();
        
        // Try to parse complete JSON responses
        const lines = responseBuffer.split('\n');
        responseBuffer = lines[lines.length - 1]; // Keep incomplete line
        
        for (let i = 0; i < lines.length - 1; i++) {
            const line = lines[i].trim();
            if (line) {
                try {
                    const response = JSON.parse(line);
                    handleResponse(response);
                } catch (e) {
                    log.warning(`Failed to parse response: ${line}`);
                }
            }
        }
    });
    
    // Handle server errors
    server.stderr.on('data', (data) => {
        const message = data.toString().trim();
        if (message.includes('[OmniFocus Server]')) {
            // Server logs, ignore for test output
        } else {
            log.warning(`Server error: ${message}`);
        }
    });
    
    // Handle response validation
    function handleResponse(response) {
        if (testIndex < tests.length) {
            const test = tests[testIndex];
            
            if (test.validate(response)) {
                log.success(`${test.name}`);
                passedTests++;
            } else {
                log.error(`${test.name}`);
                log.error(`  Response: ${JSON.stringify(response, null, 2)}`);
                failedTests++;
            }
            
            testIndex++;
            
            // Run next test or finish
            if (testIndex < tests.length) {
                setTimeout(() => sendRequest(tests[testIndex].request), 100);
            } else {
                // All tests complete
                setTimeout(() => {
                    log.info(`\nTest Results:`);
                    log.info(`  Passed: ${passedTests}`);
                    log.info(`  Failed: ${failedTests}`);
                    
                    if (failedTests === 0) {
                        log.success('All tests passed! ✨');
                    } else {
                        log.error('Some tests failed.');
                    }
                    
                    // Cleanup
                    server.kill();
                    process.exit(failedTests > 0 ? 1 : 0);
                }, 100);
            }
        }
    }
    
    // Send request to server
    function sendRequest(request) {
        const requestStr = JSON.stringify(request) + '\n';
        server.stdin.write(requestStr);
        log.info(`Sent: ${request.method}`);
    }
    
    // Start with first test
    setTimeout(() => {
        sendRequest(tests[0].request);
    }, 500); // Wait for server to start
    
    // Timeout handler
    setTimeout(() => {
        log.error('Tests timed out');
        server.kill();
        process.exit(1);
    }, 10000);
}

// Run the tests
runTests().catch(error => {
    log.error(`Test runner error: ${error.message}`);
    process.exit(1);
});
