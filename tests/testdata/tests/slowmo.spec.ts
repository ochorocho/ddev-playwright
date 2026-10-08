import { test } from '@playwright/test';

test('slowmo env', async () => {
  console.log(`SLOWMO=${process.env.PLAYWRIGHT_SLOWMO ?? 'unset'}`);
});
