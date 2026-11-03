// PNG delivery renderer for the code-native design boards, not a gameplay test.
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const playwrightPath = process.env.PLAYWRIGHT_MODULE || '/Users/yilungao/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright';
const { chromium } = require(playwrightPath);
const root = path.resolve(__dirname, '../..');
const output = path.join(root, 'docs/art/echoes-ui');

(async () => {
  const browser = await chromium.launch({executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless:true});
  const page = await browser.newPage({viewport:{width:1600,height:1300}, deviceScaleFactor:1});
  const report = { scope:'Static design boards only. No input, gameplay, or aesthetic acceptance claim.', boards:[] };
  try {
    for (const name of JSON.parse(fs.readFileSync(path.join(output,'boards.json'))).boards) {
      await page.goto(pathToFileURL(path.join(output,name+'.html')).href);
      await page.evaluate(() => document.fonts.ready);
      const checks = await page.evaluate(() => {
        const screen=document.querySelector('.screen');
        const rects={};
        for(const cls of ['top','index','main','chronicle','dock']) {
          const e=document.querySelector('.'+cls);
          if(e && screen){const r=e.getBoundingClientRect(),s=screen.getBoundingClientRect();rects[cls]=[r.x-s.x,r.y-s.y,r.width,r.height];}
        }
        const overflow=[...document.querySelectorAll('.prayer,.focus-choice,.surface,.dock,.sample-block,.btn,.effect-row,.power,.relic')].filter(e=>e.scrollHeight>e.clientHeight+2||e.scrollWidth>e.clientWidth+2).map(e=>({class:e.className,text:e.innerText.slice(0,80),width:[e.clientWidth,e.scrollWidth],height:[e.clientHeight,e.scrollHeight]}));
        const powers=[...document.querySelectorAll('[data-power]')].map(e=>e.dataset.power);
        return {rects,overflow,powers,bodyWidth:document.body.scrollWidth,bodyHeight:document.body.scrollHeight};
      });
      await page.setViewportSize({width:1600,height:checks.bodyHeight});
      await page.screenshot({path:path.join(output,name+'.png'),fullPage:true});
      report.boards.push({name,...checks});
      console.log(name, checks.overflow.length+' overflow findings', checks.bodyWidth+'×'+checks.bodyHeight);
    }
    fs.writeFileSync(path.join(output,'layout-checks.json'),JSON.stringify(report,null,2)+'\n');
    if(report.boards.some(b=>b.overflow.length||b.bodyWidth!==1600)) process.exitCode=1;
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exitCode=1;});
