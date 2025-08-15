# OmniFocus Claude Extension

A powerful OmniFocus integration for Claude Desktop that enables natural language task management using GTD (Getting Things Done) methodology.

## Features

- **Add Tasks**: Create tasks with natural language, including notes, projects, due dates, and flags
- **Inbox Management**: View and process tasks in your OmniFocus inbox
- **Today's Tasks**: See all tasks due today at a glance
- **Complete Tasks**: Mark tasks as complete by name
- **Weekly Review**: Get a comprehensive summary for your GTD weekly review

## Requirements

- macOS (10.15 or later)
- OmniFocus 3 or later
- Claude Desktop app
- Node.js 14+ (for development)

## Installation

### Quick Install

1. Download the latest `omnifocus-gtd.dxt` from the [Releases](https://github.com/yourusername/omnifocus-claude-extension/releases) page
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

# Build the extension
npm run build:dxt

# The extension will be created at dist/omnifocus-gtd.dxt
```

## Usage

Once installed, you can use natural language commands in Claude Desktop:

### Adding Tasks

```
"Add a task to review Q3 reports due Friday"
"Create a task to call John in the Sales project"
"Add a flagged task to prepare presentation notes"
```

### Managing Tasks

```
"Show me my inbox"
"What tasks are due today?"
"Complete the task about reviewing reports"
"Give me a weekly review summary"
```

## Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `add_task` | Add a new task to OmniFocus | "Add task to buy milk" |
| `list_inbox` | Show all inbox tasks | "Show my inbox" |
| `today_tasks` | List tasks due today | "What's due today?" |
| `complete_task` | Mark a task as complete | "Complete the budget review task" |
| `weekly_review` | Get weekly review summary | "Show weekly review" |

## Development

### Project Structure

```
omnifocus-claude-extension/
├── src/
│   ├── server/
│   │   └── index.js        # MCP server implementation
│   ├── scripts/
│   │   ├── add_task.applescript
│   │   ├── list_inbox.applescript
│   │   └── ...             # AppleScript implementations
│   ├── tools/
│   │   └── ...             # Tool definitions
│   └── manifest-dxt.json   # Extension manifest
├── dist/
│   └── omnifocus-gtd.dxt   # Built extension
└── build-dxt.js            # Build script
```

### Building

```bash
# Build the DXT extension
npm run build:dxt

# Run tests
npm test

# Validate the built extension
npm run validate
```

### Adding New Tools

1. Create a tool definition in `src/tools/`
2. Add corresponding AppleScript in `src/scripts/`
3. Update the manifest in `src/manifest-dxt.json`
4. Rebuild the extension

## Architecture

The extension uses a Model Context Protocol (MCP) server that:
1. Receives commands from Claude Desktop via JSON-RPC
2. Translates commands to AppleScript
3. Executes AppleScript to interact with OmniFocus
4. Returns formatted results to Claude

## Troubleshooting

### Extension Not Loading

1. Check Claude Desktop logs for errors
2. Ensure OmniFocus is installed and running
3. Verify macOS permissions for automation

### Tasks Not Appearing

1. Ensure OmniFocus is the active task manager
2. Check that the default document is open
3. Verify AppleScript automation is enabled in System Preferences

### Common Issues

- **"Script Error"**: Enable automation permissions for Claude Desktop in System Preferences > Security & Privacy > Privacy > Automation
- **"OmniFocus not found"**: Ensure OmniFocus is installed in /Applications
- **"No tasks found"**: Verify tasks exist in OmniFocus and match search criteria

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

### Development Guidelines

1. Follow semantic commit conventions
2. Add tests for new features
3. Update documentation
4. Ensure AppleScript is properly escaped
5. Test with different OmniFocus configurations

## Security

This extension:
- Only reads and writes to OmniFocus via AppleScript
- Does not store or transmit personal data
- Runs entirely locally on your machine
- Requires explicit user permission for automation

## License

MIT License - see [LICENSE](LICENSE) file for details

## Acknowledgments

- OmniFocus by The Omni Group
- Claude Desktop by Anthropic
- GTD methodology by David Allen
- Community contributors

## Support

For issues, questions, or suggestions:
- Open an issue on [GitHub](https://github.com/yourusername/omnifocus-claude-extension/issues)
- Check the [Wiki](https://github.com/yourusername/omnifocus-claude-extension/wiki) for detailed guides
- Join our [Discord community](https://discord.gg/example)

## Roadmap

- [ ] Project management tools
- [ ] Advanced filtering and search
- [ ] Perspective support
- [ ] Tag management
- [ ] Recurring task templates
- [ ] Integration with other GTD tools
- [ ] Batch operations
- [ ] Natural language date parsing improvements

---

Made with ❤️ for the GTD community
