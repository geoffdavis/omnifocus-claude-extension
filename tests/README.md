# OmniFocus Claude Extension Test Suite

## Overview
Comprehensive unit tests for the OmniFocus Claude Extension using Jest.

## Test Coverage

### Server Tests (`server.test.js`)
- **Server Initialization**: Validates server file existence and syntax
- **JSON-RPC Protocol**: Tests MCP protocol implementation
  - Initialize request handling
  - Tools list request/response
  - Error handling for invalid methods
  - Malformed JSON handling
- **Tool Definitions**: Verifies all tools have required fields

### Build System Tests (`build.test.js`)
- **Build Script**: Validates build script existence and syntax
- **Build Process**: Tests DXT package creation
- **Manifest Generation**: Verifies manifest format compliance
- **Version Management**: Ensures version consistency
- **File Structure**: Validates required directories and files

### AppleScript Tests (`applescript.test.js`)
- **Script Files**: Verifies all required scripts exist
- **Script Syntax**: Validates AppleScript syntax
- **Script Parameters**: Tests parameter handling
- **Script Output**: Validates return formats
- **OmniFocus Integration**: Tests application integration

## Running Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm test:watch

# Run with coverage report
npm test:coverage

# Run legacy tests
npm test:legacy
```

## Test Configuration

Tests are configured in `jest.config.js` with:
- Node test environment
- 10-second timeout for async operations
- Coverage reporting for source files
- Verbose output for debugging

## Writing New Tests

When adding new features:
1. Add corresponding test file in `tests/` directory
2. Follow existing test structure and naming conventions
3. Ensure tests are isolated and don't depend on external state
4. Mock external dependencies when necessary
5. Run tests locally before committing

## CI/CD Integration

Tests run automatically on:
- Pull request creation
- Commits to main branch
- Pre-release validation

## Troubleshooting

If tests fail:
1. Check console output for specific failure details
2. Run individual test files: `jest tests/server.test.js`
3. Use `--verbose` flag for detailed output
4. Check for missing dependencies or file permissions
5. Ensure OmniFocus is installed (for AppleScript tests)