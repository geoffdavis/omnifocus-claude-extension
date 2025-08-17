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

// Execute AppleScript file with arguments
function executeAppleScriptFile(scriptName, args = []) {
    try {
        const scriptPath = path.join(__dirname, '..', 'scripts', `${scriptName}.applescript`);
        
        // Check if script file exists
        if (!fs.existsSync(scriptPath)) {
            log(`Script file not found: ${scriptPath}`);
            // Fall back to embedded implementation
            return executeEmbeddedScript(scriptName, args);
        }
        
        // Build the osascript command with arguments
        // For osascript, arguments after the script path are passed to the script
        const scriptArgs = args.map(arg => {
            // Escape quotes and special characters for shell
            const escaped = String(arg)
                .replace(/\\/g, '\\\\')
                .replace(/"/g, '\\"')
                .replace(/'/g, "'\\''");
            return `"${escaped}"`;
        });
        
        const command = `osascript "${scriptPath}" ${scriptArgs.join(' ')}`;
        log(`Executing: ${command}`);
        
        const result = execSync(command, {
            encoding: 'utf8',
            maxBuffer: 1024 * 1024
        });
        
        return result.trim();
    } catch (error) {
        log('AppleScript execution error:', error.message);
        throw new Error(`AppleScript execution failed: ${error.message}`);
    }
}

// Embedded fallback implementations
function executeEmbeddedScript(scriptName, args = []) {
    let script = '';
    
    switch (scriptName) {
        case 'add_task':
            const taskName = args[0] || 'New Task';
            const taskNote = args[1] || '';
            const projectName = args[2] || '';
            const dueDate = args[3] || '';
            const isFlagged = args[4] === 'true' || args[4] === true;
            
            // Build AppleScript directly
            script = `
                tell application "OmniFocus"
                    tell default document
                        set newTask to make new inbox task with properties {name:"${taskName.replace(/"/g, '\\"')}"${taskNote ? `, note:"${taskNote.replace(/"/g, '\\"')}"` : ''}${isFlagged ? ', flagged:true' : ''}}
                        return "✅ Added: " & name of newTask
                    end tell
                end tell
            `;
            break;
            
        case 'list_inbox':
            script = `
                tell application "OmniFocus"
                    tell default document
                        set incompleteTasks to every inbox task whose completed is false
                        
                        if (count of incompleteTasks) = 0 then
                            return "📥 Inbox is empty"
                        else
                            set taskList to "📥 Inbox (" & (count of incompleteTasks) & " items):"
                            repeat with aTask in incompleteTasks
                                set taskName to name of aTask
                                if flagged of aTask then
                                    set taskList to taskList & return & "• " & taskName & " 🚩"
                                else
                                    set taskList to taskList & return & "• " & taskName
                                end if
                            end repeat
                            return taskList
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
                        
                        set todayTasks to every flattened task whose due date ≥ todayStart and due date < todayEnd and completed is false
                        
                        if (count of todayTasks) = 0 then
                            return "📅 No tasks due today"
                        else
                            set taskList to "📅 Today's Tasks (" & (count of todayTasks) & "):"
                            repeat with aTask in todayTasks
                                set taskName to name of aTask
                                try
                                    set projName to name of containing project of aTask
                                    set taskList to taskList & return & "• " & taskName & " (" & projName & ")"
                                on error
                                    set taskList to taskList & return & "• " & taskName
                                end try
                            end repeat
                            return taskList
                        end if
                    end tell
                end tell
            `;
            break;
            
        case 'complete_task':
            const searchTerm = args[0] || '';
            if (!searchTerm) {
                return "❌ Please provide a task name to complete";
            }
            
            script = `
                tell application "OmniFocus"
                    tell default document
                        -- First check inbox tasks separately
                        set searchTerm to "${searchTerm.replace(/"/g, '\\"')}"
                        set foundInInbox to false
                        set inboxTask to missing value
                        
                        repeat with aTask in (every inbox task)
                            if name of aTask contains searchTerm and completed of aTask is false then
                                if foundInInbox then
                                    -- Multiple matches, need to check all
                                    set foundInInbox to false
                                    exit repeat
                                else
                                    set foundInInbox to true
                                    set inboxTask to aTask
                                end if
                            end if
                        end repeat
                        
                        -- If we found exactly one inbox task, complete it
                        if foundInInbox and inboxTask is not missing value then
                            set taskName to name of inboxTask
                            mark complete inboxTask
                            return "✅ Completed: " & taskName
                        end if
                        
                        -- Otherwise, search all tasks
                        try
                            set foundTasks to every flattened task whose name contains searchTerm and completed is false
                            
                            if (count of foundTasks) = 0 then
                                return "❌ No matching tasks found for: " & searchTerm
                            else if (count of foundTasks) = 1 then
                                set targetTask to item 1 of foundTasks
                                set taskName to name of targetTask
                                
                                -- Try both completion methods
                                try
                                    set completed of targetTask to true
                                on error
                                    mark complete targetTask
                                end try
                                
                                return "✅ Completed: " & taskName
                            else
                                -- Multiple matches - show them
                                set taskList to "🔍 Multiple tasks found (" & (count of foundTasks) & "):" & return
                                repeat with aTask in foundTasks
                                    set taskList to taskList & "• " & name of aTask & return
                                end repeat
                                set taskList to taskList & return & "Please be more specific."
                                return taskList
                            end if
                        on error errMsg
                            return "❌ Error: " & errMsg
                        end try
                    end tell
                end tell
            `;
            break;
            
        case 'weekly_review':
            script = `
                tell application "OmniFocus"
                    tell default document
                        set weekAgo to (current date) - 7 * days
                        set completedCount to count of (every flattened task whose completed is true and completion date > weekAgo)
                        set inboxCount to count of every inbox task
                        set overdueCount to count of (every flattened task whose due date < (current date) and completed is false)
                        set flaggedCount to count of (every flattened task whose flagged is true and completed is false)
                        set weekFromNow to (current date) + 7 * days
                        set dueThisWeek to count of (every flattened task whose due date ≤ weekFromNow and completed is false)
                        
                        set activeProjects to every project whose status is active
                        set projectCount to count of activeProjects
                        
                        set reviewText to "📊 WEEKLY REVIEW SUMMARY" & return
                        set reviewText to reviewText & "════════════════════════" & return & return
                        
                        set reviewText to reviewText & "📥 Inbox: " & inboxCount & " items" & return
                        set reviewText to reviewText & "🚩 Flagged: " & flaggedCount & " tasks" & return
                        set reviewText to reviewText & "⚠️  Overdue: " & overdueCount & " tasks" & return
                        set reviewText to reviewText & "📅 Due this week: " & dueThisWeek & " tasks" & return
                        set reviewText to reviewText & "📁 Active projects: " & projectCount & " of " & (count of every project) & return
                        
                        if inboxCount > 0 then
                            set reviewText to reviewText & return & "💡 Action: Process " & inboxCount & " inbox items"
                        end if
                        
                        if overdueCount > 0 then
                            set reviewText to reviewText & return & "💡 Action: Review " & overdueCount & " overdue tasks"
                        end if
                        
                        return reviewText
                    end tell
                end tell
            `;
            break;
            
        default:
            throw new Error(`Unknown script: ${scriptName}`);
    }
    
    try {
        const result = execSync(`osascript -e '${script.replace(/'/g, "'\"'\"'")}'`, {
            encoding: 'utf8',
            maxBuffer: 1024 * 1024
        });
        return result.trim();
    } catch (error) {
        log('Embedded script execution error:', error.message);
        throw new Error(`Script execution failed: ${error.message}`);
    }
}

// Handle tool execution
async function executeTool(name, args) {
    log(`Executing tool: ${name} with args:`, args);
    
    const tool = tools.find(t => t.name === name);
    if (!tool) {
        throw new Error(`Unknown tool: ${name}`);
    }
    
    try {
        let result;
        
        // Prepare arguments based on tool
        switch (name) {
            case 'add_task':
                const taskArgs = [
                    args.name || 'New Task',
                    args.note || '',
                    args.project || '',
                    args.due_date || '',
                    String(args.flagged || false)
                ];
                result = executeAppleScriptFile('add_task', taskArgs);
                break;
                
            case 'complete_task':
                result = executeAppleScriptFile('complete_task', [args.task_name || '']);
                break;
                
            case 'list_inbox':
            case 'today_tasks':
            case 'weekly_review':
                result = executeAppleScriptFile(name, []);
                break;
                
            default:
                throw new Error(`Tool ${name} not implemented`);
        }
        
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
