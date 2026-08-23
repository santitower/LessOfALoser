import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

test("builds the end-to-end wellness control room", async () => {
  await access(new URL("../.next/build-manifest.json", import.meta.url));
  const [app, layout] = await Promise.all([
    readFile(new URL("../app/wellness-app.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
  ]);
  assert.match(layout, /LessOfALoser · Wellness, with receipts/i);
  assert.match(app, /Your signals are fully connected/i);
  assert.match(app, /Import from iPhone/i);
  assert.match(app, /Open retrospective/i);
  assert.match(app, /Model/i);
  assert.match(app, /Report/i);
  assert.doesNotMatch(app + layout, /codex-preview|SkeletonPreview|react-loading-skeleton/i);
});

test("keeps personal data local and has no platform sign-in dependency", async () => {
  const [page, app, layout, packageJson, wellness] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/wellness-app.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../lib/wellness.ts", import.meta.url), "utf8"),
  ]);

  assert.match(app, /Raw HealthKit samples/);
  assert.match(app, /No score or health data is uploaded/);
  assert.match(app, /window\.localStorage/);
  assert.match(app, /General wellness only/);
  assert.match(wellness, /lessofaloser\.wellness-export/);
  assert.match(wellness, /records\.length > 366/);
  assert.match(layout, /og\.png/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  assert.doesNotMatch(page + app + layout, /codex-preview/);
  assert.doesNotMatch(page + app + packageJson, /ChatGPT|signin-with-chatgpt|openai\/sites|sites-vite-plugin/i);
});
