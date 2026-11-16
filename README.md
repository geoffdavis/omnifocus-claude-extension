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
- **Edit Tasks**: Modify any task property including defer dates and tags
- **Batch Task Creation**: Create multiple tasks with subtasks in one command
- **Recurring Tasks**: Create tasks with daily, weekly, monthly, or custom repeat patterns

### Tags
- **List Tags**: View all tags with hierarchy
- **Create Tags**: Create tags, optionally nested under a parent
- **Reopen Tasks**: Mark a completed or dropped task as open again
- **Subtasks and planned dates**: Add a task under an existing task, set a planned date
- **Edit Tags**: Rename, move, hide a tag, change its note or whether its tasks can be next actions
- **Tag Tasks**: Add or remove tags on existing tasks
- **Tags on Creation**: Specify tags when adding tasks, batch-creating tasks, or editing tasks. Tags at any level are found by name, by path `Parent > Child` or by `id:<id>`

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

1. Download the latest `omnifocus-gtd.mcpb` from the [Releases](https://github.com/geoffdavis/omnifocus-claude-extension/releases) page
2. Open Claude Desktop
3. Navigate to Extensions settings
4. Drag and drop the `.mcpb` file onto the Claude Desktop window
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

# The extension will be created at dist/omnifocus-gtd.mcpb
```

## Usage Examples

### Task Management
```
"Add task 'Review Q3 reports' due Friday to Work project, defer until Wednesday"
"Search for all tasks about 'budget'"
"Edit 'Team meeting' to be due tomorrow at 2pm"
"Complete the task about reviewing reports"
"Reopen the task 'Review Q3 reports'"
"Add a subtask 'Collect figures' under the task 'Review Q3 reports'"
"Set the planned date of 'Review Q3 reports' to Monday"
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
"Make the task 'Water plants' repeat every 3 days"
"Stop the repetition of 'Process inbox'"
```

### Tags
```
"List all my tags"
"Create a tag called 'Urgent'"
"Create a 'Home' tag under 'Locations'"
"Rename the tag 'Waiting' to 'Waiting for'"
"Make tasks with the tag 'Waiting for' no longer next actions"
"Hide the tag 'Someday'"
"Move the tag 'Phone' below 'Locations'"
"Add tag 'Priority' to my 'Review reports' task"
"Remove tag 'Waiting' from 'Follow up with client'"
"Add task 'Fix login bug' with tags Priority, Computer"
"Edit 'Fix login bug' and set tags to Urgent, Computer"
```

### Views and Reviews
```
"Show me my flagged tasks"
"List all overdue tasks"
"What tasks are deferred?"
"Show all projects with task counts"
"Give me a weekly review"
```

### Projects and Folders
```
"Create a folder 'Clients' and a project 'Website relaunch' in it"
"Rename the project 'Website relaunch' to 'Website 2.0'"
"Move the project 'Website 2.0' to the folder 'Clients > Active'"
"Put the project 'Website 2.0' on hold"
"Make 'Website 2.0' a sequential project"
"Review 'Website 2.0' every 2 weeks"
"Show everything in the project 'Website 2.0', also blocked and deferred tasks"
"Keep 'Someday' out of the reviews until 2027-01-01"
"Set the due date of 'Website 2.0' to 2026-12-31 and complete it with its last item"
"Drop the task 'Old idea'"
```
Projects in any folder can be addressed by name or by path (`Folder > Subfolder > Project`). If a name matches
several projects the tool lists the matches and changes nothing. Tasks and projects can also be addressed by the
`id:<id>` shown in list outputs.

### GTD Queries and Reviews
```
"What can I work on now?"
"What can I work on in the folder 'Clients'?"
"Show all tasks tagged 'Waiting for'"
"Which waiting-for items are the oldest?"
"What can I do in 15 minutes?"
"Show the available tasks tagged 'Phone'"
"What did I complete in the last 7 days?"
"Which projects are due for review?"
"Mark the project 'Website 2.0' as reviewed"
"Which projects have no next action?"
```

Dropped items and items below dropped (hidden) folders are left out of all read tools. Pass `include_dropped: true`
to include them.

## Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `add_task` | Add a task with full properties | "Add task to buy milk due tomorrow, defer until morning" |
| `search_tasks` | Search across all tasks | "Search for budget tasks" |
| `edit_task` | Modify existing task, including its repetition | "Change due date of 'Report' to Friday", "Repeat 'Pay rent' every month" |
| `batch_add_tasks` | Create multiple tasks | "Add tasks: Task1\|Task2\|-Subtask" |
| `create_recurring_task` | Set up repeating task | "Create daily task 'Review email'" |
| `list_inbox` | Show inbox tasks | "Show my inbox" |
| `today_tasks` | List due today | "What's due today?" |
| `list_projects` | Show all projects | "List projects with counts" |
| `list_deferred_tasks` | Show deferred items | "What tasks are deferred?" |
| `list_flagged_tasks` | Show flagged items | "Show flagged tasks" |
| `list_overdue_tasks` | Show overdue items | "What's overdue?" |
| `complete_task` | Mark as complete | "Complete budget review" |
| `reopen_task` | Reopen a completed or dropped task | "Reopen the task 'Budget review'" |
| `weekly_review` | GTD weekly review | "Show weekly review" |
| `get_task` | Show all details of one task, including its repetition | "Show details of 'Report'" |
| `get_project` | Show a project with its properties and all its tasks as an indented list | "Show the project 'Website 2.0' with all tasks" |
| `drop_task` | Drop a task (deleting needs `confirm_delete`) | "Drop the task 'Old idea'" |
| `list_tags` | Show all tags with hierarchy, IDs and hidden / no-next-action flags | "List my tags" |
| `create_tag` | Create a new tag, optionally below another tag | "Create tag 'Urgent'" |
| `edit_tag` | Rename, move, hide a tag, change its note or next-action behavior | "Rename tag 'Waiting' to 'Waiting for'" |
| `add_tag_to_task` | Add a tag to a task | "Tag 'Report' with 'Priority'" |
| `remove_tag_from_task` | Remove a tag from a task | "Remove 'Waiting' tag from 'Report'" |
| `create_project` | Create a project, optionally in a folder, with review interval, due and defer date and type | "Create project 'Website 2.0' in 'Clients', review every 2 weeks" |
| `edit_project` | Rename, change note, folder, status, type, review interval, next review date, due, defer and planned date, flag, completion behavior of a project | "Review 'Website 2.0' every 2 weeks" |
| `create_folder` | Create a folder, optionally inside another folder | "Create folder 'Clients'" |
| `rename_folder` | Rename a folder | "Rename folder 'Clients' to 'Customers'" |
| `list_available_tasks` | Next actions across all projects, optionally by tag, folder or time (`max_minutes`) | "What can I work on now?" |
| `list_tasks_by_tag` | Open tasks with a tag, grouped by project, or oldest first with their age (`show_age`) | "Show tasks tagged 'Waiting for'" |
| `list_completed_tasks` | Tasks completed in the last days | "What did I complete last week?" |
| `list_projects_for_review` | Projects whose review is due, with their review interval | "Which projects need a review?" |
| `mark_project_reviewed` | Mark a project as reviewed today | "Mark 'Website 2.0' as reviewed" |
| `list_stalled_projects` | Active projects without a next action | "Which projects are stalled?" |

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
│   │   │   ├── list_overdue_tasks.applescript
│   │   │   ├── list_tags.applescript
│   │   │   ├── create_tag.applescript
│   │   │   ├── edit_tag.applescript
│   │   │   ├── reopen_task.applescript
│   │   │   ├── add_tag_to_task.applescript
│   │   │   ├── remove_tag_from_task.applescript
│   │   │   ├── get_task.applescript
│   │   │   ├── get_project.applescript
│   │   │   ├── drop_task.applescript
│   │   │   ├── create_project.applescript
│   │   │   ├── edit_project.applescript
│   │   │   ├── create_folder.applescript
│   │   │   ├── rename_folder.applescript
│   │   │   ├── list_tasks_filtered.applescript    # list_available_tasks and list_tasks_by_tag
│   │   │   ├── list_completed_tasks.applescript
│   │   │   ├── list_projects_for_review.applescript
│   │   │   ├── mark_project_reviewed.applescript
│   │   │   └── list_stalled_projects.applescript
│   │   ├── add_task.applescript
│   │   ├── complete_task.applescript
│   │   ├── list_inbox.applescript
│   │   ├── today_tasks.applescript
│   │   └── weekly_review.applescript
│   └── manifest-template.json      # MCPB v0.3 manifest template
├── build.js                        # Build script
├── dist/
│   └── omnifocus-gtd.mcpb           # Built extension
└── tests/
```

### Building

```bash
# Build the MCPB extension
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
