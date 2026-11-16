# Changelog

All notable changes to the OmniFocus Claude Extension will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **GTD queries**
  - `list_available_tasks`: next actions across all projects (open, not blocked, not deferred, active project,
    no action groups), grouped by project, optionally filtered by tag or folder
  - `list_tasks_by_tag`: open tasks with a tag (and optionally its child tags), for contexts, people or "waiting for"
  - `list_completed_tasks`: tasks completed in the last N days, grouped by day
- **Review tools**: `list_projects_for_review`, `mark_project_reviewed`, `list_stalled_projects`
- **Projects and folders**: `create_project`, `edit_project` (name, note, folder, status, type), `create_folder`,
  `rename_folder`
- **Project properties**: `edit_project` sets the review interval (`1 week`, `2 weeks`, `1 month`, `1 year`), the next
  review date, due, defer and planned date, the flag and "complete with last item".
  `create_project` takes a review interval, due and defer date and a type and checks them before it creates anything.
  `list_projects_for_review` shows the review interval of each project
- **Tags**: `edit_tag` (name, note, parent, hidden, allows next action)
- **Tasks**: `reopen_task` (completed or dropped tasks), `planned_date` in `add_task` and `edit_task`, and `parent_task` in
  `add_task` to create a subtask under an existing task
- **Projects**: `get_project` shows a project with status, type, dates, review interval and all its tasks as an indented
  list with subtasks, including blocked and deferred tasks (completed and dropped tasks on request)
- **Tasks**: `get_task` (all details of one task) and `drop_task` (deleting needs the explicit `confirm_delete`)
- **ID addressing**: task and project tools accept `id:<id>`; list outputs, search results and ambiguity messages
  show the IDs
- **`include_dropped` parameter** on the read tools. Without it, dropped items and items below dropped (hidden)
  folders are left out
- Date-only ISO dates (`YYYY-MM-DD`) in `add_task`, `batch_add_tasks` and `create_recurring_task` (midnight)

### Changed
- Projects are found in all folders, not only at the top level, by name or path `Folder > Subfolder > Project`
  (`edit_task`, `add_task`, `batch_add_tasks`, `create_recurring_task`). Ambiguous or unknown projects return an
  error and change nothing; tasks are no longer silently put into the inbox
- `edit_task` parses ISO dates (`YYYY-MM-DD`, `YYYY-MM-DD HH:MM`) and rejects impossible dates
- `list_projects` shows the folder path, lists on hold projects and counts available tasks correctly
- `list_inbox`, `list_overdue_tasks` and `search_tasks` list open tasks only
- Tool output uses line feeds instead of carriage returns
- Tags are found at every level of the tag hierarchy, by name, path `Parent > Child` or `id:<id>`
  (`add_task`, `batch_add_tasks`, `edit_task`, `add_tag_to_task`, `remove_tag_from_task`, `create_tag`). An ambiguous
  tag name returns the matches and changes nothing
- `create_tag` looks for an existing tag with the same name below the same parent only, and accepts a nested tag as parent
- `list_tags` shows IDs, hidden tags and tags that do not allow next actions

### Fixed
- `search_tasks` with `filter: "remaining"` or `"available"` failed
- Completed tasks showed up in `list_inbox` and `list_overdue_tasks`
- Adding a nested tag to a task created a second tag with the same name at top level

### Security
- Tool output is wrapped in a block marked as untrusted data, so that task names and notes are not read as instructions
- The server log contains metadata only, no task content
- `delete_tag` was removed

## [2.0.3] - 2026-03-21

### Changed
- Renamed extension format from `.dxt` to `.mcpb` to match Anthropic's updated naming
- Renamed `validate-dxt.js` to `validate-mcpb.js`
- Updated npm script `build:dxt` to `build:mcpb`
- Updated CI/CD pipeline artifact names
- No changes to internal archive format (still ZIP with manifest.json)

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
3. Download and install `omnifocus-gtd.mcpb` (or `omnifocus-gtd.dxt` for versions before 2.0.3)
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
