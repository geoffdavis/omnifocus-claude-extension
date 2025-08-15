# Changelog

All notable changes to the OmniFocus Claude Extension will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-01-26

### Added
- Initial release of OmniFocus Claude Extension
- Core task management commands:
  - `add_task` - Add tasks with natural language parsing
  - `list_inbox` - View inbox items
  - `today_tasks` - Show tasks due today
  - `complete_task` - Mark tasks as complete
  - `list_projects` - Display all projects
  - `search_tasks` - Search for tasks by keyword
  - `weekly_review` - Comprehensive weekly review
  - `quick_stats` - Database statistics
- Natural language date parsing (today, tomorrow, next week)
- Flagged task support
- Project assignment capability
- Build system with Node.js
- GitHub Actions for automated releases
- Comprehensive documentation

### Technical
- Modular source structure with separate tool definitions and scripts
- Automated build process generating .dxt archive
- Test suite for validation
- MIT License

[Unreleased]: https://github.com/yourusername/omnifocus-claude-extension/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/omnifocus-claude-extension/releases/tag/v1.0.0