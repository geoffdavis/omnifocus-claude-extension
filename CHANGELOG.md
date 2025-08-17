# Changelog

All notable changes to the OmniFocus Claude Extension will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-12-20

### Added
- **Search Functionality**: Search tasks across all projects, contexts, and notes
  - Filter by availability (all, available, remaining)
  - Configurable result limits
  - Search in both task names and notes
  
- **Task Editing**: Modify any property of existing tasks
  - Edit name, note, due date, defer date
  - Change flagged status
  - Move between projects
  - Set estimated time
  
- **Batch Operations**: Create multiple tasks in one command
  - Support for subtasks using `-` prefix
  - Pipe-separated task lists
  - Bulk property assignment
  
- **Recurring Tasks**: Full support for repeating tasks
  - Daily, weekly, monthly, yearly patterns
  - Custom intervals (e.g., every 3 days)
  - Fixed or due-after-completion methods
  
- **Enhanced Views**:
  - List all projects with task statistics
  - View deferred tasks with availability dates
  - Quick access to all flagged items
  - Comprehensive overdue task list
  
- **Defer Date Support**: Full defer date handling across all operations

### Changed
- Refactored server architecture for better extensibility
- Improved error handling with detailed user-friendly messages
- Enhanced date parsing with natural language support
- Modularized AppleScript implementations
- Updated build process for enhanced features

### Fixed
- Task completion now works correctly with inbox items
- Better handling of tasks without projects
- Improved matching algorithm for task searches
- Fixed issues with special characters in task names

### Technical
- Split scripts into original and enhanced directories
- Created `index-enhanced.js` server implementation
- Added `build-dxt-enhanced.js` build script
- Increased buffer sizes for large result sets

## [1.0.0] - 2024-12-01

### Initial Release
- Basic task creation with name, note, project, due date, and flag
- Inbox listing and management
- Today's tasks view
- Task completion by name search
- Weekly review summary
- GTD methodology support

### Known Limitations (Resolved in 2.0.0)
- Could only create single tasks
- No search functionality
- No task editing capabilities
- No recurring task support
- No defer date support
- Limited project management

## [0.9.0-beta] - 2024-11-15

### Beta Release
- Initial MCP server implementation
- Basic AppleScript integration
- Claude Desktop compatibility testing
- Core GTD features

---

## Upgrade Guide

### From 1.0.0 to 2.0.0

1. **Backup your OmniFocus database** before upgrading
2. Uninstall the old extension from Claude Desktop
3. Download and install `omnifocus-gtd-enhanced.dxt`
4. All previous commands remain compatible
5. New features are immediately available

### Breaking Changes
- None - Version 2.0.0 is fully backward compatible

### New Command Examples

#### Search Tasks
```
"Search for all tasks containing 'budget'"
"Find available tasks with 'meeting'"
```

#### Edit Tasks
```
"Change the due date of 'Review proposal' to next Friday"
"Flag the task 'Important presentation'"
"Move 'Write report' to the Work project"
```

#### Batch Creation
```
"Create tasks: Research|-Literature review|-Analysis|Write report|Submit"
```

#### Recurring Tasks
```
"Create a weekly recurring task 'Team meeting' due Mondays"
"Add daily task 'Process inbox' repeating forever"
```

---

## Future Releases

### [2.1.0] - Planned Q1 2025
- Tag management and filtering
- Custom perspective support
- Task templates
- Import/export capabilities

### [3.0.0] - Planned Q2 2025
- Two-way sync with OmniFocus
- Advanced natural language processing
- Workflow automation
- Integration with calendar apps

---

For more information, see the [README](README.md) or visit our [GitHub repository](https://github.com/yourusername/omnifocus-claude-extension).
