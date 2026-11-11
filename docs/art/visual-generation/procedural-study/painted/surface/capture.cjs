// A small evidence exporter, not an acceptance suite. Open the same runtime
// page a reviewer sees, then save its actual generated outputs and passes.
const {chromium}=require('/tmp/cthulhu-painted-tools/node_modules/playwright');
const fs=require('node:fs/promises'),path=require('node:path');
async function main(){
 const output=path.resolve(__dirname,'evidence',process.argv[2]||'current');await fs.mkdir(output,{recursive:true});
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
 try{
  const page=await browser.newPage({viewport:{width:1660,height:1200},deviceScaleFactor:1});
  page.on('pageerror',e=>console.error('Browser:',e.message));await page.goto('http://127.0.0.1:8952/painted/surface/');
  await page.waitForFunction(()=>window.studyState||document.querySelector('#status')?.textContent.startsWith('生成失败'),{},{timeout:120000});
  const data=await page.evaluate(()=>({state:window.studyState,passes:window.surfacePasses,error:document.querySelector('#status').textContent}));
  if(!data.state)throw Error(data.error);
  for(const[k,url]of Object.entries(data.state.urls)){const response=await page.request.get(new URL(url,page.url()).href);await fs.writeFile(path.join(output,k+'.png'),await response.body());}
  for(const[subject,passes]of Object.entries(data.passes))for(const[k,url]of Object.entries(passes))await fs.writeFile(path.join(output,subject+'-'+k+'.png'),Buffer.from(url.split(',')[1],'base64'));
  await fs.writeFile(path.join(output,'parameters.json'),JSON.stringify(data.state,null,2)+'\n');
  await page.locator('#current').screenshot({path:path.join(output,'triptych.png')});await page.locator('#compare').screenshot({path:path.join(output,'comparison.png')});
  await page.locator('#lighting-compare').screenshot({path:path.join(output,'lighting-comparison.png')});
  console.log(JSON.stringify({output,sourceFingerprint:data.state.world.sourceFingerprint,worldHash:data.state.world.hash,styleCached:data.state.style.cached}));
 }finally{await browser.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
