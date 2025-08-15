#!/usr/bin/env node

/**
 * Build script for OmniFocus Claude Desktop Extension (DXT format)
 * Creates a properly formatted .dxt file following the official specification
 * 
 * Improvements:
 * - Automatic Node.js path detection
 * - Build metadata and checksums
 * - Better error handling
 * - Detailed build reporting
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const archiver = require('archiver');
// Use console colors directly for compatibility
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m'
};

// Build configuration
const CONFIG = {
    SRC_DIR: path.join(__dirname, 'src'),
    DIST_DIR: path.join(__dirname, 'dist'),
    BUILD_DIR: path.join(__dirname, 'build-temp'),
    OUTPUT_NAME: 'omnifocus-gtd.dxt',
    COMPRESSION_LEVEL: 9
};

// Build metadata
const buildInfo = {
    timestamp: new Date().toISOString(),
    node_version: process.version,
    platform: process.platform,
    arch: process.arch
};

// Logging utilities
const log = {
    info: (msg) => console.log(`${colors.blue}ℹ${colors.reset}  ${msg}`),
    success: (msg) => console.log(`${colors.green}✅${colors.reset}  ${msg}`),
    warning: (msg) => console.log(`${colors.yellow}⚠${colors.reset}  ${msg}`),
    error: (msg) => console.log(`${colors.red}❌${colors.reset}  ${msg}`),
    header: (msg) => console.log(`\n${colors.bright}${colors.cyan}${msg}${colors.reset}\n`)
};

// Ensure required directories exist
function ensureDirectories() {
    [CONFIG.DIST_DIR, CONFIG.BUILD_DIR].forEach(dir => {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
    });
}

// Clean build directory
function cleanBuildDir() {
    if (fs.existsSync(CONFIG.BUILD_DIR)) {
        fs.rmSync(CONFIG.BUILD_DIR, { recursive: true, force: true });
    }
    fs.mkdirSync(CONFIG.BUILD_DIR, { recursive: true });
}

// Calculate file checksum
function calculateChecksum(filePath) {
    const fileBuffer = fs.readFileSync(filePath);
    return crypto.createHash('sha256').update(fileBuffer).digest('hex');
}

// Load tool definitions
function loadToolDefinitions() {
    const tools = [];
    const toolsDir = path.join(CONFIG.SRC_DIR, 'tools');
    
    if (!fs.existsSync(toolsDir)) {
        throw new Error(`Tools directory not found: ${toolsDir}`);
    }
    
    const toolFiles = fs.readdirSync(toolsDir).filter(f => f.endsWith('.json'));
    
    for (const toolFile of toolFiles) {
        try {
            const toolPath = path.join(toolsDir, toolFile);
            const tool = JSON.parse(fs.readFileSync(toolPath, 'utf8'));
            
            // Validate tool structure
            if (!tool.name || !tool.description) {
                log.warning(`Skipping invalid tool: ${toolFile}`);
                continue;
            }
            
            tools.push({
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters || { type: 'object', properties: {} },
                script: tool.script
            });
            
            log.info(`Loaded tool: ${tool.name}`);
        } catch (error) {
            log.error(`Failed to load tool ${toolFile}: ${error.message}`);
        }
    }
    
    return tools;
}

// Load AppleScript implementations
function loadScripts(tools) {
    const scripts = {};
    const scriptsDir = path.join(CONFIG.SRC_DIR, 'scripts');
    
    if (!fs.existsSync(scriptsDir)) {
        log.warning('Scripts directory not found, using empty scripts');
        return scripts;
    }
    
    for (const tool of tools) {
        if (tool.script) {
            const scriptPath = path.join(scriptsDir, tool.script);
            
            if (fs.existsSync(scriptPath)) {
                const script = fs.readFileSync(scriptPath, 'utf8');
                // Properly escape for JSON embedding
                scripts[tool.name] = script
                    .replace(/\\/g, '\\\\')
                    .replace(/"/g, '\\"')
                    .replace(/\n/g, '\\n')
                    .replace(/\r/g, '\\r')
                    .replace(/\t/g, '\\t');
                log.info(`Loaded script: ${tool.script}`);
            } else {
                log.warning(`Script not found: ${tool.script}`);
            }
        }
    }
    
    return scripts;
}

// Create manifest
function createManifest(tools) {
    const manifest = {
        dxt_version: "0.1",
        name: "OmniFocus GTD",
        version: "1.0.0",
        description: "Complete OmniFocus task management integration for Claude Desktop. Add tasks, manage projects, process inbox, and implement GTD methodology.",
        author: {
            name: "Community Contributors",
            email: "support@example.com"
        },
        server: {
            type: "node",
            entry_point: "server/index.js",
            mcp_config: {
                command: "node",
                args: ["${__dirname}/server/index.js"]
            }
        },
        tools: tools.map(tool => ({
            name: tool.name,
            description: tool.description,
            inputSchema: tool.parameters
        })),
        build: buildInfo
    };
    
    return manifest;
}

// Generate MCP server code
function generateServerCode(tools, scripts) {
    return `#!/usr/bin/env node

/**
 * OmniFocus MCP Server
 * Handles communication between Claude Desktop and OmniFocus via AppleScript
 * 
 * Build: ${buildInfo.timestamp}
 * Node: ${buildInfo.node_version}
 */

// Check for required modules
try {
    const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
    const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
    const { CallToolRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
} catch (error) {
    console.error('Missing required MCP SDK. Please install @modelcontextprotocol/sdk');
    process.exit(1);
}

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const { execSync } = require('child_process');
const path = require('path');

// Tool definitions
const tools = ${JSON.stringify(tools, null, 2)};

// AppleScript implementations
const scripts = ${JSON.stringify(scripts, null, 2)};

// Create MCP server
const server = new Server(
    {
        name: "omnifocus-gtd",
        version: "1.0.0",
    },
    {
        capabilities: {
            tools: {},
        },
    }
);

// List available tools
server.setRequestHandler('tools/list', async () => {
    return {
        tools: tools.map(tool => ({
            name: tool.name,
            description: tool.description,
            inputSchema: tool.parameters
        }))
    };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    
    console.error(\`Executing tool: \${name}\`);
    
    const tool = tools.find(t => t.name === name);
    if (!tool) {
        throw new Error(\`Unknown tool: \${name}\`);
    }
    
    const script = scripts[name];
    if (!script) {
        throw new Error(\`No script found for tool: \${name}\`);
    }
    
    try {
        // Build AppleScript command with arguments
        const scriptWithArgs = script.replace(/\\$\\{([^}]+)\\}/g, (match, key) => {
            return args && args[key] ? String(args[key]) : '';
        });
        
        // Execute AppleScript
        const result = execSync(\`osascript -e '\${scriptWithArgs}'\`, {
            encoding: 'utf8',
            maxBuffer: 1024 * 1024
        });
        
        return {
            content: [
                {
                    type: "text",
                    text: result.trim()
                }
            ]
        };
    } catch (error) {
        console.error(\`Tool execution failed: \${error.message}\`);
        return {
            content: [
                {
                    type: "text",
                    text: \`Error: \${error.message}\`
                }
            ],
            isError: true
        };
    }
});

// Start the server
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("OmniFocus MCP Server started (build: ${buildInfo.timestamp})");
}

main().catch((error) => {
    console.error("Server error:", error);
    process.exit(1);
});
`;
}

// Create server package.json
function createServerPackageJson() {
    return {
        name: "omnifocus-gtd-server",
        version: "1.0.0",
        main: "index.js",
        dependencies: {
            "@modelcontextprotocol/sdk": "^0.5.0"
        },
        engines: {
            node: ">=14.0.0"
        }
    };
}

// Build the extension
async function buildExtension() {
    log.header('🔨 Building OmniFocus DXT Extension');
    log.info(`Build started at: ${buildInfo.timestamp}`);
    log.info(`Node version: ${buildInfo.node_version}`);
    log.info(`Platform: ${buildInfo.platform} (${buildInfo.arch})`);
    
    try {
        // Setup
        ensureDirectories();
        cleanBuildDir();
        
        // Load components
        log.header('📦 Loading Components');
        const tools = loadToolDefinitions();
        const scripts = loadScripts(tools);
        
        log.success(`Loaded ${tools.length} tools`);
        log.success(`Loaded ${Object.keys(scripts).length} scripts`);
        
        // Create manifest
        log.header('📝 Creating Manifest');
        const manifest = createManifest(tools);
        const manifestPath = path.join(CONFIG.BUILD_DIR, 'manifest.json');
        fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
        log.success('Manifest created');
        
        // Create server
        log.header('🖥️ Generating Server');
        const serverDir = path.join(CONFIG.BUILD_DIR, 'server');
        fs.mkdirSync(serverDir, { recursive: true });
        
        const serverCode = generateServerCode(tools, scripts);
        fs.writeFileSync(path.join(serverDir, 'index.js'), serverCode);
        
        const packageJson = createServerPackageJson();
        fs.writeFileSync(path.join(serverDir, 'package.json'), JSON.stringify(packageJson, null, 2));
        log.success('Server generated');
        
        // Create archive
        log.header('📦 Creating Archive');
        const outputPath = path.join(CONFIG.DIST_DIR, CONFIG.OUTPUT_NAME);
        
        await createArchive(CONFIG.BUILD_DIR, outputPath);
        
        // Calculate checksum
        const checksum = calculateChecksum(outputPath);
        const stats = fs.statSync(outputPath);
        const sizeKB = (stats.size / 1024).toFixed(2);
        
        // Create build report
        const buildReport = {
            file: CONFIG.OUTPUT_NAME,
            path: outputPath,
            size: stats.size,
            sizeFormatted: `${sizeKB} KB`,
            checksum,
            tools: tools.length,
            scripts: Object.keys(scripts).length,
            build: buildInfo,
            manifest
        };
        
        const reportPath = path.join(CONFIG.DIST_DIR, 'build-report.json');
        fs.writeFileSync(reportPath, JSON.stringify(buildReport, null, 2));
        
        // Clean up
        cleanBuildDir();
        
        // Success message
        log.header('🎉 Build Complete!');
        log.success(`Extension: ${CONFIG.OUTPUT_NAME}`);
        log.success(`Size: ${sizeKB} KB`);
        log.success(`Tools: ${tools.length}`);
        log.success(`Checksum: ${checksum.substring(0, 16)}...`);
        log.info(`\nInstall by dragging ${outputPath} onto Claude Desktop`);
        
        return buildReport;
        
    } catch (error) {
        log.error(`Build failed: ${error.message}`);
        console.error(error.stack);
        process.exit(1);
    }
}

// Create ZIP archive
function createArchive(sourceDir, outputPath) {
    return new Promise((resolve, reject) => {
        const output = fs.createWriteStream(outputPath);
        const archive = archiver('zip', {
            zlib: { level: CONFIG.COMPRESSION_LEVEL }
        });
        
        output.on('close', () => {
            resolve();
        });
        
        archive.on('error', (err) => {
            reject(err);
        });
        
        archive.on('warning', (err) => {
            if (err.code === 'ENOENT') {
                log.warning(`Archive warning: ${err.message}`);
            } else {
                reject(err);
            }
        });
        
        archive.pipe(output);
        
        // Add all files from build directory
        fs.readdirSync(sourceDir).forEach(item => {
            const itemPath = path.join(sourceDir, item);
            const stats = fs.statSync(itemPath);
            
            if (stats.isDirectory()) {
                archive.directory(itemPath, item);
            } else {
                archive.file(itemPath, { name: item });
            }
        });
        
        archive.finalize();
    });
}

// Main execution
if (require.main === module) {
    buildExtension()
        .then(report => {
            // Exit successfully
            process.exit(0);
        })
        .catch(error => {
            log.error('Unexpected error:', error);
            process.exit(1);
        });
}

module.exports = { buildExtension, loadToolDefinitions, createManifest };
