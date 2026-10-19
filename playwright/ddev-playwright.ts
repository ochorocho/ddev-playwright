// #ddev-generated
// Helpers for `ddev playwright`: auto-pacing, action highlights, step captions, video + trace.
// No runtime import of @playwright/test, so it works with any node_modules location.
import type { Page, PlaywrightTestConfig, TestType } from '@playwright/test';

const watching = () => process.env.PLAYWRIGHT_DDEV_WATCH === '1';
const recording = () => process.env.PLAYWRIGHT_DDEV_RECORD === '1';

/** Wrap defineConfig(): slowMo from PLAYWRIGHT_SLOWMO, video + trace with --record, one worker when watching. */
export function withDdev<T extends PlaywrightTestConfig>(config: T): T {
  const use = { ...(config.use ?? {}) } as NonNullable<PlaywrightTestConfig['use']>;
  const slowMo = Number(process.env.PLAYWRIGHT_SLOWMO ?? 0);
  use.launchOptions = { ...(slowMo > 0 ? { slowMo } : {}), ...(use.launchOptions ?? {}) };
  if (recording()) {
    use.video = 'on';
    use.trace = 'on';
  }
  return { ...config, use, ...(watching() ? { workers: 1 } : {}) };
}

// showActions/showChapter exist since Playwright 1.59
type Screencast = {
  showActions?: () => Promise<unknown>;
  showChapter?: (title: string) => Promise<void>;
};
const screencast = (page: Page): Screencast | undefined => (page as unknown as { screencast?: Screencast }).screencast;

/** Extend the project's `test` so every page highlights actions and shows the test title. */
export function withWatch<T extends TestType<any, any>>(base: T): T {
  return (base as TestType<any, any>).extend({
    page: async ({ page }: { page: Page }, use: (page: Page) => Promise<void>, testInfo: { title: string }) => {
      const sc = screencast(page);
      if ((watching() || recording()) && sc?.showActions && sc.showChapter) {
        await sc.showActions();
        await sc.showChapter(testInfo.title);
      }
      await use(page);
    },
  }) as unknown as T;
}

/** test.step() that also shows the step title over the page. */
export async function step<R>(test: TestType<any, any>, page: Page, title: string, body: () => Promise<R>): Promise<R> {
  if (watching() || recording()) {
    await screencast(page)?.showChapter?.(title);
  }
  return test.step(title, body);
}
