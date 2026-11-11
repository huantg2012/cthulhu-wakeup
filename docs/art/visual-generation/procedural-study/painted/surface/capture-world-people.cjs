const {chromium}=require('/tmp/cthulhu-painted-tools/node_modules/playwright');
const fs=require('node:fs/promises'),path=require('node:path');
(async()=>{
 const out=path.resolve(__dirname,'evidence',process.argv[2]||'world-people-current');await fs.mkdir(out,{recursive:true});
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
 try{
  const page=await browser.newPage({viewport:{width:1640,height:1200},deviceScaleFactor:1});page.on('pageerror',e=>console.error(e));
  await page.goto('http://127.0.0.1:8952/painted/surface/world-people.html?batch='+(process.argv[3]||0));
  await page.waitForFunction(()=>window.worldPeopleState||document.querySelector('#status').textContent.startsWith('生成失败'),null,{timeout:300000});
  const data=await page.evaluate(()=>({state:window.worldPeopleState,passes:window.worldPeoplePasses,error:document.querySelector('#status').textContent}));if(!data.state)throw Error(data.error);
  await fs.writeFile(path.join(out,'parameters.json'),JSON.stringify(data.state,null,2));
  for(let g=0;g<data.state.groups.length;g++){
   const group=data.state.groups[g];
   for(const name of['world','cult']){const response=await page.request.get(new URL(group.world[name].url,page.url()).href);await fs.writeFile(path.join(out,group.world.request.template+'-'+name+'.png'),await response.body());}
   for(let i=0;i<group.people.length;i++){
    const person=group.people[i],res=await page.request.get(new URL(person.render.url,page.url()).href);await fs.writeFile(path.join(out,person.id+'.png'),await res.body());
    for(const[k,url]of Object.entries(data.passes[g][i]))await fs.writeFile(path.join(out,person.id+'-'+k+'.png'),Buffer.from(url.split(',')[1],'base64'));
   }
   await page.locator('section').nth(g).screenshot({path:path.join(out,group.world.request.template+'-sheet.png')});
  }
  await page.locator('#groups').screenshot({path:path.join(out,'contact-sheet.png')});
  console.log(JSON.stringify({out,durationMs:data.state.durationMs,seeds:data.state.groups.map(g=>g.people.map(p=>({seed:p.recipe.personSeed,outfit:p.recipe.construction,gender:p.features.genderExpression,ms:p.drawMs})))}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
