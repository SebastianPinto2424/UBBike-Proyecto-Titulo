import { PrismaClient } from '../../src/generated/prisma/client';
import { mockDeep, mockReset, DeepMockProxy } from 'jest-mock-extended';

jest.mock('../../src/configuracion/prisma', () => ({
  __esModule: true,
  prisma: mockDeep<PrismaClient>()
}));

beforeEach(() => {
  mockReset(prismaSimulado);
  prismaSimulado.$transaction.mockImplementation((async (arg: unknown) =>
    typeof arg === 'function'
      ? (arg as (tx: typeof prismaSimulado) => unknown)(prismaSimulado)
      : Promise.all(arg as Promise<unknown>[])) as never);
});

export const prismaSimulado = jest.requireMock('../../src/configuracion/prisma')
  .prisma as DeepMockProxy<PrismaClient>;
