# OmniFocus MCP Plugin Smoke Test: GTD, Review and Project Tools

> **Purpose:** End-to-end smoke test for the tools added after the base smoke test (`omnifocus-mcp-smoke-test.md`):
> GTD queries, review tools, project and folder tools, `get_task`, `drop_task` and `include_dropped`.
> It is designed to run as a single prompt in Claude Desktop.

---

## Instructions

Copy everything below the `---START PROMPT---` line and paste it into Claude Desktop as a single message. Claude executes all tests in order and produces a pass/fail report at the end.

**Prerequisites:**
- The OmniFocus MCP server is connected and OmniFocus is open
- A project named **"Smoke Test"** exists (the same one as in the base smoke test)

**Safety:** All synthetic data uses the `SMOKETEST` + YYMMDDHHMMSS prefix. Tasks are created in the "Smoke Test" project and are deleted again at the end with `drop_task` and `confirm_delete`. The tags created in Phases 2 and 3, and the folder and project created in Phase 4, cannot be removed with the tools and have to be deleted by hand in OmniFocus. No existing data is modified.

---START PROMPT---

You are executing a structured smoke test of the OmniFocus MCP plugin. Follow every step. Do not ask for confirmation between steps. Produce the final report at the end.

## Setup

Construct the test prefix `SMOKETEST` + YYMMDDHHMMSS from the current date and time (example: `SMOKETEST260324130501`). Refer to it as `{PREFIX}`. Record for each test: ID, tool, result (PASS/FAIL) and error message.

## Phase 1: Read-only tools (9 tests)

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

## Phase 2: Tasks and tags (7 tests)

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

## Phase 4: Folders and projects (7 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| P01 | `create_folder` | Create folder `{PREFIX} Folder`. PASS if created. |
| P02 | `create_project` | Create project `{PREFIX} Project` with `folder: "{PREFIX} Folder"`. PASS if created. |
| P03 | `add_task` | Create `{PREFIX} Task B` with `project: "{PREFIX} Folder > {PREFIX} Project"`. PASS if created. |
| P04 | `get_task` | `task_name: "{PREFIX} Task B"`. PASS if the project is shown as `{PREFIX} Folder > {PREFIX} Project`. FAIL if the task is in the inbox. |
| P05 | `edit_project` | `project: "{PREFIX} Project"`, `property: "type"`, `value: "sequential"`. PASS if confirmed. |
| P06 | `mark_project_reviewed` | `project: "{PREFIX} Folder > {PREFIX} Project"`. PASS if a next review date is shown. |
| P07 | `rename_folder` | Rename `{PREFIX} Folder` to `{PREFIX} Folder Renamed`. PASS if confirmed. |

## Phase 5: Drop and delete (3 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| D01 | `drop_task` | `task_name: "{PREFIX} Task B"`. PASS if it is dropped and not deleted. |
| D02 | `drop_task` | **Edge case:** `task_name: "{PREFIX} DOES NOT EXIST"`. PASS if it returns an error. |
| D03 | `edit_project` | `project: "{PREFIX} Project"`, `property: "status"`, `value: "dropped"`. PASS if confirmed. |

## Phase 6: Cleanup

1. Delete `{PREFIX} Task A`, `{PREFIX} Task B` and `{PREFIX} Task C` with `drop_task` and `confirm_delete: true`.
2. Delete the tags `{PREFIX}-Tag` and `{PREFIX}-Parent` (with its child tags) in OmniFocus by hand.
3. Delete the folder `{PREFIX} Folder Renamed` with its project `{PREFIX} Project` in OmniFocus by hand, because the tools cannot delete folders or projects.
4. Run `search_tasks` with `query: "{PREFIX}"` and `filter: "all"`. PASS if nothing is found.

## Phase 7: Report

List every test with its ID, tool and PASS or FAIL, plus the error message for failures. Close with the totals (tests, passed, failed) and the cleanup status.
