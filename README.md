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
- **Recurring Tasks and Projects**: Repeat by interval, on weekdays, on a day of the month or on the last Friday of the month, on a fixed schedule or after completion, based on the due, defer or planned date, with or without catching up; for tasks and projects
- **Text to tasks**: Turn a list of lines (or the note of a task) into tasks and subtasks, with the inline syntax of OmniFocus
- **Undo**: Undo or redo the last change(s) in OmniFocus (it reverts changes made by hand too)
- **Sync and clean up**: Synchronize OmniFocus on request (with the time and error of the last sync), and run Clean Up (inbox items with a project move into their projects)
- **Links**: Put a link to anything in another app into the note of a task (any URL or app link), take it from Mail, Safari, Chrome, Finder or Contacts, and get the `omnifocus:///task/<id>` link of a task or project
- **Action groups**: Move a task below another task, make the subtasks of a task sequential, let a task complete with its last subtask
- **Duplicate**: Copy a task with its subtasks or a project with all its tasks (for example as a template), into another project, folder or the inbox
- **Queries by date**: List tasks or projects by the date they were created, last modified or dropped, for the last days or a period, newest first
- **Small properties**: The primary tag of a task, the time zone setting of due and defer dates (floating or fixed) for tasks and projects, and the provisional project of an inbox task
- **Settings and backup**: Read the settings of the database and the preferences of the app (for example the default due time), and write a backup archive of the database

### Tags
- **List Tags**: View all tags with hierarchy
- **Create Tags**: Create tags, optionally nested under a parent
- **Reopen Tasks**: Mark a completed or dropped task as open again
- **Subtasks and planned dates**: Add a task under an existing task, set a planned date
- **Edit Tags**: Rename, move, hide a tag, change its note or whether its tasks can be next actions
- **Tag locations**: Set, change or remove the location of a tag (latitude, longitude, radius, arriving or leaving) for Nearby in OmniFocus
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

**Dates.** All tools that take a date (`add_task`, `batch_add_tasks`, `create_recurring_task`, `create_project`,
`edit_task`, `edit_project`) read them the same way. These forms do not depend on the language or region of the Mac:
`YYYY-MM-DD` (midnight), `YYYY-MM-DD HH:MM` (also with `T` between date and time), `today`, `tomorrow`, `next week`,
`3 days` and `2 weeks`. Anything else (for example `01.12.2026 14:30`) is read by macOS itself with the language and
region settings of the Mac, so it works only in the formats of that Mac; a date that does not exist, like 31.31.2026, is
refused. A date that cannot be read is never replaced by today or tomorrow: the edit and create tools refuse it and
change nothing, and `add_task` creates the task without that date and says so.

**Language and region.** The tools run on a Mac with any language and region. Keywords (`today`, `in 3 days`, `Inbox`,
repeat rules like `every friday`, review intervals) are English and read regardless of upper and lower case, also on a
Turkish Mac where the system treats `I` and `i` as different letters. Numbers inside repeat rules are written with the
digits 0 to 9, also on a Mac with an Arabic or Persian region. A date text that the system reads in a way that does not fit
the text (a time that gets lost, a PM that the language does not know) is refused. Tool results show dates and times in
the format of the Mac. Names, notes, tags and file paths may contain any characters (umlauts, Chinese, emoji).

**Wrong types of values.** Every value is checked against the schema of its tool before anything runs. A value with a
clear meaning is converted (the number `30` or the text `"30"` for a number, `"true"` for a boolean, a number for a text,
a list of tags for `tags`, `Active` for `active`). Anything else (text for a number, a fraction like `2.5`, an object for a text, a value that
is not in the list of an enumeration) is refused with a message that names the parameter and what is expected, and
nothing is changed. All numbers of the tools (limits, attachment numbers, minutes, days) are whole numbers.

### Batch Operations
```
"Create project plan: Research phase|-Literature review|-Market analysis|Development|-Prototype|-Testing|Launch"
```
Note: Use `|` to separate tasks and `-` prefix for subtasks

### Recurring Tasks and Projects
```
"Create weekly recurring task 'Process inbox' due every Sunday"
"Add monthly recurring 'Review finances' on the 15th"
"Make the task 'Water plants' repeat every 3 days"
"Repeat 'Team meeting' every Monday and Thursday"
"Repeat 'Invoices' on the last Friday of the month, fixed schedule"
"Let 'Water plants' repeat 2 weeks after I complete it, based on the defer date"
"Repeat the project 'Monthly closing' on the 1st of every month"
"Stop the repetition of 'Process inbox'"
```
`create_recurring_task`, `edit_task` and `edit_project` take the repeat rule in words or as an iCalendar rule
(`FREQ=WEEKLY;BYDAY=MO,TH`, upper case, optionally with `COUNT` or `UNTIL`). In words: `daily`, `weekly`, `monthly`,
`yearly`, `3 days`, `2 weeks`, `every monday and thursday`, `weekdays`, `every 2 weeks on monday`, `monthly on the 15th`,
`last day of the month`, `first monday of the month`, `last friday of the month`. `fixed` at the end follows the calendar
(the next occurrence does not depend on when you complete the task), `from completion` follows the completion; without
either, a rule that only has an interval follows the completion and a rule with weekdays or days of the month follows
the calendar. `none` stops the repetition. A repeating task or project needs a due, defer or planned date.

Two more properties change a rule that exists, without touching the rest of it: `repeat_based_on` (`due`, `defer` or
`planned`: the date the next occurrence is calculated from; the task needs this date) and `repeat_catch_up` (`true` or
`false`: a fixed schedule skips the occurrences in the past instead of creating them one after the other). `get_task`
and `get_project` show the rule, for example `every week on Monday and Thursday, fixed schedule, based on the defer date,
catches up automatically`. A rule that OmniFocus does not accept changes nothing. OmniFocus has no yearly rule for a fixed
month and day: a yearly rule repeats on the date of the due date.

### Text to Tasks
```
"Turn the note of 'Plan offsite' into subtasks"
"Create these tasks in the project 'Website 2.0': Design review, then below it Collect feedback and Write summary"
```
One task per line, indented lines become subtasks of the closest line above that is indented less. A list marker
(`- `, `* ` or `• `) at the start of a line is removed, and every line goes through the text parser of OmniFocus, so
its inline syntax works (for example `Call Max //number 123` puts the number in the note). `single_task` makes the whole
text one task, `clear_note` empties the note after `from_note` was converted.

### Links to Other Apps
```
"Create a task 'Answer the offer' with the link to the selected mail in its note"
"Add the link to the page I have open in Safari to the note of 'Plan offsite'"
"Add the link to the file selected in Finder to the project 'Taxes 2026'"
"Show me the link to the task 'Answer the offer'"
```
A link is only text in the note, so any app link works: `add_task` (`note`) and `edit_task` / `edit_project` with
`append_note` accept `message://`, `https://`, `file://`, `things:///`, `x-devonthink-item://` and so on. `append_note`
adds a line to the end of the note and keeps the existing text; it refuses to change a note with attachments or
formatting instead of losing them. `get_selected_link` reads the link from the app: for the messages selected in Mail
(`message://`), the front tab of Safari or a Chromium browser (Chrome, Brave, Edge, Arc, Vivaldi), the files selected in
Finder (`file://`) and the contacts selected in Contacts (`addressbook://`). It reads titles, senders and IDs, never the
text of a message or a file, does not start the app, and the first use of each app asks for permission to control it.
`get_task` and `get_project` show the `omnifocus:///task/<id>` link of the item, which you can paste into other apps.
Apple Notes cannot be linked this way: scripts get no link to a note.

### Attachments in Notes
```
"Attach the file ~/Documents/offer.pdf to the task 'Answer the offer'"
"Link the file /Users/me/Contracts/lease.pdf in the note of the project 'Rental'"
"Show the attachments of the task 'Answer the offer'"
"Remove attachment 2 from the task 'Answer the offer'"
"Save the attachment of the task 'Answer the offer' to ~/Downloads/offer.pdf"
```
`edit_task`, `edit_project` and `edit_folder` take the properties `attach_file` (the full path of a file; a copy is stored
in the note and synchronized to all devices), `link_file` (the note only links to the file, which has to stay where it is
and opens on this Mac only) and `remove_attachment` (the number shown by `get_task`, `get_project`; 1 is the first one).
The file goes to the end of the note in its own line, the text of the note stays as it is. `get_task` and `get_project`
list the attachments (linked files with their path) and show a paperclip in the note where an attachment sits. OmniFocus
does not give scripts the name of an embedded file. `save_attachment` writes an embedded attachment to a new file
(the path is up to you and must not exist yet), a linked file is not copied. Notes with attachments are not changed by
`append_note`.

### View and Selection
```
"What is selected in OmniFocus?"
"Show the Forecast perspective"
"Search OmniFocus for 'invoice'"
"Focus OmniFocus on the project 'Website 2.0'"
"Show the project 'Rental' in OmniFocus"
```
`get_selection` shows what the front OmniFocus window shows: the perspective, the search term, the focus and the selected
items (tasks, projects, folders or tags) with their IDs, so that you can say "this task" or "the selected project" and
the other tools take the item with `id:<id>`. `set_view` switches the perspective (a part of a name works if only one
perspective fits), sets or clears the search term and focuses the window on a project or folder (`none` removes the
focus). It also sets the grouping, sorting and filters of the list (`grouping`, `sorting`, `task_filter`,
`duration_filter`, `flagged_filter`) and the smart group of the sidebar of the Projects perspective (`smart_group`) with
the identifiers of OmniFocus (`get_selection` shows the current ones in the line `List view:`); a value that the
view does not offer is answered with the list of those it offers. `expand` (`all` or `none`) expands or collapses every row of the list (collapsing can clear the selection of the list) and `show_notes` shows or hides the notes in the list (a row that cannot show a note stays as it is) (`get_selection` shows the number of rows in the line `List rows:`). `get_forecast` lists the days of the Forecast with the badge counts of the Forecast sidebar; OmniFocus gives them only while the Forecast is shown, so the window switches to it for a moment and back. `set_view` checks the result and says so if OmniFocus did not accept a value. OmniFocus reports a removed focus to the
script late, so `set_view` may only say that the removal was sent: check it with `get_selection`. For a project that is
completed or dropped, or below a hidden folder, `set_view` and `show_item` add a note, because OmniFocus may not show it. `show_item` opens a task, project, folder or
tag in the window and selects it, through the `omnifocus:///` links of OmniFocus. These tools only change what the window
shows, never a task, project or folder.

### Action Groups
```
"Move the task 'Collect figures' below the task 'Review Q3 reports'"
"Make the subtasks of 'Review Q3 reports' sequential"
"Let 'Review Q3 reports' complete when its last subtask is done"
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
"Set the location of the tag 'Office' to latitude 50.9787 and longitude 11.3235, radius 0.5 km, notify when arriving"
"Change the radius of the location of 'Office' to 1 km"
"Remove the location of the tag 'Office'"
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

### Duplicate
```
"Duplicate the project 'Onboarding' into the folder 'Clients' as 'Onboarding Acme' and reopen all tasks"
"Duplicate the task 'Prepare release' into the project 'Website 2.0'"
"Copy the task 'Weekly report' to the inbox"
"Duplicate the task 'Send invoice' as a subtask of 'Monthly closing'"
```
`duplicate_item` copies a task with all its subtasks or a project with all its tasks. The copy keeps notes, tags, dates,
estimate, flag, repetition and (for a project) status and type. Without a destination the copy goes
directly after the original. `project` (a project, or `inbox`) or `parent_task` choose the place of a task copy,
`folder` (or `none` for the top level) the place of a project copy. `new_name` renames the copy; a project copy gets
` copy` after its name if its folder already has a project with this name. OmniFocus loses the dropped state of a
task when it copies it, so the tool drops those tasks again in the copy. Completed tasks stay completed, unless
`reopen_completed` is true, which makes a copy usable as a template. The answer shows the ID of the copy, so it can be
addressed with `id:<id>` (the copy has the same name as the original). Only open tasks can be duplicated; OmniFocus
cannot duplicate folders.

### Small Properties, Settings and Backup
```
"Make 'Phone' the primary tag of 'Call the plumber'"
"Tag the project 'Website 2.0' with 'Work' and 'Q4'"
"Let the due date of 'Flight check-in' keep its clock time in every time zone"
"Assign the inbox task 'Order cable' to the project 'Home office' without moving it"
"What is the default due time in OmniFocus?"
"Write a backup of OmniFocus to ~/Documents/omnifocus-backup"
```
`primary_tag` is the first tag of a task or project: an existing tag moves to the front, a new one is added in front, `none`
removes the first tag and keeps the others. `get_task` and `get_project` show the primary tag when the item has several tags.
`tags` (tasks and projects) replaces all tags with a comma-separated list (name, path `Parent > Child` or `id:<id>`; a missing
tag is created), `none` removes all tags; `create_project` takes the same list in `tags`. All tags are looked up before
anything changes, so a failed lookup leaves the item as it was and `create_project` creates nothing.
`floating_time_zone` (tasks and projects) decides whether the due and defer date keep their clock time in every time
zone (`true`) or stay at a fixed time zone (`false`); `get_task` and `get_project` show it for items with a due or defer
date. `assigned_container` gives an inbox task a provisional project (or `task:<name>` as parent task); it stays in the
inbox, `list_inbox` shows the project after an arrow, and `clean_up` moves it there.
`get_task` also shows the dates a task gets from a containing task or project (`Effective due:`, `Effective deferred until:`,
`Effective planned:`, only when they differ from its own dates), the dates of the next occurrence of a task that repeats on a
fixed schedule (`Next occurrence:`) and the number of subtasks that can be worked on now (`Available subtasks:`).
`get_task` searches a name among open, completed and dropped tasks, ignoring case, spaces around the name and the `📝` in front of
it (the first line of the answer shows the name with it). A task with exactly this name wins over tasks that only contain the
text. When several tasks remain, the answer lists all of them with ID, state and project (open first, at most 20); of several
tasks with the same name, the one that is open is shown and the others are named below it.
A project is no task: OmniFocus gives every project a hidden root task with the ID of the project. `get_task`, `complete_task`,
`drop_task`, `reopen_task`, `edit_task`, `add_tag_to_task`, `remove_tag_from_task` (and the tools that take a task by name or ID, such as
`add_task` with `parent_task`, `parse_tasks`, `show_item`, `save_attachment` and `duplicate_item`) refuse the ID of a project
(`is a project, not a task`, nothing is changed), and a name search leaves the projects out and says so when only projects
have that name.
The lists and the search (`search_tasks`, `list_overdue_tasks`, `list_flagged_tasks`, `list_deferred_tasks`, `list_due_soon`,
`list_completed_tasks`, `today_tasks`, `weekly_review`) do not show a project, or count it, as a task.
`list_tags` with `include_counts` shows the remaining and the available tasks of each tag as OmniFocus counts them (the tasks of
child tags included); an OmniFocus that does not give these numbers shows the number of open tasks per tag instead.
`get_project` shows the same for projects: `Next occurrence:` for a project that repeats on a fixed schedule, the number of
tasks directly below the project that can be worked on now (`available at top level`) and `default project for single
actions` for the project that OmniFocus uses for single actions. `edit_project` sets it with `default_single_action_list`
(`true` or `false`): OmniFocus has only one such project, so the flag leaves the project that had it (the answer names it),
and the project becomes a single action list.

`get_settings` reads the settings of the database (`scope: document`, the default) or the preferences of the app
(`scope: application`, or `all`). Every entry shows its ID and value, and the default value if it differs; `filter`
finds entries by a part of the ID; a value that is a list or data is shown as not readable. The first line shows the version and build number of OmniFocus. Nothing is changed. `create_backup` writes a backup archive of the database to a
new path (it must not exist, its folder must exist; `compression` is on by default); it uses the `archive` command of
OmniFocus, so the folder has to be one that OmniFocus may write to. OmniFocus writes the archive as a package, a folder
that Finder shows as one file. The archive is written by a process of its own, so a large database cannot block the call
or run into the time limit of the app (about 80 seconds): the call waits `wait_seconds` (default 40, at most 70) and, if
the archive is not finished by then, says that it is still being written. `status_only: true` with the same path shows
later whether it is finished, still being written, failed or interrupted, with its size.

`purge_tasks` deletes completed and/or dropped tasks permanently, for example everything older than a year. It only
lists what it would delete (`dry_run`, the default); deleting needs `dry_run: false` and `confirm_delete: true`. `scope`
is `completed`, `dropped` or `both`, `older_than_days` looks at the completion or drop date, `folder` or `project` limit
it (without them the whole database counts, with the inbox). Open tasks, also recurring ones, are never touched. Deleting a
task deletes its subtasks, so a task is only deleted if all its subtasks are part of the purge too: a task with open
subtasks (or with subtasks that are too young or in another state) is skipped and reported. Tasks below hidden folders
are counted and marked. `limit` (default 200) and a time limit of about 50 seconds keep one call short; the answer says
how many tasks are left, and calling it again continues. Deleting cannot be undone.

### GTD Queries and Reviews
```
"What can I work on now?"
"What can I work on in the folder 'Clients'?"
"What are the next actions of the project 'Website 2.0'?"
"Show all tasks tagged 'Waiting for'"
"Which waiting-for items are the oldest?"
"What is due in the next 7 days, grouped by tag?"
"What can I do in 15 minutes?"
"Show the available tasks tagged 'Phone'"
"What did I complete in the last 7 days?"
"What did I add this week?"
"Which open tasks of the project 'Website 2.0' changed since Monday?"
"Which projects did I create in October?"
"What did I drop yesterday?"
"Which projects are due for review?"
"Mark the project 'Website 2.0' as reviewed"
"Which perspectives do I have?"
"Which projects have no next action?"
```

Dropped items and items below dropped (hidden) folders are left out of all read tools. Pass `include_dropped: true`
to include them.

`list_tasks_by_date` lists tasks (or `item_type: projects`) by one of three dates: `created`, `modified` (OmniFocus
updates it with every change, also with the completion or the drop of a task) or `dropped`. Completed tasks stay with
`list_completed_tasks`. The period is the last `days` (default 7) or a range from `since` to `until`
(`YYYY-MM-DD`, `YYYY-MM-DD HH:MM`, `today` or `yesterday`; a date as `until` counts through the end of that day).
`status: open` leaves out completed and dropped tasks (for projects: only active and on hold), `project` limits the list
to one project, `limit` caps the number of items. The list is sorted newest first and grouped by day; tasks show their
project, completed tasks a `✓`, dropped ones a `🚫`. Items below hidden (dropped) folders are always left out.

## Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `add_task` | Add a task with full properties | "Add task to buy milk due tomorrow, defer until morning" |
| `search_tasks` | Search across all tasks | "Search for budget tasks" |
| `edit_task` | Modify existing task, including its repetition (`repeat`, `repeat_based_on`, `repeat_catch_up`), its parent task, the behavior of its subtasks, its primary tag (`primary_tag`), its time zone setting (`floating_time_zone`), the provisional project of an inbox task (`assigned_container`) and file attachments in its note | "Change due date of 'Report' to Friday", "Repeat 'Pay rent' every month" |
| `batch_add_tasks` | Create multiple tasks | "Add tasks: Task1\|Task2\|-Subtask" |
| `create_recurring_task` | Set up a repeating task with a repeat rule in words or as an iCalendar rule | "Create daily task 'Review email'", "Repeat 'Invoices' on the last Friday of the month" |
| `list_inbox` | Show inbox tasks | "Show my inbox" |
| `today_tasks` | List due today | "What's due today?" |
| `list_projects` | Show all projects | "List projects with counts" |
| `list_deferred_tasks` | Show deferred items | "What tasks are deferred?" |
| `list_flagged_tasks` | Show flagged items | "Show flagged tasks" |
| `list_overdue_tasks` | Show overdue items | "What's overdue?" |
| `complete_task` | Mark as complete | "Complete budget review" |
| `reopen_task` | Reopen a completed or dropped task | "Reopen the task 'Budget review'" |
| `weekly_review` | GTD weekly review | "Show weekly review" |
| `get_task` | Show all details of one task, including inherited dates, the next occurrence, repetition and attachments | "Show details of 'Report'" |
| `get_project` | Show a project with its properties, repetition (with the next occurrence), counts and all its tasks as an indented list | "Show the project 'Website 2.0' with all tasks" |
| `drop_task` | Drop a task (deleting needs `confirm_delete`) | "Drop the task 'Old idea'" |
| `list_tags` | Show all tags with hierarchy, IDs, hidden / no-next-action flags, locations and optionally remaining / available task counts | "List my tags" |
| `create_tag` | Create a new tag, optionally below another tag | "Create tag 'Urgent'" |
| `edit_tag` | Rename, move, hide a tag, change its note or next-action behavior, set or remove its location (latitude, longitude, radius, trigger) | "Rename tag 'Waiting' to 'Waiting for'" |
| `add_tag_to_task` | Add a tag to a task | "Tag 'Report' with 'Priority'" |
| `remove_tag_from_task` | Remove a tag from a task | "Remove 'Waiting' tag from 'Report'" |
| `create_project` | Create a project, optionally in a folder, with review interval, due and defer date, type and tags | "Create project 'Website 2.0' in 'Clients', review every 2 weeks" |
| `edit_project` | Rename, change or extend note (`append_note`), attach or remove files (`attach_file`, `link_file`, `remove_attachment`), folder, status, type, review interval, next review date, due, defer and planned date, flag, completion behavior, time zone setting (`floating_time_zone`), the default project for single actions (`default_single_action_list`), tags (`tags`, `primary_tag`) and repetition of a project (`repeat`, `repeat_based_on`, `repeat_catch_up`) | "Review 'Website 2.0' every 2 weeks", "Repeat the project 'Monthly closing' on the 1st" |
| `create_folder` | Create a folder, optionally inside another folder | "Create folder 'Clients'" |
| `format_note` | Set or remove bold, italic and underline in the note of a task, project or folder (whole note, one paragraph or the places of a text); `get_task` and `get_project` show styles as `**bold**`, `*italic*`, `__underlined__` | "Make 'Deadline' bold in the note of 'Tax return'" |
| `save_attachment` | Save an embedded attachment of a task, project or folder as a file | "Save the attachment of 'Answer the offer' to ~/Downloads/offer.pdf" |
| `rename_folder` | Rename a folder | "Rename folder 'Clients' to 'Customers'" |
| `list_folders` | Show all folders as a hierarchy with IDs, project counts, hidden folders and notes | "List my folders" |
| `edit_folder` | Rename, move (with everything in it), hide or show a folder, change or extend its note, attach or remove files | "Move the folder 'Old clients' below 'Archive'" |
| `delete_folder` | Delete a folder (needs `confirm_delete`; a folder with content only with `delete_contents`) | "Delete the empty folder 'Test'" |
| `purge_tasks` | Delete completed and/or dropped tasks permanently (preview by default; deleting needs `dry_run: false` and `confirm_delete`), optionally only older than N days, in a folder or a project | "Show which completed tasks older than a year could be deleted" |
| `list_available_tasks` | Next actions across all projects, optionally by tag, folder, a single project or time (`max_minutes`) | "What can I work on now?" |
| `list_tasks_by_tag` | Open tasks with a tag, grouped by project (or one `project`), or oldest first with their age (`show_age`); projects that carry the tag are listed in a block of their own | "Show tasks tagged 'Waiting for'" |
| `parse_tasks` | Turn text, or the note of a task, into tasks and subtasks | "Turn the note of 'Plan offsite' into subtasks" |
| `get_selected_link` | What is selected or open in Mail, Safari, Chrome and other Chromium browsers, Finder or Contacts, with a link that opens it again | "Put the link to the selected mail in the note of 'Answer the offer'" |
| `undo` | Undo or redo the last change(s) in OmniFocus, whoever made them | "Undo that" |
| `synchronize` | Synchronize OmniFocus with its sync database and wait until it is finished; shows when the last synchronization finished and its error, `status_only` only reports that | "Sync OmniFocus now", "When did OmniFocus last sync?" |
| `clean_up` | Clean Up: move inbox items that have a project into their projects, hide completed tasks | "Clean up OmniFocus" |
| `get_selection` | Perspective, search term, focus and selected items (with IDs) of the front OmniFocus window | "What is selected in OmniFocus?" |
| `set_view` | Switch the perspective, group, sort or filter the list, choose a smart group, expand or collapse the rows, show the notes, search, or focus on a project or folder in the front OmniFocus window | "Show the Forecast perspective", "Group the list by due date" |
| `get_forecast` | The days of the Forecast with the badge counts of the Forecast sidebar | "How many items does the Forecast show for the next days?" |
| `show_item` | Open a task, project, folder or tag in OmniFocus and select it | "Show the project 'Rental' in OmniFocus" |
| `duplicate_item` | Duplicate a task with its subtasks or a project with all its tasks, optionally into another project, folder or the inbox, under a new name, with completed tasks reopened | "Duplicate the project 'Onboarding' into the folder 'Clients'" |
| `list_perspectives` | Built-in and custom perspectives with their IDs (the rules of a perspective are not available to scripts) | "Which perspectives do I have?" |
| `list_due_soon` | Tasks due in the next days, grouped by tag, day or project | "What is due this week, by tag?" |
| `list_completed_tasks` | Tasks completed in the last days | "What did I complete last week?" |
| `list_tasks_by_date` | Tasks or projects by creation, modification or drop date, for the last days or a period, optionally one project or only open items | "What did I add this week?" |
| `get_settings` | Settings of the database (`document`) and preferences of the app (`application`) with their values and defaults, optionally filtered by a part of the ID | "What is the default due time in OmniFocus?" |
| `create_backup` | Write a backup archive of the database to a new path, in the background (`wait_seconds`; `status_only` shows whether it is finished) | "Write a backup of OmniFocus to ~/Documents/omnifocus-backup" |
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
│   │   │   ├── list_due_soon.applescript
│   │   │   ├── get_selected_link.applescript
│   │   │   ├── get_forecast.applescript
│   │   │   ├── get_selection.applescript
│   │   │   ├── set_view.applescript
│   │   │   ├── show_item.applescript
│   │   │   ├── duplicate_item.applescript
│   │   │   ├── undo.applescript
│   │   │   ├── synchronize.applescript
│   │   │   ├── clean_up.applescript
│   │   │   ├── list_perspectives.applescript
│   │   │   ├── parse_tasks.applescript
│   │   │   ├── drop_task.applescript
│   │   │   ├── create_project.applescript
│   │   │   ├── edit_project.applescript
│   │   │   ├── create_folder.applescript
│   │   │   ├── rename_folder.applescript
│   │   │   ├── list_folders.applescript
│   │   │   ├── format_note.applescript
│   │   │   ├── save_attachment.applescript
│   │   │   ├── edit_folder.applescript
│   │   │   ├── delete_folder.applescript
│   │   │   ├── purge_tasks.applescript
│   │   │   ├── list_tasks_filtered.applescript    # list_available_tasks and list_tasks_by_tag
│   │   │   ├── list_completed_tasks.applescript
│   │   │   ├── list_tasks_by_date.applescript
│   │   │   ├── get_settings.applescript
│   │   │   ├── create_backup.applescript
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

### A tool is slow or stops after two minutes

The tools read OmniFocus with a few queries for all tasks, projects or tags at once, so even a database with several
thousand tasks answers in a few seconds. Searches in notes (`search_tasks`) and the 100 entries of `get_settings` are the
slowest calls. A script that does not finish within 120 seconds is stopped with a message; check in OmniFocus whether a
change was made before you repeat it. Set `OMNIFOCUS_SCRIPT_TIMEOUT_SECONDS` in the environment of the server to
change the limit.

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
