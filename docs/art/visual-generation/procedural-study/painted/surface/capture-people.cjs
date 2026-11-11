// Capture actual runtime evidence; this is not an aesthetic acceptance test.
const {chromium}=require('/tmp/cthulhu-painted-tools/node_modules/playwright');
const fs=require('node:fs/promises'),path=require('node:path');
(async()=>{
 const out=path.resolve(__dirname,'evidence',process.argv[2]||'people-current');await fs.mkdir(out,{recursive:true});
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
 try{
  const page=await browser.newPage({viewport:{width:1500,height:1200},deviceScaleFactor:1});page.on('pageerror',e=>console.error(e));
  await page.goto('http://127.0.0.1:8952/painted/surface/people.html?start='+(process.argv[3]||'0')+'&background='+encodeURIComponent(process.argv[4]||'all'));
  await page.waitForFunction(()=>window.peopleState||document.querySelector('#status').textContent.startsWith('生成失败'),null,{timeout:240000});
  const data=await page.evaluate(()=>({state:window.peopleState,passes:window.peoplePasses,error:document.querySelector('#status').textContent}));if(!data.state)throw Error(data.error);
  await fs.writeFile(path.join(out,'parameters.json'),JSON.stringify(data.state,null,2));
  for(let i=0;i<data.state.people.length;i++){
   const person=data.state.people[i],res=await page.request.get(new URL(person.render.url,page.url()).href);await fs.writeFile(path.join(out,person.id+'.png'),await res.body());
   for(const[k,url]of Object.entries(data.passes[i]))await fs.writeFile(path.join(out,person.id+'-'+k+'.png'),Buffer.from(url.split(',')[1],'base64'));
  }
  await page.locator('#people').screenshot({path:path.join(out,'contact-sheet.png')});
  console.log(JSON.stringify({out,timings:data.state.timings,seeds:data.state.people.map(p=>p.recipe.personSeed),drawMs:data.state.people.map(p=>p.drawMs)}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
