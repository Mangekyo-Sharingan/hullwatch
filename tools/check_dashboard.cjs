// Run with NODE_PATH pointing to an installed playwright-core package.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium} = require('playwright-core');
(async () => {
  const root = path.resolve(__dirname, '..');
  const target = process.argv[2] || path.join(root, 'docs/dashboard/index.html');
  const browser = await chromium.launch({headless:true});
  try {
    const page = await browser.newPage({viewport:{width:1440,height:1000}});
    const errors = [], external = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('request', request => { if (/^https?:/.test(request.url())) external.push(request.url()); });
    await page.goto(pathToFileURL(target).href);
    const data = await page.locator('#dashboard-data').textContent().then(JSON.parse);
    for (const doc of data.documents) assert.equal(doc.content, fs.readFileSync(path.join(root, doc.path), 'utf8'), doc.path);
    async function route(hash) { await page.evaluate(hash => location.hash=hash, hash); await page.waitForTimeout(100); }
    await page.locator('[data-view="roadmap"]').click();
    await page.locator('.milestone').first().waitFor();
    assert.equal(await page.locator('.milestone').count(), data.roadmap.milestones.length);
    await route('#view=roadmap&milestone=ART');
    assert.equal(await page.locator('.task-row').count(), data.roadmap.milestones.find(m=>m.id==='ART').tasks.length);
    await route('#view=library&doc=docs%2FPRODUCTION_SPEC.md');
    assert.ok(await page.locator('.document table').count());
    await page.locator('[data-action="source"]').click();
    assert.equal(await page.locator('.raw-source').textContent(), fs.readFileSync(path.join(root,'docs/PRODUCTION_SPEC.md'),'utf8'));
    await page.locator('#search').fill('Xenonite');
    await page.waitForTimeout(250);
    assert.ok(await page.locator('.doc-item').count());
    await route('#view=gallery');
    assert.equal(await page.locator('.image-card').count(), data.media.length);
    await page.locator('.image-card').first().click();
    assert.ok(await page.locator('#image-dialog').evaluate(d=>d.open));
    await page.waitForFunction(()=>document.getElementById('image-full').naturalWidth>0);
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('#image-dialog').evaluate(d=>d.open),false);
    await page.evaluate(()=>{DOCS.set('unsafe.md',{path:'unsafe.md',title:'Safety check',category:'Checks',format:'md',content:'<img src=x onerror="window.bad=true">\n\n[unsafe](javascript:alert(1))'});});
    await route('#view=library&doc=unsafe.md');
    assert.equal(await page.locator('.document img').count(),0);
    assert.equal(await page.locator('.document a[href^="javascript:"]').count(),0);
    for (const width of [1440,390]) {
      await page.setViewportSize({width,height:844});
      for (const view of ['overview','roadmap','library','gallery','activity']) {
        await route('#view='+view+(view==='library'?'&doc=docs%2FPRODUCTION_SPEC.md':''));
        assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),`${width}px ${view} overflow`);
      }
      await route('#view=overview');
      await page.screenshot({path:`/tmp/hullwatch-dashboard-${width}.png`,fullPage:true});
    }
    assert.deepEqual(errors,[]);
    assert.deepEqual(external,[]);
    console.log(`PASS: dashboard browser — ${data.documents.length} exact source documents, roadmap, search, reader, gallery, safe Markdown, desktop/mobile, offline`);
  } finally { await browser.close(); }
})().catch(error=>{ console.error(error); process.exitCode=1; });
