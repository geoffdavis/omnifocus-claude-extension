# Build Guide for OmniFocus Claude Extension

## Quick Start

```bash
# Install dependencies
npm install

# Build the DXT extension
npm run build:dxt

# Validate the build
npm run validate
```

## Available Build Scripts

| Script | Command | Description |
|--------|---------|-------------|
| `build` | `npm run build` | Build standard extension format |
| `build:dxt` | `npm run build:dxt` | Build DXT format with validation and checksums |
| `build:all` | `npm run build:all` | Build all extension formats |
| `clean` | `npm run clean` | Clean all build artifacts |
| `rebuild` | `npm run rebuild` | Clean and rebuild everything |
| `validate` | `npm run validate` | Validate all DXT files |
| `release` | `npm run release` | Production build with validation |
| `test` | `npm test` | Run tests |
| `watch` | `npm run watch` | Watch mode for development |

## Build Output

All built extensions are placed in the `dist/` directory:
- `omnifocus-gtd.dxt` - Main extension file (4.17 KB)
- `build-report.json` - Build metadata and checksums

## Project Structure

```
omnifocus-claude-extension/
├── src/                    # Source files
│   ├── tools/             # Tool definitions (JSON)
│   ├── scripts/           # AppleScript implementations
│   └── manifest-dxt.json  # DXT manifest template
├── dist/                  # Build output (gitignored)
├── build-dxt.js          # Enhanced DXT build script
├── build-minimal.js      # Minimal build variant
├── build-simple.js       # Simple build variant
├── build.js              # Standard build script
├── validate-dxt.js       # Validation script
└── test.js               # Test runner
```

## Build Features

The enhanced DXT build process includes:
- ✅ SHA-256 checksums for integrity verification
- ✅ Build metadata (timestamp, platform, Node version)
- ✅ Comprehensive build reporting
- ✅ Color-coded console output
- ✅ Proper error handling
- ✅ Cross-platform compatibility

## Installation

After building, install the extension by:
1. Open Claude Desktop
2. Drag `dist/omnifocus-gtd.dxt` onto the application
3. The extension will be automatically installed

## Development

For development with file watching:
```bash
npm run watch
```

This will automatically rebuild when source files change.

## Validation

The build process automatically validates:
- DXT format specification compliance
- Manifest structure
- Tool definitions
- Archive integrity
- File checksums

Run validation separately with:
```bash
npm run validate
```

## Troubleshooting

If the build fails:
1. Ensure Node.js v14+ is installed
2. Run `npm install` to install dependencies
3. Clean build artifacts: `npm run clean`
4. Try rebuilding: `npm run rebuild`

## Requirements

- Node.js v14.0.0 or higher
- macOS (for OmniFocus integration)
- npm or yarn package manager

## License

MIT - See LICENSE file for details
