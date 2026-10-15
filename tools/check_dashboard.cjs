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
    const releasePath = data.roadmap.release_path;
    assert.equal(await page.locator('.stage-card').count(), releasePath.stages.length);
    assert.equal(await page.locator('.stage-current').count(), 1);
    assert.equal(await page.locator('.stage-card[aria-current="step"]').getAttribute('data-stage'), releasePath.current_stage);
    assert.equal(await page.locator('.stat.recorded strong').textContent(), data.roadmap.checkpoint.source.label);
    assert.equal(await page.locator('.delivered-build').count(), data.roadmap.checkpoint.delivered.length);
    for (const stage of releasePath.stages) {
      await page.locator(`[data-stage="${stage.id}"]`).click();
      await page.waitForFunction(id=>document.querySelector('.stage-card[aria-current="step"]')?.dataset.stage===id,stage.id);
      assert.equal(await page.locator('#stage-detail h3').textContent(), stage.title);
      assert.equal(await page.locator('#stage-detail .acceptance li').count(), stage.exit_criteria.length);
      assert.equal(await page.locator('.stage-card[aria-current="step"]').getAttribute('data-stage'), stage.id);
    }
    const withMilestones = releasePath.stages.find(s=>s.milestones.length);
    await page.locator(`[data-stage="${withMilestones.id}"]`).click();
    await page.waitForFunction(id=>document.querySelector('.stage-card[aria-current="step"]')?.dataset.stage===id,withMilestones.id);
    await page.locator('#stage-detail a[href*="milestone="]').first().click();
    await page.locator('.detail-top').waitFor();
    assert.equal(await page.locator('.detail-top .tag').textContent(), withMilestones.milestones[0]);
    await route('#view=roadmap');
    const withGates = releasePath.stages.find(s=>s.gates.length);
    await page.locator(`[data-stage="${withGates.id}"]`).click();
    await page.waitForFunction(id=>document.querySelector('.stage-card[aria-current="step"]')?.dataset.stage===id,withGates.id);
    await page.locator('#stage-detail a[href*="gate="]').first().click();
    const selectedGate = page.locator('#gate-'+withGates.gates[0]);
    await page.waitForFunction(id=>{const el=document.getElementById('gate-'+id);return el?.classList.contains('gate-selected')&&el.getBoundingClientRect().top>=-1&&el.getBoundingClientRect().top<innerHeight},withGates.gates[0]);
    assert.ok(await selectedGate.evaluate(el=>el.classList.contains('gate-selected')));
    assert.ok(await selectedGate.evaluate(el=>el.getBoundingClientRect().top>=-1&&el.getBoundingClientRect().top<innerHeight));
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
      await route('#view=roadmap');
      const boxes = await page.locator('.stage-card').evaluateAll(cards=>cards.map(c=>{const r=c.getBoundingClientRect();return {x:r.x,y:r.y}}));
      if (width===1440) assert.ok(boxes.every(b=>Math.abs(b.y-boxes[0].y)<1),'Desktop stage cards share a row');
      else assert.ok(boxes.every((b,i)=>i===0||b.y>boxes[i-1].y),'Mobile stage cards stack in order');
      await page.screenshot({path:`/tmp/hullwatch-roadmap-${width}.png`,fullPage:true});
      await route('#view=overview');
      await page.screenshot({path:`/tmp/hullwatch-dashboard-${width}.png`,fullPage:true});
    }
    assert.deepEqual(errors,[]);
    assert.deepEqual(external,[]);
    console.log(`PASS: dashboard browser — ${data.documents.length} exact source documents, visual EA stages and links, current source/delivery, gate navigation, search, reader, gallery, safe Markdown, desktop/mobile, offline`);
  } finally { await browser.close(); }
})().catch(error=>{ console.error(error); process.exitCode=1; });
