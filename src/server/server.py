#!/usr/bin/env python3
"""
OmniFocus MCP Server - Python Implementation
Handles communication between Claude Desktop and OmniFocus via AppleScript
"""

import sys
import json
import subprocess
import os
from typing import Dict, Any, List, Optional

class MCPServer:
    def __init__(self):
        self.initialized = False
        self.tools = [
            {
                "name": "add_task",
                "description": "Add a new task to OmniFocus inbox or specific project",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string", "description": "The task name/title"},
                        "note": {"type": "string", "description": "Optional note or description"},
                        "project": {"type": "string", "description": "Optional project name"},
                        "due_date": {"type": "string", "description": "Optional due date"},
                        "flagged": {"type": "boolean", "description": "Whether to flag as important", "default": False}
                    },
                    "required": ["name"]
                }
            },
            {
                "name": "list_inbox",
                "description": "List all tasks currently in the OmniFocus inbox",
                "inputSchema": {"type": "object", "properties": {}}
            },
            {
                "name": "today_tasks",
                "description": "List all tasks due today",
                "inputSchema": {"type": "object", "properties": {}}
            },
            {
                "name": "complete_task",
                "description": "Mark a task as complete by searching for it by name",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "task_name": {"type": "string", "description": "Name or partial name of the task"}
                    },
                    "required": ["task_name"]
                }
            },
            {
                "name": "weekly_review",
                "description": "Get a comprehensive weekly review summary",
                "inputSchema": {"type": "object", "properties": {}}
            }
        ]
    
    def log(self, message: str):
        """Log to stderr to avoid interfering with JSON-RPC communication"""
        print(f"[OmniFocus Server] {message}", file=sys.stderr, flush=True)
    
    def send_response(self, id: Any, result: Any = None, error: Any = None):
        """Send JSON-RPC response"""
        response = {"jsonrpc": "2.0", "id": id}
        if error:
            response["error"] = error
        else:
            response["result"] = result
        
        print(json.dumps(response), flush=True)
        self.log(f"Response: {json.dumps(response)}")
    
    def execute_applescript(self, script: str) -> str:
        """Execute AppleScript and return result"""
        try:
            result = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            self.log(f"AppleScript error: {e}")
            raise Exception(f"AppleScript execution failed: {e.stderr}")
    
    def execute_tool(self, name: str, args: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a tool and return the result"""
        self.log(f"Executing tool: {name} with args: {args}")
        
        if name == "add_task":
            task_name = args.get("name", "New Task")
            note = args.get("note", "")
            flagged = args.get("flagged", False)
            
            script = f'''
                tell application "OmniFocus"
                    tell default document
                        set newTask to make new inbox task with properties {{name:"{task_name}"}}
                        {f'set note of newTask to "{note}"' if note else ''}
                        {'set flagged of newTask to true' if flagged else ''}
                        return "Task added: " & name of newTask
                    end tell
                end tell
            '''
            result = self.execute_applescript(script)
            
        elif name == "list_inbox":
            script = '''
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
            '''
            result = self.execute_applescript(script)
            
        elif name == "today_tasks":
            script = '''
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
            '''
            result = self.execute_applescript(script)
            
        elif name == "complete_task":
            task_name = args.get("task_name", "")
            script = f'''
                tell application "OmniFocus"
                    tell default document
                        set searchTerm to "{task_name}"
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
            '''
            result = self.execute_applescript(script)
            
        elif name == "weekly_review":
            script = '''
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
            '''
            result = self.execute_applescript(script)
        else:
            raise Exception(f"Unknown tool: {name}")
        
        return {
            "content": [
                {
                    "type": "text",
                    "text": result
                }
            ]
        }
    
    def handle_request(self, request: Dict[str, Any]):
        """Handle JSON-RPC request"""
        method = request.get("method")
        params = request.get("params", {})
        id = request.get("id")
        
        self.log(f"Handling request: {method}")
        
        try:
            if method == "initialize":
                if self.initialized:
                    raise Exception("Server already initialized")
                
                self.initialized = True
                result = {
                    "protocolVersion": "2025-06-18",
                    "capabilities": {"tools": {}},
                    "serverInfo": {
                        "name": "omnifocus-gtd",
                        "version": "1.0.0"
                    }
                }
                self.send_response(id, result)
                
            elif method == "initialized":
                self.log("Client confirmed initialization")
                
            elif method == "tools/list":
                if not self.initialized:
                    raise Exception("Server not initialized")
                
                self.send_response(id, {"tools": self.tools})
                
            elif method == "tools/call":
                if not self.initialized:
                    raise Exception("Server not initialized")
                
                tool_name = params.get("name")
                tool_args = params.get("arguments", {})
                result = self.execute_tool(tool_name, tool_args)
                self.send_response(id, result)
                
            elif method == "shutdown":
                self.send_response(id, None)
                sys.exit(0)
                
            else:
                self.send_response(id, None, {
                    "code": -32601,
                    "message": f"Method not found: {method}"
                })
                
        except Exception as e:
            self.log(f"Request error: {e}")
            self.send_response(id, None, {
                "code": -32603,
                "message": str(e)
            })
    
    def run(self):
        """Main server loop"""
        self.log("Starting OmniFocus MCP Server...")
        
        for line in sys.stdin:
            try:
                request = json.loads(line.strip())
                self.log(f"Received: {line.strip()}")
                
                if request.get("jsonrpc") != "2.0":
                    self.log(f"Invalid JSON-RPC version: {request.get('jsonrpc')}")
                    continue
                
                self.handle_request(request)
                
            except json.JSONDecodeError as e:
                self.log(f"Parse error: {e}")
            except Exception as e:
                self.log(f"Unexpected error: {e}")

if __name__ == "__main__":
    server = MCPServer()
    server.run()
