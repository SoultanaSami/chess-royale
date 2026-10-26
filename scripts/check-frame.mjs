import assert from "node:assert/strict";
import { mkdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { chromium } from "@playwright/test";

const baseURL = process.env.BASE_URL || "http://127.0.0.1:3000";
const output = resolve("test-results");
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  viewport: { width: 1440, height: 1080 },
  deviceScaleFactor: 1,
  acceptDownloads: true,
});
const page = await context.newPage();
const errors = [];
page.on("pageerror", (error) => errors.push(error.message));

async function child(id = "one") {
  const element = await page
    .locator(`iframe[src*="device=${id}"]`)
    .elementHandle();
  assert.ok(element, `Device ${id} exists`);
  return element.contentFrame();
}

async function dimensions(frame, width, height) {
  await frame.waitForFunction(
    ({ width, height }) => innerWidth === width && innerHeight === height,
    { width, height },
  );
  assert.deepEqual(await frame.evaluate(() => [innerWidth, innerHeight]), [
    width,
    height,
  ]);
}

try {
  await page.goto(baseURL, { waitUntil: "domcontentloaded" });
  await page.waitForFunction(
    () => window.chessRoyaleFrame?.getState()?.devices.length === 1,
  );
  const first = await child();
  await dimensions(first, 393, 852);
  await first.waitForFunction(
    () => window.chessRoyale?.getState()?.profile?.id,
  );
  const firstProfile = await first.evaluate(
    () => window.chessRoyale.getState().profile.id,
  );

  for (const [id, width, height] of [
    ["pixel", 412, 915],
    ["small", 360, 640],
    ["tablet", 768, 1024],
    ["iphone", 393, 852],
  ]) {
    await page.locator(`[data-preset="${id}"]`).click();
    await dimensions(first, width, height);
    assert.equal(
      await page.locator(`[data-preset="${id}"]`).getAttribute("aria-pressed"),
      "true",
    );
  }
  await page.locator('[data-action="rotate"]').click();
  await dimensions(first, 852, 393);
  await page.locator('[data-action="rotate"]').click();
  await dimensions(first, 393, 852);

  await page.locator('[data-action="touch"]').click();
  assert.equal(
    await page.evaluate(() => window.chessRoyaleFrame.getState().touchEnabled),
    false,
  );
  await page.locator('[data-action="touch"]').click();
  assert.equal(
    await page.evaluate(() => window.chessRoyaleFrame.getState().touchEnabled),
    true,
  );

  await page.locator('[data-action="second"]').click();
  await page.waitForFunction(
    () => window.chessRoyaleFrame.getState().devices.length === 2,
  );
  const second = await child("two");
  await second.waitForFunction(
    () => window.chessRoyale?.getState()?.profile?.id,
  );
  await dimensions(second, 393, 852);
  const secondProfile = await second.evaluate(
    () => window.chessRoyale.getState().profile.id,
  );
  assert.notEqual(
    firstProfile,
    secondProfile,
    "The second device must use its own account",
  );

  await page.locator('[data-network="offline"]').click();
  await first.locator(".network-banner").waitFor({ state: "visible" });
  await second.locator(".network-banner").waitFor({ state: "visible" });
  assert.equal(
    await page.evaluate(() => window.chessRoyaleFrame.getState().network),
    "offline",
  );
  await page.locator('[data-network="slow"]').click();
  assert.equal(
    await page.evaluate(() => window.chessRoyaleFrame.getState().network),
    "slow",
  );
  await page.locator('[data-network="normal"]').click();
  await first.locator(".network-banner").waitFor({ state: "hidden" });
  await second.locator(".network-banner").waitFor({ state: "hidden" });

  await page.locator(".lab-remove-device").click();
  assert.equal(await page.locator("iframe").count(), 1);
  await Promise.all([
    page.waitForEvent("framenavigated", (frame) => frame === first),
    page.locator('[data-action="reload"]').click(),
  ]);
  await first.waitForFunction(
    () => window.chessRoyale?.getState()?.profile?.id,
  );
  assert.equal(
    await first.evaluate(() => window.chessRoyale.getState().profile.id),
    firstProfile,
    "Reload preserves the account",
  );

  await page.screenshot({
    path: resolve(output, "device-lab.png"),
    fullPage: true,
  });
  const downloaded = page.waitForEvent("download", { timeout: 30000 });
  await page.locator('[data-action="screenshot"]').click();
  const download = await downloaded;
  const pngFile = resolve(output, "device-screenshot.png");
  await download.saveAs(pngFile);
  const png = await readFile(pngFile);
  assert.deepEqual(
    [...png.subarray(0, 8)],
    [137, 80, 78, 71, 13, 10, 26, 10],
    "Screenshot is a PNG",
  );
  assert.ok(png.length > 20000, "Screenshot contains rendered app content");
  assert.equal(png.readUInt32BE(16), 786, "Screenshot uses 2× native width");
  assert.equal(png.readUInt32BE(20), 1704, "Screenshot uses 2× native height");

  await page.goto(`${baseURL}/?frame=off`, { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.chessRoyale?.getState()?.profile?.id);
  assert.equal(
    await page.locator(".lab-root").count(),
    0,
    "frame=off bypasses the simulator",
  );
  assert.deepEqual(errors, [], "No uncaught JavaScript errors");
  console.log(
    "PASS: frame presets, rotation, touch toggle, independent accounts, network modes, reload, PNG screenshot, frame=off.",
  );
} finally {
  await context.close();
  await browser.close();
}
