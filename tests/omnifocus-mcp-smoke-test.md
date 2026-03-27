# OmniFocus MCP Plugin Smoke Test

> **Version:** 1.1
> **Extension Version:** 2.1 (any 2.1.x patch should be non-breaking; breaking changes bump to 2.2)
> **Last Updated:** 2026-03-24
> **Author:** John Telford (generated with Claude)
> **Purpose:** Reusable end-to-end smoke test for all 18 OmniFocus MCP tools, designed to run as a single prompt in Claude Desktop.

---

## Instructions

Copy everything below the `---START PROMPT---` line and paste it into Claude Desktop as a single message. Claude will execute all tests sequentially and produce a pass/fail report at the end.

**Prerequisites:**
- OmniFocus MCP server is connected and running in Claude Desktop
- OmniFocus is open on your Mac
- A project named **"Smoke Test"** exists in OmniFocus (create it manually before first run; it will be reused across runs)

**Runtime:** ~3-4 minutes

**Safety:** All synthetic data uses the `SMOKETEST` + today's YYMMDD as a prefix. All created tasks are routed to the "Smoke Test" project and marked complete at the end. All created tags are deleted (with confirm=true) at the end. No existing data is modified.

---START PROMPT---

You are executing a structured smoke test of the OmniFocus MCP plugin. Follow every step below exactly. Do not skip steps. Do not ask for confirmation between steps. Execute the entire plan end-to-end, then produce the final report.

## Setup

1. Determine today's date and time in YYMMDDHHMMSS format. Construct the test prefix: `SMOKETEST` + YYMMDDHHMMSS (example: `SMOKETEST260324130501`). Use this prefix for ALL synthetic data created during the test. Refer to this as `{PREFIX}` below.
2. Initialize an internal results tracker. For each test, record: test ID, tool name, description, result (PASS/FAIL), and any error message.

## Phase 1: Read-Only Tools (10 tests)

These tests call tools that do not create or modify data. They validate that each tool responds without error.

| Test ID | Tool | Action |
|---------|------|--------|
| R01 | `list_inbox` | Call with no parameters. PASS if it returns a response (empty list is OK). |
| R02 | `today_tasks` | Call with no parameters. PASS if it returns a response. |
| R03 | `list_projects` | Call with `include_stats: false`. PASS if it returns a list of projects. |
| R04 | `list_projects` | Call with `include_stats: true`. PASS if it returns projects with task counts. |
| R05 | `list_deferred_tasks` | Call with no parameters. PASS if it returns a response. |
| R06 | `list_flagged_tasks` | Call with no parameters. PASS if it returns a response. |
| R07 | `list_overdue_tasks` | Call with no parameters. PASS if it returns a response. |
| R08 | `weekly_review` | Call with no parameters. PASS if it returns a review summary. |
| R09 | `list_tags` | Call with no parameters. PASS if it returns a response. |
| R10 | `search_tasks` | Call with `query: "{PREFIX}"`. PASS if it returns an empty result (confirms clean state). |

## Phase 2: Tag Creation (3 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| T01 | `create_tag` | Create tag with `name: "{PREFIX}-Tag"`. PASS if tag is created successfully. |
| T02 | `create_tag` | Create nested tag with `name: "{PREFIX}-ChildTag"`, `parent_tag: "{PREFIX}-Tag"`. PASS if child tag is created under parent. |
| T03 | `create_tag` | **Edge case: duplicate.** Create tag with `name: "{PREFIX}-Tag"` again. Record whether it errors or silently succeeds. PASS either way (this documents behavior). Note the actual behavior in the report. |

## Phase 3: Task Creation (6 tests)

All tasks MUST use `project: "Smoke Test"`.

| Test ID | Tool | Action |
|---------|------|--------|
| C01 | `add_task` | Create task with ALL optional parameters: `name: "{PREFIX} Full Task"`, `due_date: "tomorrow"`, `defer_date: "today"`, `note: "Smoke test task with all fields populated"`, `flagged: true`, `estimated_minutes: 15`, `project: "Smoke Test"`, `tags: "{PREFIX}-Tag"`. PASS if task is created. |
| C02 | `add_task` | **Minimal parameters.** Create task with only `name: "{PREFIX} Minimal Task"`, `project: "Smoke Test"`. PASS if task is created. |
| C03 | `add_task` | **Edge case: long name with special characters.** Create task with `name: "{PREFIX} Edge/Case: Task with 'quotes', ampersands & symbols! (100+ chars padding AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA)"`, `project: "Smoke Test"`. PASS if task is created without error. |
| C04 | `batch_add_tasks` | Create batch with subtasks: `tasks: "{PREFIX} Batch Parent|-{PREFIX} Batch Sub 1|-{PREFIX} Batch Sub 2|{PREFIX} Batch Standalone"`, `project: "Smoke Test"`. PASS if all tasks (including subtasks) are created. |
| C05 | `create_recurring_task` | Create recurring task: `name: "{PREFIX} Recurring Daily"`, `repeat_rule: "daily"`, `initial_due_date: "tomorrow"`, `project: "Smoke Test"`. PASS if recurring task is created. |
| C06 | `create_recurring_task` | **Edge case: unusual repeat rule.** Create: `name: "{PREFIX} Recurring 3 Days"`, `repeat_rule: "3 days"`, `project: "Smoke Test"`. PASS if task is created. Record behavior if the plugin rejects the rule. |
| C07 | `batch_add_tasks` | **Batch with tags.** Create batch: `tasks: "{PREFIX} Tagged Batch 1|{PREFIX} Tagged Batch 2"`, `project: "Smoke Test"`, `tags: "{PREFIX}-Tag"`. PASS if tasks are created with the tag applied to both. |
| C08 | `add_task` | **Tag auto-creation.** Create task with a tag that does not exist: `name: "{PREFIX} AutoTag Task"`, `project: "Smoke Test"`, `tags: "{PREFIX}-AutoTag"`. PASS if task is created and the tag is auto-created. |

## Phase 4: Search & Filter (4 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| S01 | `search_tasks` | Search with `query: "{PREFIX}"`, `filter: "all"`. PASS if it returns multiple tasks created in Phase 3. |
| S02 | `search_tasks` | Search with `query: "{PREFIX}"`, `filter: "available"`. PASS if it returns results (count may differ from S01). |
| S03 | `search_tasks` | Search with `query: "{PREFIX}"`, `filter: "remaining"`. PASS if it returns results. |
| S04 | `search_tasks` | **Edge case: limit parameter.** Search with `query: "{PREFIX}"`, `limit: 1`. PASS if it returns exactly 1 result. |

## Phase 5: Edit Operations (7 tests)

All edits target `{PREFIX} Full Task` (created in C01).

| Test ID | Tool | Action |
|---------|------|--------|
| E01 | `edit_task` | Edit `task_name: "{PREFIX} Full Task"`, `property: "name"`, `value: "{PREFIX} Full Task Renamed"`. PASS if name is changed. |
| E02 | `edit_task` | Edit `task_name: "{PREFIX} Full Task Renamed"`, `property: "note"`, `value: "Updated note from smoke test"`. PASS if note is updated. |
| E03 | `edit_task` | Edit `task_name: "{PREFIX} Full Task Renamed"`, `property: "due_date"`, `value: "next week"`. PASS if due date is changed. |
| E04 | `edit_task` | Edit `task_name: "{PREFIX} Full Task Renamed"`, `property: "defer_date"`, `value: "tomorrow"`. PASS if defer date is changed. |
| E05 | `edit_task` | Edit `task_name: "{PREFIX} Full Task Renamed"`, `property: "flagged"`, `value: "false"`. PASS if flag is removed. |
| E06 | `edit_task` | Edit `task_name: "{PREFIX} Full Task Renamed"`, `property: "estimated_minutes"`, `value: "30"`. PASS if estimate is updated. |
| E07 | `edit_task` | **Edge case: edit nonexistent task.** Edit `task_name: "{PREFIX} DOES NOT EXIST"`, `property: "name"`, `value: "anything"`. PASS if it returns an error or "not found" (expected failure). FAIL if it silently succeeds or crashes. |

## Phase 6: Tag Operations on Tasks (4 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| G01 | `add_tag_to_task` | Add tag `tag_name: "{PREFIX}-ChildTag"` to `task_name: "{PREFIX} Minimal Task"`. PASS if tag is added. |
| G02 | `remove_tag_from_task` | Remove tag `tag_name: "{PREFIX}-ChildTag"` from `task_name: "{PREFIX} Minimal Task"`. PASS if tag is removed. |
| G03 | `add_tag_to_task` | **Edge case: tag nonexistent task.** Add `tag_name: "{PREFIX}-Tag"` to `task_name: "{PREFIX} DOES NOT EXIST"`. PASS if it returns an error. FAIL if it silently succeeds or crashes. |
| G04 | `remove_tag_from_task` | **Edge case: remove tag not on task.** Remove `tag_name: "{PREFIX}-ChildTag"` from `task_name: "{PREFIX} Full Task Renamed"` (this tag was never added to this task). PASS if it returns an error or no-op. FAIL if it crashes. |
| G05 | `list_tags` | **Verify auto-created tag.** Call `list_tags` and check that `{PREFIX}-AutoTag` (created in C08) appears in the output. PASS if found. |

## Phase 7: Delete Tag (Dry Run + Real) (2 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| D01 | `delete_tag` | **Dry run.** Call with `name: "{PREFIX}-ChildTag"`, `confirm: false`. PASS if it returns impact info without deleting. |
| D02 | `delete_tag` | **Edge case: delete nonexistent tag (dry run).** Call with `name: "{PREFIX} NONEXISTENT TAG"`, `confirm: false`. PASS if it returns an error or empty impact. FAIL if it crashes. |

## Phase 8: Complete Tasks (2 tests)

| Test ID | Tool | Action |
|---------|------|--------|
| X01 | `complete_task` | Complete `task_name: "{PREFIX} Minimal Task"`. PASS if task is marked complete. |
| X02 | `complete_task` | **Edge case: complete nonexistent task.** Complete `task_name: "{PREFIX} DOES NOT EXIST"`. PASS if it returns an error. FAIL if it silently succeeds or crashes. |

## Phase 9: Cleanup

Execute these steps to leave OmniFocus clean. Record failures but do not stop.

1. **Complete all remaining smoke test tasks.** Search for `{PREFIX}` and complete every task that is still incomplete. This includes: `{PREFIX} Full Task Renamed`, `{PREFIX} Batch Parent`, `{PREFIX} Batch Sub 1`, `{PREFIX} Batch Sub 2`, `{PREFIX} Batch Standalone`, `{PREFIX} Recurring Daily`, `{PREFIX} Recurring 3 Days`, `{PREFIX} Tagged Batch 1`, `{PREFIX} Tagged Batch 2`, `{PREFIX} AutoTag Task`, and the edge case task from C03.
2. **Delete synthetic tags.** Call `delete_tag` with `confirm: true` for `{PREFIX}-ChildTag` first (child before parent), then `{PREFIX}-Tag`, then `{PREFIX}-AutoTag`.
3. **Verify cleanup.** Run `search_tasks` with `query: "{PREFIX}"`, `filter: "remaining"`. PASS if zero remaining (incomplete) tasks are found.

## Phase 10: Generate Report

Produce the final report in this exact format. Replace the sample data with actual results.

```
============================================================
  OMNIFOCUS MCP SMOKE TEST REPORT
============================================================
  Test Prefix:  {PREFIX}
  Date:         [today's full date]
  Start Time:   [time you started Phase 1]
  End Time:     [time you finished Phase 9]
  Duration:     [elapsed time]
============================================================

  SUMMARY
  -------
  Total Tests:  [count]
  Passed:       [count]
  Failed:       [count]
  Pass Rate:    [percentage]

  RESULTS BY PHASE
  ----------------

  Phase 1: Read-Only Tools
  R01  list_inbox              [PASS/FAIL]  [error if FAIL]
  R02  today_tasks             [PASS/FAIL]
  R03  list_projects           [PASS/FAIL]
  R04  list_projects (stats)   [PASS/FAIL]
  R05  list_deferred_tasks     [PASS/FAIL]
  R06  list_flagged_tasks      [PASS/FAIL]
  R07  list_overdue_tasks      [PASS/FAIL]
  R08  weekly_review           [PASS/FAIL]
  R09  list_tags               [PASS/FAIL]
  R10  search (clean state)    [PASS/FAIL]

  Phase 2: Tag Creation
  T01  create_tag              [PASS/FAIL]
  T02  create_tag (nested)     [PASS/FAIL]
  T03  create_tag (duplicate)  [PASS/FAIL]  [note: describe behavior]

  Phase 3: Task Creation
  C01  add_task (full)         [PASS/FAIL]
  C02  add_task (minimal)      [PASS/FAIL]
  C03  add_task (edge chars)   [PASS/FAIL]
  C04  batch_add_tasks         [PASS/FAIL]
  C05  recurring_task          [PASS/FAIL]
  C06  recurring_task (3 days) [PASS/FAIL]
  C07  batch_add (with tags)   [PASS/FAIL]
  C08  add_task (auto-tag)     [PASS/FAIL]

  Phase 4: Search & Filter
  S01  search (all)            [PASS/FAIL]  [count returned]
  S02  search (available)      [PASS/FAIL]  [count returned]
  S03  search (remaining)      [PASS/FAIL]  [count returned]
  S04  search (limit=1)        [PASS/FAIL]  [count returned]

  Phase 5: Edit Operations
  E01  edit name               [PASS/FAIL]
  E02  edit note               [PASS/FAIL]
  E03  edit due_date           [PASS/FAIL]
  E04  edit defer_date         [PASS/FAIL]
  E05  edit flagged            [PASS/FAIL]
  E06  edit estimated_minutes  [PASS/FAIL]
  E07  edit (nonexistent)      [PASS/FAIL]  [note: describe error]

  Phase 6: Tag Operations on Tasks
  G01  add_tag_to_task         [PASS/FAIL]
  G02  remove_tag_from_task    [PASS/FAIL]
  G03  tag nonexistent task    [PASS/FAIL]  [note: describe error]
  G04  remove absent tag       [PASS/FAIL]  [note: describe behavior]
  G05  verify auto-tag         [PASS/FAIL]

  Phase 7: Delete Tag
  D01  delete_tag (dry run)    [PASS/FAIL]
  D02  delete nonexistent tag  [PASS/FAIL]  [note: describe error]

  Phase 8: Complete Tasks
  X01  complete_task           [PASS/FAIL]
  X02  complete (nonexistent)  [PASS/FAIL]  [note: describe error]

  Cleanup
  Remaining tasks found:  [count]
  Tags deleted:           [YES/NO]
  Cleanup status:         [CLEAN/ISSUES]

  EDGE CASE BEHAVIOR LOG
  ----------------------
  T03 (duplicate tag):     [describe what happened]
  C03 (special chars):     [describe what happened]
  C06 (unusual repeat):    [describe what happened]
  C08 (tag auto-create):   [describe what happened]
  E07 (edit missing task): [describe error message]
  G03 (tag missing task):  [describe error message]
  G04 (remove absent tag): [describe behavior]
  D02 (delete missing tag):[describe error message]
  X02 (complete missing):  [describe error message]

============================================================
  END OF REPORT
============================================================
```

Begin execution now. Start with Phase 1.
