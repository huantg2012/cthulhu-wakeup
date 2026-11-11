// Only newly affected invariants; no gameplay or full 66-combination matrix.
const {chromium}=require('/tmp/cthulhu-painted-tools/node_modules/playwright');
const fs=require('node:fs/promises'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
 const out=path.join(__dirname,'evidence/worlds-current'),manifest=JSON.parse(await fs.readFile(path.join(out,'manifest.json'))),accepted=JSON.parse(await fs.readFile(path.join(__dirname,'evidence/accepted-single/parameters.json'))),samples=manifest.samples;
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
 try{
  const page=await browser.newPage();await page.goto('http://127.0.0.1:8952/painted/surface/evidence/current/lighting.html');
  const sample=samples.find(s=>s.id===(process.argv[2]||'frozen-0-4-1339'));
  const check=await page.evaluate(async sample=>{
   const {drawCult,post}=await import('/painted/surface/world-runtime.js');const catalog=await(await fetch('/api/cult-config')).json();
   const one=drawCult(sample.request,catalog).p.albedo.toDataURL(),two=drawCult(sample.request,catalog).p.albedo.toDataURL();
   const raw=Uint8Array.from(atob(one.split(',')[1]),c=>c.charCodeAt(0));const input=[...new Uint8Array(await crypto.subtle.digest('SHA-256',raw))].map(c=>c.toString(16).padStart(2,'0')).join('');
   const output=await post('/api/cult',{request:sample.request,images:{c0:one}});
   return{sameParametersSamePixels:one===two,inputMatchesRecordedSample:input===sample.cult.inputHash,nprMatchesRecordedSample:output.scenes.c0.hash===sample.cult.hash};
  },sample);
  const approved=[];
  for(const id of ['fungal-0-3-1339','fire-0-6-1339','frozen-0-4-1339'])approved.push(JSON.parse(await fs.readFile(path.join(__dirname,'evidence/accepted-worlds-three',id+'.json'))));
  check.approvedThreeUnchanged=await page.evaluate(async records=>{
   const {drawCult,post}=await import('/painted/surface/world-runtime.js'),catalog=await(await fetch('/api/cult-config')).json();
   for(const record of records){const input=drawCult(record.request,catalog).p.albedo.toDataURL();const result=await post('/api/cult',{request:record.request,images:{c0:input}});if(result.scenes.c0.inputHash!==record.cult.inputHash||result.scenes.c0.hash!==record.cult.hash)return false;}return true;
  },approved);
  const baseline=samples.find(s=>s.id==='tide-0-0-1339');
  check.acceptedWorldUnchanged=baseline.world.hash===accepted.world.hash;
  check.acceptedCultInputUnchanged=baseline.cult.inputHash===accepted.style.inputHashes.cult;
  check.acceptedCultOutputUnchanged=baseline.cult.hash===accepted.style.hashes.cult;
  check.originalSourceUnchanged=samples.every(s=>s.world.sourceFingerprint===accepted.world.sourceFingerprint&&s.cult.sourceFingerprint===accepted.world.sourceFingerprint);
  const indices={0:0,1:1,2:2,4:3,6:4,7:5};
  check.sidIndexMapping=samples.every(s=>s.recipe.styleIndex===indices[s.request.style]&&s.world.params.style===indices[s.request.style]&&s.cult.params.style===indices[s.request.style]);
  for(const [key,value]of Object.entries(check))assert.equal(value,true,key);
  const result={checks:check,actualSampleCount:samples.length,actualArchetypes:[...new Set(samples.map(s=>s.recipe.archetype))],actualStyleSids:[...new Set(samples.map(s=>s.request.style))],scope:'指定新样本同参重绘；已认可三世界实际重画及后期指纹一致；原基准与索引核对。不代表 66 组合美术验证。',redrawnSample:sample.id};
  await fs.writeFile(path.join(out,'necessary-checks.json'),JSON.stringify(result,null,2));console.log(result);
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
