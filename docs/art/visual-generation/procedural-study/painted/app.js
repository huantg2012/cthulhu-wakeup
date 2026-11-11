import {drawPerson} from './person.js';
import {drawCult} from './cult.js';
const $=id=>document.getElementById(id);let catalog,busy=false,last;const history=new Map();
const hash=async data=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',data))).map(x=>x.toString(16).padStart(2,'0')).join('');
async function imageHash(c){return hash(c.getContext('2d').getImageData(0,0,c.width,c.height).data);}
function status(t,error=false){$('status').textContent=t;$('status').classList.toggle('error',error);}
const request=()=>({template:$('template').value,style:+$('style').value,palette:+$('palette').value,seed:+$('seed').value,personSeed:+$('personSeed').value});
async function api(path,body){const r=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}),result=await r.json();if(!r.ok)throw Error(result.error||r.statusText);return result;}
export async function render(q){
 for(const k of['seed','personSeed'])if(!Number.isInteger(q[k])||q[k]<0||q[k]>999999)throw Error('种子必须为0–999999整数');
 const identity=catalog.templates.find(t=>t.id===q.template),palette=catalog.palettes.find(t=>t.id===q.palette);if(!identity||!palette)throw Error('无效的原型或色板');
 const c={...q,palette,archetype:identity.archetype},wr={template:q.template,style:q.style,palette:q.palette,seed:q.seed};
 await new Promise(r=>requestAnimationFrame(r));
 const cult=drawCult(c),person=drawPerson(c);
 const rawHashes={cult:await imageHash(cult.p.albedo),person:await imageHash(person.p.albedo),cultNormals:await imageHash(cult.p.normals),personNormals:await imageHash(person.p.normals)};
 const [world,style]=await Promise.all([api('/api/world',wr),api('/api/style',{request:wr,images:{cult:cult.p.albedo.toDataURL(),person:person.p.albedo.toDataURL()},normals:{cult:cult.p.normals.toDataURL(),person:person.p.normals.toDataURL()}})]);
 const result={request:q,identity,palette,world,style,rawHashes,features:{cult:cult.features,person:person.features},urls:{world:world.url,...style.urls},hashes:{world:world.hash,...style.hashes},renderer:'painted-2d-v1',coverage:'原型0、7已实现；六原作sid可用，不表示所有组合已经检查'};
 const key=JSON.stringify(q),old=history.get(key);result.sameParameters=old?JSON.stringify(old.hashes)===JSON.stringify(result.hashes)&&JSON.stringify(old.rawHashes)===JSON.stringify(rawHashes):null;if(result.sameParameters===false)throw Error('同参复现不一致');history.set(key,result);return result;
}
function caption(result,kind){const{request:q,identity:i,features:f}=result;return {world:['世界 / 原生成器',i.world_name,`原型 ${i.archetype} · ${i.archetype_name} · 原作真实生成`],cult:['候选教团 / 二维绘景',i.cult_name,f.cult.construction],person:['候选人物 / 二维绘画',`求告者 · ${q.personSeed}`,`${f.person.pose} · ${f.person.head} · ${f.person.robe}`]}[kind];}
function figure(r,kind){const fig=document.createElement('figure'),img=new Image(),cap=document.createElement('figcaption');img.src=r.urls[kind];img.alt=caption(r,kind).join('，');const[c,n,d]=caption(r,kind);cap.innerHTML='<small></small><b></b><span></span><span></span>';cap.children[0].textContent=c;cap.children[1].textContent=n;cap.children[2].textContent=d;cap.children[3].textContent=`sid ${r.request.style} · 色板 ${r.request.palette} ${r.palette.name} · W ${r.request.seed} / P ${r.request.personSeed}`;fig.append(img,cap);return fig;}
function group(r,parent){const row=document.createElement('section');row.className='triple';row.append(...['world','cult','person'].map(k=>figure(r,k)));parent.append(row);}
function lock(b){busy=b;document.querySelectorAll('button,input,select').forEach(e=>e.disabled=b);}
async function generate(q=request()){
 if(busy)return;lock(true);status('正在计算二维曲线与材料场，并调用原作生成器…');window.studyState=null;
 try{last=await render(q);$('current').replaceChildren(...['world','cult','person'].map(k=>figure(last,k)));$('parameters').textContent=`${last.identity.world_name} / 候选${last.identity.cult_name} / 候选人物 ${q.personSeed}　|　原型 ${last.identity.archetype} · 原作画风 sid ${q.style}（表索引 ${last.world.params.style}） · ${last.palette.name} [${q.palette}] · 世界种子 ${q.seed} · 人物种子 ${q.personSeed}`;$('manifest').textContent=JSON.stringify(last,null,2);window.studyState=last;window.history.replaceState(null,'','?'+new URLSearchParams(q));status(last.sameParameters?'同参重新计算：二维输入与最终三图一致。':'生成完成。人物与教团为待审候选。');return last;
 }catch(e){last=null;status(e.message,true);throw e;}finally{lock(false);}
}
$('controls').onsubmit=e=>{e.preventDefault();generate().catch(console.error);};
$('next-person').onclick=()=>{$('personSeed').value=(+$('personSeed').value+1)%1000000;generate().catch(console.error);};
$('next-world').onclick=()=>{$('seed').value=(+$('seed').value+1)%1000000;generate().catch(console.error);};
$('replay').onclick=()=>generate().catch(console.error);
$('controls').onchange=()=>status('参数待生成；当前图仍对应图下的参数。');
$('save').onclick=()=>{if(!last)return;const blob=new Blob([JSON.stringify(last,null,2)],{type:'application/json'}),a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=`painted-${last.request.template}-${last.request.seed}-${last.request.personSeed}.json`;a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);};
$('samples').onclick=async()=>{if(busy)return;lock(true);const root=$('gallery');root.replaceChildren();window.sampleResults=[];try{
 const jobs=[{template:'tide',seed:1339,palette:0,style:0,personSeed:1020},{template:'archive',seed:2048,palette:1,style:0,personSeed:1003}];
 for(const q of jobs){status(`正在现场生成 ${q.template} 的三联画…`);const r=await render(q);window.sampleResults.push(r);const h=document.createElement('h2');h.textContent=r.identity.archetype_name+' · 世界与机构';root.append(h);group(r,root);}
 const h=document.createElement('h2');h.textContent='同一世界，四个独立人物种子';root.append(h);const people=document.createElement('section');people.className='people';root.append(people);
 for(const seed of[1003,1004,1009,1020]){status(`正在生成人物 ${seed}…`);const r=await render({...jobs[0],personSeed:seed});window.sampleResults.push(r);people.append(figure(r,'person'));}
 status('正在生成原作铜版画 sid 2…');const r=await render({...jobs[1],style:2});window.sampleResults.push(r);const title=document.createElement('h2');title.textContent='同一王城，原作铜版画 sid 2';root.append(title);group(r,root);status('并排样本全部现场生成完成；可继续换参数。');
 }catch(e){status(e.message,true);}finally{lock(false);}};
window.generateStudy=async q=>{for(const[k,v]of Object.entries(q))if($(k))$(k).value=String(v);return generate(q);};window.renderStudy=render;
try{catalog=await(await fetch('/api/config')).json();for(const[k,items]of[['template',catalog.templates.filter(x=>[0,7].includes(x.archetype))],['style',catalog.styles],['palette',catalog.palettes]])$(k).replaceChildren(...items.map(x=>new Option(x.name,String(x.id))));const q=new URLSearchParams(location.search);for(const k of['template','style','palette','seed','personSeed'])if(q.has(k))$(k).value=q.get(k);await generate();}catch(e){status('生成服务未就绪：'+e.message,true);}
