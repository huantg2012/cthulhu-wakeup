import {portrait} from './focus-person.js';
import {sanctuary} from './focus-cult.js';
const $=id=>document.getElementById(id),request={template:'tide',seed:1339,palette:0,style:0};let busy=false,last;
async function api(path,body){const response=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}),data=await response.json();if(!response.ok)throw Error(data.error||response.statusText);return data;}
async function generate(){if(busy)return;busy=true;$('generate').disabled=true;$('download').disabled=true;$('status').classList.remove('error');$('status').textContent='正在从参数绘制明暗区、材料与笔触，并调用原作星球及厚涂后期…';window.studyState=null;
 try{
  await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
  const cult=sanctuary(1339),person=portrait(1339),body={request,images:{cult:cult.p.albedo.toDataURL(),person:person.p.albedo.toDataURL()},normals:{cult:cult.p.normals.toDataURL(),person:person.p.normals.toDataURL()}};
  const [world,style]=await Promise.all([api('/api/world',request),api('/api/style',body)]);
  style.method='Complete direct 2D pigment painting -> stock CanvasItem -> unchanged original sky, bloom and post; no relief shader';
  const urls={world:world.url,...style.urls};for(const id of['world','cult','person']){$(id).src=urls[id];await $(id).decode();}for(const id of['cult','person']){$('compare-'+id).src=urls[id];await $('compare-'+id).decode();}
  last={request:{...request,personSeed:1339},world,style,urls,method:'二维直接色料绘画：整体明暗、遮挡、材料分区与定向笔触；未使用上版肢体坡度场或法线受光；原天空、bloom/post保持原实现',features:{cult:cult.features,person:person.features},coverage:'单一世界、单一教团构图、单一人物姿态；尚未扩展新文法'};
  window.studyState=last;window.focusRaw={cult:cult.p.albedo.toDataURL(),person:person.p.albedo.toDataURL()};$('manifest').textContent=JSON.stringify(last,null,2);window.history.replaceState(null,'','?template=tide&style=0&palette=0&seed=1339&personSeed=1339');$('status').textContent='本次已实际生成。下方可与给定案例同尺度比较；美术待制作人判断。';
 }catch(e){last=null;$('status').textContent='生成失败：'+e.message;$('status').classList.add('error');console.error(e);}finally{busy=false;$('generate').disabled=false;$('download').disabled=!last;}}
$('generate').onclick=generate;$('download').onclick=()=>{if(!last)return;const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(last,null,2)],{type:'application/json'}));a.download='tide-painting-focus-1339.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),500);};generate();
