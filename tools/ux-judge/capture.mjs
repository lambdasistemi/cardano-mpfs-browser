// ux-judge capture: drive the MPFS Browser SPA through fixed user journeys at several
// viewports and screenshot each, so the judge step can score the REAL rendered UI at
// mobile / tablet / desktop. Deterministic and headless; point it at prod, a preview,
// or a local build via UX_BASE_URL.
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
import { mkdir, writeFile } from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, "out");
const BASE =
  process.env.UX_BASE_URL ||
  "https://preview.dev.plutimus.com/lambdasistemi/cardano-mpfs-browser/pr-epic-72/";

// Test every journey at these sizes — responsive breakage (overflow, cramped rows,
// wrapped controls) only shows at specific widths.
const VIEWPORTS = [
  { name: "mobile", width: 390, height: 844 },
  { name: "tablet", width: 768, height: 1024 },
  { name: "desktop", width: 1440, height: 900 },
];

// Navigate without waiting on the full wasm `load` event; wait for the Halogen app shell
// to render (the workbench heading + tab strip), and retry — the shared preview box can
// be slow to serve the bundle.
async function ready(page) {
  page.setDefaultTimeout(30_000);
  let lastErr;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      await page.goto(BASE, { waitUntil: "domcontentloaded", timeout: 60_000 });
      await page.getByRole("heading", { name: "Fact workbench" }).waitFor({ state: "visible", timeout: 90_000 });
      await page.getByRole("button", { name: "Tokens" }).waitFor({ state: "visible", timeout: 30_000 });
      return;
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr;
}

async function shot(page, name) {
  await page.waitForTimeout(700);
  await page.screenshot({ path: path.join(OUT, `${name}.png`), fullPage: true });
}

// Each journey is navigation-only; the runner screenshots after, at each viewport.
const journeys = [
  {
    base: "01-initial",
    async steps(page) {
      await ready(page);
    },
  },
  {
    base: "02-tokens",
    async steps(page) {
      await ready(page);
      await page.getByRole("button", { name: "Tokens" }).click();
      await page.getByRole("button", { name: "Load tokens" }).click();
      await page.locator(".token-row").first().waitFor({ timeout: 60_000 });
    },
  },
  {
    base: "03-facts",
    async steps(page) {
      await ready(page);
      await page.getByRole("button", { name: "Tokens" }).click();
      await page.getByRole("button", { name: "Load tokens" }).click();
      await page.locator(".token-row").first().waitFor({ timeout: 60_000 });
      await page.getByRole("button", { name: "Facts" }).click();
      await page.getByRole("button", { name: "Load facts" }).click();
      await page.waitForFunction(
        () => /Verified/.test(document.body.innerText) || document.querySelectorAll(".token-list li").length > 0,
        undefined,
        { timeout: 60_000 },
      );
    },
  },
];

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM || undefined,
  args: ["--no-sandbox"],
});
await mkdir(OUT, { recursive: true });
const results = [];
for (const vp of VIEWPORTS) {
  for (const j of journeys) {
    const name = `${j.base}-${vp.name}`;
    const ctx = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
    const page = await ctx.newPage();
    try {
      await j.steps(page);
      await shot(page, name);
      results.push({ name, ok: true });
      console.log("captured", name);
    } catch (err) {
      results.push({ name, ok: false, error: String(err).slice(0, 200) });
      console.log("FAILED", name, String(err).slice(0, 200));
    }
    await ctx.close();
  }
}
await browser.close();
await writeFile(path.join(OUT, "capture.json"), JSON.stringify({ base: BASE, viewports: VIEWPORTS.map((v) => v.name), results }, null, 2));
console.log(JSON.stringify(results, null, 2));
