// Scoped checks only: replay, character isolation, and evidence capture.
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const fs=require('node:fs'),assert=require('node:assert/strict'),path=require('node:path');
(async()=>{
 const b=await chromium.launch({headless:true,executablePath:process.env.CHROME_BIN||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
 const p=await b.newPage({viewport:{width:1700,height:1100}}),errors=[];let body;
 p.on('pageerror',e=>errors.push(e.message));p.on('request',r=>{if(r.url().endsWith('/api/style'))body=r.postData();});
 await p.goto('http://127.0.0.1:8951/painted/');
 await p.waitForFunction(()=>window.studyState||document.querySelector('#status.error'),{timeout:120000});
 const base=await p.evaluate(()=>studyState);assert(base);
 const again=await p.evaluate(q=>generateStudy(q),base.request);assert.deepEqual(again.rawHashes,base.rawHashes);assert.deepEqual(again.hashes,base.hashes);
 fs.writeFileSync('/tmp/cthulhu-painted-replay-body.json',body);
 const other=await p.evaluate(q=>generateStudy({...q,personSeed:1003}),base.request);
 assert.equal(other.hashes.world,base.hashes.world);assert.equal(other.hashes.cult,base.hashes.cult);assert.equal(other.rawHashes.cult,base.rawHashes.cult);assert.equal(other.rawHashes.cultNormals,base.rawHashes.cultNormals);assert.notEqual(other.hashes.person,base.hashes.person);assert.notEqual(other.rawHashes.person,base.rawHashes.person);assert.deepEqual(errors,[]);
 const report={checks:{sameParametersCpuInputsAndFinalImages:true,personSeedPreservesWorldAndCult:true,personSeedChangesVisibleImage:true},base:base.request,baseHashes:base.hashes,replayHashes:again.hashes,other:other.request,otherHashes:other.hashes,errors,note:'API may use matching content cache; fresh independent Godot rendering is recorded separately.'};
 fs.writeFileSync(path.join(__dirname,'evidence/checks.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report.checks));await b.close();
})().catch(e=>{console.error(e);process.exitCode=1;});
