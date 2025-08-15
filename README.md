# OmniFocus GTD Desktop Extension for Claude

A comprehensive OmniFocus integration for Claude Desktop that enables natural language task management using GTD (Getting Things Done) methodology.

## 🚀 Quick Start

### Installation (Pre-built)

1. Download the latest `omnifocus-gtd.dxt` from [Releases](https://github.com/yourusername/omnifocus-claude-extension/releases)
2. Open Claude Desktop
3. Drag and drop the `.dxt` file onto the Claude Desktop window
4. Grant permission when prompted

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/omnifocus-claude-extension.git
cd omnifocus-claude-extension

# Install dependencies
npm install

# Build the extension
npm run build

# The extension will be created at dist/omnifocus-gtd.dxt
```

## 🛠️ Development

### Project Structure

```
omnifocus-claude-extension/
├── src/
│   ├── manifest.json         # Extension metadata
│   ├── tools/                # Tool definitions (JSON)
│   │   ├── add_task.json
│   │   ├── complete_task.json
│   │   └── ...
│   └── scripts/              # AppleScript implementations
│       ├── add_task.applescript
│       ├── complete_task.applescript
│       └── ...
├── dist/                     # Built extension (gitignored)
│   └── omnifocus-gtd.dxt
├── build.js                  # Build script
├── test.js                   # Test suite
└── package.json             # Project configuration
```

### Building

```bash
# Build the extension
npm run build

# Clean build directories
npm run clean

# Clean and rebuild
npm run rebuild

# Run tests
npm test

# Watch mode (rebuilds on file changes)
npm run watch
```

### Adding New Tools

1. Create a tool definition in `src/tools/`:
```json
{
  "name": "tool_name",
  "description": "What this tool does",
  "parameters": {
    "type": "object",
    "properties": {
      "param": {
        "type": "string",
        "description": "Parameter description"
      }
    },
    "required": ["param"]
  },
  "script": "tool_name.applescript"
}
```

2. Create the AppleScript in `src/scripts/tool_name.applescript`

3. Run `npm run build` to rebuild the extension

4. Test the new tool

## ✨ Features

### Core Task Management
- **Add tasks** with natural language parsing (supports "tomorrow", "next week", etc.)
- **Complete tasks** by name or partial match
- **Search tasks** across your entire OmniFocus database
- **Flag tasks** for priority tracking

### Views & Lists
- **Inbox view** - See and process all inbox items
- **Today's tasks** - Focus on what's due today
- **Upcoming tasks** - View tasks due in next N days
- **Flagged items** - Quick access to priority tasks
- **Project list** - Overview of all projects with task counts

### GTD Reviews
- **Weekly review** - Comprehensive statistics and action items
- **Process inbox** - Interactive guidance for inbox zero
- **Quick stats** - Database overview and completion rates

## 💬 Natural Language Examples

### Adding Tasks
- "Add task: Call dentist tomorrow"
- "Add a task to buy milk with high priority"
- "Create task: Finish report by Friday in Work project"
- "Add flagged task: Review budget presentation"

### Checking Status
- "What's due today?"
- "Show my inbox"
- "List upcoming tasks for next 3 days"
- "Show flagged tasks"
- "What are my active projects?"

### Completing Work
- "Complete task about dentist"
- "Mark 'Buy milk' as done"
- "Complete the budget review task"

## 🛠️ Available Commands

| Command | Description | Parameters |
|---------|-------------|------------|
| `add_task` | Add a new task | name, note, project, due_date, flagged |
| `list_inbox` | Show inbox items | - |
| `today_tasks` | List today's tasks | - |
| `complete_task` | Mark task complete | task_name |
| `weekly_review` | Review summary | - |

## 📋 Requirements

- **OmniFocus 3** or later installed on macOS
- **Claude Desktop** application
- **macOS** with AppleScript support enabled
- **Node.js** 14+ (for building from source)

## 🔧 Troubleshooting

### Extension not working?
1. Ensure OmniFocus is running
2. Check System Preferences → Security & Privacy → Privacy → Automation
3. Allow Claude Desktop to control OmniFocus

### Build issues?
1. Ensure Node.js is installed: `node --version`
2. Clear and rebuild: `npm run rebuild`
3. Check for script errors: `npm test`

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Add your tool/feature
4. Run tests: `npm test`
5. Build: `npm run build`
6. Test in Claude Desktop
7. Submit a pull request

## 📄 License

MIT License - See [LICENSE](LICENSE) for details

## 🙏 Acknowledgments

Created by the Claude Desktop community for GTD practitioners and OmniFocus users everywhere.

## 📚 Resources

- [OmniFocus AppleScript Guide](https://omni-automation.com/omnifocus/)
- [GTD Methodology](https://gettingthingsdone.com/)
- [Claude Desktop Extensions Docs](https://claude.ai/docs/desktop-extensions)

## 📈 Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

---

Enjoy using OmniFocus with Claude Desktop! 🚀