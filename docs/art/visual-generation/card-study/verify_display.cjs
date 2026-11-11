// Focused display check; provide PLAYWRIGHT_MODULE if Playwright is not installed locally.
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const browser = await chromium.launch({headless:true});
  try {
    const page = await browser.newPage({viewport:{width:1600,height:1000}});
    const errors=[]; page.on('pageerror',error=>errors.push(error.message));
    await page.goto('file://' + path.join(__dirname,'index.html'));
    await page.evaluate(()=>setStudySkin(0));
    const cards=await page.locator('.study-card-art img').evaluateAll(images=>images.map(image=>{
      const style=getComputedStyle(image), rect=image.getBoundingClientRect(), box=image.parentElement.getBoundingClientRect();
      return {loaded:image.complete&&image.naturalWidth>0,filter:style.filter,mask:style.maskImage,opacity:style.opacity,fit:style.objectFit,inside:rect.left>=box.left-1&&rect.top>=box.top-1&&rect.right<=box.right+1&&rect.bottom<=box.bottom+1};
    }));
    assert.equal(cards.length,3);
    for (const card of cards) {
      assert.equal(card.loaded,true); assert.equal(card.inside,true,'Artwork cropped by container');
      assert.equal(card.filter,'none'); assert.equal(card.mask,'none'); assert.equal(card.opacity,'1'); assert.equal(card.fit,'contain');
    }
    const text=await page.locator('#study-gallery-view').innerText();
    for(const name of ['塔穆什','听潮密会','守历人','1337','溺亡之海','深海靛蓝','ImageGen']) assert(text.includes(name),`Missing provenance: ${name}`);
    await page.screenshot({path:path.join(__dirname,'evidence/v2-triptych.png')});
    await page.evaluate(()=>showStudyReference());
    const refs=await page.locator('.study-reference-grid img').evaluateAll(images=>images.map(image=>{const s=getComputedStyle(image);return {width:image.width,height:image.height,natural:[image.naturalWidth,image.naturalHeight],filter:s.filter,mask:s.maskImage,opacity:s.opacity,fit:s.objectFit};}));
    assert.equal(refs.length,2); assert.deepEqual(refs[0],refs[1]);
    await page.screenshot({path:path.join(__dirname,'evidence/v2-reference.png')});
    assert.deepEqual(errors,[]);
    fs.writeFileSync(path.join(__dirname,'reference-check/display-check.json'),JSON.stringify({viewport:[1600,1000],cards,referenceDisplay:refs,errors},null,2));
    console.log('PASS: 3 artworks loaded without clipping or filters; identities/parameters visible; reference display geometry equal.');
  } finally { await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
