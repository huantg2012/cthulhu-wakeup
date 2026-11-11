import {worldRecipe,post} from './world-runtime.js';
import {characterRecipe,seedOf} from './people.js';
import {drawPetitioner} from './petition-nohands.js';
const $=id=>document.getElementById(id),pause=()=>new Promise(r=>setTimeout(r,20));let busy=false;
$('close').onclick=()=>$('dialog').close();$('batch').value=new URLSearchParams(location.search).get('batch')||0;
async function run(){
 if(busy)return;const batch=Number($('batch').value);if(!Number.isInteger(batch)||batch<0||batch>999999)return;
 busy=true;window.petitionState=null;for(const id of['again','next','batch'])$(id).disabled=true;
 try{
  const [catalog,contexts]=await Promise.all([fetch('/api/cult-config').then(r=>r.json()),fetch('/api/people-contexts').then(r=>r.json())]),items=[],allPasses=[];
  $('pair').replaceChildren();
  for(const [template,palette]of[['frozen',4],['fire',6]]){
   const request={template,palette,style:0,seed:1339},world=worldRecipe(request,catalog),images={},group=[];
   const title=document.createElement('h2');title.textContent=template==='frozen'?'冷原 · 风雪下的人':'炎狱 · 余烬中的人';$('pair').append(title);
   const row=document.createElement('div');row.className='row';$('pair').append(row);
   for(const caseId of['shaking_hand','fever_child','judge_letter']){
    $('status').textContent=`正在绘制 ${template} 的衣着与姿态…`;await pause();
    const rule=contexts.worldRules.find(r=>r.template===template&&r.case_id===caseId),background={...contexts.contexts.find(r=>r.caseId===caseId),worldRule:{...rule,source:'data/portrait_world_rules.csv',hash:contexts.worldRulesHash}};
    for(const key of['garments','heads','gestures'])background[key]=rule[key].split('|');
    if(caseId==='shaking_hand')background.genderRule='male'; // 既有案例以“他”指代雕刻师
    const recipe=characterRecipe(seedOf('no-hands-1',template,batch,caseId,0),world,background),draw=drawPetitioner(recipe,world),layers={material:draw.p.material.toDataURL(),form:draw.p.form.toDataURL(),lit:draw.p.albedo.toDataURL()},key='p'+recipe.personSeed;
    const figure=document.createElement('figure');figure.innerHTML='<img><figcaption><b></b><p class="pose"></p><p class="appeal"></p><small></small></figcaption>';figure.querySelector('img').src=layers.lit;row.append(figure);
    figure.querySelector('b').textContent=background.role;figure.querySelector('.pose').textContent=draw.features.construction+' · '+draw.features.pose+' · '+draw.features.expression;figure.querySelector('.appeal').textContent='“'+background.appeal+'”';figure.querySelector('small').textContent=`原型 ${world.archetype} / sid 0 / 色板 ${palette} / 世界 1339 / 人物 ${recipe.personSeed}`;
    images[key]=layers.lit;group.push({request,world,recipe,key,features:draw.features,figure,layers});
   }
   $('status').textContent='正在运行原作 NPR…';await pause();const styled=await post('/api/people',{request,images});
   for(const item of group){const render=styled.portraits[item.key],img=item.figure.querySelector('img');img.src=render.url;await img.decode();img.onclick=()=>{$('large').src=render.url;$('dialog').showModal();};const {figure,layers,...record}=item;items.push({...record,render});allPasses.push(layers);}
  }
  window.petitionState={version:'no-hands-1',batch,items,scope:'冷原与炎狱各三人；依背景决定衣着与姿态，手隐藏；人物仍为探索候选，待制作人审阅。'};window.petitionPasses=allPasses;
  $('params').textContent=JSON.stringify(window.petitionState,null,2);$('status').textContent='已实际生成六人；点击放大。';
 }catch(e){$('status').textContent='生成失败：'+e.message;console.error(e);}finally{busy=false;for(const id of['again','next','batch'])$(id).disabled=false;}
}
$('again').onclick=run;$('next').onclick=()=>{$('batch').value=Number($('batch').value)+1;run();};run();
