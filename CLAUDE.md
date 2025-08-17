# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an OmniFocus Claude Desktop Extension that enables advanced task management using GTD (Getting Things Done) methodology. The extension uses MCP (Model Context Protocol) to communicate between Claude Desktop and OmniFocus via AppleScript.

## Essential Commands

### Build & Development
```bash
# Install dependencies
npm install

# Build the DXT extension file
npm run build

# Validate the built extension
npm run validate

# Clean and rebuild
npm run rebuild

# Development build with validation
npm run dev

# Production release build
npm run release
```

### Testing
```bash
# Run tests
npm test

# Test specific components
node test-server.js      # Test MCP server
node test-manifests.js   # Test manifest generation
node validate-dxt.js     # Validate DXT package
```

## Architecture

### Core Components

1. **MCP Server** (`src/server/index.js`)
   - JSON-RPC 2.0 implementation for Claude Desktop communication
   - Tool registration and execution routing
   - AppleScript execution via child processes
   - Error handling and response formatting

2. **AppleScript Layer** (`src/scripts/`)
   - Original scripts: `add_task.applescript`, `complete_task.applescript`, `list_inbox.applescript`, `today_tasks.applescript`, `weekly_review.applescript`
   - Enhanced scripts in `enhanced/`: `search_tasks.applescript`, `edit_task.applescript`, `batch_add_tasks.applescript`, `create_recurring_task.applescript`, plus list views

3. **Build System** (`build.js`, `build-dxt-new.js`)
   - Creates DXT package following official specification
   - Handles manifest generation with proper format (dxt_version: "0.1")
   - Archives extension with correct structure
   - Generates checksums and build reports

4. **Extension Manifest** (`src/manifest.json`)
   - Must follow exact DXT specification format
   - Server entry point configuration
   - Tool definitions and metadata

### Key Implementation Details

- **Date Parsing**: AppleScripts handle natural language dates ("tomorrow", "next Friday", etc.)
- **Error Handling**: Each AppleScript returns structured error messages for better debugging
- **Batch Operations**: Use pipe (`|`) for task separation and dash (`-`) for subtask prefix
- **MCP Protocol**: Strict JSON-RPC 2.0 compliance for Claude Desktop compatibility

## Important Considerations

1. **AppleScript Escaping**: Always properly escape special characters in AppleScript strings
2. **OmniFocus Permissions**: Extension requires automation permissions for OmniFocus
3. **Manifest Format**: Must use exact format - `dxt_version: "0.1"` (not 0.1.0 or 0.0.1)
4. **Build Output**: Extension files go to `dist/` directory as `.dxt` files
5. **Error Messages**: Provide clear, actionable error messages from AppleScripts
6. **Task Matching**: Be careful with task name matching - handle multiple matches gracefully

## Common Development Tasks

### Adding New Tool
1. Create AppleScript in `src/scripts/enhanced/`
2. Add tool definition to `tools` array in `src/server/index.js`
3. Implement handler in the server's tool execution logic
4. Test with `node test-server.js`
5. Rebuild and validate: `npm run dev`

### Debugging Issues
1. Check Claude Desktop logs: `~/Library/Logs/Claude/`
2. Test AppleScript directly: `osascript src/scripts/[script_name].applescript`
3. Verify MCP server: `node src/server/index.js` (send test JSON-RPC)
4. Validate DXT package: `npm run validate`

### Testing AppleScript Changes
```bash
# Test individual script
osascript src/scripts/enhanced/search_tasks.applescript "test query"

# Test through server
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search_tasks","arguments":{"query":"test"}},"id":1}' | node src/server/index.js
```

## File Structure Notes

- Build artifacts (`dist/`, `build/`, `extension-build/`) are gitignored
- Source files must stay in `src/` directory structure
- AppleScripts must maintain exact formatting for OmniFocus compatibility
- Server must output clean JSON-RPC to stdout (logs to stderr only)