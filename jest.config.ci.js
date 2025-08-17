module.exports = {
    ...require('./jest.config.js'),
    reporters: [
        'default'
    ],
    coverageReporters: ['text', 'lcov', 'html', 'json-summary'],
    collectCoverageFrom: [
        'src/**/*.js',
        'build.js',
        '!node_modules/**',
        '!dist/**',
        '!build/**',
        '!coverage/**',
        '!tests/**'
    ],
    coverageThreshold: {
        global: {
            branches: 50,
            functions: 50,
            lines: 60,
            statements: 60
        }
    }
};