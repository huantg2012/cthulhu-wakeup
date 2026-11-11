import {Painter} from './paint.js';
import {drawCult} from './cult.js';
import {drawPerson} from './person.js';
import {familyCult,familyPersonAdornment,familyPerson} from './family.js';
const $=id=>document.getElementById(id), history=new Map();let catalog,last,busy=false;
const hash=async bytes=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(x=>x.toString(16).padStart(2,'0')).join('');
const canvasHash=canvas=>hash(canvas.getContext('2d').getImageData(0,0,canvas.width,canvas.height).data);
function requested(){return {template:$('template').value,style:Number($('style').value),palette:Number($('palette').value),seed:Number($('seed').value),personSeed:Number($('personSeed').value)};}
function status(text,error=false){$('status').textContent=text;document.querySelector('.status').classList.toggle('error',error);}
function lock(value){busy=value;document.body.classList.toggle('busy',value);document.querySelectorAll('form button,form select,form input').forEach(el=>el.disabled=value);}
async function generate(request=requested()){
 if(busy)return;request={...request,personSeed:request.personSeed??Number($('personSeed').value)};const worldRequest={template:request.template,seed:request.seed,style:request.style,palette:request.palette};const start=performance.now();lock(true);last=null;window.studyState=null;status('正在绘制教团与人物；原作星球随后生成…');
 try{
  const palette=catalog.palettes.find(p=>p.id===request.palette), identity=catalog.templates.find(t=>t.id===request.template);
  if(!palette||!identity||!Number.isInteger(request.seed)||request.seed<0||request.seed>999999||!Number.isInteger(request.personSeed)||request.personSeed<0||request.personSeed>999999)throw Error('世界与人物种子均须是0–999999的整数。');
  const config={...request,palette,archetype:identity.archetype};await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
  const pc=new Painter($('cult'),config);pc.ctx.save();pc.ctx.translate(384,395);pc.ctx.scale(1.07,1.07);pc.ctx.translate(-384,-395);const cf=[0,7].includes(config.archetype)?drawCult(pc,config):familyCult(pc,config);pc.ctx.restore();const cm=pc.finish();
  await new Promise(r=>requestAnimationFrame(r));
  const characterConfig={...config,seed:request.personSeed};const pp=new Painter($('person'),characterConfig),pf=[0,7].includes(config.archetype)?drawPerson(pp,characterConfig):familyPerson(pp,characterConfig);if([0,7].includes(config.archetype))pf.features.motif=familyPersonAdornment(pp,characterConfig);const pm=pp.finish();
  const rawHashes={preview:{cult:await canvasHash($('cult')),person:await canvasHash($('person'))},albedo:{cult:await canvasHash(pc.albedo),person:await canvasHash(pp.albedo)},normals:{cult:await canvasHash(pc.normals),person:await canvasHash(pp.normals)}};
  const rawImages={cult:pc.albedo.toDataURL('image/png'),person:pp.albedo.toDataURL('image/png')};
  const normalMaps={cult:pc.normals.toDataURL('image/png'),person:pp.normals.toDataURL('image/png')};
  $('world-name').textContent=identity.world_name;$('cult-name').textContent=identity.cult_name;$('person-name').textContent=`候选求告者 · ${request.personSeed}`;
  const cfeat=cf.features||cf,pfeat=pf.features||pf;
  const poseNames={'open-hand':'伸手求告','hands-gathered':'收手求告','veiled-relic':'裹衣持物','angled-relic':'斜衣持物','sleeves-folded':'敛袖持物','tide-disk':'托举潮历盘','open-calendar':'展开历书','quill-recording':'悬腕记录','sealed-ledger':'持封缄记录本'};
  $('cult-detail').textContent=`原型 ${identity.archetype} · ${identity.description} · ${cfeat.construction||cfeat.purpose}`;
  $('person-detail').textContent=`${poseNames[pfeat.pose]||pfeat.pose} · ${pfeat.costume} · ${pfeat.motif.motif}`;
  status('二维内容已绘制。原作正在生成星球，并处理教团与人物的共同画风…');
  const [response,styleResponse]=await Promise.all([
    fetch('/api/world',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(worldRequest)}),
    fetch('/api/style',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({request:worldRequest,images:rawImages,normals:normalMaps})})]);
  const world=await response.json(),styleResult=await styleResponse.json();
  if(!response.ok)throw Error(world.error||'原作生成失败');
  if(!styleResponse.ok)throw Error(styleResult.error||'原作二维后期失败');
  for(const kind of ['cult','person']){const image=new Image();image.src=styleResult.urls[kind];await image.decode();const canvas=$(kind);canvas.width=image.naturalWidth;canvas.height=image.naturalHeight;canvas.getContext('2d').drawImage(image,0,0);}
  const hashes={cult:await canvasHash($('cult')),person:await canvasHash($('person'))};
  $('world').src=world.url;await $('world').decode();hashes.world=world.hash;
  const key=[request.template,request.seed,request.style,request.palette,request.personSeed].join('|'),old=history.get(key),matches=old?JSON.stringify(old)===JSON.stringify(hashes):null;
  if(matches===false)throw Error('同参数复现不一致，请保留当前参数检查。');history.set(key,hashes);
  last={request,identity,palette,world,styleResult,rawHashes,geometry:{cult:cf,person:pf},renderers:{cult:cm,person:pm},hashes,replayIdentical:matches};
  window.studyState=last;window.history.replaceState(null,'','?'+new URLSearchParams(request));
  $('world-detail').textContent=`原型 ${world.params.archetype} · 原作 ${world.size?.join('×')||'960×960'} · ${world.cached?'同参缓存':'本次生成'}`;
  const style=catalog.styles.find(s=>s.id===request.style);
  $('params').textContent=`${identity.world_name} / ${identity.cult_name} / 候选求告者 ${request.personSeed}　｜　${style?.name||request.style} · ${palette.name} [${palette.id}] · 世界种子 ${request.seed} / 人物种子 ${request.personSeed}　｜　教团 ${cm.shapes} / 人物 ${pm.shapes} 个二维绘制形`;
  $('manifest').textContent=JSON.stringify(last,null,2);$('timing').textContent=`${((performance.now()-start)/1000).toFixed(1)} 秒`;
  status(matches?'同参重绘：世界、教团、人物三张像素指纹均一致。':'已按当前参数生成。可换种子比较结构，或同参重绘验证复现。');
 }catch(e){$('world').removeAttribute('src');status('生成未完成：'+e.message,true);console.error(e);}finally{lock(false);}
}
$('controls').addEventListener('submit',e=>{e.preventDefault();generate();});
$('controls').addEventListener('change',()=>status('参数已修改；点击「生成这一组」更新画面。当前图仍对应下方已生成参数。'));
$('next').onclick=()=>{$('seed').value=(Number($('seed').value)+1)%1000000;generate();};
$('next-person').onclick=()=>{$('personSeed').value=(Number($('personSeed').value)+1)%1000000;generate();};
$('replay').onclick=()=>generate();
$('compare').onclick=()=>{if(last)window.open(last.world.url,'_blank','noopener');};
// Uncompressed ZIP keeps image/parameter export dependency-free and in one user download.
const crc32=bytes=>{let c=-1;for(const b of bytes){c^=b;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^-1)>>>0;};
function pack(files){const parts=[],central=[];let offset=0;const encode=new TextEncoder();for(const [filename,bytes]of files){const name=encode.encode(filename),crc=crc32(bytes);const header=new Uint8Array(30+name.length),h=new DataView(header.buffer);h.setUint32(0,0x04034b50,true);h.setUint16(4,20,true);h.setUint32(14,crc,true);h.setUint32(18,bytes.length,true);h.setUint32(22,bytes.length,true);h.setUint16(26,name.length,true);header.set(name,30);parts.push(header,bytes);const row=new Uint8Array(46+name.length),v=new DataView(row.buffer);v.setUint32(0,0x02014b50,true);v.setUint16(4,20,true);v.setUint16(6,20,true);v.setUint32(16,crc,true);v.setUint32(20,bytes.length,true);v.setUint32(24,bytes.length,true);v.setUint16(28,name.length,true);v.setUint32(42,offset,true);row.set(name,46);central.push(row);offset+=header.length+bytes.length;}const size=central.reduce((n,b)=>n+b.length,0),end=new Uint8Array(22),e=new DataView(end.buffer);e.setUint32(0,0x06054b50,true);e.setUint16(8,files.length,true);e.setUint16(10,files.length,true);e.setUint32(12,size,true);e.setUint32(16,offset,true);return new Blob([...parts,...central,end],{type:'application/zip'});}
$('export').onclick=async()=>{if(!last||busy)return;const files=[];files.push(['world.png',new Uint8Array(await(await fetch(last.world.url)).arrayBuffer())]);for(const kind of ['cult','person']){const blob=await new Promise(r=>$(kind).toBlob(r,'image/png'));files.push([kind+'.png',new Uint8Array(await blob.arrayBuffer())]);}files.push(['parameters.json',new TextEncoder().encode(JSON.stringify(last,null,2))]);const url=URL.createObjectURL(pack(files)),a=document.createElement('a');a.href=url;a.download=`${last.request.template}-${last.request.seed}-${last.request.style}.zip`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
window.generateStudy=async params=>{for(const [key,value]of Object.entries(params))if($(key))$(key).value=String(value);await generate(params);return last;};
try{const response=await fetch('/api/config');catalog=await response.json();for(const [field,items]of [['template',catalog.templates],['palette',catalog.palettes],['style',catalog.styles]]){const select=$(field),value=select.value;select.replaceChildren(...items.map(item=>new Option(item.name||item.world_name,String(item.id))));select.value=value;}const url=new URLSearchParams(location.search);for(const key of ['template','palette','style','seed','personSeed'])if(url.has(key))$(key).value=url.get(key);await generate();}catch(e){status('无法连接生成服务。请用「程序立绘探索.command」启动。'+e.message,true);}
