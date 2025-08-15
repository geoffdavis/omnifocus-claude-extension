#!/usr/bin/env node

/**
 * Build script for OmniFocus Claude Desktop Extension (DXT format)
 * Creates a properly formatted .dxt file following the official specification
 */

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

// Paths
const SRC_DIR = path.join(__dirname, 'src');
const DIST_DIR = path.join(__dirname, 'dist');

// Ensure dist directory exists
if (!fs.existsSync(DIST_DIR)) {
    fs.mkdirSync(DIST_DIR, { recursive: true });
}

console.log('🔨 Building OmniFocus DXT Extension...\n');

// Create the manifest with proper DXT format
const manifest = {
    "dxt_version": "0.1",
    "name": "OmniFocus GTD",
    "version": "1.0.0",
    "description": "Complete OmniFocus task management integration for Claude Desktop. Add tasks, manage projects, process inbox, and implement GTD methodology.",
    "author": {
        "name": "Geoff Davis",
        "email": "geoff@geoffdavis.com"
    },
    "server": {
        "type": "node",
        "entry_point": "server/index.js",
        "mcp_config": {
            "command": "node",
            "args": ["${__dirname}/server/index.js"]
        }
    },
    "tools": []
};

// Load tools and scripts
const toolsDir = path.join(SRC_DIR, 'tools');
const scriptsDir = path.join(SRC_DIR, 'scripts');

// Create a temporary build directory
const BUILD_DIR = path.join(__dirname, 'build-temp');
if (fs.existsSync(BUILD_DIR)) {
    fs.rmSync(BUILD_DIR, { recursive: true, force: true });
}
fs.mkdirSync(BUILD_DIR, { recursive: true });

// Create server directory
const serverDir = path.join(BUILD_DIR, 'server');
fs.mkdirSync(serverDir, { recursive: true });

// Create a simple MCP server that handles the tools
const serverCode = `#!/usr/bin/env node

/**
 * OmniFocus MCP Server
 * Handles communication between Claude Desktop and OmniFocus via AppleScript
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const { execSync } = require('child_process');

// Tool definitions
const tools = ${JSON.stringify(loadToolDefinitions(), null, 2)};

// AppleScript implementations
const scripts = ${JSON.stringify(loadScripts(), null, 2)};

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
        let scriptArgs = [];
        if (tool.parameters && tool.parameters.properties) {
            for (const param of Object.keys(tool.parameters.properties)) {
                if (args && args[param] !== undefined) {
                    scriptArgs.push(String(args[param]));
                }
            }
        }
        
        // Execute AppleScript
        const scriptWithArgs = script.replace(/\\$\\{([^}]+)\\}/g, (match, key) => {
            return args[key] || '';
        });
        
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
    console.error("OmniFocus MCP Server started");
}

main().catch((error) => {
    console.error("Server error:", error);
    process.exit(1);
});
`;

// Helper function to load tool definitions
function loadToolDefinitions() {
    const tools = [];
    const toolFiles = fs.readdirSync(toolsDir).filter(f => f.endsWith('.json'));
    
    for (const toolFile of toolFiles) {
        const tool = JSON.parse(fs.readFileSync(path.join(toolsDir, toolFile), 'utf8'));
        tools.push({
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters || { type: 'object', properties: {} }
        });
        
        // Add to manifest
        manifest.tools.push({
            name: tool.name,
            description: tool.description,
            inputSchema: tool.parameters || { type: 'object', properties: {} }
        });
    }
    
    return tools;
}

// Helper function to load scripts
function loadScripts() {
    const scripts = {};
    const toolFiles = fs.readdirSync(toolsDir).filter(f => f.endsWith('.json'));
    
    for (const toolFile of toolFiles) {
        const tool = JSON.parse(fs.readFileSync(path.join(toolsDir, toolFile), 'utf8'));
        const scriptPath = path.join(scriptsDir, tool.script);
        
        if (fs.existsSync(scriptPath)) {
            const script = fs.readFileSync(scriptPath, 'utf8');
            // Escape for JSON
            scripts[tool.name] = script.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
        }
    }
    
    return scripts;
}

// Write server file
fs.writeFileSync(path.join(serverDir, 'index.js'), serverCode);

// Create a simple package.json for the server
const packageJson = {
    "name": "omnifocus-gtd-server",
    "version": "1.0.0",
    "main": "index.js",
    "dependencies": {
        "@modelcontextprotocol/sdk": "^0.5.0"
    }
};
fs.writeFileSync(path.join(serverDir, 'package.json'), JSON.stringify(packageJson, null, 2));

// Write manifest.json
fs.writeFileSync(path.join(BUILD_DIR, 'manifest.json'), JSON.stringify(manifest, null, 2));

// Create the .dxt archive
async function createDxtArchive() {
    return new Promise((resolve, reject) => {
        const outputPath = path.join(DIST_DIR, 'omnifocus-gtd.dxt');
        const output = fs.createWriteStream(outputPath);
        const archive = archiver('zip', {
            zlib: { level: 9 }
        });

        output.on('close', () => {
            console.log(`✅ Extension built: ${outputPath}`);
            console.log(`   Size: ${(archive.pointer() / 1024).toFixed(2)} KB`);
            console.log(`   Tools: ${manifest.tools.length}`);
            resolve();
        });

        archive.on('error', reject);
        archive.pipe(output);
        
        // Add files to archive
        archive.file(path.join(BUILD_DIR, 'manifest.json'), { name: 'manifest.json' });
        archive.directory(serverDir, 'server');
        
        archive.finalize();
    });
}

// Build the extension
createDxtArchive()
    .then(() => {
        // Clean up
        fs.rmSync(BUILD_DIR, { recursive: true, force: true });
        console.log('\n🎉 Build complete!');
        console.log('Install by dragging dist/omnifocus-gtd.dxt onto Claude Desktop');
    })
    .catch((error) => {
        console.error('Build failed:', error);
        process.exit(1);
    });