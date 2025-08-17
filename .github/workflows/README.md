# GitHub Actions Workflows

## Overview
This repository uses GitHub Actions for continuous integration and deployment.

## Workflows

### Build and Release (`build.yml`)
Triggers on:
- Push to main branch
- Pull requests to main
- Version tags (v*)
- Manual dispatch

Jobs:
1. **Test**: Runs Jest unit tests with coverage
2. **Build**: Creates DXT extension package
3. **Release**: Creates GitHub release for version tags

### Test Suite (`test.yml`)
Comprehensive testing across multiple environments.

Triggers on:
- Push to main/develop branches
- Pull requests to main
- Manual dispatch

Jobs:
1. **Unit Tests**: Matrix testing on macOS with Node 16/18/20
2. **Integration Tests**: MCP server and AppleScript validation
3. **Code Quality**: Syntax checking and security audit
4. **Test Summary**: Aggregated results dashboard

## Test Features

### Coverage Reporting
- Jest coverage reports uploaded as artifacts
- Coverage thresholds enforced in CI
- HTML reports available for download

### Matrix Testing
- Multiple Node.js versions (16, 18, 20)
- Multiple macOS versions (latest, 12)
- Parallel execution for faster feedback

### Test Results
- JSON test results for analysis
- GitHub Actions summary with metrics
- Artifact retention for 30 days

## Local Testing

Run tests locally before pushing:

```bash
# Run all tests
npm test

# Run with coverage
npm test:coverage

# Run in CI mode
npm test:ci

# Watch mode for development
npm test:watch
```

## Required Secrets
No additional secrets required. Uses default GITHUB_TOKEN for releases.

## Artifacts

Each workflow run produces:
- **Test Results**: JSON test output and coverage reports
- **Build Artifacts**: DXT extension file
- **Build Report**: JSON build metadata

## Status Badges

Add to README:
```markdown
![Tests](https://github.com/yourusername/omnifocus-claude-extension/workflows/Test%20Suite/badge.svg)
![Build](https://github.com/yourusername/omnifocus-claude-extension/workflows/Build%20and%20Release/badge.svg)
```

## Troubleshooting

### Test Failures
1. Check test output in Actions tab
2. Download test-results artifact for details
3. Run tests locally to reproduce

### Build Failures
1. Verify Node.js version compatibility
2. Check npm install completes successfully
3. Validate AppleScript syntax

### Release Issues
1. Ensure version tag format is v*.*.* 
2. Check GITHUB_TOKEN permissions
3. Verify build artifacts exist