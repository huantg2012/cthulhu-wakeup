import {generateWorld} from './world-runtime.js';
const $=id=>document.getElementById(id),query=new URLSearchParams(location.search);let catalog,last,busy=false;
const buttons=['generate','next','download'],selects=['archetype','style','palette'];
function lock(value){busy=value;for(const id of [...buttons,...selects,'seed'])$(id).disabled=value;$('download').disabled=value||!last;}
async function generate(){if(busy)return;const request={template:$('archetype').value,style:Number($('style').value),palette:Number($('palette').value),seed:Number($('seed').value)};if(!Number.isInteger(request.seed)||request.seed<0||request.seed>999999){$('status').textContent='世界种子需要是 0 至 999999 的整数。';return;}lock(true);window.worldState=null;last=null;
 try{$('status').textContent='正在生成地形、机构、材料和光，并调用原星球及原作 NPR…';await new Promise(r=>setTimeout(r,30));const result=await generateWorld(request,catalog);last=result.record;
  $('world').src=last.world.url;$('cult').src=last.cult.url;await Promise.all([$('world').decode(),$('cult').decode()]);for(const k of['material','form','lit'])$(k).src=result.passes[k];
  const identity=catalog.templates.find(v=>v.id===request.template),style=catalog.styles.find(v=>v.sid===request.style),pal=catalog.palettes.find(v=>v.id===request.palette);
  $('world-name').textContent=identity.archetype_name+' · 候选世界';$('world-params').textContent=`原型 ${identity.archetype} / ${style.name} · sid ${style.sid}（表索引 ${style.index}）/ ${pal.name} · ${pal.id} / 世界种子 ${request.seed}`;
  $('cult-name').textContent=last.rule.institution;$('construction').textContent=last.rule.translation;$('activity').textContent=last.rule.activity;$('manifest').textContent=JSON.stringify(last,null,2);$('status').textContent=`已实际生成，用时 ${(last.timing.totalMs/1000).toFixed(1)} 秒。点击原图放大。`;
  window.worldState=last;window.worldPasses=result.passes;history.replaceState(null,'','?'+new URLSearchParams(request));
 }catch(e){$('status').textContent='生成失败：'+e.message;console.error(e);}finally{lock(false);}
}
$('generate').onclick=generate;$('next').onclick=()=>{$('seed').value=(Number($('seed').value)+1)%1000000;generate();};
$('archetype').onchange=()=>{const t=catalog.templates.find(v=>v.id===$('archetype').value);$('palette').value=catalog.cultRules.find(v=>v.archetype===t.archetype).default_palette;generate();};$('style').onchange=generate;$('palette').onchange=generate;
for(const key of['world','cult'])$(key).onclick=()=>{if(!last)return;$('zoom-image').src=$(key).src;$('zoom').showModal();};$('close').onclick=()=>$('zoom').close();
$('download').onclick=()=>{if(!last)return;const a=document.createElement('a'),url=URL.createObjectURL(new Blob([JSON.stringify(last,null,2)],{type:'application/json'}));a.href=url;a.download='world-cult-recipe.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
try{const res=await fetch('/api/cult-config');if(!res.ok)throw Error('无法读取世界配置');catalog=await res.json();for(const [id,rows,key,label]of[['archetype',catalog.templates,'id','archetype_name'],['style',catalog.styles,'sid','name'],['palette',catalog.palettes,'id','name']])for(const row of rows){const o=document.createElement('option');o.value=row[key];o.textContent=row[label];$(id).append(o);}
 const template=query.get('template')||'tide';$('archetype').value=catalog.templates.some(v=>v.id===template)?template:'tide';$('style').value=query.get('style')||'0';const t=catalog.templates.find(v=>v.id===$('archetype').value);$('palette').value=query.get('palette')||catalog.cultRules.find(v=>v.archetype===t.archetype).default_palette;$('seed').value=query.get('seed')||'1339';generate();
}catch(e){$('status').textContent=e.message;}
