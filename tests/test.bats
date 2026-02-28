#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  bats_require_minimum_version 1.5.0

  # Override this variable for your add-on:
  export GITHUB_REPO=${GITHUB_REPO:-ddev/ddev-playwright}

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH:-}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p ~/tmp
  export TESTDIR=$(mktemp -d ~/tmp/${PROJNAME}.XXXXXX)
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"

  # Copy test data fixtures (package.json, playwright.config.ts, tests/)
  cp -r "${DIR}/tests/testdata/." "${TESTDIR}/"

  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  echo "Check playwright container is running" >&3
  run ddev exec -s playwright node --version
  assert_success

  echo "Install npm dependencies in playwright container" >&3
  run ddev exec -s playwright npm install
  assert_success

  echo "Check @playwright/test is available" >&3
  run ddev exec -s playwright npx playwright --version
  assert_success

  echo "Check ddev playwright --help works" >&3
  run ddev playwright --help
  assert_success
  assert_output --partial "Playwright for DDEV"
  assert_output --partial "ddev playwright test"
  assert_output --partial "ddev playwright browser"

  echo "Check ddev playwright --version works" >&3
  run ddev playwright --version
  assert_success

  echo "Check playwright container can reach web container" >&3
  run ddev exec -s playwright bash -c "curl -s -o /dev/null -w '%{http_code}' http://web"
  assert_success

  echo "Check ddev playwright test runs successfully" >&3
  run ddev playwright test
  assert_success
  assert_output --partial "passed"

  echo "Check ddev describe shows playwright service" >&3
  run ddev describe
  assert_success
  assert_output --partial "playwright"

  echo "Check UI mode starts via direct exec" >&3
  # Start UI mode in the background using setsid (same technique as the host command)
  ddev exec -s playwright bash -c "setsid npx playwright test --ui --ui-host=0.0.0.0 --ui-port=8077 > /tmp/playwright-ui.log 2>&1 < /dev/null &"
  # Wait for the UI to become available
  local attempts=0
  while ! ddev exec -s playwright curl -s -o /dev/null -w '%{http_code}' http://localhost:8077 2>/dev/null | grep -qE "^(200|302)$"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
      echo "UI mode did not start within 30 seconds" >&3
      ddev exec -s playwright cat /tmp/playwright-ui.log >&3 || true
      false
    fi
    sleep 1
  done

  echo "Kill UI mode after test" >&3
  ddev exec -s playwright bash -c "pkill -f 'playwright.*--ui' 2>/dev/null; exit 0" 2>/dev/null || true

  echo "Remove addon - verify files are cleaned up" >&3
  expected_files=("docker-compose.playwright.yaml" "commands/host/playwright")
  for file in "${expected_files[@]}"; do
    assert_file_exist "$TESTDIR/.ddev/$file"
  done
  run ddev add-on remove playwright
  assert_success
  for file in "${expected_files[@]}"; do
    assert_file_not_exist "$TESTDIR/.ddev/$file"
  done
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  # node_modules may be owned by root (created inside container), use sudo on Linux CI
  [ "${TESTDIR}" != "" ] && (rm -rf "${TESTDIR}" 2>/dev/null || sudo rm -rf "${TESTDIR}")
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}
