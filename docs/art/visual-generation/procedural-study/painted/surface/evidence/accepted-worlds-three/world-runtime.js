import {SurfacePainter,rgb,mix,clamp} from './engine.js';
import {sanctuary} from './sanctuary.js';
import {newCult} from './cult-scenes.js';
export const CULT_VERSION='world-cults-1';
export async function post(path,body){const res=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}),data=await res.json();if(!res.ok)throw Error(data.error||res.statusText);return data;}
export function worldRecipe(request,catalog){
 const identity=catalog.templates.find(v=>v.id===request.template),pal=catalog.palettes.find(v=>v.id===request.palette),style=catalog.styles.find(v=>v.sid===request.style);
 if(!identity||!pal||!style||!Number.isInteger(request.seed)||request.seed<0||request.seed>999999)throw Error('无效世界参数');
 return{version:CULT_VERSION,archetype:identity.archetype,worldSeed:request.seed,styleSid:style.sid,styleIndex:style.index,palette:pal.id,c0:pal.dark,c1:pal.shadow,c2:pal.mid,c3:pal.light,c4:pal.glow,nebula:pal.nebula_shadow,star:pal.star,corruption:pal.corruption};
}
function tidePainter(w){
 const palette=color=>{
  if(w.palette===0)return color;
  const c=rgb(color),lum=c[0]*.299+c[1]*.587+c[2]*.114;
  if(c[0]>c[1]*1.15&&c[1]>c[2]*1.25)return color; // fire stays warm
  if(c[2]>c[1]*1.1&&c[0]>c[1]*1.12)return mix(w.c0,w.nebula,clamp(lum/95));
  const stops=[w.c0,w.c1,w.c2,w.c3,w.star],levels=[12,44,78,145,242];let i=0;while(i<3&&lum>levels[i+1])i++;return mix(stops[i],stops[i+1],clamp((lum-levels[i])/(levels[i+1]-levels[i])));
 };
 const literal=c=>Array.isArray(c)?c:palette(c);
 return class extends SurfacePainter{
  constructor(seed,options){super(seed,{...options,styleSid:w.styleSid,emitters:options.emitters.map(e=>({...e,color:rgb(palette(e.color))}))});}
  surface(d,b,o={}){const v={...o};for(const key of['color','shadow','accent','glow'])if(v[key])v[key]=literal(v[key]);return super.surface(d,b,v);}
  fill(d,c,a){return super.fill(d,literal(c),a);}
  line(d,c,width,a){return super.line(d,literal(c),width,a);}
  stroke(d,c,width,a){return super.stroke(d,literal(c),width,a);}
  glow(x,y,r,c,a){return super.glow(x,y,r,literal(c),a);}
 };
}
export function drawCult(request,catalog){
 const recipe=worldRecipe(request,catalog),rule=catalog.cultRules.find(v=>v.archetype===recipe.archetype);
 if(!rule)throw Error('没有该原型的教团规则');
 // The accepted tide baseline takes the original, bit-preserving code path.
 const item=rule.layout==='tide'?sanctuary(recipe.worldSeed,recipe,recipe.palette===0&&recipe.styleSid===0?{}:{Painter:tidePainter(recipe)}):newCult(recipe,rule);
 return{...item,recipe,rule};
}
export async function generateWorld(request,catalog){
 const start=performance.now(),draw=drawCult(request,catalog),drawMs=Math.round(performance.now()-start),passes={material:draw.p.material.toDataURL(),form:draw.p.form.toDataURL(),lit:draw.p.albedo.toDataURL()};
 const [world,styled]=await Promise.all([post('/api/world',request),post('/api/cult',{request,images:{c0:passes.lit}})]);
 return{record:{version:CULT_VERSION,request,recipe:draw.recipe,rule:draw.rule,features:draw.features,world,cult:styled.scenes.c0,rulesFingerprint:catalog.rulesFingerprint,timing:{drawMs,totalMs:Math.round(performance.now()-start)},scope:'原星球真实生成；二维教团候选；未绑定正式机构'},passes};
}
