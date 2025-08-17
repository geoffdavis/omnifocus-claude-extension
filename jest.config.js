module.exports = {
    testEnvironment: 'node',
    testMatch: [
        '**/tests/**/*.test.js'
    ],
    collectCoverageFrom: [
        'src/**/*.js',
        'build.js',
        '!node_modules/**',
        '!dist/**',
        '!build/**'
    ],
    coverageDirectory: 'coverage',
    coverageReporters: ['text', 'lcov', 'html'],
    verbose: true,
    testTimeout: 10000
};