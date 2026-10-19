import { test as base } from '@playwright/test';
import { step, withWatch } from '../.ddev/playwright/ddev-playwright';

const test = withWatch(base);

test('watch helper', async ({ page }) => {
  await step(test, page, 'Open a page', async () => {
    await page.setContent('<button id="go">Go</button>');
  });
  await step(test, page, 'Click the button', async () => {
    await page.click('#go');
  });
});
