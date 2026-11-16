# OmniFocus MCP Plugin Smoke Test: GTD, Review and Project Tools

> **Purpose:** End-to-end smoke test for the tools added after the base smoke test (`omnifocus-mcp-smoke-test.md`):
> GTD queries, review tools, project and folder tools, `get_task`, `get_project`, `drop_task` and `include_dropped`.
> It is designed to run as a single prompt in Claude Desktop.

---

## Instructions

Copy everything below the `---START PROMPT---` line and paste it into Claude Desktop as a single message. Claude executes all tests in order and produces a pass/fail report at the end.

**Prerequisites:**
- The OmniFocus MCP server is connected and OmniFocus is open
- A project named **"Smoke Test"** exists (the same one as in the base smoke test)

**Safety:** All synthetic data uses the `SMOKETEST` + YYMMDDHHMMSS prefix. Tasks are created in the "Smoke Test" project and are deleted again at the end with `drop_task` and `confirm_delete`. The tags created in Phases 2 and 3 cannot be removed with the tools and have to be deleted by hand in OmniFocus; the folders and projects created in Phase 4 are deleted at the end with `delete_folder`. No existing data is modified.

---START PROMPT---

You are executing a structured smoke test of the OmniFocus MCP plugin. Follow every step. Do not ask for confirmation between steps. Produce the final report at the end.

## Setup

Construct the test prefix `SMOKETEST` + YYMMDDHHMMSS from the current date and time (example: `SMOKETEST260324130501`). Refer to it as `{PREFIX}`. Record for each test: ID, tool, result (PASS/FAIL) and error message.

## Phase 1: Read-only tools and view (20 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| Q01 | `list_available_tasks` | No parameters. PASS if it returns a list or a message that none were found. |
| Q02 | `list_available_tasks` | `limit: 1`. PASS if at most one task is listed. |
| Q03 | `list_tasks_by_tag` | Call with `tag: "{PREFIX} NO SUCH TAG"`. PASS if it returns a "Tag not found" error and no tasks. |
| Q04 | `list_tasks_by_tag` | Call without `tag`. PASS if it returns an error that a tag is required. |
| Q05 | `list_completed_tasks` | `days: 7`. PASS if it returns a list or a message that none were completed. |
| Q06 | `list_projects_for_review` | `days_ahead: 7`. PASS if it returns a list or a message that none are due. |
| Q07 | `list_stalled_projects` | No parameters. PASS if it returns a list or a message that none are stalled. |
| Q08 | `list_projects` | `include_dropped: true`. PASS if it returns the projects plus a "Dropped Projects" section when dropped projects exist. |
| Q09 | `list_inbox` | `include_dropped: false`. PASS if every listed task has an `[id:...]`. |
| Q10 | `list_available_tasks` | `max_minutes: 15`, `limit: 5`. PASS if every listed task shows a `⏱` estimate of 15 min or less, or a message that none were found. |
| Q11 | `list_tasks_by_tag` | `tag: "{PREFIX} NO SUCH TAG"`, `show_age: true`. PASS if it returns the "Tag not found" error. Then call `list_available_tasks` with `show_age: true`, `limit: 3`. PASS if at most three tasks are listed, each with a `🕒` age and its project, the oldest first. |
| Q12 | `list_due_soon` | `days: 7`. PASS if it returns a list grouped by tag (headings starting with `🏷`) where every task shows a due date, or the message that nothing is due. |
| Q13 | `list_due_soon` | `days: 14`, `group_by: "day"`, `limit: 5`. PASS if at most five tasks are listed under date headings in ascending order. Then `group_by: "nonsense"` must still work (falls back to tag). |
| Q14 | `list_available_tasks` | `project: "{PREFIX} NO SUCH PROJECT"`. PASS if it FAILS with `Project not found` and lists nothing. Then use the name of a real project: PASS if the header contains `in the project` and only that project is listed. |
| Q15 | `list_perspectives` | PASS if the built-in perspectives (for example Inbox, Projects, Forecast) are listed, and the custom ones (OmniFocus Pro) with an ID. |
| Q16 | `get_selected_link` | Manual test, only if you can select something in the apps (otherwise mark SKIPPED). With `app: "Finder"` and a file selected in Finder: PASS if the name and a `Link: file://...` line are shown. With `app: "Safari"` (or `Google Chrome`) and a window open: PASS if the title and the URL of the front tab are shown. With Mail and a message selected: PASS if subject, sender, date and `Link: message://%3C...%3E` are shown and no message text. With a closed app the call must FAIL with `is not running`; `app: "Notes"` must FAIL with `Unsupported app`. |
| Q17 | `synchronize` | `wait_seconds: 5`. PASS if it answers `Synchronized` or `still running`, or, when no sync is set up in OmniFocus, with a message starting `Could not synchronize` (then mark the sync part SKIPPED). `wait_seconds: 0` must answer `Synchronization started`. Optional by hand: `clean_up` moves inbox items that already have a project into their projects and hides completed tasks, so it changes existing data and is not part of the automatic run; PASS if it answers `Cleaned up` with the number of moved inbox items. |
| Q18 | `get_selection` | PASS if it answers with the lines `Perspective:`, `Search:` and `Focus:` and either `Selected: nothing` or a list of selected items, each ending in `[id:...]`. If it answers `OmniFocus has no open window`, mark Q18 to Q20 SKIPPED. Remember the perspective for Q19 and Q20. |
| Q19 | `set_view` | Changes only the view of the window. `perspective: "Inbox"`: PASS if it answers `Perspective: Inbox`. `perspective: "{PREFIX} NO SUCH PERSPECTIVE"` must FAIL with `Perspective not found` and list the available perspectives. `search: "{PREFIX}"`: PASS if it answers `Search: "{PREFIX}"`; `search: ""`: PASS if it answers `Search cleared`. `perspective: "Projects"` and `focus: "Smoke Test"`: PASS if it answers `Focus: Smoke Test`, then `focus: "none"`: PASS if it answers `Focus removed` (a `⚠️` answer that OmniFocus kept the focus is a FAIL, remove it by hand in the window). Finally restore the perspective from Q18. Calling it without any argument must FAIL with `Give a perspective, a search term or a focus`. |
| Q20 | `show_item` | `item_type: "project"`, `item: "Smoke Test"`: PASS if it answers `Showing project in OmniFocus: Smoke Test`, and `get_selection` then lists the project as selected (an answer starting with `Opened project` is also a PASS if the Projects perspective is not shown). `item_type: "task"`, `item: "{PREFIX} NO SUCH TASK"` must FAIL with `Open task not found`. `item_type: "tag"`, `item: "{PREFIX} NO SUCH TAG"` must FAIL with `Tag not found`. Finally restore the perspective from Q18 with `set_view`. |

## Phase 2: Tasks and tags (36 tests)

All tasks MUST use `project: "Smoke Test"`.

| Test ID | Tool | Action |
|---------|------|--------|
| A01 | `create_tag` | Create tag `{PREFIX}-Tag`. PASS if created. |
| A02 | `add_task` | Create `{PREFIX} Task A` in project `Smoke Test` with tags `{PREFIX}-Tag`. PASS if created. |
| A03 | `list_tasks_by_tag` | `tag: "{PREFIX}-Tag"`. PASS if `{PREFIX} Task A` is listed with its project and an ID. Remember the ID. |
| A04 | `list_available_tasks` | `tag: "{PREFIX}-Tag"`. PASS if `{PREFIX} Task A` is listed. |
| A05 | `get_task` | `task_name: "id:<ID from A03>"`. PASS if the details show the same task, its project and the tag. |
| A06 | `complete_task` | `task_name: "id:<ID from A03>"`. PASS if completed. |
| A07 | `list_completed_tasks` | `days: 1`. PASS if `{PREFIX} Task A` is listed. |
| A08 | `reopen_task` | `task_name: "id:<ID from A03>"`. PASS if reopened, and `get_task` shows the state `open`. |
| A09 | `add_task` | Create `{PREFIX} Subtask A` with `parent_task: "id:<ID from A03>"` and `planned_date: "2030-01-15"`. PASS if created as a subtask of `{PREFIX} Task A`. |
| A10 | `get_task` | `task_name: "{PREFIX} Subtask A"`. PASS if it shows the parent task `{PREFIX} Task A` and the planned date. |
| A11 | `edit_task` | `task_name: "{PREFIX} Subtask A"`, `property: "planned_date"`, `value: "none"`. PASS if the planned date is cleared. |
| A12 | `edit_task` | `task_name: "{PREFIX} Task A"`, `property: "repeat"`, `value: "2 weeks"`. PASS if it FAILS with a message that a repeating task needs a due, defer or planned date (the task has none), and nothing changes. |
| A13 | `edit_task` | Set `due_date` of `{PREFIX} Task A` to `2030-01-15`, then `property: "repeat"`, `value: "2 weeks"`. PASS if confirmed with "every 2 weeks, due date after completion", and `get_task` shows a `Repeats:` line with the same text. |
| A14 | `edit_task` | `property: "repeat"`, `value: "monthly fixed"`. PASS if confirmed with "every month, fixed schedule". Then `value: "fortnight"` must FAIL with "Invalid repeat" and leave the repetition unchanged. |
| A15 | `edit_task` | `property: "repeat"`, `value: "none"`. PASS if confirmed as stopped, and `get_task` shows no `Repeats:` line. |
| A16 | `add_task` | Create `{PREFIX} Subtask B` in project `Smoke Test`. PASS if created. |
| A17 | `edit_task` | `task_name: "{PREFIX} Subtask B"`, `property: "parent_task"`, `value: "{PREFIX} Task A"`. PASS if confirmed as moved below `{PREFIX} Task A` and `get_task` of `{PREFIX} Subtask B` shows that parent task. |
| A18 | `edit_task` | `task_name: "{PREFIX} Task A"`, `property: "parent_task"`, `value: "{PREFIX} Subtask B"`. PASS if it FAILS with a message that a task cannot be moved below itself or one of its own subtasks, and nothing changed. |
| A19 | `edit_task` | `task_name: "{PREFIX} Task A"`, `property: "sequential"`, `value: "true"`. PASS if confirmed and `get_task` shows `Subtasks: 2 (one after another)`. Then `value: "maybe"` must FAIL with a message about the invalid value. |
| A20 | `edit_task` | `property: "complete_with_last_item"`, `value: "true"`. PASS if confirmed and `get_task` shows `completes with the last subtask`. Then set `sequential` and `complete_with_last_item` back to `false` and PASS if `get_task` shows plain `Subtasks: 2`. |
| A21 | `parse_tasks` | `project: "Smoke Test"`, text of three lines: `{PREFIX} P1`, then `{PREFIX} P1a //note` indented by a tab, then `{PREFIX} P2`. PASS if 3 tasks are created, `{PREFIX} P1a` below `{PREFIX} P1`, and `get_task` of `{PREFIX} P1a` shows the note `note` (and not `//note` in the name). |
| A22 | `parse_tasks` | `parent_task: "{PREFIX} P2"`, text of two lines: `- {PREFIX} P2a`, then `{PREFIX} P2b` indented by two spaces. PASS if both are created below `{PREFIX} P2` (the marker `- ` is not part of the name) and `{PREFIX} P2b` is below `{PREFIX} P2a`. |
| A23 | `parse_tasks` | `project: "Smoke Test"`, `single_task: true`, text of two lines: `{PREFIX} Single`, `second line`. PASS if one task `{PREFIX} Single` is created and `get_task` shows `second line` as its note. |
| A24 | `edit_task` then `parse_tasks` | Set the `note` of `{PREFIX} P2` to two lines `{PREFIX} N1` and `{PREFIX} N2`, then `parse_tasks` with `from_note: "{PREFIX} P2"` and `clear_note: true`. PASS if both tasks are created below `{PREFIX} P2` and `get_task` of `{PREFIX} P2` shows no note any more. |
| A25 | `parse_tasks` | Each of these must FAIL with a message and create nothing: text together with `from_note`; `project` together with `parent_task`; `clear_note` without `from_note`; an unknown `project`; `from_note` of a task without a note; no text at all. PASS if `get_project` of `Smoke Test` shows no new task. |
| A26 | `edit_task` | `task_name: "{PREFIX} Single"` (it has the note `second line`), `property: "append_note"`, `value: "message://%3Ctest%40example.com%3E"`. PASS if confirmed and `get_task` shows `second line` and the link on its own line below it. Then append `https://example.com/{PREFIX}` and a third line `{PREFIX} end`. PASS if all four lines are in this order (OmniFocus turns links into clickable links, which must not stop a further `append_note`). |
| A27 | `edit_task` | `task_name: "{PREFIX} P1"` (no note), `property: "append_note"`, `value: "{PREFIX} first line"`. PASS if `get_task` shows exactly this note without an empty line before it. Then `value: ""` must FAIL with `append_note needs a text to add`, and the note stays the same. |
| A28 | `get_task` | `task_name: "{PREFIX} P1"`. PASS if a line `Link: omnifocus:///task/<id>` with the ID of the task is shown. Then `get_project` of `Smoke Test` must show a `Link: omnifocus:///task/<id>` line for the project. |
| A29 | `add_task` then `undo` | Create `{PREFIX} Undo` in project `Smoke Test`, then call `undo` without parameters. PASS if it answers `Undid` and `search_tasks` with `query: "{PREFIX} Undo"` finds no task. Then `undo` with `action: "redo"`: PASS if it answers `Redid` and the task is found again. Do not change anything in OmniFocus by hand during this test, because `undo` reverts the last change whoever made it. |
| A30 | `edit_task` | Manual preparation: create a small text file `/tmp/{PREFIX}.txt` (for example `echo test > /tmp/{PREFIX}.txt`); mark A30 to A32 SKIPPED if that is not possible. `task_name: "{PREFIX} P1"`, `property: "attach_file"`, `value: "/tmp/{PREFIX}.txt"`. PASS if it answers `Attached` with the file name and size, `get_task` shows `Attachments: 1` and `1. embedded file`, and the note shows the text `{PREFIX} first line` followed by a paperclip in its own line. The values `relative.txt`, `/tmp/{PREFIX}-missing.txt` and `/tmp` must each FAIL with `Nothing was attached` and change nothing. |
| A31 | `edit_task` | `property: "link_file"`, `value: "/tmp/{PREFIX}.txt"` on `{PREFIX} P1`. PASS if `get_task` shows `Attachments: 2` with `2. linked file:` and the path of the file. |
| A32 | `edit_task` | `append_note` on `{PREFIX} P1`: PASS if it refuses because of the attachments. Then `property: "remove_attachment"` with `value: "2"`: PASS if `get_task` shows `Attachments: 1`. The values `5`, `0` and `x` must FAIL and change nothing. Then `value: "1"`: PASS if `get_task` shows no `Attachments` line and the note is `{PREFIX} first line` again. |
| A33 | `save_attachment` | Run it between A31 and A32, while `{PREFIX} P1` has an embedded and a linked attachment (otherwise mark it SKIPPED). `item_type: "task"`, `item: "{PREFIX} P1"`, `number: 1`, `destination: "/tmp/{PREFIX}-saved.txt"`. PASS if it answers `Saved attachment 1`, and the new file has the content of `/tmp/{PREFIX}.txt`. The same call again must FAIL because the file exists. `number: 2` (the linked file) must answer that it is not copied and show its path, `number: 9` and a destination in a folder that does not exist must FAIL. |
| A34 | `edit_task` | On `{PREFIX} Task A` (it has a due date since A13), `property: "repeat"` with `value: "every monday and thursday"`: PASS if confirmed with "every week on Monday and Thursday, fixed schedule". Then `"last friday of the month"`: PASS if confirmed with "every month on the last Friday". Then `"FREQ=WEEKLY;BYDAY=MO,TH"`: PASS if confirmed like the first one. Then `"FREQ=NONSENSE"` must FAIL with "does not understand the repeat rule" and leave the repetition unchanged (check with `get_task`). |
| A35 | `edit_task` | `{PREFIX} Task A` repeats on a fixed schedule (A34). `property: "repeat_based_on"` with `value: "defer"` must FAIL with a message that the task has no defer date (nothing changes). Set `defer_date` to `2029-12-01`, then `repeat_based_on: "defer"`: PASS if confirmed with "based on the defer date". `repeat_catch_up` with `value: "true"`: PASS if confirmed with "catches up automatically"; `"maybe"` must FAIL. Then `repeat` with `value: "weekly from completion"` and `repeat_catch_up: "true"` must FAIL (catching up needs a fixed schedule). Finally `repeat` with `value: "none"`: PASS if confirmed as stopped. `repeat_catch_up` now must FAIL because the task does not repeat. |
| A36 | `create_recurring_task` | `name: "{PREFIX} Recurring Monthly"`, `repeat_rule: "monthly on the 15th"`, `initial_due_date: "2030-01-15"`, `project: "Smoke Test"`. PASS if created with "every month on day 15, fixed schedule". Then `repeat_rule: "FREQ=NONSENSE"` with another name and `name: ""` with `repeat_rule: "daily"` must both FAIL with "Nothing was created." and `search_tasks` must find no such task. |

## Phase 3: Tag hierarchy (11 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| T01 | `create_tag` | Create tag `{PREFIX}-Parent`. PASS if created. |
| T02 | `create_tag` | Create tag `{PREFIX}-Child` with `parent_tag: "{PREFIX}-Parent"`. PASS if created. |
| T03 | `create_tag` | Create tag `{PREFIX}-Grandchild` with `parent_tag: "{PREFIX}-Parent > {PREFIX}-Child"`. PASS if created below the child tag (a nested tag as parent). |
| T04 | `list_tags` | No parameters. PASS if the three tags are shown nested, each with an `[id:...]`. Remember the ID of `{PREFIX}-Child`. |
| T05 | `add_task` | Create `{PREFIX} Task C` in project `Smoke Test` with tags `{PREFIX}-Parent > {PREFIX}-Child`. PASS if created, and `get_task` shows exactly one tag `{PREFIX}-Child` and `list_tags` shows no second top-level `{PREFIX}-Child`. |
| T06 | `edit_tag` | `tag: "id:<ID from T04>"`, `property: "allows_next_action"`, `value: "false"`. PASS if confirmed and `list_tags` marks the tag as "no next action". |
| T07 | `edit_tag` | `tag: "{PREFIX}-Child"`, `property: "name"`, `value: "{PREFIX}-Child2"`. PASS if confirmed. Then `edit_tag` with `tag: "{PREFIX}-Parent"`, `property: "parent"`, `value: "{PREFIX}-Child2"` must FAIL with a message that a tag cannot be moved below one of its child tags. |
| T08 | `edit_tag` | `tag: "{PREFIX}-Grandchild"`, `property: "hidden"`, `value: "true"`, then `value: "false"`. PASS if both are confirmed and `list_tags` shows the tag as hidden in between. |
| T09 | `edit_tag` | `tag: "{PREFIX}-Parent"`, `property: "location"`, `value: "latitude=50.9787; longitude=11.3235; radius=0.5; trigger=arriving; name={PREFIX} Place"`. PASS if confirmed with `{PREFIX} Place (50.9787, 11.3235), radius 0.5 km, arriving`, and `list_tags` shows the same after a `📍` on the tag. |
| T10 | `edit_tag` | `property: "location"`, `value: "radius=2; trigger=leaving"` on the same tag. PASS if latitude, longitude and name are unchanged, the radius is 2 km and the trigger leaving. Then each of these must FAIL with a message and change nothing: `latitude=95; longitude=1`, `latitude=abc; longitude=1`, `radius=50`, `trigger=sometimes`, `colour=red`, `latitude=1` on a tag without a location. |
| T11 | `edit_tag` | `property: "location"`, `value: "none"`. PASS if confirmed and `list_tags` shows no `📍` on the tag. A second `none` must answer that the tag has no location. |

## Phase 4: Folders and projects (22 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| P01 | `create_folder` | Create folder `{PREFIX} Folder`. PASS if created. |
| P02 | `create_project` | Create project `{PREFIX} Project` with `folder: "{PREFIX} Folder"`. PASS if created. |
| P03 | `add_task` | Create `{PREFIX} Task B` with `project: "{PREFIX} Folder > {PREFIX} Project"`. PASS if created. |
| P04 | `get_task` | `task_name: "{PREFIX} Task B"`. PASS if the project is shown as `{PREFIX} Folder > {PREFIX} Project`. FAIL if the task is in the inbox. |
| P05 | `edit_project` | `project: "{PREFIX} Project"`, `property: "type"`, `value: "sequential"`. PASS if confirmed. |
| P06 | `mark_project_reviewed` | `project: "{PREFIX} Folder > {PREFIX} Project"`. PASS if a next review date is shown. |
| P07 | `edit_project` | `project: "{PREFIX} Project"`, `property: "review_interval"`, `value: "2 weeks"`. PASS if confirmed with "every 2 weeks". |
| P08 | `edit_project` | `project: "{PREFIX} Project"`, `property: "review_interval"`, `value: "fortnight"`. PASS if it FAILS with an "Invalid review interval" message and the interval stays unchanged. |
| P09 | `edit_project` | `project: "{PREFIX} Project"`, `property: "next_review_date"`, `value: "2030-01-15"`, then `value: "none"`. PASS if the first call confirms the date and the second one reports that the next review is derived from the review interval again. |
| P10 | `edit_project` | `project: "{PREFIX} Project"`, `property: "due_date"` with `value: "2030-01-15"`, then `property: "defer_date"` with `value: "2029-12-01"`, then `property: "flagged"` with `value: "true"`. PASS if all three are confirmed. Then `due_date` with `value: "none"` must clear the due date. |
| P11 | `edit_project` | `project: "{PREFIX} Project"`, `property: "complete_with_last_item"`, `value: "true"`, then `value: "false"`. PASS if both are confirmed. |
| P12 | `create_project` | Create `{PREFIX} Project 2` with `folder: "{PREFIX} Folder"`, `review_interval: "1 month"`, `type: "single_action"` and `due_date: "2030-01-15"`. PASS if created and the answer lists the review interval, the type and the due date. Then `create_project` with `name: "{PREFIX} Project 3"` and `review_interval: "fortnight"` must FAIL with "Invalid review interval ... Nothing was created." and `list_projects` must not show `{PREFIX} Project 3`. |
| P13 | `get_project` | `project: "{PREFIX} Folder > {PREFIX} Project"`. PASS if the header shows the project with its ID, status, type `sequential`, and the list contains `{PREFIX} Task B` with a marker (▶ or 🔒) and an `[id:...]`. |
| P14 | `get_project` | `project: "{PREFIX} Project"`, `include_completed: true`, `limit: 1`. PASS if at most one task is listed and the limit note appears when the project has more tasks. |
| P15 | `rename_folder` | Rename `{PREFIX} Folder` to `{PREFIX} Folder Renamed`. PASS if confirmed. |
| P16 | `list_folders` | No parameters. PASS if `{PREFIX} Folder Renamed` is listed with `(2 projects)` and an `[id:...]`. Remember the ID. |
| P17 | `edit_folder` | `folder: "id:<ID from P16>"`, `property: "note"`, `value: "{PREFIX} note"`, then `property: "append_note"`, `value: "https://example.com/{PREFIX}"`. PASS if both are confirmed and `list_folders` shows `📝` on the folder. `append_note` with `value: ""` must FAIL and change nothing. |
| P18 | `create_folder` then `edit_folder` | Create `{PREFIX} Folder B`, then `edit_folder` with `property: "parent"`, `value: "{PREFIX} Folder Renamed"`. PASS if `{PREFIX} Folder B` is listed below `{PREFIX} Folder Renamed` by `list_folders`. The same call again must answer that the folder is already below that parent. |
| P19 | `edit_folder` | `folder: "{PREFIX} Folder Renamed"`, `property: "parent"`, `value: "{PREFIX} Folder B"`. PASS if it FAILS with a message that a folder cannot be moved below itself or one of its subfolders. Then `folder: "{PREFIX} Folder B"`, `property: "parent"`, `value: "none"`. PASS if it is at top level again. |
| P20 | `edit_folder` | `folder: "{PREFIX} Folder B"`, `property: "hidden"`, `value: "true"`, then `value: "false"`. PASS if both are confirmed and `list_folders` shows `⏸ hidden` in between. `value: "maybe"` must FAIL. A `name` that is already used at the same level must FAIL and change nothing. |
| P21 | `delete_folder` | Without `confirm_delete` on `{PREFIX} Folder Renamed`: PASS if it refuses and says what the folder contains. With `confirm_delete: true` but without `delete_contents`: PASS if it refuses because the folder contains projects. Then `delete_folder` with `folder: "{PREFIX} Folder B"` and `confirm_delete: true`: PASS if the empty folder is deleted and `list_folders` no longer shows it. |
| P22 | `edit_project` | `project: "{PREFIX} Project"` (it has a due date and a defer date since P10), `property: "repeat"`, `value: "monthly on the 1st"`: PASS if confirmed with "every month on day 1, fixed schedule" and `get_project` shows a `Repeats:` line with the same text. Then `repeat_based_on: "defer"` and `repeat_catch_up: "true"`: PASS if the answer ends with "based on the defer date, catches up automatically". `repeat: "FREQ=NONSENSE"` must FAIL with "does not understand the repeat rule" and change nothing. Finally `repeat: "none"`: PASS if confirmed as stopped and `get_project` shows no `Repeats:` line. |

## Phase 5: Drop and delete (3 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| D01 | `drop_task` | `task_name: "{PREFIX} Task B"`. PASS if it is dropped and not deleted. |
| D02 | `drop_task` | **Edge case:** `task_name: "{PREFIX} DOES NOT EXIST"`. PASS if it returns an error. |
| D03 | `edit_project` | `project: "{PREFIX} Project"`, `property: "status"`, `value: "dropped"`. PASS if confirmed. |

## Phase 6: Cleanup

1. Delete `{PREFIX} Undo` (if it exists), `{PREFIX} P1`, `{PREFIX} P2` (with their subtasks) and `{PREFIX} Single`, `{PREFIX} Recurring Monthly`, then `{PREFIX} Subtask A`, `{PREFIX} Subtask B`, `{PREFIX} Task A`, `{PREFIX} Task B` and `{PREFIX} Task C` with `drop_task` and `confirm_delete: true` (in this order).
2. Delete the tags `{PREFIX}-Tag` and `{PREFIX}-Parent` (with its child tags) in OmniFocus by hand.
3. Delete the folder `{PREFIX} Folder Renamed` with its projects `{PREFIX} Project` and `{PREFIX} Project 2` using `delete_folder` with `confirm_delete: true` and `delete_contents: true`. PASS if `list_folders` no longer shows it.
4. Delete the files `/tmp/{PREFIX}.txt` and `/tmp/{PREFIX}-saved.txt` if you created them.
5. Run `search_tasks` with `query: "{PREFIX}"` and `filter: "all"`. PASS if nothing is found.

## Phase 7: Report

List every test with its ID, tool and PASS or FAIL, plus the error message for failures. Close with the totals (tests, passed, failed) and the cleanup status.
