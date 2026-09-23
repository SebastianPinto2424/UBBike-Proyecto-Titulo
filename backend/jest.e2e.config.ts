import type { Config } from 'jest';

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  setupFiles: ['<rootDir>/tests/e2e/helpers/entorno-aislado.ts'],
  testMatch: ['<rootDir>/tests/e2e/**/*.e2e.test.ts'],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1'
  },
  transform: {
    '^.+\\.ts$': ['ts-jest', { tsconfig: { module: 'CommonJS' } }]
  },
  testTimeout: 180000,
  maxWorkers: 1
};

export default config;
