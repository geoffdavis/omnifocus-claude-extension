#!/usr/bin/env node

/**
 * OmniFocus MCP Server - Simple Implementation
 * A lightweight MCP server for OmniFocus integration
 */

const { execSync } = require('child_process');
const { readFileSync } = require('fs');
const path = require('path');

class MCPServer {
    constructor() {
        this.tools = this.loadTools();
        this.setupStdio();
    }

    loadTools() {
        // Define tools inline to avoid file dependency issues
        return [
            {
                name: "add_task",
                description: "Add a new task to OmniFocus inbox or specific project",
                inputSchema: {
                    type: "object",
                    properties: {
                        name: { type: "string", description: "The task name/title" },
                        note: { type: "string", description: "Optional note or description for the task" },
                        project: { type: "string", description: "Optional project name to add the task to" },
                        due_date: { type: "string", description: "Optional due date (e.g., 'tomorrow', 'next week', 'Friday')" },
                        flagged: { type: "boolean", description: "Whether to flag this task as important", default: false }
                    },
                    required: ["name"]
                }
            },
            {
                name: "list_inbox",
                description: "List all tasks currently in the OmniFocus inbox",
                inputSchema: { type: "object", properties: {} }
            },
            {
                name: "today_tasks",
                description: "List all tasks due today",
                inputSchema: { type: "object", properties: {} }
            },
            {
                name: "complete_task",
                description: "Mark a task as complete by searching for it by name",
                inputSchema: {
                    type: "object",
                    properties: {
                        task_name: { type: "string", description: "Name or partial name of the task to complete" }
                    },
                    required: ["task_name"]
                }
            },
            {
                name: "weekly_review",
                description: "Get a comprehensive weekly review summary",
                inputSchema: { type: "object", properties: {} }
            }
        ];
    }

    setupStdio() {
        process.stdin.setEncoding('utf8');
        process.stdin.on('data', (data) => {
            try {
                const lines = data.toString().split('\n').filter(line => line.trim());
                for (const line of lines) {
                    if (line.trim()) {
                        this.handleMessage(JSON.parse(line.trim()));
                    }
                }
            } catch (error) {
                this.sendError(-1, `Parse error: ${error.message}`);
            }
        });
    }

    send(response) {
        console.log(JSON.stringify(response));
    }

    sendError(id, message) {
        this.send({
            jsonrpc: "2.0",
            id,
            error: {
                code: -32603,
                message
            }
        });
    }

    handleMessage(message) {
        const { id, method, params } = message;

        try {
            switch (method) {
                case 'initialize':
                    this.send({
                        jsonrpc: "2.0",
                        id,
                        result: {
                            protocolVersion: "2025-06-18",
                            capabilities: {
                                tools: {}
                            },
                            serverInfo: {
                                name: "omnifocus-gtd",
                                version: "1.0.0"
                            }
                        }
                    });
                    break;

                case 'tools/list':
                    this.send({
                        jsonrpc: "2.0",
                        id,
                        result: {
                            tools: this.tools
                        }
                    });
                    break;

                case 'tools/call':
                    this.handleToolCall(id, params);
                    break;

                default:
                    this.sendError(id, `Unknown method: ${method}`);
            }
        } catch (error) {
            this.sendError(id, error.message);
        }
    }

    async handleToolCall(id, params) {
        const { name, arguments: args } = params;

        try {
            const result = await this.executeTool(name, args || {});
            this.send({
                jsonrpc: "2.0",
                id,
                result: {
                    content: [
                        {
                            type: "text",
                            text: result
                        }
                    ]
                }
            });
        } catch (error) {
            this.sendError(id, `Tool execution failed: ${error.message}`);
        }
    }

    async executeTool(toolName, args) {
        const scripts = {
            add_task: `
on run argv
  set taskName to item 1 of argv
  set taskNote to ""
  set projectName to ""
  set dueDate to missing value
  set isFlagged to false
  
  if (count of argv) > 1 then set taskNote to item 2 of argv
  if (count of argv) > 2 then set projectName to item 3 of argv
  if (count of argv) > 3 then
    set dueDateString to item 4 of argv
    if dueDateString is not "" then
      if dueDateString contains "tomorrow" then
        set dueDate to (current date) + 1 * days
      else if dueDateString contains "today" then
        set dueDate to current date
      else if dueDateString contains "week" then
        set dueDate to (current date) + 7 * days
      end if
    end if
  end if
  if (count of argv) > 4 then
    if item 5 of argv is "true" then set isFlagged to true
  end if
  
  tell application "OmniFocus"
    tell default document
      if projectName is not "" then
        try
          set targetProject to first project whose name contains projectName
          set newTask to make new task with properties {name:taskName, note:taskNote, flagged:isFlagged} at end of tasks of targetProject
        on error
          set newTask to make new inbox task with properties {name:taskName, note:taskNote, flagged:isFlagged}
        end try
      else
        set newTask to make new inbox task with properties {name:taskName, note:taskNote, flagged:isFlagged}
      end if
      
      if dueDate is not missing value then
        set due date of newTask to dueDate
      end if
      
      return "✅ Added: " & taskName
    end tell
  end tell
end run`,

            list_inbox: `
tell application "OmniFocus"
  tell default document
    set inboxTasks to every inbox task
    set taskList to "📥 Inbox Tasks:\\n"
    repeat with theTask in inboxTasks
      set taskList to taskList & "• " & (name of theTask) & "\\n"
    end repeat
    if (count of inboxTasks) = 0 then
      set taskList to "📥 Inbox is empty"
    end if
    return taskList
  end tell
end tell`,

            today_tasks: `
tell application "OmniFocus"
  tell default document
    set todayDate to current date
    set todayStart to todayDate - (time of todayDate)
    set todayEnd to todayStart + 1 * days
    
    set todayTasks to every flattened task whose (due date ≥ todayStart and due date < todayEnd and completed is false)
    set taskList to "📅 Today's Tasks:\\n"
    repeat with theTask in todayTasks
      set taskList to taskList & "• " & (name of theTask)
      if due date of theTask is not missing value then
        set taskList to taskList & " (Due: " & (due date of theTask as string) & ")"
      end if
      set taskList to taskList & "\\n"
    end repeat
    if (count of todayTasks) = 0 then
      set taskList to "📅 No tasks due today"
    end if
    return taskList
  end tell
end tell`,

            complete_task: `
on run argv
  set searchName to item 1 of argv
  
  tell application "OmniFocus"
    tell default document
      set foundTasks to every flattened task whose name contains searchName and completed is false
      if (count of foundTasks) > 0 then
        set theTask to item 1 of foundTasks
        set completed of theTask to true
        return "✅ Completed: " & (name of theTask)
      else
        return "❌ No incomplete task found matching: " & searchName
      end if
    end tell
  end tell
end run`,

            weekly_review: `
tell application "OmniFocus"
  tell default document
    set weekAgo to (current date) - 7 * days
    set completedTasks to every flattened task whose (completed is true and completion date > weekAgo)
    set overdueTasks to every flattened task whose (due date < (current date) and completed is false)
    set inboxCount to count of every inbox task
    
    set reviewText to "📊 Weekly Review:\\n\\n"
    set reviewText to reviewText & "✅ Completed this week: " & (count of completedTasks) & " tasks\\n"
    set reviewText to reviewText & "⚠️ Overdue tasks: " & (count of overdueTasks) & "\\n"
    set reviewText to reviewText & "📥 Inbox items: " & inboxCount & "\\n\\n"
    
    if (count of overdueTasks) > 0 then
      set reviewText to reviewText & "Overdue Tasks:\\n"
      repeat with theTask in overdueTasks
        set reviewText to reviewText & "• " & (name of theTask) & "\\n"
      end repeat
    end if
    
    return reviewText
  end tell
end tell`
        };

        const script = scripts[toolName];
        if (!script) {
            throw new Error(`Unknown tool: ${toolName}`);
        }

        // Build command arguments
        const scriptArgs = [];
        if (toolName === 'add_task') {
            scriptArgs.push(args.name || '');
            scriptArgs.push(args.note || '');
            scriptArgs.push(args.project || '');
            scriptArgs.push(args.due_date || '');
            scriptArgs.push(args.flagged ? 'true' : 'false');
        } else if (toolName === 'complete_task') {
            scriptArgs.push(args.task_name || '');
        }

        // Execute AppleScript
        const cmd = `osascript -e '${script.replace(/'/g, "'\\''")}' ${scriptArgs.map(arg => `'${arg.replace(/'/g, "'\\''")}' `).join('')}`;
        
        try {
            const result = execSync(cmd, {
                encoding: 'utf8',
                maxBuffer: 1024 * 1024,
                timeout: 10000
            });
            return result.trim();
        } catch (error) {
            throw new Error(`AppleScript execution failed: ${error.message}`);
        }
    }
}

// Start the server
console.error('OmniFocus MCP Server starting...');
new MCPServer();
