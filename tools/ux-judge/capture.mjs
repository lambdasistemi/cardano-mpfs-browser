// ux-judge capture: drive the MPFS Browser SPA through fixed user journeys and
// screenshot each, so the judge step can score the REAL rendered UI. Deterministic and
// headless; point it at prod, a preview, or a local build via UX_BASE_URL.
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

// Navigate without waiting on the full wasm `load` event; wait for the Halogen app
// shell to render (the workbench heading + tab strip), and retry — the shared preview
// box can be slow to serve the bundle.
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

const scenarios = [
  {
    name: "01-initial",
    async run(page) {
      await ready(page);
      await shot(page, "01-initial");
    },
  },
  {
    name: "02-tokens",
    async run(page) {
      await ready(page);
      await page.getByRole("button", { name: "Tokens" }).click();
      await page.getByRole("button", { name: "Load tokens" }).click();
      // token registry populated (a token-row button appears)
      await page.locator(".token-row").first().waitFor({ timeout: 60_000 });
      await shot(page, "02-tokens");
    },
  },
  {
    name: "03-facts",
    async run(page) {
      await ready(page);
      await page.getByRole("button", { name: "Tokens" }).click();
      await page.getByRole("button", { name: "Load tokens" }).click();
      await page.locator(".token-row").first().waitFor({ timeout: 60_000 });
      await page.getByRole("button", { name: "Facts" }).click();
      await page.getByRole("button", { name: "Load facts" }).click();
      // verifications resolved (a "Verified" verdict appears) OR request rows render
      await page.waitForFunction(
        () => /Verified/.test(document.body.innerText) || document.querySelectorAll(".token-list li").length > 0,
        undefined,
        { timeout: 60_000 },
      );
      await shot(page, "03-facts");
    },
  },
];

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM || undefined,
  args: ["--no-sandbox"],
});
await mkdir(OUT, { recursive: true });
const results = [];
for (const s of scenarios) {
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  try {
    await s.run(page);
    results.push({ name: s.name, ok: true });
    console.log("captured", s.name);
  } catch (err) {
    results.push({ name: s.name, ok: false, error: String(err).slice(0, 200) });
    console.log("FAILED", s.name, String(err).slice(0, 200));
  }
  await ctx.close();
}
await browser.close();
await writeFile(path.join(OUT, "capture.json"), JSON.stringify({ base: BASE, results }, null, 2));
console.log(JSON.stringify(results, null, 2));
