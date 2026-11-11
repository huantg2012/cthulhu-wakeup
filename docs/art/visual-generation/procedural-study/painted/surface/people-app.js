import {tide} from './world.js';
import {portrait} from './portrait.js';
import {sanctuary} from './sanctuary.js';
import {recipeForId,characterRecipe,generateCharacter,PEOPLE_VERSION} from './people.js';
const $=id=>document.getElementById(id),request={template:'tide',seed:1339,palette:0,style:0};
let busy=false,context=null,current=[],selected=0,last=null,catalog=null;
const supplied=new URLSearchParams(location.search).get('start');if(supplied!==null)$('start').value=supplied;
async function api(path,body){const r=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const data=await r.json();if(!r.ok)throw Error(data.error||r.statusText);return data;}
const pause=()=>new Promise(r=>setTimeout(r,20));
function controls(value){busy=value;$('background').disabled=value;for(const id of['generate','next','repeat','single'])$(id).disabled=value;$('download').disabled=value||!last;}
function showImage(){const item=current[selected];$('inspection-image').src=$('pass').value==='final'?item.render.url:item.passes[$('pass').value];}
function inspect(index){selected=index;$('inspection-title').textContent=`人物 ${current[index].id} · 种子 ${current[index].recipe.personSeed}`;$('pass').value='final';showImage();$('inspection').showModal();}
async function worldContext(){
 const cult=sanctuary(request.seed),person=portrait(1339,request.seed),images={},normals={};
 for(const[k,v]of Object.entries({cult,person})){images[k]=v.p.albedo.toDataURL();normals[k]=v.p.normals.toDataURL();}
 const [world,style]=await Promise.all([api('/api/world',request),api('/api/style',{request,images,normals})]);
 $('world').src=world.url;$('cult').src=style.urls.cult;
 await Promise.all([$('world').decode(),$('cult').decode()]);
 context={request,world,cult:{url:style.urls.cult,hash:style.hashes.cult,inputHash:style.inputHashes.cult},baselinePersonHash:style.hashes.person};
 $('world-state').textContent='世界与教团由固定参数生成；下方换人时保持不变。';
}
async function generate(single=false){
 if(busy)return;const start=Number($('start').value),seed=Number($('single-seed').value);
 if(!Number.isInteger(start)||start<0||start>1e9||single&&(!Number.isInteger(seed)||seed<0||seed>0xffffffff)){$('status').textContent='请输入范围内的整数。';return;}
 controls(true);window.peopleState=null;last=null;const started=performance.now();
 try{
  if(!catalog){const r=await fetch('/api/people-contexts');if(!r.ok)throw Error('无法读取祈求背景');catalog=await r.json();for(const row of catalog.contexts){const option=document.createElement('option');option.value=row.caseId;option.textContent=row.role+' · '+row.title;$('background').append(option);}const requested=new URLSearchParams(location.search).get('background');if(catalog.contexts.some(row=>row.caseId===requested))$('background').value=requested;}
  if(!context){await pause();await worldContext();}
  current=[];$('people').replaceChildren();const count=single?1:6,images={};
  for(let i=0;i<count;i++){
   $('status').textContent=`正在生成第 ${i+1} / ${count} 人的结构、衣料与受光…`;await pause();
   const id=single?'指定种子':String(start+i),background=$('background').value==='all'?catalog.contexts[(single?seed:start+i)%catalog.contexts.length]:catalog.contexts.find(row=>row.caseId===$('background').value),recipe=single?characterRecipe(seed,tide,background):recipeForId(id,tide,background),t=performance.now(),item=generateCharacter(recipe);
   const passes={material:item.p.material.toDataURL(),form:item.p.form.toDataURL(),lit:item.p.albedo.toDataURL()},key='p'+recipe.personSeed;
   images[key]=passes.lit;current.push({id,recipe,key,features:item.features,passes,drawMs:Math.round(performance.now()-t)});
   const figure=document.createElement('figure');figure.className='pending';figure.innerHTML='<img alt="正在绘制的人物"><figcaption></figcaption>';figure.querySelector('img').src=passes.lit;
   figure.querySelector('figcaption').textContent=`人物 ${id} · 表面已绘制，等待原作 NPR`; $('people').append(figure);
  }
  $('status').textContent='人物表面已绘制，正在批量运行原作 NPR…';await pause();const t=performance.now(),styled=await api('/api/people',{request,images}),postMs=Math.round(performance.now()-t);
  for(let i=0;i<current.length;i++){
   const item=current[i];item.render=styled.portraits[item.key];const fig=$('people').children[i],img=fig.querySelector('img');img.src=item.render.url;await img.decode();img.onclick=()=>inspect(i);img.alt=item.features.pose;fig.className='';
   const caption=fig.querySelector('figcaption');caption.replaceChildren();const small=document.createElement('small'),b=document.createElement('b'),p=document.createElement('p');small.textContent=`人物 ${item.id} · 独立种子 ${item.recipe.personSeed}`;b.textContent=item.features.role+' · '+item.features.pose;p.textContent=item.features.silhouette;const appeal=document.createElement('p');appeal.className='appeal';appeal.textContent='“'+item.recipe.background.appeal+'”';caption.append(small,b,p,appeal);
  }
  const durationMs=Math.round(performance.now()-started);last={version:PEOPLE_VERSION,context,people:current.map(({passes,...v})=>v),timings:{totalMs:durationMs,postMs},coverage:'取材于既有祈求 CSV 的 6 个背景角色槽；每类仍可连续换人。不是正式 Session 人物绑定，不把求告者默认为教徒。其他世界/画风及其余祈求角色未覆盖。'};
  window.peopleState=last;window.peoplePasses=current.map(v=>v.passes);$('manifest').textContent=JSON.stringify(last,null,2);$('status').textContent=`已实际生成 ${current.length} 人，用时 ${(durationMs/1000).toFixed(1)} 秒。点击立绘放大并查看中间结果。`;history.replaceState(null,'','?start='+start+(single?'&personSeed='+seed:'')+'&background='+encodeURIComponent($('background').value));
 }catch(e){$('status').textContent='生成失败：'+e.message;console.error(e);}finally{controls(false);}
}
$('background').onchange=()=>{if(!busy)generate();};
$('generate').onclick=()=>generate();$('repeat').onclick=()=>generate(current.length===1);$('next').onclick=()=>{$('start').value=Number($('start').value)+6;generate();};$('single').onclick=()=>generate(true);$('close').onclick=()=>$('inspection').close();$('pass').onchange=showImage;
$('download').onclick=()=>{if(!last)return;const a=document.createElement('a'),url=URL.createObjectURL(new Blob([JSON.stringify(last,null,2)],{type:'application/json'}));a.href=url;a.download='tide-people-recipes.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
const single=new URLSearchParams(location.search).get('personSeed');if(single!==null)$('single-seed').value=single;
generate(single!==null);
