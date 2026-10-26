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
// hasTouch makes the page report a touchscreen, so the touch controls show.
const page = await browser.newPage({ viewport: { width: 960, height: 600 }, hasTouch: true });
const cdp = await page.context().newCDPSession(page);
const touch = (type, points) =>
  cdp.send("Input.dispatchTouchEvent", { type, touchPoints: points });
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
await page.keyboard.down("KeyQ");
await page.waitForTimeout(150);
await shot("nova");
await page.keyboard.up("KeyQ");
await page.waitForTimeout(3000);
await shot("after");

// Touch: hold the move stick to the right, hold FIRE and drag up to aim, then
// tap LURE and NOVA. Coordinates are the 1280x800 layout scaled to 960x600.
await touch("touchStart", [{ x: 140, y: 440, id: 0 }]);
await touch("touchMove", [{ x: 220, y: 440, id: 0 }]);
await touch("touchStart", [{ x: 220, y: 440, id: 0 }, { x: 820, y: 440, id: 1 }]);
await touch("touchMove", [{ x: 220, y: 440, id: 0 }, { x: 820, y: 370, id: 1 }]);
await page.waitForTimeout(1500);
await shot("touch");
await touch("touchEnd", []);
await touch("touchStart", [{ x: 864, y: 300, id: 2 }]);
await page.waitForTimeout(100);
await touch("touchEnd", []);
await page.waitForTimeout(2500); // let lured camps arrive
await touch("touchStart", [{ x: 720, y: 360, id: 3 }]);
await page.waitForTimeout(150);
await shot("touch-nova");
await touch("touchEnd", []);
await page.waitForTimeout(500);

await browser.close();
server.close();
if (!booted) problems.push("engine never printed its version banner");
for (const p of problems) console.log(`PROBLEM ${p}`);
console.log(problems.length ? `web smoke: ${problems.length} problem(s)` : "web smoke: ok");
process.exit(problems.length ? 1 : 0);
