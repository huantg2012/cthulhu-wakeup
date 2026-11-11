import {portrait} from './portrait.js';
import {tide,roles} from './world.js';
import {rng,lerp,mix} from './engine.js';
import {designSpace,painterFor,vectorEllipse} from './design-space.js';
import {configureFigure,GESTURE_NAMES} from './figure-grammar.js';
import {configureWorldPerson} from './world-person.js';
import {configureCivilian,OUTFIT_NAMES,HEAD_NAMES} from './civilian.js';

export const PEOPLE_VERSION='tide-people-3';
export function seedOf(...parts){let h=2166136261;for(const c of parts.join('|')){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return h>>>0;}
// Background is explicit input bound to an existing prayer role, never inferred
// from the fact that somebody prays. Named streams retain identity stability.
export function characterRecipe(personSeed,world=tide,background){
 if(!Number.isInteger(personSeed)||personSeed<0||personSeed>0xffffffff)throw Error('人物种子必须是 uint32');
 if(!((world.archetype===0&&world.palette===0)||[4,5].includes(world.archetype))||world.styleSid!==0)throw Error('人物目前仅实现潮汐 / 冷原 / 炎狱的 sid 0');
 if(world.archetype!==0&&!background?.worldRule)throw Error('跨世界人物需要明确的环境造型规则');
 const version=world.archetype===0?PEOPLE_VERSION:'world-people-1';
 if(!background?.caseId||!background.garments?.length||!background.heads?.length||!background.gestures?.length)throw Error('需要祈求背景及其造型规则');
 const stream=name=>rng(seedOf(version,personSeed,name)),body=stream('body'),head=stream('head'),pose=stream('gesture'),cloth=stream('garment'),pigment=stream('pigment');
 const between=(r,a,b)=>lerp(a,b,r()),choose=(values,name)=>values[Math.floor(stream(name)()*values.length)];
 const d={width:between(body,.84,1.20),height:between(body,.94,1.04),lean:between(body,-.065,.065),shoulderSlope:between(body,-.11,.11),
  headTilt:between(head,-.18,.18),headWidth:between(head,.88,1.09),headShift:between(head,-12,12),crown:between(head,-15,15),capRise:head(),hairTone:head(),
  gripX:between(pose,-22,22),gripY:between(pose,-35,38),elbowSpread:between(pose,-20,18),elbowDrop:between(pose,-12,12),
  mantle:between(cloth,18,140),panel:between(cloth,35,116),panelSlant:between(cloth,-30,30),veil:cloth(),border:between(cloth,.1,.95),hem:cloth(),
  dye:pigment(),linen:pigment(),panelDye:pigment(),tension:between(cloth,.85,1.15),sleeve:cloth()};
 const gender=stream('gender-expression')();d.presentation=background.genderRule==='male'?gender*.28:gender;
 d.handScale=1.05-d.presentation*.2;d.width*=lerp(1.04,.91,d.presentation);d.headWidth*=lerp(1.04,.96,d.presentation);
 d.elbowSpread=Math.max(d.elbowSpread,-22+(d.width-1)*30);
 const construction={civilian:true,head:choose(background.heads,'head-construction'),garment:choose(background.garments,'garment-construction'),gesture:choose(background.gestures,'situational-gesture'),held:'none'};
 if(world.archetype!==0){d.viewPitch=.28+body()*.08;d.headLift=.35+head()*.5;d.sleeve*=world.archetype===4?.55:1;d.cover=cloth();}
 return {version,world:{archetype:world.archetype,styleSid:world.styleSid,palette:world.palette,worldSeed:world.worldSeed},personSeed,background:structuredClone(background),dimensions:d,construction};
}
export function recipeForId(id,world=tide,background){return characterRecipe(seedOf(PEOPLE_VERSION,world.worldSeed,String(id)),world,background);}

export function generateCharacter(recipe,world=tide){
 if(![PEOPLE_VERSION,'world-people-1'].includes(recipe.version))throw Error('不支持的人物 recipe 版本');
 if(['archetype','styleSid','palette','worldSeed'].some(k=>recipe.world[k]!==world[k]))throw Error('人物 recipe 与世界不匹配');
 const d=recipe.dimensions,k=recipe.construction,b=recipe.background,C=roles(world),space=designSpace(d);
 if(!OUTFIT_NAMES[k.garment]||!HEAD_NAMES[k.head]||!GESTURE_NAMES[k.gesture])throw Error('未知的服装、头部或动作构造');
 // Physical pigment families; the source palette still provides shadow, salt,
 // reflected sea light and material mixing, rather than tinting every coat green.
 const pigments={ochre:mix('#aa8b50',world.c3,.3),linen:mix('#a8ad9d',world.c3,.25),umber:mix('#795b43',world.c3,.19),ink:mix('#353e4e',world.nebula,.12),slate:mix('#5d7274',world.c2,.2)};
 const base=pigments[b.pigment],outer=mix(base,C.salt,d.dye*.26),shirt=mix(C.linen,'#bab8a6',.35+d.linen*.2);
 const colors={...C,outer,cloth:['apron','jerkin','waistcoat'].includes(k.garment)?mix(shirt,world.c1,.18):outer,clothShadow:mix(world.c0,base,.2),linen:shirt,violet:mix(world.nebula,world.c0,.7),hair:mix('#34312b','#867768',d.hairTone*.7)};
 const config={Painter:painterFor(space),colors,ellipse:vectorEllipse,layers:{},tension:d.tension,emitters:[]};
 const anatomy=configureFigure(config,recipe,colors);configureCivilian(config,recipe,colors);
 if(recipe.version==='world-people-1')configureWorldPerson(config,recipe,colors,world);
 const result=portrait(recipe.personSeed,world.worldSeed,world,config);
 const framing=config.framing||[1.14,-60,-48];
 const framed=q=>{const [x,y]=space.map(...q);return [x*framing[0]+framing[1],y*framing[0]+framing[2]];};
 result.features={...result.features,recipe,role:b.role,caseTitle:b.title,pose:anatomy.gesture,
  silhouette:`${OUTFIT_NAMES[k.garment]} · ${HEAD_NAMES[k.head]} · ${d.presentation<.34?'偏男性':d.presentation>.66?'偏女性':'中性表达'}`,
  genderExpression:d.presentation<.34?'masculine':d.presentation>.66?'feminine':'androgynous',
  view:recipe.version==='world-people-1'?'轻俯视；抬头向画外上方传达诉求':'原基准视角',
  environment:b.worldRule||null,
  framing,
  faceConcealment:recipe.version==='world-people-1'?(k.head==='brim'?'帽檐阴影':d.cover<.3&&k.head==='tiedhair'?'薄面纱':world.archetype===5?'防风围布':'防灰面布'):'阴影',
  materials:[b.material,'亚麻衬衣','旧皮革','头发','铜扣'],
  landmarks:{shoulders:anatomy.shoulders.map(framed),elbows:anatomy.elbows.map(framed),wrists:anatomy.wrists.map(framed),head:framed([440,250])},
  method:'existing prayer background and role → constrained occupation clothing / practical headwear / situational gesture → continuous 2D contours and material fields → illustrated light → original NPR'};
 space.cache.clear();return result;
}
