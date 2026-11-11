// Actual runtime samples. Limited visual coverage, not a 66-combination test.
const {chromium}=require('/tmp/cthulhu-painted-tools/node_modules/playwright');
const fs=require('node:fs/promises'),path=require('node:path');
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
(async()=>{
 const out=path.resolve(__dirname,'evidence',process.argv[2]||'worlds-current');await fs.mkdir(out,{recursive:true});
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
 try{
  const page=await browser.newPage({viewport:{width:1540,height:1100},deviceScaleFactor:1});
  await page.goto('http://127.0.0.1:8952/painted/surface/evidence/current/lighting.html');
  const config=await (await page.request.get('http://127.0.0.1:8952/api/cult-config')).json();
  const requests=config.templates.map(t=>({template:t.id,seed:1339,style:0,palette:config.cultRules.find(r=>r.archetype===t.archetype).default_palette}));
  requests.push(...[1,2,4,6,7].map(style=>({template:'fire',seed:1339,style,palette:6})),{template:'frozen',seed:1339,style:0,palette:5},{template:'fire',seed:1340,style:0,palette:6});
  const records=process.argv[3]?JSON.parse(await fs.readFile(path.join(out,'manifest.json'),'utf8')).samples:[];
  for(const request of requests){
   if(process.argv[3]&&!process.argv[3].split(',').includes(request.template))continue;
   const result=await page.evaluate(async request=>{const {generateWorld}=await import('/painted/surface/world-runtime.js');const config=await(await fetch('/api/cult-config')).json();return generateWorld(request,config);},request);
   const id=[request.template,request.style,request.palette,request.seed].join('-');
   await fs.writeFile(path.join(out,id+'.json'),JSON.stringify(result.record,null,2));
   for(const key of['world','cult']){const res=await page.request.get(new URL(result.record[key].url,page.url()).href);await fs.writeFile(path.join(out,id+'-'+key+'.png'),await res.body());}
   for(const [key,url]of Object.entries(result.passes))await fs.writeFile(path.join(out,id+'-'+key+'.png'),Buffer.from(url.split(',')[1],'base64'));
   const old=records.findIndex(v=>v.id===id);if(old>=0)records.splice(old,1);records.push({id,...result.record});console.log(id+' '+result.record.timing.totalMs+' ms');
  }
  records.sort((a,b)=>requests.findIndex(q=>[q.template,q.style,q.palette,q.seed].join('-')===a.id)-requests.findIndex(q=>[q.template,q.style,q.palette,q.seed].join('-')===b.id));
  await fs.writeFile(path.join(out,'manifest.json'),JSON.stringify({scope:'11 个原型各一张 sid 0；炎狱同构图六画风；冷原换色板与炎狱换种子。不是 66 组合审美通过。',samples:records},null,2));
  function card(v){const st=config.styles.find(s=>s.sid===v.request.style),pa=config.palettes.find(p=>p.id===v.request.palette),t=config.templates.find(t=>t.id===v.request.template);return `<article><h2>${escape(t.archetype_name)} · ${escape(v.rule.institution)}</h2><div class="pair"><img src="${v.id}-world.png"><img src="${v.id}-cult.png"></div><p>${escape(st.name)} · sid ${st.sid} / ${escape(pa.name)} [${pa.id}] / 世界种子 ${v.request.seed}</p><p>${escape(v.rule.translation)} · ${escape(v.rule.activity)}</p><a href="../../worlds.html?${new URLSearchParams(v.request)}">按此参数重新生成</a> · <a href="${v.id}.json">完整参数</a></article>`;}
  const css='body{margin:0;padding:30px;background:#081015;color:#d5ddd5;font:16px sans-serif}h1{font-size:28px}h2{font-size:21px;margin:16px 0}a{color:#9dc7be}p{line-height:1.7}section{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin:24px 0}article{padding:14px;background:#101c21}.pair{display:grid;grid-template-columns:34% 66%;align-items:center}.pair img{width:100%;display:block}article p{font-size:13px;margin:10px 0}';
  const main=records.filter(v=>v.request.style===0&&v.request.seed===1339&&v.request.palette===v.rule.default_palette),styles=records.filter(v=>v.request.template==='fire'&&v.request.seed===1339),other=records.filter(v=>v.request.seed!==1339||v.request.palette!==v.rule.default_palette);
  const html=`<!doctype html><meta charset="utf-8"><title>世界与教团 · 实际生成样本</title><style>${css}</style><h1>世界与教团 · 实际生成样本</h1><p>图片均由本地生成器实际运行导出。11 个原型可组合 6 种画风；这里是代表性样本，不是全部组合的美术认可。</p><a href="../../worlds.html">返回运行时生成入口</a><p><a href="composition.html">已认可三世界对照</a> · <a href="seven.html">本轮其余七个教团重做对照</a>：菌界、炎狱、冷原的指定样本已认可；本轮七张待审。</p><h2>不同原型的场所</h2><section id="archetypes">${main.map(card).join('')}</section><h2>同一炎狱世界：六种原作画风</h2><section id="styles">${styles.map(card).join('')}</section><h2>色板与种子独立变化</h2><section>${other.map(card).join('')}</section>`;
  await fs.writeFile(path.join(out,'index.html'),html);
  const url='http://127.0.0.1:8952/painted/surface/evidence/'+path.basename(out)+'/index.html';await page.goto(url);await page.locator('img').evaluateAll(imgs=>Promise.all(imgs.map(i=>i.decode())));
  for(let i=0;i<main.length;i+=4){const name='archetypes-'+(1+i/4);await fs.writeFile(path.join(out,name+'.html'),`<!doctype html><meta charset="utf-8"><style>${css}</style><section>${main.slice(i,i+4).map(card).join('')}</section>`);await page.goto(url.replace('index.html',name+'.html'));await page.locator('img').evaluateAll(imgs=>Promise.all(imgs.map(i=>i.decode())));await page.locator('section').screenshot({path:path.join(out,name+'.png')});}
  await page.goto(url);await page.locator('img').evaluateAll(imgs=>Promise.all(imgs.map(i=>i.decode())));if(styles.length)await page.locator('#styles').screenshot({path:path.join(out,'styles.png')});
  console.log('SAVED '+out);
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
