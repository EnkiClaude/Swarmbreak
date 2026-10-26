// Loads the exported web build in headless Chrome, plays a few seconds of
// scripted input and prints what happened, so a CI log shows whether the
// browser build actually boots and renders.
//
// Usage: node tools/web_smoke.mjs <build dir>
// Needs playwright-core and an installed Google Chrome. Screenshots are
// printed into the log as base64 JPEG between SCREENSHOT markers, and saved
// next to the build as smoke-*.jpg.
import { chromium } from "playwright-core";
import { createServer } from "node:http";
import { readFile, writeFile } from "node:fs/promises";
import { extname, join } from "node:path";

const root = process.argv[2] ?? "build/web";
const types = {
  ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm",
  ".pck": "application/octet-stream", ".png": "image/png", ".svg": "image/svg+xml",
};
const server = createServer(async (req, res) => {
  const path = join(root, decodeURIComponent(new URL(req.url, "http://x").pathname));
  try {
    const body = await readFile(path.endsWith("/") ? join(path, "index.html") : path);
    res.writeHead(200, { "Content-Type": types[extname(path)] ?? "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end();
  }
});
await new Promise((ok) => server.listen(8060, ok));

const args = ["--enable-unsafe-swiftshader", "--use-angle=swiftshader", "--ignore-gpu-blocklist"];
// Prefer the runner's Google Chrome; fall back to Playwright's own Chromium.
const browser = await chromium.launch({ channel: "chrome", args })
  .catch(() => chromium.launch({ args }));
const page = await browser.newPage({ viewport: { width: 960, height: 600 } });
const problems = [];
let booted = false;
page.on("console", (msg) => {
  const text = msg.text();
  console.log(`[console.${msg.type()}] ${text}`);
  if (text.includes("Godot Engine v")) booted = true;
  if (msg.type() === "error" || /SCRIPT ERROR|Parse Error|^ERROR:/.test(text)) problems.push(text);
});
page.on("pageerror", (err) => problems.push(`page error: ${err.message}`));

async function shot(name) {
  const jpg = await page.screenshot({ type: "jpeg", quality: 45 });
  await writeFile(join(root, `smoke-${name}.jpg`), jpg);
  console.log(`SCREENSHOT_BEGIN ${name}`);
  const b64 = jpg.toString("base64");
  for (let i = 0; i < b64.length; i += 4000) console.log(b64.slice(i, i + 4000));
  console.log(`SCREENSHOT_END ${name}`);
}

await page.goto("http://localhost:8060/index.html");
await page.waitForTimeout(12000);
await shot("boot");
await page.mouse.click(480, 300); // focus the canvas
await page.keyboard.down("KeyD");
await page.waitForTimeout(1500);
await page.keyboard.up("KeyD");
await page.waitForTimeout(6000); // let the swarm close in
await page.keyboard.down("Space");
await page.waitForTimeout(150);
await shot("nova");
await page.keyboard.up("Space");
await page.waitForTimeout(3000);
await shot("after");

await browser.close();
server.close();
if (!booted) problems.push("engine never printed its version banner");
for (const p of problems) console.log(`PROBLEM ${p}`);
console.log(problems.length ? `web smoke: ${problems.length} problem(s)` : "web smoke: ok");
process.exit(problems.length ? 1 : 0);
