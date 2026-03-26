#!/usr/bin/env node

/**
 * OmniFocus MCP Server
 * Complete MCP server implementation with advanced OmniFocus features
 * Compatible with Claude Desktop Extension format
 */

const readline = require('readline');
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// Read version - try from package.json if available, otherwise use fallback
let VERSION = '2.0.1'; // Fallback version
try {
    const packageJsonPath = path.join(__dirname, '..', '..', 'package.json');
    if (fs.existsSync(packageJsonPath)) {
        const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
        VERSION = packageJson.version;
    }
} catch (error) {
    // Use fallback version if package.json not found (e.g., when running from MCPB package)
}

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

// Complete tool definitions - includes both original and enhanced tools
const tools = [
    // Core tools
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
                defer_date: {
                    type: 'string',
                    description: 'Optional defer date (when the task becomes available)'
                },
                flagged: {
                    type: 'boolean',
                    description: 'Whether to flag this task as important',
                    default: false
                },
                estimated_minutes: {
                    type: 'number',
                    description: 'Estimated time in minutes to complete the task'
                },
                tags: {
                    type: 'string',
                    description: 'Comma-separated list of tags to apply to the task (e.g., "work,urgent")'
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
    },

    // Advanced tools
    {
        name: 'search_tasks',
        description: 'Search for tasks across all projects and contexts',
        inputSchema: {
            type: 'object',
            properties: {
                query: {
                    type: 'string',
                    description: 'Search term to find in task names and notes'
                },
                filter: {
                    type: 'string',
                    enum: ['all', 'available', 'remaining'],
                    description: 'Filter for task availability status',
                    default: 'all'
                },
                limit: {
                    type: 'number',
                    description: 'Maximum number of results to return',
                    default: 50
                }
            },
            required: ['query']
        }
    },
    {
        name: 'edit_task',
        description: 'Edit properties of an existing task',
        inputSchema: {
            type: 'object',
            properties: {
                task_name: {
                    type: 'string',
                    description: 'Name or partial name of the task to edit'
                },
                property: {
                    type: 'string',
                    enum: ['name', 'note', 'due_date', 'defer_date', 'flagged', 'project', 'estimated_minutes', 'tags'],
                    description: 'Property to modify'
                },
                value: {
                    type: 'string',
                    description: 'New value for the property'
                }
            },
            required: ['task_name', 'property', 'value']
        }
    },
    {
        name: 'batch_add_tasks',
        description: 'Create multiple tasks at once, optionally with subtasks',
        inputSchema: {
            type: 'object',
            properties: {
                tasks: {
                    type: 'string',
                    description: 'Pipe-separated list of tasks (use - prefix for subtasks, e.g., "Task 1|-Subtask 1|-Subtask 2|Task 2")'
                },
                project: {
                    type: 'string',
                    description: 'Optional project to add all tasks to'
                },
                due_date: {
                    type: 'string',
                    description: 'Optional due date for all tasks'
                },
                flagged: {
                    type: 'boolean',
                    description: 'Whether to flag all tasks',
                    default: false
                }
            },
            required: ['tasks']
        }
    },
    {
        name: 'create_recurring_task',
        description: 'Create a task with recurrence/repeat settings',
        inputSchema: {
            type: 'object',
            properties: {
                name: {
                    type: 'string',
                    description: 'Task name'
                },
                repeat_rule: {
                    type: 'string',
                    description: 'Repeat pattern (e.g., "daily", "weekly", "monthly", "3 days", "2 weeks")',
                    default: 'weekly'
                },
                project: {
                    type: 'string',
                    description: 'Optional project name'
                },
                initial_due_date: {
                    type: 'string',
                    description: 'First due date for the recurring task'
                }
            },
            required: ['name']
        }
    },
    {
        name: 'list_projects',
        description: 'List all active projects in OmniFocus',
        inputSchema: {
            type: 'object',
            properties: {
                include_stats: {
                    type: 'boolean',
                    description: 'Include task count statistics for each project',
                    default: false
                }
            }
        }
    },
    {
        name: 'list_deferred_tasks',
        description: 'List tasks that are currently deferred (not yet available)',
        inputSchema: {
            type: 'object',
            properties: {}
        }
    },
    {
        name: 'list_flagged_tasks',
        description: 'List all flagged tasks across all projects',
        inputSchema: {
            type: 'object',
            properties: {}
        }
    },
    {
        name: 'list_overdue_tasks',
        description: 'List all overdue tasks',
        inputSchema: {
            type: 'object',
            properties: {}
        }
    },

    // Tag management tools
    {
        name: 'list_tags',
        description: 'List all tags in OmniFocus with task counts',
        inputSchema: {
            type: 'object',
            properties: {}
        }
    },
    {
        name: 'create_tag',
        description: 'Create a new tag in OmniFocus',
        inputSchema: {
            type: 'object',
            properties: {
                name: {
                    type: 'string',
                    description: 'Name of the new tag'
                },
                parent_tag: {
                    type: 'string',
                    description: 'Optional parent tag name to nest this tag under'
                }
            },
            required: ['name']
        }
    },
    {
        name: 'delete_tag',
        description: 'Delete a tag from OmniFocus',
        inputSchema: {
            type: 'object',
            properties: {
                name: {
                    type: 'string',
                    description: 'Name of the tag to delete'
                }
            },
            required: ['name']
        }
    },
    {
        name: 'add_tag_to_task',
        description: 'Add a tag to a task (creates the tag if it does not exist)',
        inputSchema: {
            type: 'object',
            properties: {
                task_name: {
                    type: 'string',
                    description: 'Name or partial name of the task'
                },
                tag_name: {
                    type: 'string',
                    description: 'Name of the tag to add'
                }
            },
            required: ['task_name', 'tag_name']
        }
    },
    {
        name: 'remove_tag_from_task',
        description: 'Remove a tag from a task',
        inputSchema: {
            type: 'object',
            properties: {
                task_name: {
                    type: 'string',
                    description: 'Name or partial name of the task'
                },
                tag_name: {
                    type: 'string',
                    description: 'Name of the tag to remove'
                }
            },
            required: ['task_name', 'tag_name']
        }
    }
];

// Execute AppleScript file with arguments
function executeAppleScriptFile(scriptName, args = []) {
    // Try enhanced scripts first
    let scriptPath = path.join(__dirname, '..', 'scripts', 'enhanced', `${scriptName}.applescript`);

    // Fall back to regular scripts if enhanced version doesn't exist
    if (!fs.existsSync(scriptPath)) {
        scriptPath = path.join(__dirname, '..', 'scripts', `${scriptName}.applescript`);
    }

    // Check if script file exists — throw before the try so the message isn't
    // wrapped by the generic "AppleScript execution failed:" catch below.
    if (!fs.existsSync(scriptPath)) {
        throw new Error(`Script file not found: ${scriptName}.applescript (looked in ${scriptPath})`);
    }

    try {
        const scriptArgs = args.map(arg => String(arg));
        const argv = [scriptPath, ...scriptArgs];
        log(`Executing: osascript ${JSON.stringify(argv)}`);

        const result = execFileSync('osascript', argv, {
            encoding: 'utf8',
            maxBuffer: 1024 * 1024 * 10 // Increased buffer for search results
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
                    String(args.flagged || false),
                    args.defer_date || '',
                    String(args.estimated_minutes || 0),
                    args.tags || ''
                ];
                result = executeAppleScriptFile('add_task', taskArgs);
                break;

            case 'search_tasks':
                result = executeAppleScriptFile('search_tasks', [
                    args.query || '',
                    args.filter || 'all',
                    String(args.limit || 50)
                ]);
                break;

            case 'edit_task':
                result = executeAppleScriptFile('edit_task', [
                    args.task_name || '',
                    args.property || '',
                    args.value || ''
                ]);
                break;

            case 'batch_add_tasks':
                result = executeAppleScriptFile('batch_add_tasks', [
                    args.tasks || '',
                    args.project || '',
                    args.due_date || '',
                    String(args.flagged || false)
                ]);
                break;

            case 'create_recurring_task':
                result = executeAppleScriptFile('create_recurring_task', [
                    args.name || '',
                    args.repeat_rule || 'weekly',
                    args.project || '',
                    args.initial_due_date || ''
                ]);
                break;

            case 'list_projects':
                result = executeAppleScriptFile('list_projects', [
                    String(args.include_stats || false)
                ]);
                break;

            case 'complete_task':
                result = executeAppleScriptFile('complete_task', [args.task_name || '']);
                break;

            case 'list_inbox':
            case 'today_tasks':
            case 'weekly_review':
            case 'list_deferred_tasks':
            case 'list_flagged_tasks':
            case 'list_overdue_tasks':
            case 'list_tags':
                result = executeAppleScriptFile(name, []);
                break;

            case 'create_tag':
                result = executeAppleScriptFile('create_tag', [
                    args.name || '',
                    args.parent_tag || ''
                ]);
                break;

            case 'delete_tag':
                result = executeAppleScriptFile('delete_tag', [args.name || '']);
                break;

            case 'add_tag_to_task':
                result = executeAppleScriptFile('add_tag_to_task', [
                    args.task_name || '',
                    args.tag_name || ''
                ]);
                break;

            case 'remove_tag_from_task':
                result = executeAppleScriptFile('remove_tag_from_task', [
                    args.task_name || '',
                    args.tag_name || ''
                ]);
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
                    protocolVersion: '2025-11-25',
                    capabilities: {
                        tools: {
                            listChanged: true
                        }
                    },
                    serverInfo: {
                        name: 'omnifocus-gtd',
                        version: VERSION
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
log('Starting OmniFocus MCP Server v2.0...');

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
