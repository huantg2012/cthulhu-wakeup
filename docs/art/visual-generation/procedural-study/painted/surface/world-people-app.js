import {characterRecipe,generateCharacter,seedOf} from './people.js';
import {generateWorld,post} from './world-runtime.js';
const $=id=>document.getElementById(id),pause=()=>new Promise(r=>setTimeout(r,30));
let busy=false,catalog,contexts,worlds=[],current=[],selected;
$('batch').value=new URLSearchParams(location.search).get('batch')||'0';
const requests=[{template:'frozen',palette:4,style:0,seed:1339},{template:'fire',palette:6,style:0,seed:1339}];
const roles=['shaking_hand','judge_letter','fever_child','protected_witness'];
function show(){if(selected)$('large').src=$('pass').value==='final'?selected.render.url:selected.passes[$('pass').value];}
$('close').onclick=()=>$('inspect').close();$('pass').onchange=show;
export function buildRecipe(index,batch,world,source){
 const rule=source.worldRules.find(r=>r.template===world.request.template&&r.case_id===roles[index]);
 if(!rule)throw Error('缺少世界人物造型规则');
 const base=source.contexts.find(r=>r.caseId===rule.case_id),background={...base,worldRule:{...rule,source:'data/portrait_world_rules.csv',hash:source.worldRulesHash}};
 for(const key of['garments','heads','gestures'])background[key]=rule[key].split('|');
 const seed=seedOf('world-people-1',world.request.template,world.request.seed,batch,index);
 return characterRecipe(seed,world.recipe,background);
}
async function generate(){
 if(busy)return;const batch=Number($('batch').value);if(!Number.isInteger(batch)||batch<0||batch>999999){$('status').textContent='批次须为 0–999999 的整数';return;}
 busy=true;for(const id of['generate','next','repeat','batch'])$(id).disabled=true;window.worldPeopleState=null;current=[];const started=performance.now();
 try{
  if(!catalog){[catalog,contexts]=await Promise.all([fetch('/api/cult-config').then(r=>r.json()),fetch('/api/people-contexts').then(r=>r.json())]);}
  if(!worlds.length){for(const request of requests){$('status').textContent=`实际生成 ${request.template} 的原作星球与教团…`;await pause();worlds.push((await generateWorld(request,catalog)).record);}}
  $('groups').replaceChildren();
  for(const world of worlds){
   const request=world.request,name=request.template==='frozen'?'冷原':'炎狱之星',section=document.createElement('section');
   section.innerHTML='<div class="world"><img class="planet"><img class="cult"><div><h2></h2><p class="metadata"></p><p class="muted"></p></div></div><div class="people"></div>';
   section.querySelector('.planet').src=world.world.url;section.querySelector('.cult').src=world.cult.url;section.querySelector('h2').textContent=name+' · 四个诉求';
   section.querySelector('.metadata').textContent=`原型 ${world.recipe.archetype} · 暗黑厚涂 sid 0 · 色板 ${request.palette} · 世界种子 ${request.seed}`;
   section.querySelector('.muted').textContent=request.template==='frozen'?'风雪下的夹层、绗缝、厚领与护耳；冷光落在肩顶。':'余烬旁的卷袖、皮围裙、分襟与防灰遮面；暖光从右下反射。';
   $('groups').append(section);const people=[],images={};
   for(let i=0;i<4;i++){
    $('status').textContent=`${name}：正在绘制人物 ${i+1}/4 的衣料与受光…`;await pause();
    const recipe=buildRecipe(i,batch,world,contexts),t=performance.now(),draw=generateCharacter(recipe,world.recipe),key='p'+recipe.personSeed;
    const passes={material:draw.p.material.toDataURL(),form:draw.p.form.toDataURL(),lit:draw.p.albedo.toDataURL()},item={id:request.template+'-'+i,recipe,features:draw.features,passes,key,drawMs:Math.round(performance.now()-t)};
    people.push(item);images[key]=passes.lit;
    const fig=document.createElement('figure');fig.innerHTML='<img><figcaption><small></small><b></b><p class="dress"></p><p class="intent"></p><p class="appeal"></p></figcaption>';
    fig.querySelector('img').src=passes.lit;fig.querySelector('small').textContent='人物种子 '+recipe.personSeed;
    fig.querySelector('b').textContent=recipe.background.role+' · '+draw.features.pose;
    fig.querySelector('.dress').textContent=draw.features.silhouette+' · '+draw.features.faceConcealment;fig.querySelector('.intent').textContent=recipe.background.worldRule.appeal_pose;
    fig.querySelector('.appeal').textContent='“'+recipe.background.appeal+'”';section.querySelector('.people').append(fig);
    fig.querySelector('img').onclick=()=>{if(!item.render)return;selected=item;$('pass').value='final';show();$('inspect').showModal();};
   }
   $('status').textContent=`${name}：运行原作 NPR…`;await pause();const styled=await post('/api/people',{request,images});
   for(let i=0;i<4;i++){const item=people[i];item.render=styled.portraits[item.key];const img=section.querySelectorAll('figure img')[i];img.src=item.render.url;await img.decode();}
   current.push({world,people});
  }
  window.worldPeoplePasses=current.map(g=>g.people.map(p=>p.passes));
  window.worldPeopleState={version:'world-people-1',batch,groups:current.map(g=>({world:g.world,people:g.people.map(({passes,...item})=>item)})),durationMs:Math.round(performance.now()-started),scope:'两世界、每世界四人物；独立二维程序生成，原作 NPR；轻俯视是二维插画近似，未建人物三维模型；未接正式回合'};
  $('manifest').textContent=JSON.stringify(window.worldPeopleState,null,2);$('status').textContent=`已实际生成 8 人，耗时 ${(window.worldPeopleState.durationMs/1000).toFixed(1)} 秒。点击图片可看大图与中间层。`;
  history.replaceState(null,'','?batch='+batch);
 }catch(e){console.error(e);$('status').textContent='生成失败：'+e.message;}finally{busy=false;for(const id of['generate','next','repeat','batch'])$(id).disabled=false;}
}
$('generate').onclick=generate;$('repeat').onclick=generate;$('next').onclick=()=>{$('batch').value=Number($('batch').value)+1;generate();};generate();
