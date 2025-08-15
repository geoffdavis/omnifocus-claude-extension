#!/usr/bin/env node

/**
 * Build script for OmniFocus Claude Desktop Extension (DXT format)
 * Creates a properly formatted .dxt file with embedded MCP server
 */

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');
const crypto = require('crypto');

// Build configuration
const CONFIG = {
    SRC_DIR: path.join(__dirname, 'src'),
    DIST_DIR: path.join(__dirname, 'dist'),
    OUTPUT_NAME: 'omnifocus-gtd.dxt'
};

// Console colors
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m'
};

// Logging utilities
const log = {
    info: (msg) => console.log(`${colors.blue}ℹ${colors.reset}  ${msg}`),
    success: (msg) => console.log(`${colors.green}✅${colors.reset}  ${msg}`),
    warning: (msg) => console.log(`${colors.yellow}⚠${colors.reset}  ${msg}`),
    error: (msg) => console.log(`${colors.red}❌${colors.reset}  ${msg}`),
    header: (msg) => console.log(`\n${colors.bright}${colors.cyan}${msg}${colors.reset}\n`)
};

// Ensure dist directory exists
function ensureDirectories() {
    if (!fs.existsSync(CONFIG.DIST_DIR)) {
        fs.mkdirSync(CONFIG.DIST_DIR, { recursive: true });
    }
}

// Create ZIP archive
function createArchive(sourceDir, outputPath) {
    return new Promise((resolve, reject) => {
        const output = fs.createWriteStream(outputPath);
        const archive = archiver('zip', {
            zlib: { level: 9 }
        });
        
        output.on('close', () => {
            resolve(archive.pointer());
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
        
        // Add manifest
        const manifestPath = path.join(sourceDir, 'manifest-dxt.json');
        if (fs.existsSync(manifestPath)) {
            const manifestContent = fs.readFileSync(manifestPath, 'utf8');
            archive.append(manifestContent, { name: 'manifest.json' });
            log.info('Added manifest.json');
        } else {
            reject(new Error('manifest-dxt.json not found'));
        }
        
        // Add server directory
        const serverDir = path.join(sourceDir, 'server');
        if (fs.existsSync(serverDir)) {
            archive.directory(serverDir, 'server');
            log.info('Added server directory');
        } else {
            reject(new Error('server directory not found'));
        }
        
        // Add scripts directory
        const scriptsDir = path.join(sourceDir, 'scripts');
        if (fs.existsSync(scriptsDir)) {
            archive.directory(scriptsDir, 'scripts');
            log.info('Added scripts directory');
        }
        
        // Add tools directory (for reference)
        const toolsDir = path.join(sourceDir, 'tools');
        if (fs.existsSync(toolsDir)) {
            archive.directory(toolsDir, 'tools');
            log.info('Added tools directory');
        }
        
        archive.finalize();
    });
}

// Calculate file checksum
function calculateChecksum(filePath) {
    const fileBuffer = fs.readFileSync(filePath);
    return crypto.createHash('sha256').update(fileBuffer).digest('hex');
}

// Build the extension
async function buildExtension() {
    log.header('🔨 Building OmniFocus DXT Extension');
    
    try {
        // Setup
        ensureDirectories();
        
        // Verify required files exist
        const requiredFiles = [
            path.join(CONFIG.SRC_DIR, 'manifest-dxt.json'),
            path.join(CONFIG.SRC_DIR, 'server', 'index.js')
        ];
        
        for (const file of requiredFiles) {
            if (!fs.existsSync(file)) {
                throw new Error(`Required file not found: ${file}`);
            }
        }
        
        log.success('All required files found');
        
        // Create archive
        log.header('📦 Creating Archive');
        const outputPath = path.join(CONFIG.DIST_DIR, CONFIG.OUTPUT_NAME);
        
        const archiveSize = await createArchive(CONFIG.SRC_DIR, outputPath);
        
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
            timestamp: new Date().toISOString(),
            node_version: process.version,
            platform: process.platform
        };
        
        const reportPath = path.join(CONFIG.DIST_DIR, 'build-report.json');
        fs.writeFileSync(reportPath, JSON.stringify(buildReport, null, 2));
        
        // Success message
        log.header('🎉 Build Complete!');
        log.success(`Extension: ${CONFIG.OUTPUT_NAME}`);
        log.success(`Size: ${sizeKB} KB`);
        log.success(`Checksum: ${checksum.substring(0, 16)}...`);
        log.info(`\nTo install:`);
        log.info(`1. Open Claude Desktop`);
        log.info(`2. Go to Extensions settings`);
        log.info(`3. Drop ${outputPath} onto the window`);
        
        return buildReport;
        
    } catch (error) {
        log.error(`Build failed: ${error.message}`);
        console.error(error.stack);
        process.exit(1);
    }
}

// Main execution
if (require.main === module) {
    buildExtension()
        .then(report => {
            process.exit(0);
        })
        .catch(error => {
            log.error('Unexpected error:', error);
            process.exit(1);
        });
}

module.exports = { buildExtension };
