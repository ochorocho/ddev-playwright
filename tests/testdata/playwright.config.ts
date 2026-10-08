import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  retries: 0,
  workers: 1,
  reporter: 'list',
  use: {
    baseURL: 'http://web',
    trace: 'on-first-retry',
    launchOptions: { slowMo: Number(process.env.PLAYWRIGHT_SLOWMO ?? 0) },
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
});
