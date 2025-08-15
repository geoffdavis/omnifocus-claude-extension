# Changelog

All notable changes to the OmniFocus Claude Extension will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-08-15

### Added
- Initial release of OmniFocus Claude Extension
- Standalone MCP server implementation without external dependencies
- Five core tools for task management:
  - `add_task` - Add tasks to OmniFocus inbox or projects
  - `list_inbox` - View all inbox tasks
  - `today_tasks` - List tasks due today
  - `complete_task` - Mark tasks as complete by name
  - `weekly_review` - Get comprehensive weekly review summary
- AppleScript integration for OmniFocus automation
- Comprehensive test suite for validation
- GitHub Actions workflow for CI/CD
- Detailed documentation and installation guide

### Fixed
- Resolved server initialization issues with Claude Desktop
- Fixed JSON-RPC protocol implementation
- Corrected manifest configuration for stdio transport
- Fixed Node.js path issues in build and test scripts

### Technical Details
- Implemented JSON-RPC 2.0 protocol handling
- Created fallback AppleScript implementations for all tools
- Added proper error handling and logging
- Optimized build process for DXT format

## [0.1.0] - 2025-08-14 (Pre-release)

### Added
- Initial project structure
- Basic AppleScript files
- Tool definitions
- Build scripts

### Known Issues
- Server not initializing properly
- MCP SDK dependency issues
- Extension failing to load in Claude Desktop

---

## Upgrade Guide

### From 0.1.0 to 1.0.0

1. Clean previous installation:
   ```bash
   npm run clean
   ```

2. Rebuild the extension:
   ```bash
   npm run build
   ```

3. Reinstall in Claude Desktop:
   - Remove old extension if present
   - Install new `omnifocus-gtd.dxt` from `dist/` folder

### Breaking Changes
- Server implementation completely rewritten
- Build process changed from `build-dxt.js` to `build-dxt-new.js`
- Manifest structure updated for proper MCP compliance

## Support

For issues or questions, please open an issue on [GitHub](https://github.com/yourusername/omnifocus-claude-extension/issues).
