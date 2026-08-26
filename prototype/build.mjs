/**
 * Inlines core.js, app.js and styles.css into a single self-contained HTML file.
 *
 * One file is a hard requirement for the published artifact: the CSP blocks
 * every external host except Google Fonts, so there is nothing to fetch from.
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const src = join(here, 'src');
const outDir = join(here, 'dist');
const outFile = join(outDir, 'comtam-tycoon.html');

const read = (f) => readFileSync(join(src, f), 'utf8');

const styles = read('styles.css');
const core = read('core.js');
const app = read('app.js');
let template = read('template.html');

// Fold core.js into app.js: strip the import of './core.js' and concatenate,
// since a single inline module cannot resolve a relative specifier.
const coreBody = core
  .replace(/^export\s+/gm, '')            // drop export keywords
  .trim();

const appBody = app
  .replace(/^import\s+\{[\s\S]*?\}\s+from\s+'\.\/core\.js';\s*$/m, '')
  .trim();

const bundle = `// --- core.js ---\n${coreBody}\n\n// --- app.js ---\n${appBody}\n`;

template = template
  .replace('/*{{STYLES}}*/', () => styles)
  .replace('/*{{APP}}*/', () => bundle);

// Guard against a placeholder silently surviving into the output.
for (const marker of ['{{STYLES}}', '{{APP}}']) {
  if (template.includes(marker)) {
    console.error(`error: placeholder ${marker} was not replaced`);
    process.exit(1);
  }
}

mkdirSync(outDir, { recursive: true });
writeFileSync(outFile, template, 'utf8');

const kb = (Buffer.byteLength(template, 'utf8') / 1024).toFixed(1);
console.log(`Built ${outFile}  (${kb} KB, self-contained)`);
