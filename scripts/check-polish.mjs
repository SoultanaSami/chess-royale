import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
const browser=await chromium.launch();
const context=await browser.newContext({viewport:{width:393,height:852}});
const page=await context.newPage();
const errors=[];page.on('pageerror',e=>errors.push(e.message));
try{
 await page.goto('http://localhost:3000/?frame=off&device=polish-test');
 await page.waitForFunction(()=>window.chessRoyale?.getState().profile);
 for(let lesson=1;lesson<=3;lesson++){
  await page.locator('[data-action="tutorial-start"]').click();
  await page.waitForFunction(n=>window.chessRoyale.getState().match?.tutorial?.lesson===n,lesson);
  if(lesson===1){await page.locator('[data-square="e2"]').click();await page.locator('[data-square="e4"]').click();}
  if(lesson===2){await page.locator('[data-action="summon"][data-id="miner"]').click();await page.locator('[data-square="e2"]').click();}
  if(lesson===3){await page.locator('[data-action="cast"][data-id="shield"]').click();await page.locator('[data-square="e1"]').click();}
  await page.waitForFunction(()=>window.chessRoyale.getState().match.tutorial.goalReached&&!window.chessRoyale.getState().busy);
  await page.locator('[data-action="tutorial-finish"]').click();
  await page.waitForFunction(n=>window.chessRoyale.getState().profile.tutorial===n,lesson);
  await page.locator('[data-action="home"]').click();
 }
 await page.locator('[data-action="settings"]').click();
 for(const key of ['colorblind','largeText','battery']){
  await page.locator(`[data-key="${key}"]`).click();
  await page.waitForFunction(k=>window.chessRoyale.getState().profile.settings[k]&&!window.chessRoyale.getState().preferencesSaving,key);
 }
 await page.locator('[data-pref="language"]').selectOption('en');
 await page.waitForFunction(()=>document.documentElement.lang==='en'&&!window.chessRoyale.getState().preferencesSaving);
 await page.getByText('Graphics quality',{exact:true}).waitFor();
 await page.screenshot({path:'test-results/settings-accessibility.png'});
 await page.reload();
 await page.waitForFunction(()=>window.chessRoyale?.getState().profile?.settings?.language==='en');
 assert.ok(await page.evaluate(()=>document.body.classList.contains('battery-mode')));
 assert.equal(await page.evaluate(()=>window.chessRoyale.getState().profile.tutorial),3);
 await page.evaluate(()=>navigator.serviceWorker.ready);
 await context.setOffline(true);await page.reload();await page.locator('[data-action="retry"]').waitFor();
 await context.setOffline(false);await page.locator('[data-action="retry"]').click();await page.waitForFunction(()=>window.chessRoyale.getState().profile);
 assert.deepEqual(errors,[]);
 console.log('PASS: three tutorial games, accessibility, language, persistence, PWA offline shell and recovery.');
}catch(error){console.error(await page.evaluate(()=>{const s=window.chessRoyale?.getState();return {tutorial:s?.profile?.tutorial,match:s?.match?.tutorial,toast:s?.toast,error:s?.bootError};}));throw error;}
finally{await browser.close();}
