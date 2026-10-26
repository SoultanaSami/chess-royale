import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { mkdtemp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// Run against a dedicated in-memory server; never the player's port 3000.
const base = process.env.TEST_BASE_URL || 'http://localhost:3001';
assert.notEqual(new URL(base).port, '3000', 'Use an isolated in-memory test server.');
const screenshots = await mkdtemp(join(tmpdir(), 'chess-war-room-'));
const browser = await chromium.launch();
const errors = [];
try {
  const context = await browser.newContext({ viewport: { width: 393, height: 852 }, isMobile: true, hasTouch: true });
  const page = await context.newPage();
  page.on('pageerror', e => errors.push(e.message));
  page.on('response', r => { if (r.status() >= 400) errors.push(`${r.status()} ${r.url()}`); });
  await page.goto(`${base}/?frame=off&device=war-room-check`);
  await page.waitForFunction(() => window.chessRoyale?.getState().profile);
  await page.evaluate(() => document.fonts.ready);
  assert.equal(await page.locator('.hero img').evaluate(img => img.naturalWidth > 0), true);
  assert.equal(await page.evaluate(() => document.fonts.check('600 16px Cinzel')), true);
  for (const [width, height] of [[320, 640], [360, 640], [393, 852], [768, 1024]]) {
    await page.setViewportSize({ width, height });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, `home overflow ${width}`);
    assert.equal(await page.locator('.screen').evaluate(el => el.scrollWidth <= el.clientWidth), true, `screen overflow ${width}`);
  }
  await page.setViewportSize({ width: 393, height: 852 });
  await page.screenshot({ path: join(screenshots, 'home.png') });
  await page.getByRole('button', { name: 'Deck', exact: true }).click();
  assert.equal(await page.locator('.formation-slot').count(), 16);
  assert.equal(await page.locator('.piece-card').count(), 6);
  assert.equal(await page.locator('.deck-spells .spell-card').count(), 3);
  await page.screenshot({ path: join(screenshots, 'deck.png') });
  await page.locator('.formation-slot[data-role="n"]').first().click();
  assert.equal(await page.locator('.formation-slot.active').count(), 2);
  assert.equal(await page.locator('[data-action="collection-filter"][data-value="n"]').getAttribute('aria-pressed'), 'true');
  assert.equal(await page.locator('.variant-card:not([data-role="n"])').count(), 0);
  const knight = await page.locator('.variant-card:not(.active)').first().getAttribute('data-id');
  await page.locator(`.variant-card[data-id="${knight}"]`).click();
  await page.waitForFunction(id => !window.chessRoyale.getState().deckSaving && window.chessRoyale.getState().profile.deck.n === id, knight);
  await page.locator('[data-action="collection-filter"][data-value="all"]').click();
  // Selecting from "All" must update the card's own role, not the last tapped slot.
  await page.locator('[data-action="variant"][data-id="shadow-king"]').click();
  await page.waitForFunction(() => !window.chessRoyale.getState().deckSaving && window.chessRoyale.getState().profile.deck.k === 'shadow-king');
  assert.equal(await page.evaluate(() => window.chessRoyale.getState().profile.deck.n), knight);
  await page.locator('[data-action="collection-owned"]').click();
  const ids = await page.locator('.variant-card').evaluateAll(cards => cards.map(card => card.dataset.id));
  const owned = await page.evaluate(() => Object.keys(window.chessRoyale.getState().profile.collection));
  assert.ok(ids.length && ids.every(id => owned.includes(id)));
  await page.locator('[data-action="collection-owned"]').click();
  await page.locator('[data-action="collection-filter"][data-value="spell"]').click();
  assert.equal(await page.locator('.variant-card:not([data-role="spell"])').count(), 0);
  const spell = await page.locator('.variant-card:not(.active)').first().getAttribute('data-id');
  await page.locator(`.variant-card[data-id="${spell}"]`).click();
  await page.locator('[data-action="choose-spell"][data-index="1"]').click();
  await page.waitForFunction(id => !window.chessRoyale.getState().deckSaving && window.chessRoyale.getState().profile.spells[1] === id, spell);
  assert.equal(await page.evaluate(() => new Set(window.chessRoyale.getState().profile.spells).size), 3);
  await page.reload();
  await page.waitForFunction(() => window.chessRoyale?.getState().profile);
  assert.equal(await page.evaluate(() => window.chessRoyale.getState().profile.deck.k), 'shadow-king');
  assert.equal(await page.evaluate(() => window.chessRoyale.getState().profile.deck.n), knight);
  assert.equal(await page.evaluate(() => window.chessRoyale.getState().profile.spells[1]), spell);
  await page.getByRole('button', { name: 'Deck', exact: true }).click();
  for (const [width, height] of [[320, 640], [360, 640], [393, 852], [768, 1024]]) {
    await page.setViewportSize({ width, height });
    assert.equal(await page.locator('.screen').evaluate(el => el.scrollWidth <= el.clientWidth), true, `deck overflow ${width}`);
  }
  await page.setViewportSize({ width: 393, height: 852 });
  await page.locator('[data-action="collection-filter"][data-value="n"]').click();
  await page.locator('.collection-table').scrollIntoViewIfNeeded();
  await page.screenshot({ path: join(screenshots, 'collection.png') });
  await page.getByRole('button', { name: 'Start', exact: true }).click();
  await page.locator('[data-action="mode"][data-value="classic"]').click();
  await page.locator('[data-action="difficulty"][data-value="easy"]').click();
  await page.locator('[data-action="battle"]').click();
  await page.locator('[data-square="e2"]').click();
  assert.ok((await page.locator('[data-square="e4"]').getAttribute('class')).includes('legal'));
  await page.locator('[data-square="e4"]').click();
  await page.waitForFunction(() => window.chessRoyale.getState().match.state.version >= 2);
  await page.locator('[data-action="resign"]').click();
  await page.locator('[data-action="confirm-resign"]').click();
  await page.waitForFunction(() => window.chessRoyale.getState().match.state.result);
  await page.locator('[data-action="home"]').click();
  await page.locator('[data-action="mode"][data-value="fantasy"]').click();
  await page.locator('[data-action="battle"]').click();
  await page.locator('[data-square="e1"]').click();
  await page.locator('[data-action="ability"]').click();
  await page.waitForFunction(() => window.chessRoyale.getState().match.state.version >= 2);
  assert.ok(await page.evaluate(() => window.chessRoyale.getState().match.state.board.find(p => p.square === 'e1').effects.some(e => e.kind === 'invisible')));
  assert.deepEqual(errors, []);
  console.log('PASS: 320–768px layouts, 16 slots, role filters, owned filter, cross-role equip, spell replacement, reload persistence, classic move/AI and fantasy ability.');
  console.log(`Screenshots: ${screenshots}`);
} finally { await browser.close(); }
