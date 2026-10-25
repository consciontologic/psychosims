// Browser-specific transport tests precede production UI acceptance. CI and
// Pages install Playwright Chromium before invoking this shared gate.
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const { chromium } = createRequire(import.meta.url)('playwright');
const root = fileURLToPath(new URL('../', import.meta.url));
const chrome = process.env.CHROMIUM_PATH || process.env.CHROME_EXECUTABLE || chromium.executablePath();
const env = { ...process.env, CHROME_EXECUTABLE: chrome, CHROMIUM_PATH: chrome };

function run(command, args, cwd) {
  const location = spawnSync('pwd', [], { cwd, stdio: 'inherit' });
  if (location.status !== 0) process.exit(location.status || 1);
  const result = spawnSync(command, args, { cwd, env, stdio: 'inherit' });
  if (result.error) console.error(result.error.message);
  if (result.signal) console.error(`Browser verification terminated by ${result.signal}`);
  if (result.status !== 0) process.exit(result.status || 1);
}

run('flutter', ['test', '--platform', 'chrome', 'test/browser_http_client_test.dart'], `${root}app`);
run(process.execPath, [`${root}scripts/web_smoke.mjs`], root);
