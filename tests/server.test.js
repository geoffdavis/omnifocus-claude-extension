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

        test('GTD query tools are listed and list_tasks_by_tag requires a tag', async () => {
            serverProcess = spawn('node', [serverPath]);
            let responseData = '';
            let toolsRequestSent = false;
            let callRequestSent = false;

            await new Promise((resolve, reject) => {
                serverProcess.stdout.on('data', (data) => {
                    responseData += data.toString();
                    if (!toolsRequestSent && responseData.includes('"id":1')) {
                        toolsRequestSent = true;
                        serverProcess.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'tools/list', params: {}, id: 2 }) + '\n');
                    }
                    if (!callRequestSent && responseData.includes('"id":2')) {
                        callRequestSent = true;
                        // Without a tag the tool must answer with a message and never reach OmniFocus
                        const callRequest = {
                            jsonrpc: '2.0', method: 'tools/call',
                            params: { name: 'list_tasks_by_tag', arguments: {} }, id: 5
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

            const responses = responseData.split('\n').filter(l => l.trim()).map(l => JSON.parse(l));
            const toolNames = responses.find(r => r.id === 2).result.tools.map(t => t.name);
            ['list_available_tasks', 'list_tasks_by_tag', 'list_completed_tasks', 'edit_tag', 'reopen_task', 'get_project', 'list_due_soon', 'parse_tasks', 'list_perspectives', 'get_selected_link', 'synchronize', 'clean_up', 'undo', 'list_folders', 'edit_folder', 'delete_folder', 'save_attachment', 'get_selection', 'set_view', 'show_item', 'duplicate_item', 'list_tasks_by_date', 'get_settings', 'create_backup'].forEach(name => {
                expect(toolNames).toContain(name);
            });

            const callResponse = responses.find(r => r.id === 5);
            expect(callResponse.result.content[0].text).toContain('Tag name is required');
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

    describe('Argument types', () => {
        // normalizeArgs is a plain function of the server file; it is taken from the source to test it without OmniFocus
        const source = fs.readFileSync(serverPath, 'utf8');
        const functionText = source.match(/function normalizeArgs[\s\S]*?\n}\n/)[0];
        const normalizeArgs = new Function(`${functionText}\nreturn normalizeArgs;`)();
        const tool = {
            inputSchema: {
                properties: {
                    name: { type: 'string' },
                    tags: { type: 'string' },
                    flagged: { type: 'boolean' },
                    limit: { type: 'number' },
                    status: { type: 'string', enum: ['active', 'on_hold'] }
                }
            }
        };

        test('values of the right type pass unchanged', () => {
            const result = normalizeArgs(tool, { name: 'A', flagged: true, limit: 5, status: 'active' });
            expect(result.args).toEqual({ name: 'A', flagged: true, limit: 5, status: 'active' });
        });

        test('clear meanings are converted: numbers and booleans as text, numeric text as number, text as boolean', () => {
            const result = normalizeArgs(tool, { name: 42, tags: ['a', 'b', 3], flagged: 'TRUE', limit: ' 30 ' });
            expect(result.args).toEqual({ name: '42', tags: 'a, b, 3', flagged: true, limit: 30 });
        });

        test('an enumeration value in another case is the same value, without locale rules', () => {
            expect(normalizeArgs(tool, { status: 'Active' }).args.status).toBe('active');
            expect(normalizeArgs(tool, { status: 'ON_HOLD ' }).args.status).toBe('on_hold');
        });

        test('wrong values are refused with a message naming the parameter, and nothing is passed on', () => {
            const cases = [
                [{ name: { a: 1 } }, 'name', 'expected text'],
                [{ name: ['x'] }, 'name', 'expected text'],
                [{ limit: 'abc' }, 'limit', 'expected a whole number'],
                [{ limit: '1e3' }, 'limit', 'expected a whole number'],
                [{ limit: NaN }, 'limit', 'expected a whole number'],
                [{ limit: [] }, 'limit', 'expected a whole number'],
                [{ limit: 2.5 }, 'limit', 'not a fraction'],
                [{ limit: '2.5' }, 'limit', 'expected a whole number'],
                [{ flagged: 'yes' }, 'flagged', 'expected true or false'],
                [{ flagged: 1 }, 'flagged', 'expected true or false'],
                [{ status: 'finished' }, 'status', 'expected one of: active, on_hold'],
                [{ status: 5 }, 'status', 'expected one of: active, on_hold']
            ];
            for (const [args, key, text] of cases) {
                const result = normalizeArgs(tool, args);
                expect(result.args).toBeUndefined();
                expect(result.problem).toContain(`for ${key} (`);
                expect(result.problem).toContain(text);
                expect(result.problem).toContain('Nothing was done.');
            }
        });

        test('several wrong values are reported together', () => {
            const result = normalizeArgs(tool, { limit: 'x', flagged: 'maybe' });
            expect(result.problem).toContain('Invalid values');
            expect(result.problem).toContain('limit');
            expect(result.problem).toContain('flagged');
        });

        test('null, undefined and unknown parameters are dropped', () => {
            const result = normalizeArgs(tool, { name: null, limit: undefined, bogus: 1, flagged: false });
            expect(result.args).toEqual({ flagged: false });
        });

        test('arguments that are not an object are refused', () => {
            for (const args of ['abc', 5, [1], null]) {
                expect(normalizeArgs(tool, args).problem).toContain('expected an object');
            }
        });

        test('the server refuses a wrong type before anything reaches OmniFocus', async () => {
            const serverProcess = spawn('node', [serverPath]);
            let responseData = '';
            let sent = false;
            await new Promise((resolve, reject) => {
                serverProcess.stdout.on('data', (data) => {
                    responseData += data.toString();
                    if (!sent && responseData.includes('"id":1')) {
                        sent = true;
                        const calls = [
                            { name: 'search_tasks', arguments: { query: 'x', limit: 'abc' } },
                            { name: 'edit_task', arguments: { task_name: 'x', property: 'bogus', value: 'y' } },
                            { name: 'add_task', arguments: { name: { a: 1 } } }
                        ];
                        calls.forEach((params, index) => {
                            serverProcess.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'tools/call', params, id: 10 + index }) + '\n');
                        });
                    }
                    if (responseData.includes('"id":12')) serverProcess.stdin.end();
                });
                serverProcess.on('close', resolve);
                serverProcess.on('error', reject);
                serverProcess.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {} }, id: 1 }) + '\n');
            });
            const responses = responseData.split('\n').filter(l => l.trim()).map(l => JSON.parse(l));
            const text = id => responses.find(r => r.id === id).result.content[0].text;
            expect(text(10)).toContain('limit');
            expect(text(10)).toContain('expected a whole number');
            expect(text(11)).toContain('property');
            expect(text(11)).toContain('expected one of');
            expect(text(12)).toContain('expected text');
            responses.filter(r => r.id >= 10).forEach(r => expect(r.result.content[0].text).toContain('Nothing was done.'));
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
