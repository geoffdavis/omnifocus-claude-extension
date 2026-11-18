# Changelog

All notable changes to the OmniFocus Claude Extension will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Dates and counts**: `get_task` shows the dates a task gets from a containing task or project (effective due, defer and
  planned date, only when they differ from its own), the dates of the next occurrence of a task that repeats on a fixed
  schedule and the number of available subtasks. The state of a task that starts in the future reads `deferred` (as in
  `get_project`) instead of `blocked`; `blocked` stays for tasks that wait for an earlier task or for their subtasks.
  `list_tags` with `include_counts` shows the remaining and the available tasks per tag as OmniFocus counts them (child tags included, one query each for all tags; the old count of open tasks stays
  as the fallback for an OmniFocus without these numbers)
  `get_project` shows the dates of the next occurrence of a project that repeats on a fixed schedule, the number of
  available tasks at top level and whether the project is the default project for single actions; `edit_project` sets that
  flag (`default_single_action_list`, the flag leaves the project that had it and the answer names it)
- **Projects with a tag**: OmniFocus keeps the tags of a project on its hidden root task and counts the project as one
  remaining task of the tag, so `list_tags` counted one more than `list_tasks_by_tag` listed. `list_tasks_by_tag` now lists
  the open projects that carry the tag (or a child tag) in a block of their own with flag, due date, `on hold`, tags,
  ID and folder (`include_projects`, default on; not with `available_only`, `max_minutes` or `project`). The text of
  `list_tags` says that such a project counts as one task
- **Projects are no tasks**: OmniFocus gives every project a hidden root task with the ID of the project, which the task
  tools found by ID or by name. `get_task` now answers with a pointer to `get_project`; `complete_task`, `drop_task`,
  `reopen_task`, `edit_task`, `add_tag_to_task`, `remove_tag_from_task` and the tools that take a task by name or ID
  (`add_task` and `parse_tasks` with `parent_task`, `show_item`, `save_attachment`, `duplicate_item`, and `edit_task` with
  `parent_task` or `assigned_container`) refuse the ID of a project and change nothing. The name search leaves the root
  tasks out and says so when only projects have that name
  Also `search_tasks`, `list_overdue_tasks`, `list_flagged_tasks`, `list_deferred_tasks`, `list_due_soon`, `list_completed_tasks`,
  `today_tasks` and `weekly_review` no longer show (or count) a project with a due date, a flag or a completion as a task
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
- **Tags of projects**: `edit_project` sets the tags (`tags`, a comma-separated list or `none`) and the primary tag
  (`primary_tag`) of a project, `create_project` takes `tags`, `get_project` shows `Tags:` and `Primary tag:`. Tasks and
  projects share the same handlers; all tags are looked up before anything changes
- **Settings and backup**: `get_settings` reads the settings of the database and the preferences of the app (value and
  default, filter by ID), `create_backup` writes a backup archive of the database to a new path (a package). The archive
  is written in the background: the call waits `wait_seconds` (default 40, at most 70) and `status_only` shows later
  whether the archive is finished, still being written, failed or interrupted, with its size
- **Purge**: `purge_tasks` deletes completed and/or dropped tasks permanently (`scope`, `older_than_days`, `folder`,
  `project`). It only lists what it would delete unless `dry_run` is false and `confirm_delete` is true. Open tasks are
  never touched; a task is only deleted together with all its subtasks, so a task with open subtasks is skipped and
  reported. Tasks below hidden folders are counted and marked. `limit` (default 200) and a time limit of about 50
  seconds keep a call short, the answer says how many tasks are left
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
- Shorter output for the reader (fewer tokens per call): the list tools (`list_overdue_tasks`, `list_flagged_tasks`,
  `list_deferred_tasks`, `list_due_soon`, `list_completed_tasks`, `list_tasks_by_date`, `list_available_tasks`,
  `list_tasks_by_tag`, `list_projects_for_review`, `search_tasks`) write dates as `2026-11-18` (with `08:30` if the date has
  a time) instead of `Wednesday, 18. November 2026 at 08:30:00`; the form is the same on every Mac, whatever its language
  and region. The decoration lines (`════`) and the advice blocks (`Recommended Actions` in `list_overdue_tasks`,
  `Summary` in `list_flagged_tasks`, the action lines in `weekly_review`) are gone; the counts are in the headings.
  `search_tasks` says when the list was cut at the limit and how to get fewer results. `get_task`, `get_project` and the
  messages after a change keep the long date

### Fixed
- `create_backup` blocked the call until OmniFocus had written the archive, so a large database ran into the time limit of
  the app (about 80 seconds) and left it open whether the archive was written. The archive command now runs in a process of
  its own, the call returns after `wait_seconds`, and `status_only` shows the result
- `search_tasks` with `filter: "remaining"` or `"available"` failed
- Completed tasks showed up in `list_inbox` and `list_overdue_tasks`
- Adding a nested tag to a task created a second tag with the same name at top level
- Language and region of the Mac: on an Arabic or Persian Mac the numbers of repeat rules were written with Eastern
  Arabic digits (`INTERVAL=٢`), and OmniFocus rejected the rule. On a Turkish Mac keywords with a capital I (`Inbox`,
  `In 3 days`, `DAILY`) were not recognized. A date text that the system parser read without its time (`01.12.2026 14:30`
  on a US Mac) or without its PM was accepted with the wrong time, and a month name with an accent made a valid date
  fail. A date written as a literal in a script stopped the whole script on a Mac whose language cannot read it.
  Repeat rules use the digits 0 to 9, keywords are compared in lower case, and a date text whose time does not fit is
  refused. The review interval takes whole numbers only (`1,5 weeks` was rounded)
- Wrong types of values: all tools check their arguments against the schema first. A number for a text, numeric text
  for a whole number, `"true"` for a boolean and an enumeration value in other case are converted; an object for a text,
  `"abc"` or `2.5` for a whole number, a value outside an enumeration or arguments that are not an object are refused
  with a message naming the parameter (`Invalid value for limit ("abc"): expected a whole number. Nothing was done.`)
  instead of an AppleScript error. Attachment numbers (`edit_task`, `edit_project`, `edit_folder`, `save_attachment`), the
  limit of `search_tasks` and `estimated_minutes` of `add_task` are whole numbers only (`1.5` was rounded or failed,
  depending on the region), and a number with more than nine digits is no longer converted in dates and repeat rules
- `today_tasks` named the database instead of the inbox for tasks in the inbox (`(OmniFocus)`); they show `(Inbox)`
- Dates: `add_task` read "2026-12-01 10:00" as a date in 2007, and the other tools set today or tomorrow when they could
  not read a date. All tools that take a date now use one parser: `YYYY-MM-DD`, `YYYY-MM-DD HH:MM`, `today`, `tomorrow`,
  `next week`, `3 days`, `2 weeks`, and the date formats of the system language as a last try. A date that cannot be read
  (or does not exist, like 2026-02-30) is refused with a clear message and nothing is changed or created; `add_task` skips
  it and warns, as before

### Performance
- The read tools no longer ask OmniFocus once per task, project or tag. Every Apple Event costs about 17 ms, so a tool that
  read three properties of each of 1,300 tasks needed more than a minute (`list_tags` with counts 28 s, `search_tasks`
  over all tasks 135 s, `list_available_tasks` 30 s, `list_projects` with statistics 19 s). The tools now read each
  property of all tasks, projects, folders or tags with one query (about 0.05 s) and filter, group and sort in the
  script. Measured with 1,318 tasks, 74 projects, 147 tags and 29 folders: all 48 calls of the test run together took 49 s
  instead of 589 s (`list_tags` with counts 1.4 s, `list_projects` with statistics 1.0 s, `search_tasks` over all tasks
  2.2 s, `list_available_tasks` 1.2 s); the output is the same
- Tasks and projects below hidden (dropped) folders are recognized through the ID of their project (one query for all
  folders and one for all projects) instead of a list of all their task IDs or one query per item
- Lists sorted by date (`list_overdue_tasks`, `list_deferred_tasks`, `list_due_soon`) are sorted in the script
  (stable merge sort, equal dates keep the order of OmniFocus) instead of comparing two dates with Apple Events per
  comparison, which took 17 s for 33 tasks
- Projects are found by name or path with one query for all names instead of one query per project; the same for
  tags and folders
- The server runs scripts asynchronously, one after the other, and stops a script after 120 seconds
  (`OMNIFOCUS_SCRIPT_TIMEOUT_SECONDS` changes the limit) with the message to check OmniFocus before repeating a change.
  A script that does not return no longer blocks the server, and an answer that is still being written is not lost when
  Claude Desktop closes the connection

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
