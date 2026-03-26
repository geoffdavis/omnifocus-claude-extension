# Contributing to OmniFocus Claude Extension

First off, thank you for considering contributing to the OmniFocus Claude Extension! It's people like you that make this tool better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please be respectful and constructive in all interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* **Use a clear and descriptive title** for the issue to identify the problem.
* **Describe the exact steps which reproduce the problem** in as many details as possible.
* **Provide specific examples to demonstrate the steps**.
* **Describe the behavior you observed after following the steps** and point out what exactly is the problem with that behavior.
* **Explain which behavior you expected to see instead and why.**
* **Include screenshots** if relevant.
* **Include your system details** (macOS version, OmniFocus version, Claude Desktop version).

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* **Use a clear and descriptive title** for the issue to identify the suggestion.
* **Provide a step-by-step description of the suggested enhancement** in as many details as possible.
* **Provide specific examples to demonstrate the steps** or provide code snippets.
* **Describe the current behavior** and **explain which behavior you expected to see instead** and why.
* **Explain why this enhancement would be useful** to most OmniFocus Claude Extension users.

### Pull Requests

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed commands, update the documentation.
4. Ensure the extension still works properly.
5. Make sure your code follows the existing style.
6. Issue that pull request!

## Development Process

1. **Test your changes** with OmniFocus and Claude Desktop
2. **Update the README** if you've added new commands or changed existing ones
3. **Update the version number** in package.json if appropriate
4. **Write clear commit messages** that explain what changed and why

## Adding New Commands

When adding a new command to the extension:

1. Add the command definition to the `tools` array in `src/server/index.js`
2. Ensure the AppleScript is properly formatted and escaped
3. Test the command thoroughly with various inputs
4. Add documentation to the README.md
5. Include examples of usage

### Command Structure

```json
{
  "name": "command_name",
  "description": "What this command does",
  "parameters": {
    "type": "object",
    "properties": {
      "param_name": {
        "type": "string",
        "description": "What this parameter is for"
      }
    },
    "required": ["param_name"]
  },
  "command": "osascript",
  "arguments": [
    "-e",
    "AppleScript code here",
    "{{param_name}}"
  ]
}
```

## Testing

Before submitting a PR:

1. Test all existing commands still work
2. Test your new features/fixes
3. Test edge cases (empty inputs, special characters, etc.)
4. Test with different OmniFocus configurations

## Style Guide

### AppleScript Style

* Use clear variable names
* Add comments for complex logic
* Handle errors gracefully
* Return user-friendly messages

### Documentation Style

* Use clear, concise language
* Include examples for all features
* Keep the README organized and scannable
* Update the version history

## Release Process

Releases are triggered by pushing a `v*` git tag. The GitHub Actions workflow then builds the `.mcpb` extension and publishes a GitHub Release with it as a downloadable asset.

### Releasing a New Version

**Option A — Local (recommended for maintainers):**

1. Update `CHANGELOG.md` with the changes for the new release.
2. Run one of:
   ```bash
   npm run release:patch   # x.y.Z — bug fixes
   npm run release:minor   # x.Y.0 — new features
   npm run release:major   # X.0.0 — breaking changes
   ```
   This bumps `package.json`, creates a commit (`chore: release vX.Y.Z`), tags it `vX.Y.Z`, and pushes both to GitHub. The existing CI workflow picks up the tag and publishes the release.

**Option B — GitHub UI (no local checkout needed):**

1. Go to **Actions → Bump Version and Release** and click **Run workflow**.
2. Select `patch`, `minor`, or `major`.
3. The workflow runs tests, bumps the version in `package.json`, pushes the tag, builds the extension, and creates the GitHub Release — all in one step.

> **Note:** Update `CHANGELOG.md` before triggering Option B (commit it to `main` first), or update it in a follow-up commit after the release.

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

Thank you for contributing! 🎉
