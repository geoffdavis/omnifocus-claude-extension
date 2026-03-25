const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

describe('MCP Server', () => {
    const serverPath = path.join(__dirname, '..', 'src', 'server', 'index.js');

    describe('Server Initialization', () => {
        test('server file exists', () => {
            expect(fs.existsSync(serverPath)).toBe(true);
        });

        test('server has valid JavaScript syntax', () => {
            expect(() => {
                execSync(`node -c "${serverPath}"`, { stdio: 'pipe' });
            }).not.toThrow();
        });
    });

    describe('JSON-RPC Protocol', () => {
        let serverProcess;

        function sendRequest(request) {
            return new Promise((resolve, reject) => {
                serverProcess = spawn('node', [serverPath]);
                let responseData = '';
                let errorData = '';

                serverProcess.stdout.on('data', (data) => {
                    responseData += data.toString();
                });

                serverProcess.stderr.on('data', (data) => {
                    errorData += data.toString();
                });

                serverProcess.on('close', () => {
                    try {
                        const lines = responseData.split('\n').filter(line => line.trim());
                        const responses = lines.map(line => JSON.parse(line));
                        resolve(responses);
                    } catch (error) {
                        reject(new Error(`Failed to parse response: ${responseData}\nError: ${errorData}`));
                    }
                });

                serverProcess.stdin.write(JSON.stringify(request) + '\n');
                serverProcess.stdin.end();
            });
        }

        afterEach(() => {
            if (serverProcess && !serverProcess.killed) {
                serverProcess.kill();
            }
        });

        test('responds to initialize request', async () => {
            const request = {
                jsonrpc: '2.0',
                method: 'initialize',
                params: {
                    protocolVersion: '2024-11-05',
                    capabilities: {}
                },
                id: 1
            };

            const responses = await sendRequest(request);
            expect(responses.length).toBeGreaterThan(0);

            const response = responses[0];
            expect(response.jsonrpc).toBe('2.0');
            expect(response.id).toBe(1);
            expect(response.result).toBeDefined();
            expect(response.result.protocolVersion).toBeDefined();
            expect(response.result.capabilities).toBeDefined();
            expect(response.result.serverInfo).toBeDefined();
            expect(response.result.serverInfo.name).toBe('omnifocus-gtd');
        });

        test('responds to tools/list request', async () => {
            serverProcess = spawn('node', [serverPath]);
            let responseData = '';
            let secondRequestSent = false;

            await new Promise((resolve, reject) => {
                serverProcess.stdout.on('data', (data) => {
                    responseData += data.toString();
                    // Send tools/list once we have the initialize response (id:1)
                    if (!secondRequestSent && responseData.includes('"id":1')) {
                        secondRequestSent = true;
                        const toolsRequest = { jsonrpc: '2.0', method: 'tools/list', params: {}, id: 2 };
                        serverProcess.stdin.write(JSON.stringify(toolsRequest) + '\n');
                        serverProcess.stdin.end();
                    }
                });
                serverProcess.on('close', resolve);
                serverProcess.on('error', reject);

                const initRequest = {
                    jsonrpc: '2.0', method: 'initialize',
                    params: { protocolVersion: '2024-11-05', capabilities: {} }, id: 1
                };
                serverProcess.stdin.write(JSON.stringify(initRequest) + '\n');
            });

            const lines = responseData.split('\n').filter(l => l.trim());
            const responses = lines.map(l => JSON.parse(l));
            const toolsResponse = responses.find(r => r.id === 2);

            expect(toolsResponse).toBeDefined();
            expect(toolsResponse.result).toBeDefined();
            expect(Array.isArray(toolsResponse.result.tools)).toBe(true);
            expect(toolsResponse.result.tools.length).toBeGreaterThan(0);

            toolsResponse.result.tools.forEach(tool => {
                expect(typeof tool.name).toBe('string');
                expect(typeof tool.description).toBe('string');
                expect(tool.inputSchema).toBeDefined();
                expect(tool.inputSchema.type).toBe('object');
            });
        });

        test('tools/call returns valid content shape even when OmniFocus is unavailable', async () => {
            serverProcess = spawn('node', [serverPath]);
            let responseData = '';
            let secondRequestSent = false;

            await new Promise((resolve, reject) => {
                serverProcess.stdout.on('data', (data) => {
                    responseData += data.toString();
                    // Send tools/call once we have the initialize response (id:1).
                    // Use list_inbox (read-only) to avoid creating tasks in OmniFocus.
                    if (!secondRequestSent && responseData.includes('"id":1')) {
                        secondRequestSent = true;
                        const callRequest = {
                            jsonrpc: '2.0', method: 'tools/call',
                            params: { name: 'list_inbox', arguments: {} }, id: 3
                        };
                        serverProcess.stdin.write(JSON.stringify(callRequest) + '\n');
                        serverProcess.stdin.end();
                    }
                });
                serverProcess.on('close', resolve);
                serverProcess.on('error', reject);

                const initRequest = {
                    jsonrpc: '2.0', method: 'initialize',
                    params: { protocolVersion: '2024-11-05', capabilities: {} }, id: 1
                };
                serverProcess.stdin.write(JSON.stringify(initRequest) + '\n');
            });

            const lines = responseData.split('\n').filter(l => l.trim());
            const responses = lines.map(l => JSON.parse(l));
            const callResponse = responses.find(r => r.id === 3);

            expect(callResponse).toBeDefined();
            expect(callResponse.result).toBeDefined();
            expect(Array.isArray(callResponse.result.content)).toBe(true);
            expect(callResponse.result.content.length).toBeGreaterThan(0);
            expect(callResponse.result.content[0].type).toBe('text');
            expect(typeof callResponse.result.content[0].text).toBe('string');
        });

        test('tools/call returns error for unknown tool', async () => {
            serverProcess = spawn('node', [serverPath]);
            let responseData = '';
            let secondRequestSent = false;

            await new Promise((resolve, reject) => {
                serverProcess.stdout.on('data', (data) => {
                    responseData += data.toString();
                    // Send tools/call once we have the initialize response (id:1)
                    if (!secondRequestSent && responseData.includes('"id":1')) {
                        secondRequestSent = true;
                        const callRequest = {
                            jsonrpc: '2.0', method: 'tools/call',
                            params: { name: 'nonexistent_tool', arguments: {} }, id: 4
                        };
                        serverProcess.stdin.write(JSON.stringify(callRequest) + '\n');
                        serverProcess.stdin.end();
                    }
                });
                serverProcess.on('close', resolve);
                serverProcess.on('error', reject);

                const initRequest = {
                    jsonrpc: '2.0', method: 'initialize',
                    params: { protocolVersion: '2024-11-05', capabilities: {} }, id: 1
                };
                serverProcess.stdin.write(JSON.stringify(initRequest) + '\n');
            });

            const lines = responseData.split('\n').filter(l => l.trim());
            const responses = lines.map(l => JSON.parse(l));
            const callResponse = responses.find(r => r.id === 4);

            expect(callResponse).toBeDefined();
            // Unknown tool returns an error response (JSON-RPC error or content with isError)
            const isJsonRpcError = callResponse.error !== undefined;
            const isContentError = callResponse.result && callResponse.result.isError === true;
            expect(isJsonRpcError || isContentError).toBe(true);
        });

        test('handles invalid method gracefully', async () => {
            const request = {
                jsonrpc: '2.0',
                method: 'invalid/method',
                params: {},
                id: 3
            };

            const responses = await sendRequest(request);
            const errorResponse = responses.find(r => r.id === 3);

            expect(errorResponse).toBeDefined();
            expect(errorResponse.error).toBeDefined();
            expect(errorResponse.error.code).toBe(-32601);
            expect(errorResponse.error.message).toContain('Method not found');
        });

        test('handles malformed JSON gracefully', async () => {
            const serverProcess = spawn('node', [serverPath]);
            let responseData = '';

            await new Promise((resolve) => {
                serverProcess.stdout.on('data', (data) => {
                    responseData += data.toString();
                });

                serverProcess.stdin.write('{"invalid json\n');
                serverProcess.stdin.end();

                setTimeout(resolve, 500);
            });

            serverProcess.kill();

            if (responseData) {
                expect(responseData).toContain('error');
                try {
                    const response = JSON.parse(responseData.split('\n')[0]);
                    expect(response.error.code).toBe(-32700);
                } catch {
                    // Server might not respond to malformed JSON
                    expect(responseData.length).toBe(0);
                }
            }
        });
    });

    describe('Tool Coverage', () => {
        test('every tool in the tools array has a corresponding switch case in executeTool', () => {
            const serverContent = fs.readFileSync(serverPath, 'utf8');

            // Extract tool names from the const tools = [...] block in a format-agnostic way
            const toolsBlockMatch = serverContent.match(/const tools\s*=\s*\[(.*?)\n\];/s);
            expect(toolsBlockMatch).not.toBeNull();
            const toolsSection = toolsBlockMatch[1];
            const toolNames = [...toolsSection.matchAll(/\bname:\s*'([^']+)'/g)].map(m => m[1]);

            expect(toolNames.length).toBeGreaterThan(0);

            // Extract all case 'xxx': labels from the switch(name) block
            const caseNames = [...serverContent.matchAll(/case\s+'([^']+)':/g)].map(m => m[1]);

            toolNames.forEach(toolName => {
                expect(caseNames).toContain(toolName);
            });
        });
    });
});
