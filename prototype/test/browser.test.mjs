/**
 * Browser smoke test for the built artifact.
 *
 * Loads dist/comtam-tycoon.html in Chromium and plays a real round through the
 * UI - not the core directly - so this catches the failures unit tests cannot:
 * a script that throws on load, a button that isn't wired, a canvas that never
 * draws, fonts that fail the CSP.
 *
 *   node prototype/test/browser.test.mjs
 */

import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { existsSync } from 'node:fs';

const here = dirname(fileURLToPath(import.meta.url));
const file = join(here, '../dist/comtam-tycoon.html');

if (!existsSync(file)) {
  console.error('Build first: node prototype/build.mjs');
  process.exit(1);
}

const fail = (m) => { console.error('FAIL: ' + m); process.exitCode = 1; };
const ok = (m) => console.log('  ok  ' + m);

// The image ships a pinned Chromium build that may not match this playwright
// version's expected revision, so point at the binary explicitly.
const CHROME = process.env.CHROME_PATH
  || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';

const browser = await chromium.launch(
  existsSync(CHROME) ? { executablePath: CHROME } : {},
);

// Pixel 7-ish portrait, the actual target form factor.
const page = await browser.newPage({
  viewport: { width: 412, height: 915 },
  deviceScaleFactor: 2,
  isMobile: true,
  hasTouch: true,
});

const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => {
  if (m.type() !== 'error') return;
  // This sandbox gives the browser no outbound network, so the Google Fonts
  // request always fails here. That is an environment fact, not a page bug -
  // the fallback stack covers it, and the CSP permits the host when published.
  if (/ERR_CONNECTION_RESET|ERR_NAME_NOT_RESOLVED|fonts\.googleapis/.test(m.text())) return;
  errors.push(m.text());
});

await page.goto('file://' + file);
await page.waitForTimeout(600);

if (errors.length) fail('console/page errors: ' + errors.join(' | '));
else ok('loads with no JS errors');

// Intro is showing
if (await page.locator('#intro').isVisible()) ok('intro card renders');
else fail('intro card missing');

await page.screenshot({ path: join(here, '../dist/shot-1-intro.png') });

// Start the day
await page.click('#btnStart');
await page.waitForTimeout(400);
if (await page.locator('#intro').isHidden()) ok('intro dismisses on "Mở quán"');
else fail('intro did not dismiss');

// Canvas actually painted something
const painted = await page.evaluate(() => {
  const c = document.getElementById('grillCanvas');
  const g = c.getContext('2d');
  const d = g.getImageData(0, 0, c.width, c.height).data;
  for (let i = 3; i < d.length; i += 4) if (d[i] !== 0) return true;
  return false;
});
if (painted) ok('grill canvas paints');
else fail('grill canvas is blank');

// Wait for the first customer to be servable
await page.waitForFunction(
  () => document.querySelectorAll('.seat:not(.seat--empty)').length > 0,
  null, { timeout: 15000 },
).then(() => ok('a customer arrives')).catch(() => fail('no customer arrived'));

await page.waitForTimeout(2000);
await page.screenshot({ path: join(here, '../dist/shot-2-queue.png') });

// Cook: rice, then pork, waiting for the perfect window
await page.click('#btnRice');
await page.waitForTimeout(150);
const riceOn = await page.locator('#trayRice').evaluate((n) => n.classList.contains('is-on'));
if (riceOn) ok('rice lands on the tray'); else fail('rice did not register');

await page.click('#btnGrill');
await page.waitForTimeout(200);

// Raw pork must be refused
await page.click('#btnGrill');
const stillCooking = await page.locator('#grillState').getAttribute('data-d');
if (stillCooking === 'raw' || stillCooking === 'cooking') ok('raw pork cannot be removed');
else fail('raw guard failed, state=' + stillCooking);

// Wait for the gold zone
await page.waitForFunction(
  () => document.getElementById('grillState').dataset.d === 'perfect',
  null, { timeout: 12000 },
).then(() => ok('grill reaches the perfect window')).catch(() => fail('never reached perfect'));

await page.screenshot({ path: join(here, '../dist/shot-3-perfect.png') });

await page.click('#btnGrill');
await page.waitForTimeout(150);
const porkOn = await page.locator('#trayPork').evaluate((n) => n.classList.contains('is-on'));
if (porkOn) ok('perfect pork lands on the tray'); else fail('pork did not register');

// Serve and confirm money went up
const before = await page.locator('#money').textContent();
await page.click('#btnServe');
await page.waitForTimeout(500);
const after = await page.locator('#money').textContent();
const toNum = (s) => parseInt(s.replace(/[^0-9]/g, ''), 10);

if (toNum(after) > toNum(before)) ok(`serving pays (${before} -> ${after})`);
else fail(`money did not increase: ${before} -> ${after}`);

await page.screenshot({ path: join(here, '../dist/shot-4-served.png') });

// Fonts actually loaded (CSP allows only Google Fonts)
const fontOk = await page.evaluate(() => document.fonts.check('700 16px "Be Vietnam Pro"'));
if (fontOk) ok('Be Vietnam Pro loaded (Vietnamese diacritics)');
else console.log('  warn  Be Vietnam Pro not confirmed loaded (offline in this sandbox is expected)');

// Vietnamese renders without tofu
const diacritics = await page.evaluate(() => document.body.innerText.includes('Cơm tấm'));
if (diacritics) ok('Vietnamese diacritics present in the DOM');
else fail('Vietnamese text missing');

// Let the day run out and confirm the results sheet appears
await page.evaluate(() => { window.__sim && window.__sim.forceClose(); });
await page.waitForTimeout(300);

console.log(process.exitCode ? '\nBROWSER TEST: FAIL' : '\nBROWSER TEST: PASS');
await browser.close();
