const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

describe('Build System', () => {
    const buildScript = path.join(__dirname, '..', 'build.js');
    const packageJsonPath = path.join(__dirname, '..', 'package.json');
    const distDir = path.join(__dirname, '..', 'dist');
    
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
        
        test('build creates MCPB file', () => {
            const mcpbFiles = fs.readdirSync(distDir).filter(f => f.endsWith('.mcpb'));
            expect(mcpbFiles.length).toBeGreaterThan(0);
            
            const mcpbFile = path.join(distDir, mcpbFiles[0]);
            expect(fs.existsSync(mcpbFile)).toBe(true);
            
            const stats = fs.statSync(mcpbFile);
            expect(stats.size).toBeGreaterThan(0);
        });
        
        test('MCPB file has correct structure', () => {
            const mcpbFiles = fs.readdirSync(distDir).filter(f => f.endsWith('.mcpb'));
            const mcpbFile = path.join(distDir, mcpbFiles[0]);
            
            // MCPB files are archives, we can verify they exist and have content
            const stats = fs.statSync(mcpbFile);
            expect(stats.isFile()).toBe(true);
            expect(stats.size).toBeGreaterThan(1000); // Should be at least 1KB
        });
    });
    
    describe('Manifest Generation', () => {
        test('manifest template has correct format', () => {
            const manifestSrcPath = path.join(__dirname, '..', 'src', 'manifest-template.json');

            expect(fs.existsSync(manifestSrcPath)).toBe(true);

            const manifest = JSON.parse(fs.readFileSync(manifestSrcPath, 'utf8'));

            expect(manifest.manifest_version).toBe('0.3');
            expect(manifest.name).toBeDefined();
            expect(manifest.server).toBeDefined();
            expect(manifest.server.type).toBe('node');
            expect(manifest.server.entry_point).toBeDefined();
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