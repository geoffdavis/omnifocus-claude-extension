#!/usr/bin/env node

/**
 * OmniFocus MCP Server
 * A minimal MCP server implementation for OmniFocus integration
 * Compatible with Claude Desktop Extension format
 */

const readline = require('readline');
const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// Initialize stdio interface
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
});

// Server state
let serverCapabilities = {};
let clientCapabilities = {};
let initialized = false;

// Log to stderr to avoid interfering with JSON-RPC communication
function log(...args) {
    console.error('[OmniFocus Server]', ...args);
}

// Send JSON-RPC response
function sendResponse(id, result, error = null) {
    const response = {
        jsonrpc: '2.0',
        id
    };
    
    if (error) {
        response.error = error;
    } else {
        response.result = result;
    }
    
    const responseStr = JSON.stringify(response);
    console.log(responseStr);
    log('Response:', responseStr);
}

// Send JSON-RPC notification
function sendNotification(method, params) {
    const notification = {
        jsonrpc: '2.0',
        method,
        params
    };
    
    console.log(JSON.stringify(notification));
}

// Tool definitions
const tools = [
    {
        name: 'add_task',
        description: 'Add a new task to OmniFocus inbox or specific project',
        inputSchema: {
            type: 'object',
            properties: {
                name: {
                    type: 'string',
                    description: 'The task name/title'
                },
                note: {
                    type: 'string',
                    description: 'Optional note or description for the task'
                },
                project: {
                    type: 'string',
                    description: 'Optional project name to add the task to'
                },
                due_date: {
                    type: 'string',
                    description: 'Optional due date (e.g., "tomorrow", "next week", "Friday")'
                },
                flagged: {
                    type: 'boolean',
                    description: 'Whether to flag this task as important',
                    default: false
                }
            },
            required: ['name']
        }
    },
    {
        name: 'list_inbox',
        description: 'List all tasks currently in the OmniFocus inbox',
        inputSchema: {
            type: 'object',
            properties: {}
        }
    },
    {
        name: 'today_tasks',
        description: 'List all tasks due today',
        inputSchema: {
            type: 'object',
            properties: {}
        }
    },
    {
        name: 'complete_task',
        description: 'Mark a task as complete by searching for it by name',
        inputSchema: {
            type: 'object',
            properties: {
                task_name: {
                    type: 'string',
                    description: 'Name or partial name of the task to complete'
                }
            },
            required: ['task_name']
        }
    },
    {
        name: 'weekly_review',
        description: 'Get a comprehensive weekly review summary',
        inputSchema: {
            type: 'object',
            properties: {}
        }
    }
];

// Load AppleScript files
function loadScript(scriptName) {
    try {
        const scriptPath = path.join(__dirname, '..', 'scripts', `${scriptName}.applescript`);
        if (fs.existsSync(scriptPath)) {
            return fs.readFileSync(scriptPath, 'utf8');
        }
        log(`Script not found: ${scriptPath}`);
        return null;
    } catch (error) {
        log(`Error loading script ${scriptName}:`, error.message);
        return null;
    }
}

// Execute AppleScript
function executeAppleScript(script, args = {}) {
    try {
        // Replace template variables in script
        let processedScript = script;
        for (const [key, value] of Object.entries(args)) {
            // Escape values for AppleScript
            const escapedValue = String(value)
                .replace(/\\/g, '\\\\')
                .replace(/"/g, '\\"');
            processedScript = processedScript.replace(new RegExp(`\\$\\{${key}\\}`, 'g'), escapedValue);
        }
        
        // Execute the script
        const result = execSync(`osascript -e '${processedScript.replace(/'/g, "'\"'\"'")}'`, {
            encoding: 'utf8',
            maxBuffer: 1024 * 1024
        });
        
        return result.trim();
    } catch (error) {
        log('AppleScript execution error:', error.message);
        throw new Error(`AppleScript execution failed: ${error.message}`);
    }
}

// Handle tool execution
async function executeTool(name, args) {
    log(`Executing tool: ${name} with args:`, args);
    
    const tool = tools.find(t => t.name === name);
    if (!tool) {
        throw new Error(`Unknown tool: ${name}`);
    }
    
    // Load the corresponding AppleScript
    const script = loadScript(name);
    if (!script) {
        // Fallback to a simple implementation
        return executeSimpleTool(name, args);
    }
    
    try {
        const result = executeAppleScript(script, args || {});
        return {
            content: [
                {
                    type: 'text',
                    text: result
                }
            ]
        };
    } catch (error) {
        return {
            content: [
                {
                    type: 'text',
                    text: `Error: ${error.message}`
                }
            ],
            isError: true
        };
    }
}

// Simple fallback implementations
function executeSimpleTool(name, args) {
    let script = '';
    
    switch (name) {
        case 'add_task':
            script = `
                tell application "OmniFocus"
                    tell default document
                        set newTask to make new inbox task with properties {name:"${args.name || 'New Task'}"}
                        ${args.note ? `set note of newTask to "${args.note}"` : ''}
                        ${args.flagged ? 'set flagged of newTask to true' : ''}
                        return "Task added: " & name of newTask
                    end tell
                end tell
            `;
            break;
            
        case 'list_inbox':
            script = `
                tell application "OmniFocus"
                    tell default document
                        set inboxTasks to every inbox task
                        if (count of inboxTasks) = 0 then
                            return "Inbox is empty"
                        else
                            set taskList to ""
                            repeat with aTask in inboxTasks
                                set taskList to taskList & "• " & name of aTask & return
                            end repeat
                            return "Inbox tasks:" & return & taskList
                        end if
                    end tell
                end tell
            `;
            break;
            
        case 'today_tasks':
            script = `
                tell application "OmniFocus"
                    tell default document
                        set todayStart to current date
                        set hours of todayStart to 0
                        set minutes of todayStart to 0
                        set seconds of todayStart to 0
                        
                        set todayEnd to todayStart + (1 * days)
                        
                        set todayTasks to every flattened task whose due date ≥ todayStart and due date < todayEnd
                        
                        if (count of todayTasks) = 0 then
                            return "No tasks due today"
                        else
                            set taskList to ""
                            repeat with aTask in todayTasks
                                set taskList to taskList & "• " & name of aTask & return
                            end repeat
                            return "Tasks due today:" & return & taskList
                        end if
                    end tell
                end tell
            `;
            break;
            
        case 'complete_task':
            script = `
                tell application "OmniFocus"
                    tell default document
                        set searchTerm to "${args.task_name || ''}"
                        set foundTasks to every flattened task whose name contains searchTerm and completed is false
                        
                        if (count of foundTasks) = 0 then
                            return "No matching tasks found"
                        else if (count of foundTasks) = 1 then
                            set completed of item 1 of foundTasks to true
                            return "Completed: " & name of item 1 of foundTasks
                        else
                            set taskList to ""
                            repeat with aTask in foundTasks
                                set taskList to taskList & "• " & name of aTask & return
                            end repeat
                            return "Multiple tasks found:" & return & taskList & return & "Please be more specific"
                        end if
                    end tell
                end tell
            `;
            break;
            
        case 'weekly_review':
            script = `
                tell application "OmniFocus"
                    tell default document
                        set completedCount to count of (every flattened task whose completed is true and completion date > (current date) - 7 * days)
                        set inboxCount to count of every inbox task
                        set overdueCount to count of (every flattened task whose due date < (current date) and completed is false)
                        set flaggedCount to count of (every flattened task whose flagged is true and completed is false)
                        
                        return "Weekly Review Summary:" & return & ¬
                            "• Completed this week: " & completedCount & return & ¬
                            "• Items in inbox: " & inboxCount & return & ¬
                            "• Overdue tasks: " & overdueCount & return & ¬
                            "• Flagged tasks: " & flaggedCount
                    end tell
                end tell
            `;
            break;
            
        default:
            throw new Error(`Tool ${name} not implemented`);
    }
    
    try {
        const result = executeAppleScript(script, {});
        return {
            content: [
                {
                    type: 'text',
                    text: result
                }
            ]
        };
    } catch (error) {
        return {
            content: [
                {
                    type: 'text',
                    text: `Error: ${error.message}`
                }
            ],
            isError: true
        };
    }
}

// Handle JSON-RPC requests
async function handleRequest(request) {
    const { method, params, id } = request;
    
    log(`Handling request: ${method}`);
    
    try {
        switch (method) {
            case 'initialize':
                if (initialized) {
                    throw new Error('Server already initialized');
                }
                
                clientCapabilities = params.capabilities || {};
                initialized = true;
                
                const initResult = {
                    protocolVersion: '2025-06-18',
                    capabilities: {
                        tools: {}
                    },
                    serverInfo: {
                        name: 'omnifocus-gtd',
                        version: '1.0.0'
                    }
                };
                
                sendResponse(id, initResult);
                break;
                
            case 'initialized':
                // Client confirms initialization
                log('Client confirmed initialization');
                break;
                
            case 'tools/list':
                if (!initialized) {
                    throw new Error('Server not initialized');
                }
                
                sendResponse(id, {
                    tools: tools.map(tool => ({
                        name: tool.name,
                        description: tool.description,
                        inputSchema: tool.inputSchema
                    }))
                });
                break;
                
            case 'tools/call':
                if (!initialized) {
                    throw new Error('Server not initialized');
                }
                
                const { name, arguments: toolArgs } = params;
                const result = await executeTool(name, toolArgs);
                sendResponse(id, result);
                break;
                
            case 'shutdown':
                sendResponse(id, null);
                process.exit(0);
                break;
                
            default:
                sendResponse(id, null, {
                    code: -32601,
                    message: `Method not found: ${method}`
                });
        }
    } catch (error) {
        log(`Request error: ${error.message}`);
        sendResponse(id, null, {
            code: -32603,
            message: error.message
        });
    }
}

// Main server loop
log('Starting OmniFocus MCP Server...');

let buffer = '';

rl.on('line', (line) => {
    try {
        const request = JSON.parse(line);
        log('Received:', line);
        
        if (request.jsonrpc !== '2.0') {
            log('Invalid JSON-RPC version:', request.jsonrpc);
            return;
        }
        
        handleRequest(request);
    } catch (error) {
        log('Parse error:', error.message);
    }
});

rl.on('close', () => {
    log('Server shutting down');
    process.exit(0);
});

// Handle errors
process.on('uncaughtException', (error) => {
    log('Uncaught exception:', error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    log('Unhandled rejection at:', promise, 'reason:', reason);
    process.exit(1);
});

// Signal handling
process.on('SIGINT', () => {
    log('Received SIGINT, shutting down gracefully');
    process.exit(0);
});

process.on('SIGTERM', () => {
    log('Received SIGTERM, shutting down gracefully');
    process.exit(0);
});

log('Server ready, waiting for requests...');
