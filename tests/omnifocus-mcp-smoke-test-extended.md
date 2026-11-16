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

**Safety:** All synthetic data uses the `SMOKETEST` + YYMMDDHHMMSS prefix. Tasks are created in the "Smoke Test" project and are deleted again at the end with `drop_task` and `confirm_delete`. The tags created in Phases 2 and 3, and the folder and projects created in Phase 4, cannot be removed with the tools and have to be deleted by hand in OmniFocus. No existing data is modified.

---START PROMPT---

You are executing a structured smoke test of the OmniFocus MCP plugin. Follow every step. Do not ask for confirmation between steps. Produce the final report at the end.

## Setup

Construct the test prefix `SMOKETEST` + YYMMDDHHMMSS from the current date and time (example: `SMOKETEST260324130501`). Refer to it as `{PREFIX}`. Record for each test: ID, tool, result (PASS/FAIL) and error message.

## Phase 1: Read-only tools (16 tests)

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

## Phase 2: Tasks and tags (28 tests)

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

## Phase 3: Tag hierarchy (8 tests)

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

## Phase 4: Folders and projects (15 tests)

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

## Phase 5: Drop and delete (3 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| D01 | `drop_task` | `task_name: "{PREFIX} Task B"`. PASS if it is dropped and not deleted. |
| D02 | `drop_task` | **Edge case:** `task_name: "{PREFIX} DOES NOT EXIST"`. PASS if it returns an error. |
| D03 | `edit_project` | `project: "{PREFIX} Project"`, `property: "status"`, `value: "dropped"`. PASS if confirmed. |

## Phase 6: Cleanup

1. Delete `{PREFIX} P1`, `{PREFIX} P2` (with their subtasks) and `{PREFIX} Single`, then `{PREFIX} Subtask A`, `{PREFIX} Subtask B`, `{PREFIX} Task A`, `{PREFIX} Task B` and `{PREFIX} Task C` with `drop_task` and `confirm_delete: true` (in this order).
2. Delete the tags `{PREFIX}-Tag` and `{PREFIX}-Parent` (with its child tags) in OmniFocus by hand.
3. Delete the folder `{PREFIX} Folder Renamed` with its projects `{PREFIX} Project` and `{PREFIX} Project 2` in OmniFocus by hand, because the tools cannot delete folders or projects.
4. Run `search_tasks` with `query: "{PREFIX}"` and `filter: "all"`. PASS if nothing is found.

## Phase 7: Report

List every test with its ID, tool and PASS or FAIL, plus the error message for failures. Close with the totals (tests, passed, failed) and the cleanup status.
