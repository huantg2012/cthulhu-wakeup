// Only relevant invariants: descriptor determinism, pixels, isolated cache and
// accepted world/cult preservation. Aesthetic review remains a human task.
const {chromium}=require('/tmp/cthulhu-painted-tools/node_modules/playwright');
const fs=require('node:fs/promises'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
 const directory=path.join(__dirname,'evidence/people-current');
 const actual=JSON.parse(await fs.readFile(path.join(directory,'parameters.json'))),accepted=JSON.parse(await fs.readFile(path.join(__dirname,'evidence/accepted-single/parameters.json')));
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
 try{
  const page=await browser.newPage();await page.goto('http://127.0.0.1:8952/painted/surface/evidence/current/lighting.html');
  const check=await page.evaluate(async({recipe,request,expected})=>{
   const {generateCharacter,characterRecipe}=await import('/painted/surface/people.js');
   const {tide}=await import('/painted/surface/world.js');
   const rebuilt=characterRecipe(recipe.personSeed,tide,recipe.background);
   const one=generateCharacter(recipe).p.albedo.toDataURL(),two=generateCharacter(rebuilt).p.albedo.toDataURL();
   const raw=Uint8Array.from(atob(one.split(',')[1]),c=>c.charCodeAt(0));const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',raw))].map(n=>n.toString(16).padStart(2,'0')).join('');
   const response=await fetch('/api/people',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({request,images:{['p'+recipe.personSeed]:one}})});
   if(!response.ok)throw Error(await response.text());const rendered=(await response.json()).portraits['p'+recipe.personSeed];
   return {sameRecipe:JSON.stringify(rebuilt)===JSON.stringify(recipe),sameInput:one===two,inputMatchesBatch:hash===expected.inputHash,individualOutputMatchesBatch:rendered.hash===expected.hash,individualCacheHit:rendered.cached};
  },{recipe:actual.people[0].recipe,request:actual.context.request,expected:actual.people[0].render});
  check.worldUnchanged=actual.context.world.hash===accepted.world.hash;
  check.cultUnchanged=actual.context.cult.hash===accepted.style.hashes.cult;
  check.acceptedPortraitUnchanged=actual.context.baselinePersonHash===accepted.style.hashes.person;
  check.originalSourceUnchanged=actual.context.world.sourceFingerprint===accepted.world.sourceFingerprint;
  for(const[k,v]of Object.entries(check))assert.equal(v,true,k);
  const result={checks:check,scope:'两次真实二维重绘；单人请求复用批次中的同一内容缓存；当前批次的世界、教团与获认可母版一致。不是审美验收或全组合验证。'};
  await fs.writeFile(path.join(directory,'necessary-checks.json'),JSON.stringify(result,null,2));console.log(result);
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
