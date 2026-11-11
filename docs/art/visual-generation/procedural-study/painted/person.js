import {Paint,rng,mix,drape,sleeve,clamp} from './field.js';
const POSES=['敛袖拢手','抚胸求告','抱持封卷','双手承灯'];
const HEADS=['深兜帽','垂落面纱','缠布覆面','低垂风帽'];
function hand(p,x,y,flip=1,tilt=0){
 p.group(x,y,.83,()=>{
  // The fingers stay in a single restrained silhouette, with a tucked thumb.
  const d='M-18,1 C-11,-8 -2,-13 10,-12 C18,-11 28,-6 31,0 Q31,5 25,6 Q30,11 22,12 Q27,17 18,18 L1,16 Q-8,12 -18,13 Z';
  p.paint(d,[-21,-16,34,22],{mat:'skin',color:mix(p.p.light,'#b18c71',.68),height:(x,y)=>8*Math.exp(-((x-3)**2/800+(y-1)**2/220)),texture:.05});
  p.stroke('M7,1 Q17,-2 25,2 M5,7 Q16,5 24,8 M-2,8 Q-7,0 0,-3',mix(p.p.dark,'#603f32',.6),1.1,{mat:'skin',alpha:.6});
 },flip);
}
function head(p,cx,cy,type,cloth,seed,arch){
 p.group(cx,cy,1,()=>{
  const field=drape({top:-115,bottom:135,cx:0,end:8,width:66,endWidth:85,seed,depth:5,folds:4,bulge:30});
  // The throat disappears into the collar, while its axis continues to the skull.
  p.paint('M-32,50 Q-32,92 -51,114 Q-5,150 47,112 L28,52Z',[-53,50,48,146],{mat:'cloth',color:mix(cloth,p.p.dark,.3),height:field});
  if(type===0||type===3){
   const low=type===3?24:0;
   const d=`M-63,60 C-80,10 -64,-70 -27,${-112+low} Q-9,${-135+low} 13,${-111+low} C55,-91 72,-40 69,13 Q64,71 44,96 Q5,118 -53,90Z`;
   p.paint(d,[-82,-137,76,120],{mat:'cloth',color:cloth,height:field,texture:.14});
   p.paint('M-45,-10 Q-25,-66 10,-66 Q48,-52 50,-2 L33,57 Q9,76 -21,52 Q-48,29 -45,-10Z',[-48,-69,54,79],{mat:'void',color:mix(p.p.dark,'#020407',.72),texture:.05});
   p.stroke('M-48,32 C-59,-12 -30,-76 9,-80 Q36,-75 53,-39',mix(cloth,p.p.light,.35),3.5,{mat:'cloth',normal:[-.55,.45,.7]});
   p.stroke('M-54,43 Q-38,84 5,85 Q36,87 57,39',mix(cloth,p.p.dark,.32),4,{mat:'cloth'});
  }else if(type===1){
   p.paint('M-55,-36 Q-57,-100 -2,-106 Q49,-104 58,-44 L73,91 Q37,128 -49,104 L-65,8Z',[-70,-110,77,132],{mat:'cloth',color:mix(cloth,p.p.light,.18),height:field});
   p.paint('M-40,-32 Q-24,-61 22,-49 L42,-28 L24,56 Q5,74 -25,48Z',[-43,-62,45,77],{mat:'void',color:mix(p.p.dark,'#151316',.35)});
   p.paint('M-45,-10 Q-4,9 45,-11 L61,99 Q6,134 -55,99Z',[-59,-15,65,138],{mat:'cloth',color:mix(cloth,p.p.dark,.27),height:drape({top:-12,bottom:125,cx:3,width:52,seed:seed+8,depth:5,folds:6,bulge:7}),texture:.08});
   p.stroke('M-43,-14 Q-2,5 45,-15',mix(cloth,p.p.light,.15),3,{mat:'cloth'});
  }else{
   p.paint('M-48,-43 Q-61,-91 -18,-105 Q36,-128 56,-73 L48,1 Q52,41 28,72 Q5,91 -30,55 L-49,5Z',[-64,-130,62,93],{mat:'cloth',color:mix(cloth,p.p.dark,.12),height:field});
   p.a.save();p.n.save();const cap=new Path2D('M-48,-43Q-61,-91 -18,-105Q36,-128 56,-73L48,15Q0,36 -49,5Z');p.a.clip(cap);p.n.clip(cap);
   for(let i=0;i<5;i++){
    const y=-86+i*14;
    p.paint(`M-56,${y+12}Q-7,${y+40} 60,${y-14}L57,${y+2}Q8,${y+56} -57,${y+27}Z`,[-60,y-16,64,y+57],{mat:'cloth',color:mix(cloth,p.p.light,.22+i*.025),height:(x,yy)=>8*Math.sin((yy-y-x*.25)*.1),texture:.08});
   }
   p.a.restore();p.n.restore();
   p.paint('M-40,-8 Q0,8 44,-9 L39,15 Q3,29 -40,16Z',[-42,-12,48,32],{mat:'void',color:mix(p.p.dark,'#00040b',.6)});
   p.paint('M-45,21 Q-2,33 42,12 L36,79 Q-2,106 -42,72Z',[-47,10,45,110],{mat:'cloth',color:cloth,height:drape({top:10,bottom:106,cx:0,width:40,seed,depth:3,folds:3,bulge:12})});
  }
  // World-specific construction, not the same stone pattern on every portrait.
  if(arch===0){
   p.stroke('M-54,68 Q-34,100 -23,116',mix(p.p.light,'#b6c8b7',.4),2,{mat:'cloth'});
   for(let i=0;i<4;i++)p.ellipse(-23+i*5,110+i*2,2,3,{mat:'metal',color:mix(p.p.light,p.p.glow,.2),normal:[-.5,.5,.7]});
  }else{
   p.stroke('M-57,-30 Q-8,-8 52,-40',mix(p.p.light,'#d5b283',.4),3,{mat:'metal'});
  }
 });
}
export function drawPerson(config){
 const p=new Paint({...config,seed:config.personSeed}),r=rng(config.personSeed*3571+config.seed*17+109),arch=config.archetype;
 const pose=Math.floor(r()*4),cover=Math.floor(r()*4),build=.84+r()*.3,lean=(r()-.5)*32,turn=r()>.5?1:-1,robe=Math.floor(r()*3),shoulder=130*build,neckX=380+lean,neckY=302+(r()-.5)*24;
 const pal=p.p,cloth=mix(mix(pal.mid,pal.light,.30+r()*.22),'#8a9283',.14),under=mix(cloth,pal.shadow,.26),accent=mix(pal.light,arch===0?'#c4c4aa':'#e5c18d',.32);
 const features={pose:POSES[pose],head:HEADS[cover],build:+build.toFixed(3),lean:+lean.toFixed(2),robe:['交叠长衣','宽披肩','窄肩垂带'][robe],turn,worldArchetype:arch,personSeed:config.personSeed};
 p.group(384,0,1,()=>{
  // Mirror the entire construction, not isolated hands or disconnected joints.
  p.group(-384,0,1,()=>{
   const left=neckX-shoulder,right=neckX+shoulder;
   const body=`M${neckX-38},${neckY} C${left+30},${neckY+20} ${left-18},${neckY+26} ${left-19},${neckY+98} Q${left-15},570 ${left-32},820 L${right+36},820 Q${right-2},602 ${right+17},${neckY+106} C${right+18},${neckY+40} ${right-12},${neckY+27} ${neckX+36},${neckY}Z`;
   p.paint(body,[left-38,neckY-3,right+44,826],{mat:'cloth',color:under,height:drape({top:neckY,bottom:830,cx:neckX,end:neckX+18,width:shoulder,endWidth:shoulder+26,seed:config.personSeed,depth:14,folds:5,bulge:52}),ao:(x,y)=>.84+.16*clamp((y-neckY)/130),texture:.1});
   // Continuous shoulder mantle: diagonal drape around the ribcage, no breastplate.
   const mantle=`M${neckX-44},${neckY-8} Q${left-6},${neckY+13} ${left-14},${neckY+55} C${left+25},${neckY+140} ${neckX+50},${neckY+184} ${right+14},${neckY+49} Q${neckX+87},${neckY+26} ${neckX+43},${neckY-12}Z`;
   p.paint(mantle,[left-19,neckY-18,right+20,neckY+190],{mat:'cloth',color:cloth,height:(x,y)=>{
    const u=(x-neckX)/shoulder,v=(y-neckY-30)/150;const curve=v+.32*u*u-.18*u;return 27*Math.exp(-u*u)+9*Math.exp(-(((curve-.34)/.17)**2))-5*Math.exp(-(((curve-.62)/.12)**2))+3*Math.exp(-(((curve-.83)/.11)**2));
   },texture:.09});
   p.stroke(`M${left+3},${neckY+67}Q${neckX+8},${neckY+219} ${right-7},${neckY+67}`,mix(cloth,pal.dark,.25),3,{mat:'cloth'});
   if(robe!==0){
    const x=robe===1?left+19:neckX+47,w=robe===1?68:26;
    const d=`M${x},${neckY+48}Q${x+15},452 ${x-18},820 L${x+w+12},820Q${x+w-5},491 ${x+w},${neckY+65}Z`;
    p.paint(d,[x-23,neckY+44,x+w+18,826],{mat:'cloth',color:mix(accent,cloth,.4),height:drape({top:neckY+40,bottom:820,cx:x+w/2,end:x+w/2-9,width:w/2+4,seed:config.personSeed+31,depth:7,folds:3,bulge:6})});
    p.stroke(`M${x+7},${neckY+75}Q${x+19},580 ${x-7},800`,mix(accent,pal.dark,.2),1.5,{mat:'cloth'});
   }
   const ls=[left+20,neckY+54],rs=[right-18,neckY+59];let lpoints,rpoints;
   if(pose===0){lpoints=[ls,[left-6,532],[neckX-23,598]];rpoints=[rs,[right+1,547],[neckX+24,594]];}
   if(pose===1){lpoints=[ls,[left-4,546],[neckX-57,655]];rpoints=[rs,[right+10,529],[neckX+8,451]];}
   if(pose===2){lpoints=[ls,[left-4,538],[neckX+17,586]];rpoints=[rs,[right-5,544],[neckX+48,516]];}
   if(pose===3){lpoints=[ls,[left-19,547],[neckX-65,553]];rpoints=[rs,[right+10,554],[neckX+67,553]];}
   sleeve(p,lpoints,[46*build,46,22],cloth,config.personSeed+4);
   if(pose===2){
    // Book lies against the chest; the lower sleeve supports its weight.
    p.paint(`M${neckX-15},470L${neckX+101},488L${neckX+73},638L${neckX-47},609Z`,[neckX-50,467,neckX+104,642],{mat:'paper',color:mix(accent,pal.shadow,.37),normal:[-.3,.3,1],texture:.18});
    p.stroke(`M${neckX-6},482L${neckX+84},496L${neckX+63},622L${neckX-32},601Z`,accent,2,{mat:'paper'});
    for(let i=0;i<7;i++)p.stroke(`M${neckX-8},${515+i*10}l${55+(i%3)*7},9`,pal.shadow,1,{mat:'paper',alpha:.6});
   }
   sleeve(p,rpoints,[43*build,43,22],mix(cloth,pal.light,.05),config.personSeed+9);
   p.stroke(`M${left+15},${neckY+38}Q${left+45},${neckY+76} ${left+27},${neckY+114}`,mix(cloth,pal.dark,.3),2.2,{mat:'cloth',alpha:.6});
   p.stroke(`M${right-18},${neckY+41}Q${right-40},${neckY+80} ${right-23},${neckY+115}`,mix(cloth,pal.dark,.28),2.2,{mat:'cloth',alpha:.6});
   head(p,neckX-5,neckY-61,cover,cloth,config.personSeed,arch);
   // Cuffs close at the wrists. Pose-specific hiding avoids loose fingers.
   if(pose===0){hand(p,neckX-17,595,1);hand(p,neckX+20,592,-1);}
   if(pose===1){hand(p,neckX+1,447,-1);hand(p,neckX-47,659,1);}
   if(pose===2){hand(p,neckX+43,517,-1);hand(p,neckX+13,584,1);}
   if(pose===3){
    hand(p,neckX-57,551,1);hand(p,neckX+60,551,-1);
    p.paint(`M${neckX-59},544Q${neckX},573 ${neckX+60},544Q${neckX+43},594 ${neckX},590Q${neckX-45},583 ${neckX-59},544Z`,[neckX-62,541,neckX+64,598],{mat:'metal',color:mix(pal.mid,accent,.5),height:(x,y)=>14*Math.cos((x-neckX)/62)*Math.sin((y-541)/60),texture:.1});
    p.ellipse(neckX,544,60,14,{mat:'void',color:pal.dark});p.ellipse(neckX,543,47,9,{mat:'water',color:mix(pal.glow,accent,.4),normal:[0,.75,.65]});
    p.ellipse(neckX-5,539,6,3,{mat:'glow',color:mix(pal.glow,'#fcf1cf',.6)});
   }
   // Wear belongs at exposed hems; it does not overwrite body modelling.
   if(arch===0){
    p.dots(body,[left,620,right,790],mix(accent,pal.mid,.45),90,'cloth');
    p.stroke(`M${left+25},460Q${left+42},484 ${left+34},511`,accent,2,{mat:'cloth'});
    p.ellipse(left+34,500,9,13,{mat:'metal',color:mix(accent,pal.mid,.2),normal:[-.6,.1,.8]});
   }else{
    for(let i=0;i<8;i++)p.stroke(`M${neckX+66},${660+i*14}l13,3m-9,-5l-2,10`,accent,.9,{mat:'cloth',alpha:.6});
   }
  });
 },turn);
 // Crop at the waist, with a painterly fade; never close the robe into a pot.
 for(const c of[p.a,p.n]){c.save();c.globalCompositeOperation='destination-in';const g=c.createLinearGradient(0,0,0,768);g.addColorStop(0,'#fff');g.addColorStop(.91,'#fff');g.addColorStop(1,'#fff0');c.fillStyle=g;c.fillRect(0,0,768,768);c.restore();}
 return {p,features};
}
