# OmniFocus Claude Extension

A powerful OmniFocus integration for Claude Desktop that enables advanced task management using GTD (Getting Things Done) methodology.

## Features

### Core
- **Add Tasks**: Create tasks with notes, projects, due dates, defer dates, and flags
- **Inbox Management**: View and process tasks in your OmniFocus inbox
- **Today's Tasks**: See all tasks due today at a glance
- **Complete Tasks**: Mark tasks as complete by name
- **Weekly Review**: Get a comprehensive summary for your GTD weekly review

### Advanced
- **Search Tasks**: Search across all projects, contexts, and notes
- **Edit Tasks**: Modify any task property including defer dates
- **Batch Task Creation**: Create multiple tasks with subtasks in one command
- **Recurring Tasks**: Create tasks with daily, weekly, monthly, or custom repeat patterns

### Views
- **List Projects**: View all active projects with task counts
- **Deferred Tasks**: See tasks that aren't available yet
- **Flagged Tasks**: Quick access to all flagged items
- **Overdue Tasks**: Track tasks past their due date

## Requirements

- macOS 10.15 (Catalina) or later
- OmniFocus 3 or later
- Claude Desktop app
- Node.js 14+ (for development only)

## Installation

### Quick Install

1. Download the latest `omnifocus-gtd.dxt` from the [Releases](https://github.com/geoffdavis/omnifocus-claude-extension/releases) page
2. Open Claude Desktop
3. Navigate to Extensions settings
4. Drag and drop the `.dxt` file onto the Claude Desktop window
5. Restart Claude Desktop
6. The first time you use an OmniFocus tool, macOS will prompt you to grant `node` permission to control OmniFocus - click **Allow**

### Build from Source

```bash
# Clone the repository
git clone https://github.com/geoffdavis/omnifocus-claude-extension.git
cd omnifocus-claude-extension

# Install dependencies
npm install

# Build the extension
npm run build

# The extension will be created at dist/omnifocus-gtd.dxt
```

## Usage Examples

### Task Management
```
"Add task 'Review Q3 reports' due Friday to Work project, defer until Wednesday"
"Search for all tasks about 'budget'"
"Edit 'Team meeting' to be due tomorrow at 2pm"
"Complete the task about reviewing reports"
```

### Batch Operations
```
"Create project plan: Research phase|-Literature review|-Market analysis|Development|-Prototype|-Testing|Launch"
```
Note: Use `|` to separate tasks and `-` prefix for subtasks

### Recurring Tasks
```
"Create weekly recurring task 'Process inbox' due every Sunday"
"Add monthly recurring 'Review finances' on the 15th"
```

### Views and Reviews
```
"Show me my flagged tasks"
"List all overdue tasks"
"What tasks are deferred?"
"Show all projects with task counts"
"Give me a weekly review"
```

## Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `add_task` | Add a task with full properties | "Add task to buy milk due tomorrow, defer until morning" |
| `search_tasks` | Search across all tasks | "Search for budget tasks" |
| `edit_task` | Modify existing task | "Change due date of 'Report' to Friday" |
| `batch_add_tasks` | Create multiple tasks | "Add tasks: Task1\|Task2\|-Subtask" |
| `create_recurring_task` | Set up repeating task | "Create daily task 'Review email'" |
| `list_inbox` | Show inbox tasks | "Show my inbox" |
| `today_tasks` | List due today | "What's due today?" |
| `list_projects` | Show all projects | "List projects with counts" |
| `list_deferred_tasks` | Show deferred items | "What tasks are deferred?" |
| `list_flagged_tasks` | Show flagged items | "Show flagged tasks" |
| `list_overdue_tasks` | Show overdue items | "What's overdue?" |
| `complete_task` | Mark as complete | "Complete budget review" |
| `weekly_review` | GTD weekly review | "Show weekly review" |

## Development

### Project Structure

```
omnifocus-claude-extension/
├── src/
│   ├── server/
│   │   └── index.js               # MCP server (JSON-RPC 2.0)
│   ├── scripts/
│   │   ├── enhanced/               # Advanced AppleScript implementations
│   │   │   ├── search_tasks.applescript
│   │   │   ├── edit_task.applescript
│   │   │   ├── batch_add_tasks.applescript
│   │   │   ├── create_recurring_task.applescript
│   │   │   ├── list_projects.applescript
│   │   │   ├── list_deferred_tasks.applescript
│   │   │   ├── list_flagged_tasks.applescript
│   │   │   └── list_overdue_tasks.applescript
│   │   ├── add_task.applescript
│   │   ├── complete_task.applescript
│   │   ├── list_inbox.applescript
│   │   ├── today_tasks.applescript
│   │   └── weekly_review.applescript
│   └── manifest-template.json      # MCPB v0.3 manifest template
├── build.js                        # Build script
├── dist/
│   └── omnifocus-gtd.dxt           # Built extension
└── tests/
```

### Building

```bash
# Build the DXT extension
npm run build

# Clean and rebuild
npm run rebuild

# Build and validate
npm run dev

# Run tests
npm test

# Validate the built extension
npm run validate
```

### Adding New Tools

1. Create AppleScript in `src/scripts/enhanced/`
2. Add tool definition to `src/server/index.js`
3. Implement handler in the server's tool execution logic
4. Test with `node test-server.js`
5. Rebuild and validate: `npm run dev`

## Architecture

The extension uses a Model Context Protocol (MCP) server that:

1. Receives commands from Claude Desktop via JSON-RPC 2.0 over stdio
2. Routes to the appropriate AppleScript file
3. Executes AppleScript via `osascript` with proper parameter handling
4. Returns formatted results to Claude

## Troubleshooting

### "Not authorized to send Apple events to OmniFocus" (error -1743)

This is the most common issue. Claude Desktop runs the extension via `node`, which needs macOS Automation permission for OmniFocus.

**First install**: macOS should show a permission dialog the first time you use an OmniFocus tool. Click **Allow**.

**If the dialog doesn't appear** or you accidentally denied it:

1. Reset Apple Events permissions:
   ```bash
   tccutil reset AppleEvents
   ```
2. Restart Claude Desktop
3. Use any OmniFocus tool - the permission dialog should appear
4. Click **Allow**

You can verify the permission in **System Settings > Privacy & Security > Automation** - look for `node` with OmniFocus enabled.

### Extension Not Loading

1. Check Claude Desktop logs: `~/Library/Logs/Claude/`
2. Ensure OmniFocus is installed and running
3. Try reinstalling the extension

### Tasks Not Appearing

1. Ensure OmniFocus default document is open
2. Check that you're not in a filtered view

### Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| "Not authorized" (-1743) | Run `tccutil reset AppleEvents` and restart Claude Desktop |
| "OmniFocus not found" | Ensure OmniFocus is in /Applications |
| "No tasks found" | Check search terms and task availability |
| "Multiple matches" | Be more specific in task names |
| "Cannot create recurring" | Ensure OmniFocus Pro features are available |

## Security

This extension:
- Only reads and writes to OmniFocus via AppleScript
- Does not store or transmit personal data
- Runs entirely locally on your machine
- Requires explicit user permission for automation
- Open source for full transparency

## License

MIT License - see [LICENSE](LICENSE) file for details

## Acknowledgments

- OmniFocus by [The Omni Group](https://www.omnigroup.com/)
- Claude Desktop by [Anthropic](https://www.anthropic.com/)
- GTD methodology by David Allen
