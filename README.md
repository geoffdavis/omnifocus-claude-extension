# OmniFocus GTD Desktop Extension for Claude

A comprehensive OmniFocus integration for Claude Desktop that enables natural language task management using GTD (Getting Things Done) methodology.

## 🚀 Installation

1. Download the `omnifocus-gtd.dxt` file
2. Open Claude Desktop
3. Drag and drop the `.dxt` file onto the Claude Desktop window
4. The extension will be installed automatically
5. Grant permission for Claude Desktop to control OmniFocus when prompted

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

### Project Management
- **Create projects** with optional folder placement
- **List projects** with active task counts
- **Organize by folders** for better structure

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

### Searching
- "Search for tasks about meetings"
- "Find all tasks with 'report' in the name"
- "Search completed tasks for invoice"

### Reviews
- "Run weekly review"
- "Show quick stats"
- "Process my inbox"

### Project Management
- "Create project called Q1 Planning in Work folder"
- "List all projects"
- "Show projects with tasks"

## 🛠️ Available Commands

| Command | Description | Parameters |
|---------|-------------|------------|
| `add_task` | Add a new task | name, note, project, due_date, flagged |
| `list_inbox` | Show inbox items | include_notes |
| `today_tasks` | List today's tasks | - |
| `complete_task` | Mark task complete | task_name |
| `list_projects` | Show all projects | include_empty |
| `search_tasks` | Find tasks | search_term, include_completed |
| `create_project` | New project | name, folder, notes |
| `weekly_review` | Review summary | - |
| `upcoming_tasks` | Future tasks | days |
| `flagged_tasks` | Priority items | - |
| `process_inbox` | Inbox helper | - |
| `quick_stats` | Statistics | - |

## 📋 Requirements

- **OmniFocus 3** or later installed on macOS
- **Claude Desktop** application
- **macOS** with AppleScript support enabled
- Permission for Claude Desktop to control OmniFocus (granted on first use)

## 🔧 Troubleshooting

### Extension not working?
1. Ensure OmniFocus is running
2. Check System Preferences → Security & Privacy → Privacy → Automation
3. Allow Claude Desktop to control OmniFocus

### Tasks not appearing?
- Verify tasks are not completed (hidden by default)
- Check the correct project/folder is selected
- Ensure proper date filters are applied

### Permission errors?
- Grant automation permissions when prompted
- Restart Claude Desktop after granting permissions
- Check that OmniFocus is not in a modal dialog state

## 🤝 Contributing

This extension is open source and community-driven. Contributions are welcome!

### How to contribute:
1. Test the extension and report issues
2. Suggest new features or improvements
3. Share your workflows and use cases
4. Help improve the documentation

### Feature requests:
- Perspective support
- Custom metadata fields
- Recurring task templates
- Batch operations
- Integration with OmniFocus tags/contexts

## 📄 License

MIT License - Feel free to use, modify, and share!

## 🙏 Acknowledgments

Created by the Claude Desktop community for GTD practitioners and OmniFocus users everywhere.

Special thanks to:
- The OmniFocus team for their excellent AppleScript support
- Anthropic for making Claude Desktop extensible
- The GTD community for methodology and workflows

## 📚 Resources

- [OmniFocus AppleScript Guide](https://omni-automation.com/omnifocus/)
- [GTD Methodology](https://gettingthingsdone.com/)
- [Claude Desktop Extensions Docs](https://claude.ai/docs/desktop-extensions)

## 💡 Tips for Best Use

1. **Natural language works best** - Just describe what you want naturally
2. **Use projects for organization** - Keep inbox clean by assigning to projects
3. **Regular reviews** - Run weekly review every week for best results
4. **Flag sparingly** - Only flag true priorities to maintain focus
5. **Process inbox daily** - Keep inbox at zero for clarity

## 🐛 Known Limitations

- Date parsing is limited to "today", "tomorrow", and "next week" (more coming soon)
- Cannot access OmniFocus perspectives directly
- Limited to 20 results in search to prevent overload
- Cannot modify recurring task patterns
- No access to tags/contexts (OF2 legacy)

## 📈 Version History

### v1.0.0 (Current)
- Initial release with core GTD features
- 12 commands for complete task management
- Natural language task entry
- Weekly review automation
- Basic date parsing

### Planned for v1.1.0
- Enhanced date parsing
- Tag/context support
- Perspective access
- Recurring task templates
- Batch operations

---

Enjoy using OmniFocus with Claude Desktop! 🚀