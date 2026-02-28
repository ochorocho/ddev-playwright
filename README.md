# ddev-playwright <!-- omit in toc -->

[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/ochorocho/ddev-playwright/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/<owner>/ddev-playwright/actions/workflows/tests.yml)
[![last commit](https://img.shields.io/github/last-commit/<owner>/ddev-playwright)](https://github.com/ochorocho/ddev-playwright/commits)
[![release](https://img.shields.io/github/v/release/ochorocho/ddev-playwright)](https://github.com/<owner>/ddev-playwright/releases)

A DDEV add-on that provides [Playwright](https://playwright.dev/) end-to-end testing in an isolated Docker container. Uses the official Microsoft Playwright Docker image with all browsers and system dependencies pre-installed, and Playwright's native UI mode for interactive debugging — no VNC required.

- [Installation](#installation)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Accessing Your Web Application from Tests](#accessing-your-web-application-from-tests)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

## Installation

```bash
ddev add-on get ochorocho/ddev-playwright
ddev restart
```

After installation, the `.ddev` directory should be committed to version control.

## Prerequisites

Your project must have `@playwright/test` installed as an npm dependency:

```bash
npm install -D @playwright/test
```

The version of `@playwright/test` in your `package.json` **must match** the Docker image version. The default Docker image is `mcr.microsoft.com/playwright:v1.50.0-noble`, which matches `@playwright/test@1.50.0`.

If you use a different version, update the Docker image accordingly (see [Configuration](#configuration)).

## Usage

| Command | Description |
|---------|-------------|
| `ddev playwright test` | Run all Playwright tests headlessly |
| `ddev playwright test --project=chromium` | Run tests in Chromium only |
| `ddev playwright test -g "login"` | Run tests matching a name pattern |
| `ddev playwright test --reporter=html` | Run tests and generate an HTML report |
| `ddev playwright test --workers=4` | Run tests with 4 parallel workers |
| `ddev playwright test --retries=2` | Retry failed tests up to 2 times |
| `ddev playwright browser` | Launch the interactive Playwright UI mode |
| `ddev playwright show-report` | Open the last HTML test report in your browser |
| `ddev playwright --version` | Show the installed Playwright version |
| `ddev playwright install` | Install browser binaries (usually not needed) |
| `ddev playwright --dir=<path> test` | Run tests from a different directory |
| `ddev playwright --help` | Show all available commands |

Any `npx playwright` command and option can be passed through:

```bash
ddev playwright test --trace on --timeout 60000
ddev playwright test --shard 1/4
ddev playwright test --last-failed
```

### Playwright UI Mode

The `ddev playwright browser` command starts Playwright's native [UI mode](https://playwright.dev/docs/test-ui-mode), which provides:

- Time-travel debugging with DOM snapshots
- Watch mode for automatic re-runs on file changes
- Test filtering by name, project, tags, or status
- Built-in trace viewer with network and console logs
- Locator picker for identifying elements

The UI is accessible at `https://<DDEV_SITENAME>.ddev.site:8078` (shown in `ddev describe`).

### HTML Test Reports

After running tests with `--reporter=html`, view the report with:

```bash
ddev playwright show-report
```

The report is accessible at `https://<DDEV_SITENAME>.ddev.site:9324` (shown in `ddev describe`).

## Accessing Your Web Application from Tests

Inside the Playwright container, your DDEV web application is reachable at `http://web`. Configure this in your `playwright.config.ts`:

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  use: {
    baseURL: 'http://web',
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
    {
      name: 'firefox',
      use: { browserName: 'firefox' },
    },
    {
      name: 'webkit',
      use: { browserName: 'webkit' },
    },
  ],
});
```

## Configuration

### Test Directory

If your Playwright installation is not in the project root (e.g., in `test/Playwright/`), configure the test directory:

```bash
ddev dotenv set .ddev/.env.playwright --playwright-test-dir="test/Playwright"
ddev restart
```

This sets the working directory for all `ddev playwright` commands. The path is relative to your project root. Default: `.` (project root).

### Multiple Playwright Installations

If you have multiple Playwright installations in different directories, use the `--dir` flag to target a specific one per command without changing the persistent configuration:

```bash
ddev playwright --dir=test/Playwright test
ddev playwright --dir=test/E2E test --project=chromium
ddev playwright --dir=test/Playwright browser
```

The `--dir` flag takes priority over the `PLAYWRIGHT_TEST_DIR` setting in `.env.playwright`.

### Docker Image Version

The default image is `mcr.microsoft.com/playwright:v1.50.0-noble`. To use a different version:

```bash
ddev dotenv set .ddev/.env.playwright --playwright-docker-image="mcr.microsoft.com/playwright:v1.50.0-noble"
ddev restart
```

The image version **must match** your installed `@playwright/test` version. Check the available tags at the [Microsoft Artifact Registry](https://mcr.microsoft.com/en-us/artifact/mar/playwright/tags).

### Service Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8077 | HTTP | Playwright UI mode |
| 8078 | HTTPS | Playwright UI mode |
| 9323 | HTTP | HTML test reports |
| 9324 | HTTPS | HTML test reports |

These ports appear automatically in `ddev describe`.

### Shell Access

Access the Playwright container shell for debugging:

```bash
ddev ssh -s playwright
```

View container logs:

```bash
ddev logs -s playwright
```

## Troubleshooting

### Version Mismatch Error

If you see an error like `browserType.launch: Executable doesn't exist`, the Docker image version doesn't match your `@playwright/test` version.

1. Check your installed version: `ddev playwright --version`
2. Update the Docker image to match:
   ```bash
   ddev dotenv set .ddev/.env.playwright --playwright-docker-image="mcr.microsoft.com/playwright:v<YOUR_VERSION>-noble"
   ddev restart
   ```

### Firefox Hangs in Docker

Firefox can occasionally hang inside Docker containers. This is a [known Playwright issue](https://github.com/microsoft/playwright/issues). Workarounds:

- Use Chromium or WebKit as your primary browser for Docker-based testing
- Add a timeout to your Firefox project configuration

### File Permissions

If test artifacts (screenshots, reports) have incorrect permissions, you can fix them with:

```bash
ddev exec -s playwright chown -R $(id -u):$(id -g) /var/www/html/test-results /var/www/html/playwright-report 2>/dev/null || true
```
