# OmniFocus Claude Extension - Enhanced Edition

A powerful OmniFocus integration for Claude Desktop that enables advanced task management using GTD (Getting Things Done) methodology. This enhanced version addresses previous limitations with comprehensive new features.

## 🚀 What's New in Version 2.0

### Previous Limitations - Now Resolved! ✅

1. **~~Single Task Creation Only~~** → **Batch Operations**: Create multiple tasks with subtasks in one command
2. **~~No Search History~~** → **Advanced Search**: Search across all projects, contexts, and notes
3. **~~No Task Editing~~** → **Full Edit Capabilities**: Modify any task property including defer dates
4. **~~No Repeat Fields~~** → **Recurring Tasks**: Create tasks with daily, weekly, monthly, or custom repeat patterns
5. **Enhanced Project Management**: List projects with statistics, move tasks between projects
6. **Comprehensive Views**: Deferred tasks, flagged items, overdue tasks, and more

## Features

### 🆕 Enhanced Features

#### Search Tasks
Search across your entire OmniFocus database:
```
"Search for tasks containing 'budget'"
"Find all available tasks with 'meeting'"
"Search remaining tasks for 'review'"
```

#### Edit Tasks
Modify any property of existing tasks:
```
"Change the due date of 'Review proposal' to next Friday"
"Add a note to 'Call client' saying 'Discuss contract terms'"
"Flag the task 'Prepare presentation'"
"Move 'Write report' to the Work project"
"Set defer date for 'Start research' to Monday"
```

#### Batch Task Creation
Create multiple tasks with subtasks in one command:
```
"Create tasks: Research options|-Compare prices|-Make decision|Follow up with team"
"Add tasks to Project X: Phase 1|-Design|-Implementation|Phase 2|-Testing|-Deployment"
```
Note: Use `|` to separate tasks and `-` prefix for subtasks

#### Recurring Tasks
Set up tasks with repeat patterns:
```
"Create a daily recurring task 'Review inbox'"
"Add weekly recurring 'Team meeting' every Monday"
"Create monthly task 'Pay bills' due on the 1st"
"Set up task 'Quarterly review' repeating every 3 months"
```

#### Advanced Views
- **List Projects**: View all active projects with task counts
- **Deferred Tasks**: See tasks that aren't available yet
- **Flagged Tasks**: Quick access to all flagged items
- **Overdue Tasks**: Track tasks past their due date

### 📝 Original Features

- **Add Tasks**: Create tasks with notes, projects, due dates, defer dates, and flags
- **Inbox Management**: View and process tasks in your OmniFocus inbox
- **Today's Tasks**: See all tasks due today at a glance
- **Complete Tasks**: Mark tasks as complete by name
- **Weekly Review**: Get a comprehensive summary for your GTD weekly review

## Requirements

- macOS 10.15 (Catalina) or later
- OmniFocus 3 or later
- Claude Desktop app
- Node.js 14+ (for development only)

## Installation

### Quick Install

1. Download the latest `omnifocus-gtd-enhanced.dxt` from the [Releases](https://github.com/yourusername/omnifocus-claude-extension/releases) page
2. Open Claude Desktop
3. Navigate to Extensions settings
4. Drag and drop the `.dxt` file onto the Claude Desktop window
5. The extension will be installed and available immediately

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/omnifocus-claude-extension.git
cd omnifocus-claude-extension

# Install dependencies
npm install

# Build the enhanced extension
npm run build:enhanced

# The extension will be created at dist/omnifocus-gtd-enhanced.dxt
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
│   │   ├── index.js              # Original MCP server
│   │   └── index-enhanced.js     # Enhanced server with new features
│   ├── scripts/
│   │   ├── enhanced/              # New AppleScript implementations
│   │   │   ├── search_tasks.applescript
│   │   │   ├── edit_task.applescript
│   │   │   ├── batch_add_tasks.applescript
│   │   │   └── create_recurring_task.applescript
│   │   └── ...                    # Original scripts
│   └── manifest.json              # Extension manifest
├── dist/
│   └── omnifocus-gtd-enhanced.dxt # Built extension
└── build-dxt-enhanced.js          # Enhanced build script
```

### Building

```bash
# Build the enhanced DXT extension
npm run build:enhanced

# Build legacy version
npm run build:legacy

# Clean and rebuild
npm run rebuild

# Run tests
npm test

# Validate the built extension
npm run validate
```

### Adding New Tools

1. Create AppleScript in `src/scripts/enhanced/`
2. Add tool definition to `src/server/index-enhanced.js`
3. Update the manifest if needed
4. Rebuild the extension
5. Test thoroughly with different OmniFocus configurations

## Architecture

The enhanced extension uses an improved Model Context Protocol (MCP) server that:

1. Receives commands from Claude Desktop via JSON-RPC
2. Routes to appropriate AppleScript (enhanced or original)
3. Executes AppleScript with proper parameter handling
4. Manages complex operations like batch creation and searches
5. Returns formatted, actionable results to Claude

### Key Improvements

- **Modular Script System**: Separate enhanced scripts for maintainability
- **Parameter Validation**: Robust input handling and error messages
- **Batch Processing**: Efficient handling of multiple operations
- **Advanced Date Parsing**: Natural language date interpretation
- **State Management**: Better handling of task relationships

## Troubleshooting

### Extension Not Loading

1. Check Claude Desktop logs: `~/Library/Logs/Claude/`
2. Ensure OmniFocus is installed and running
3. Verify macOS permissions for automation
4. Try reinstalling the extension

### Tasks Not Appearing

1. Ensure OmniFocus default document is open
2. Check that you're not in a filtered view
3. Verify AppleScript automation is enabled:
   - System Preferences → Security & Privacy → Privacy → Automation
   - Ensure Claude Desktop can control OmniFocus

### Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| "Script Error" | Enable automation permissions for Claude Desktop |
| "OmniFocus not found" | Ensure OmniFocus is in /Applications |
| "No tasks found" | Check search terms and task availability |
| "Multiple matches" | Be more specific in task names |
| "Cannot create recurring" | Ensure OmniFocus Pro features are available |

## Security

This extension:
- ✅ Only reads and writes to OmniFocus via AppleScript
- ✅ Does not store or transmit personal data
- ✅ Runs entirely locally on your machine
- ✅ Requires explicit user permission for automation
- ✅ Open source for full transparency

## License

MIT License - see [LICENSE](LICENSE) file for details

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Development Guidelines

1. **Semantic Commits**: Use conventional commit messages
   - `feat:` New features
   - `fix:` Bug fixes
   - `docs:` Documentation updates
   - `refactor:` Code refactoring
   - `test:` Test additions/changes

2. **AppleScript Best Practices**:
   - Properly escape special characters
   - Handle missing values gracefully
   - Provide meaningful error messages
   - Test with different OmniFocus configurations

3. **Testing Checklist**:
   - [ ] Test with empty OmniFocus database
   - [ ] Test with large database (1000+ tasks)
   - [ ] Test with various project structures
   - [ ] Test error handling and edge cases

## Changelog

### Version 2.0.0 (Current)
- ✨ Added task search across all projects
- ✨ Added task editing capabilities
- ✨ Added batch task creation with subtasks
- ✨ Added recurring task support
- ✨ Added defer date support
- ✨ Added project listing with statistics
- ✨ Added deferred, flagged, and overdue task views
- 🔧 Improved error handling and messages
- 🔧 Enhanced date parsing
- 📝 Comprehensive documentation

### Version 1.0.0
- Initial release with basic functionality

## Roadmap

### Version 2.1 (Planned)
- [ ] Tag management and filtering
- [ ] Custom perspective support
- [ ] Context/tag-based task creation
- [ ] Task templates
- [ ] Quick entry with global hotkeys

### Version 3.0 (Future)
- [ ] Two-way sync capabilities
- [ ] Advanced filtering and smart searches
- [ ] Integration with other GTD tools
- [ ] Natural language processing improvements
- [ ] Workflow automation

## Acknowledgments

- OmniFocus by [The Omni Group](https://www.omnigroup.com/)
- Claude Desktop by [Anthropic](https://www.anthropic.com/)
- GTD methodology by David Allen
- Community contributors and testers

## Support

For issues, questions, or feature requests:
- 🐛 Open an issue on [GitHub](https://github.com/yourusername/omnifocus-claude-extension/issues)
- 📚 Check the [Wiki](https://github.com/yourusername/omnifocus-claude-extension/wiki) for detailed guides
- 💬 Join our [Discord community](https://discord.gg/example)
- 📧 Email: support@example.com

---

Made with ❤️ for the GTD community
