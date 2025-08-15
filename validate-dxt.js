#!/usr/bin/env node

/**
 * Validate DXT files for OmniFocus Claude Extension
 * Checks the structure and format of generated .dxt files
 */

const fs = require('fs');
const path = require('path');

const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m'
};

const log = {
    info: (msg) => console.log(`${colors.blue}ℹ${colors.reset}  ${msg}`),
    success: (msg) => console.log(`${colors.green}✓${colors.reset}  ${msg}`),
    warning: (msg) => console.log(`${colors.yellow}⚠${colors.reset}  ${msg}`),
    error: (msg) => console.log(`${colors.red}✗${colors.reset}  ${msg}`),
    header: (msg) => console.log(`\n${colors.bright}${colors.cyan}${msg}${colors.reset}`)
};

const DIST_DIR = path.join(__dirname, 'dist');

/**
 * Check if a file is a valid ZIP archive
 */
function isZipFile(filePath) {
    try {
        const buffer = fs.readFileSync(filePath);
        // ZIP files start with PK (0x504B)
        return buffer[0] === 0x50 && buffer[1] === 0x4B;
    } catch (error) {
        return false;
    }
}

/**
 * Check if a file is valid JSON
 */
function isJsonFile(filePath) {
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        JSON.parse(content);
        return true;
    } catch (error) {
        return false;
    }
}

/**
 * Parse JSON file and validate structure
 */
function validateJsonStructure(filePath) {
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        const data = JSON.parse(content);
        
        const issues = [];
        
        // Check for required fields (different formats might have different requirements)
        const possibleRequiredFields = [
            ['name', 'version', 'tools'],  // Standard format
            ['dxt_version', 'name', 'version'],  // DXT format
            ['id', 'name', 'version', 'tools']  // Alternative format
        ];
        
        let hasValidFormat = false;
        for (const requiredSet of possibleRequiredFields) {
            if (requiredSet.every(field => data.hasOwnProperty(field))) {
                hasValidFormat = true;
                break;
            }
        }
        
        if (!hasValidFormat) {
            issues.push('Missing required fields for any known format');
        }
        
        // Check tools array if present
        if (data.tools) {
            if (!Array.isArray(data.tools)) {
                issues.push('Tools field is not an array');
            } else if (data.tools.length === 0) {
                issues.push('Tools array is empty');
            } else {
                // Validate each tool
                data.tools.forEach((tool, index) => {
                    if (!tool.name) {
                        issues.push(`Tool at index ${index} missing name`);
                    }
                    if (!tool.description) {
                        issues.push(`Tool at index ${index} missing description`);
                    }
                });
            }
        }
        
        return {
            valid: issues.length === 0,
            issues,
            format: data.dxt_version ? 'DXT' : (data.id ? 'Extension' : 'Standard'),
            toolCount: data.tools ? data.tools.length : 0
        };
    } catch (error) {
        return {
            valid: false,
            issues: [`Failed to parse: ${error.message}`],
            format: 'Unknown',
            toolCount: 0
        };
    }
}

/**
 * Validate a DXT file
 */
function validateDxtFile(filePath) {
    const fileName = path.basename(filePath);
    const fileSize = fs.statSync(filePath).size;
    const sizeKB = (fileSize / 1024).toFixed(2);
    
    log.header(`Validating: ${fileName}`);
    log.info(`Size: ${sizeKB} KB`);
    
    // Check if it's a ZIP or JSON
    if (isZipFile(filePath)) {
        log.info('Format: ZIP archive');
        log.success('Valid ZIP structure detected');
        // For ZIP files, we can't easily validate internal structure without extracting
        log.warning('Cannot validate internal structure without extracting');
    } else if (isJsonFile(filePath)) {
        log.info('Format: Plain JSON');
        const validation = validateJsonStructure(filePath);
        
        log.info(`Structure: ${validation.format} format`);
        log.info(`Tools: ${validation.toolCount}`);
        
        if (validation.valid) {
            log.success('Valid JSON structure');
        } else {
            validation.issues.forEach(issue => log.error(issue));
        }
        
        return validation.valid;
    } else {
        log.error('Unknown file format (neither ZIP nor JSON)');
        return false;
    }
    
    return true;
}

/**
 * Main validation function
 */
function validateAll() {
    log.header('🔍 DXT File Validation');
    
    if (!fs.existsSync(DIST_DIR)) {
        log.error('dist/ directory not found. Run build first.');
        process.exit(1);
    }
    
    const dxtFiles = fs.readdirSync(DIST_DIR)
        .filter(f => f.endsWith('.dxt'))
        .map(f => path.join(DIST_DIR, f));
    
    if (dxtFiles.length === 0) {
        log.warning('No .dxt files found in dist/');
        process.exit(1);
    }
    
    log.info(`Found ${dxtFiles.length} DXT files to validate`);
    
    let allValid = true;
    const results = [];
    
    for (const dxtFile of dxtFiles) {
        const isValid = validateDxtFile(dxtFile);
        results.push({
            file: path.basename(dxtFile),
            valid: isValid
        });
        if (!isValid) {
            allValid = false;
        }
    }
    
    // Summary
    log.header('📊 Validation Summary');
    
    const validCount = results.filter(r => r.valid).length;
    const invalidCount = results.filter(r => !r.valid).length;
    
    log.info(`Total files: ${results.length}`);
    log.success(`Valid: ${validCount}`);
    if (invalidCount > 0) {
        log.error(`Invalid: ${invalidCount}`);
    }
    
    if (allValid) {
        log.header('✨ All DXT files are valid!');
    } else {
        log.header('⚠️  Some files have validation issues');
        log.info('Review the issues above and rebuild if necessary');
    }
    
    process.exit(allValid ? 0 : 1);
}

// Run validation
if (require.main === module) {
    validateAll();
}

module.exports = { validateDxtFile, isZipFile, isJsonFile };
