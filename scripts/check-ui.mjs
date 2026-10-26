import { chromium } from "@playwright/test";
import assert from "node:assert/strict";
const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: 360, height: 640 },
  isMobile: true,
  hasTouch: true,
});
const page = await context.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(e.message));
try {
  await page.goto("http://localhost:3000/?frame=off&device=ui-test");
  await page.waitForFunction(() => window.chessRoyale?.getState().profile);
  await page.locator('[data-action="mode"][data-value="classic"]').click();
  await page.locator('[data-action="difficulty"][data-value="easy"]').click();
  await page.locator('[data-action="battle"]').click();
  await page.locator('[data-square="e2"]').click();
  assert.equal(
    await page
      .locator('[data-square="e4"]')
      .getAttribute("class")
      .then((c) => c.includes("legal")),
    true,
  );
  await page.locator('[data-square="e4"]').click();
  await page.waitForFunction(
    () => window.chessRoyale.getState().match.state.version >= 2,
  );
  assert.equal(
    await page.evaluate(() => window.chessRoyale.getState().match.state.turn),
    "w",
  );
  await page.screenshot({ path: "test-results/mobile-game.png" });
  assert.ok(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  );
  await page.locator('[data-action="resign"]').click();
  await page.locator('[data-action="confirm-resign"]').click();
  await page.waitForFunction(
    () => window.chessRoyale.getState().match.state.result,
  );
  await page.locator('[data-action="home"]').click();
  await page.locator('[data-action="tab"][data-tab="deck"]').click();
  await page.locator('[data-action="variant"][data-id="shadow-king"]').click();
  await page.waitForFunction(() => !window.chessRoyale.getState().deckSaving);
  await page.locator('[data-action="tab"][data-tab="home"]').click();
  await page.locator('[data-action="mode"][data-value="fantasy"]').click();
  await page.locator('[data-action="battle"]').click();
  await page.locator('[data-square="e1"]').click();
  await page.locator('[data-action="ability"]').click();
  await page.waitForFunction(
    () => window.chessRoyale.getState().match.state.version >= 2,
  );
  assert.ok(
    await page.evaluate(() =>
      window.chessRoyale
        .getState()
        .match.state.board.find((p) => p.square === "e1")
        .effects.some((e) => e.kind === "invisible"),
    ),
  );
  assert.deepEqual(errors, []);
  console.log(
    "PASS: 360×640 touch game, legal previews, AI response, resign, deck persistence, untargeted ability.",
  );
} finally {
  await browser.close();
}
