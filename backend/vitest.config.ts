import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
    globals: false,
    // The local E2E files intentionally exercise the same synthetic trip IDs.
    // Keep them serial when the opt-in database journey gate is enabled.
    fileParallelism: process.env.RUN_E2E_TESTS !== '1',
  },
});
