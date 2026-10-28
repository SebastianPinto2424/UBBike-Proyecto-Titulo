import type { Config } from 'jest';

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: ['<rootDir>/tests/**/*.test.ts'],
  testPathIgnorePatterns: ['<rootDir>/tests/e2e/'],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1'
  },
  transform: {
    '^.+\\.ts$': ['ts-jest', { tsconfig: { module: 'CommonJS' } }]
  },
  testTimeout: 60000,
  maxWorkers: '50%',
  clearMocks: true,
  collectCoverageFrom: [
    'src/modulos/**/*.ts',
    'src/comun/**/*.ts',
    'src/tiempo-real/**/*.ts',
    'src/aplicacion.ts',
    'src/configuracion/redis.ts',
    '!src/generated/**'
  ],
  coverageThreshold: {
    global: {
      statements: 87,
      branches: 70,
      functions: 74,
      lines: 86
    }
  }
};

export default config;
