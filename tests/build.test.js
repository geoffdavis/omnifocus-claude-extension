const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

describe('Build System', () => {
    const buildScript = path.join(__dirname, '..', 'build.js');
    const packageJsonPath = path.join(__dirname, '..', 'package.json');
    const distDir = path.join(__dirname, '..', 'dist');
    
    beforeAll(() => {
        // Clean up any existing build artifacts
        if (fs.existsSync(distDir)) {
            fs.rmSync(distDir, { recursive: true, force: true });
        }
    });
    
    afterAll(() => {
        // Clean up test artifacts
        if (fs.existsSync(distDir)) {
            fs.rmSync(distDir, { recursive: true, force: true });
        }
    });
    
    describe('Build Script', () => {
        test('build script exists', () => {
            expect(fs.existsSync(buildScript)).toBe(true);
        });
        
        test('build script has valid syntax', () => {
            expect(() => {
                execSync(`node -c "${buildScript}"`, { stdio: 'pipe' });
            }).not.toThrow();
        });
        
        test('package.json exists and is valid', () => {
            expect(fs.existsSync(packageJsonPath)).toBe(true);
            
            const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
            expect(packageJson.name).toBe('omnifocus-claude-extension');
            expect(packageJson.version).toBeDefined();
            expect(packageJson.scripts.build).toBeDefined();
        });
    });
    
    describe('Build Process', () => {
        test('build creates dist directory', () => {
            execSync('npm run build', { 
                cwd: path.join(__dirname, '..'),
                stdio: 'pipe'
            });
            
            expect(fs.existsSync(distDir)).toBe(true);
        });
        
        test('build creates DXT file', () => {
            const dxtFiles = fs.readdirSync(distDir).filter(f => f.endsWith('.dxt'));
            expect(dxtFiles.length).toBeGreaterThan(0);
            
            const dxtFile = path.join(distDir, dxtFiles[0]);
            expect(fs.existsSync(dxtFile)).toBe(true);
            
            const stats = fs.statSync(dxtFile);
            expect(stats.size).toBeGreaterThan(0);
        });
        
        test('DXT file has correct structure', () => {
            const dxtFiles = fs.readdirSync(distDir).filter(f => f.endsWith('.dxt'));
            const dxtFile = path.join(distDir, dxtFiles[0]);
            
            // DXT files are archives, we can verify they exist and have content
            const stats = fs.statSync(dxtFile);
            expect(stats.isFile()).toBe(true);
            expect(stats.size).toBeGreaterThan(1000); // Should be at least 1KB
        });
    });
    
    describe('Manifest Generation', () => {
        test('manifest has correct format', () => {
            const manifestSrcPath = path.join(__dirname, '..', 'src', 'manifest.json');
            
            if (!fs.existsSync(manifestSrcPath)) {
                // Skip if using different manifest structure
                return;
            }
            
            const manifest = JSON.parse(fs.readFileSync(manifestSrcPath, 'utf8'));
            
            expect(manifest.dxt_version).toBe('0.1');
            expect(manifest.name).toBeDefined();
            expect(manifest.version).toBeDefined();
            expect(manifest.server).toBeDefined();
            expect(manifest.server.command).toBeDefined();
            expect(manifest.server.args).toBeDefined();
            expect(Array.isArray(manifest.server.args)).toBe(true);
        });
    });
    
    describe('Version Management', () => {
        test('version is consistent across files', () => {
            const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
            const packageVersion = packageJson.version;
            
            expect(packageVersion).toMatch(/^\d+\.\d+\.\d+$/);
            
            // Check if manifest version matches if it exists
            const manifestPath = path.join(__dirname, '..', 'src', 'manifest.json');
            if (fs.existsSync(manifestPath)) {
                const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
                expect(manifest.version).toBe(packageVersion);
            }
        });
        
        test('build script uses package.json version', () => {
            const buildContent = fs.readFileSync(buildScript, 'utf8');
            expect(buildContent).toContain('package.json');
            expect(buildContent).toContain('version');
        });
    });
    
    describe('File Structure', () => {
        test('required source directories exist', () => {
            const requiredDirs = [
                'src',
                'src/server',
                'src/scripts'
            ];
            
            requiredDirs.forEach(dir => {
                const dirPath = path.join(__dirname, '..', dir);
                expect(fs.existsSync(dirPath)).toBe(true);
            });
        });
        
        test('server entry point exists', () => {
            const serverPath = path.join(__dirname, '..', 'src', 'server', 'index.js');
            expect(fs.existsSync(serverPath)).toBe(true);
        });
    });
});