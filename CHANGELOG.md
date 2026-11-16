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
  - `list_tasks_by_date`: tasks or projects by the date they were created, last modified or dropped, for the last N days
    or a period (`since`, `until`), newest first and grouped by day; optionally only open items or one project
  - `list_due_soon`: open tasks due in the next N days, soonest first, grouped by tag, day or project
  - `list_perspectives`: built-in and custom perspectives with their IDs (scripts cannot read the rules of a perspective)
- `list_available_tasks` and `list_tasks_by_tag`: `project` limits the list to one project (name, path or `id:<id>`),
  `max_minutes` (with `include_unestimated`) filters by estimated minutes,
  `show_age` lists the tasks oldest first with their age since creation (for example for a "waiting for" list)
- **Review tools**: `list_projects_for_review`, `mark_project_reviewed`, `list_stalled_projects`
- **Projects and folders**: `create_project`, `edit_project` (name, note, folder, status, type), `create_folder`,
  `rename_folder`
- **Project properties**: `edit_project` sets the review interval (`1 week`, `2 weeks`, `1 month`, `1 year`), the next
  review date, due, defer and planned date, the flag and "complete with last item".
  `create_project` takes a review interval, due and defer date and a type and checks them before it creates anything.
  `list_projects_for_review` shows the review interval of each project
- **Tags**: `edit_tag` (name, note, parent, hidden, allows next action, location)
- **Tag locations**: `edit_tag` sets (`location`: `latitude=50.9787; longitude=11.3235; radius=0.5; trigger=arriving`, name,
  altitude, radius in km and trigger optional) or removes (`none`) the location of a tag, the values OmniFocus uses for
  Nearby; fields that are not given keep their value. `list_tags` shows the location of a tag
- **Tasks**: `reopen_task` (completed or dropped tasks), `planned_date` in `add_task` and `edit_task`, and `parent_task` in
  `add_task` to create a subtask under an existing task
- **Repetition**: `edit_task` and `edit_project` set (`repeat`: "daily", "2 weeks", "weekly fixed", ...) or remove (`none`) the
  repetition of an existing task or project, `get_task` and `get_project` show it
- **Repetition rules**: `repeat` and `create_recurring_task` accept weekdays ("every monday and thursday", "weekdays"), days
  of the month ("monthly on the 15th", "last day of the month"), the nth or last weekday of the month ("first monday of
  the month", "last friday of the month") and iCalendar rules (`FREQ=WEEKLY;BYDAY=MO,TH`, with `COUNT` or `UNTIL`), on a
  fixed schedule (`fixed`) or after completion (`from completion`). `repeat_based_on` (`due`, `defer`, `planned`) and
  `repeat_catch_up` (`true`/`false`) change the date a repetition is based on and the automatic catching up of a
  fixed schedule without touching the rest of the rule. A rule that OmniFocus does not accept changes nothing, and
  `create_recurring_task` creates nothing (also without a name). OmniFocus has no yearly rule for a fixed month and
  day: a yearly rule repeats on the date of the due date
- **Undo**: `undo` undoes or redoes the last change(s) in OmniFocus (`action`, `steps` up to 20). OmniFocus reverts the last
  change whoever made it, so also changes made by hand
- **Small properties**: `edit_task` sets the primary tag (`primary_tag`), the time zone setting of the due and defer date
  (`floating_time_zone`, also in `edit_project`) and the provisional project or parent task of an inbox task
  (`assigned_container`, made final by `clean_up`). `get_task`, `get_project` and `list_inbox` show them
- **Settings and backup**: `get_settings` reads the settings of the database and the preferences of the app (value and
  default, filter by ID), `create_backup` writes a backup archive of the database to a new path (a package)
- **Sync and clean up**: `synchronize` starts the synchronization with the sync database and waits until OmniFocus reports that
  it is finished (`wait_seconds`, default 15, 0 = do not wait); its answer shows when the last synchronization finished and
  its error, if there was one, and `status_only` reports that without starting a synchronization; `clean_up` runs Clean Up (inbox items that already have
  a project are moved into their projects, completed tasks are hidden) and reports how many inbox items were moved
- **View and selection**: `get_selection` shows the perspective, search term, focus and selected items (type, name and ID,
  so that other tools can take them with `id:<id>`) of the front OmniFocus window, `set_view` switches the perspective,
  sets or clears the search term and focuses the window on a project or folder (and checks the result), `show_item` opens
  a task, project, folder or tag in the window through its `omnifocus:///` link and selects it. Both add a note for a
  project that is completed or dropped, or that is below a hidden folder
- **Estimate**: `edit_task` removes the estimate (`estimated_minutes`: `none`) and refuses a value that is not a whole number of
  minutes instead of failing with an AppleScript error
- **Duplicate**: `duplicate_item` copies a task with its subtasks or a project with all its tasks. The copy keeps notes, tags,
  dates, estimate, flag and repetition; it goes directly after the original or into another project (`project`, or the
  inbox), below a task (`parent_task`) or into a folder (`folder`, `none` for the top level). `new_name` renames the copy
  (a project copy gets " copy" if its folder already has a project with this name). Tasks that were dropped are dropped
  again in the copy, because OmniFocus loses that state when it copies; `reopen_completed` opens the completed tasks of
  the copy again, for example to use a project as a template. Folders cannot be duplicated (OmniFocus does not allow it)
- **Attachments in notes**: `edit_task`, `edit_project` and `edit_folder` attach a file (`attach_file`: a copy is stored in the
  note, `link_file`: the note links to the file) at the end of the note and remove an attachment (`remove_attachment`, by number).
  `get_task` and `get_project` list the attachments (path of linked files) and mark them in the note text;
  `save_attachment` writes an embedded attachment to a new file
- **Folder actions**: `list_folders` shows all folders as a hierarchy (project counts, hidden folders, notes, IDs),
  `edit_folder` changes the name, note (`note`, `append_note`), parent (`parent`, `none` = top level; the folder is moved
  with everything in it; cycles and duplicate names are refused) and visibility (`hidden`) of a folder, `delete_folder`
  deletes a folder (needs `confirm_delete`; a folder that contains projects or subfolders only with `delete_contents`).
  Folders can also be addressed by `id:<id>` in `rename_folder`, `create_folder`, `create_project` and `edit_project`
- **Links**: `get_selected_link` shows what is selected or open in Mail (`message://`), Safari and Chromium browsers (URL of
  the front tab), Finder (`file://`) or Contacts (`addressbook://`) with a link for each item (no message bodies or file
  contents are read, the app is not started). `edit_task` and `edit_project` have `append_note`, which adds a line to the
  end of the note (any app link as text) and refuses to change a note with attachments or formatting. `get_task` and
  `get_project` show the `omnifocus:///task/<id>` link of the item
- **Text to tasks**: `parse_tasks` turns text into tasks and subtasks (one per line, indentation makes subtasks) in the inbox, in a
  project or below a task, or converts the note of an existing task (`from_note`, optionally emptying it with
  `clear_note`). Each line goes through the text parser of OmniFocus ("parse tasks into"), so its inline syntax works;
  OmniFocus itself would make one task out of a multi-line text, so the lines are split by the script
- **Action groups**: `edit_task` moves a task (with its subtasks) below another open task (`parent_task`) and sets whether the
  subtasks are done one after another (`sequential`) and whether the task completes with its last subtask
  (`complete_with_last_item`). `get_task` and `get_project` show the behavior of an action group. The task lookup of
  `add_task` (parent task) is shared with `edit_task`
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
