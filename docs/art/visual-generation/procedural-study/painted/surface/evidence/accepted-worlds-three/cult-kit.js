import {SurfacePainter,ellipse,mix,rng,fbm,foldField,rgb} from './engine.js';
import {worldField} from './world-fields.js';
import {roles} from './world.js';

// A drawing vocabulary: paths are painted in page space. No meshes or scene
// models. Each world authors its own footprints, occlusion and focal activity.
export function cultKit(w,rule){
 const C=roles(w),r=rng(w.worldSeed+rule.archetype*1009),lights=[],p=new SurfacePainter(w.worldSeed,{emitters:lights,styleSid:w.styleSid});
 const field=worldField(rule.material,w),base={mat:rule.material,field,color:mix(C.stone,w.c2,.20),shadow:mix(w.c1,w.c0,.35),accent:C.salt,glow:w.c4,bump:.65,exposure:.83};
 const top={...base,normal:[-.28,-.66,.72]},side={...base,normal:[.35,.12,.9],ambient:[.14,.17,.21],exposure:.84};
 const built={mat:'masonry',field:undefined,color:mix(C.stone,w.c2,.17),shadow:C.stoneShadow,accent:C.salt,bump:.5,scale:27},wood={mat:'wood',field:worldField('wood',w),color:mix(C.copper,w.c3,.4),shadow:C.stoneShadow,accent:C.salt};
 const rect=(x,y,a,b)=>[x-a-4,y-b-4,x+a+4,y+b+4];
 function surf(d,b,o={}){p.surface(d,b,{...base,...o});}
 function lamp(x,y,power=.55,color=w.c4,radius=145){const e={x,y,z:58,r:radius,color:rgb(color),power:power*.66,falloff:1.8,specular:.055};lights.push(e);return e;}
 function lightMark(e){const {x,y}=e;p.fill(ellipse(x+3,y+16,9,3),w.c0,.7);p.line(`M${x} ${y+3}v15`,C.copper,3);p.fill(ellipse(x,y,5,7),mix(e.color,w.star,.6));p.glow(x,y,26,e.color,.32);}
 function person(x,y,s=.85,light=false){
  p.fill(ellipse(x+5*s,y+2*s,9*s,3*s),w.c0,.68);p.fill(`M${x-4*s} ${y-17*s}Q${x-8*s} ${y-5*s} ${x-7*s} ${y}Q${x} ${y+3*s} ${x+7*s} ${y}L${x+4*s} ${y-17*s}Z`,light?C.linen:mix(w.c1,w.c3,.38));
  p.fill(ellipse(x,y-20*s,4*s,6*s),light?C.salt:C.stone);p.fill(ellipse(x+1*s,y-20*s,2*s,3*s),w.c0);p.line(`M${x-3*s} ${y-14*s}l${-2*s},${12*s}`,C.salt,1.3*s,.65);
 }

 // Activity figures are drawn as clothed continuous silhouettes with hands,
 // feet and task-dependent lean. They receive the same scene lighting.
 function actor(x,y,s=1,action='carry',light=false){
  const lean=action==='work'?6:action==='bow'?4:0,body=light?mix(C.linen,'#bcac89',.48):mix(w.c2,'#514e48',.52);
  p.fill(ellipse(x+8*s,y+2*s,12*s,3.5*s),w.c0,.62);
  if(action!=='kneel')for(const d of[-1,1])p.line(`M${x+d*3*s} ${y-5*s}l${d*1.5*s},${7*s}`,w.c0,3*s);
  const hem=action==='kneel'?11:7;
  surf(`M${x+(-5+lean)*s} ${y-23*s}Q${x-8*s} ${y-13*s} ${x-hem*s} ${y-3*s}Q${x} ${y+2*s} ${x+hem*s} ${y-3*s}L${x+(5+lean)*s} ${y-22*s}Q${x+lean*s} ${y-27*s} ${x+(-5+lean)*s} ${y-23*s}Z`,[x-14*s,y-28*s,x+18*s,y+5*s],{mat:'cloth',field:undefined,color:body,shadow:w.c0,accent:C.salt,normal:[-.3,.1,1],height:(u,v)=>Math.sin((u-x)*.5)*.6,bump:.3});
  p.fill(ellipse(x+lean*s,y-27*s,4.5*s,5.5*s),mix(body,C.salt,.45));p.fill(ellipse(x+(lean+2)*s,y-26*s,2.3*s,3*s),w.c0);
  p.stroke(`M${x-3*s} ${y-18*s}l${-2*s},${12*s}`,C.salt,1.3*s,.45);
  const wristX=x+(action==='work'?16:action==='torch'?11:8)*s,wristY=y-(action==='torch'?28:action==='work'?14:13)*s;
  p.line(`M${x+(lean+4)*s} ${y-20*s}Q${x+9*s} ${y-9*s} ${wristX} ${wristY}`,body,4*s);
  p.fill(ellipse(wristX,wristY,2.3*s,1.8*s),mix('#b2a17d',C.salt,.2));
  if(action==='carry'){p.fill(`M${x-1*s} ${y-16*s}l${14*s},${3*s}l${-2*s},${8*s}l${-11*s},${-2*s}Z`,'#827052');p.line(`M${x+1*s} ${y-17*s}l${4*s},${-4*s}l${7*s},${6*s}`,'#b2a17d',1*s);}
  if(action==='work')p.line(`M${wristX} ${wristY}l${10*s},${-10*s}`,C.copper,1.8*s);
  if(action==='torch'){p.line(`M${wristX} ${wristY+5*s}v${-16*s}`,C.copper,2*s);p.fill(ellipse(wristX,wristY-13*s,2*s,4*s),'#ffc079');p.glow(wristX,wristY-13*s,19*s,'#f4a251',.22);}
 }
 function brazier(e,s=1){
  e.marker=false;const{x,y}=e;
  surf(`M${x-4*s} ${y+7*s}L${x-5*s} ${y+25*s}L${x+6*s} ${y+27*s}L${x+4*s} ${y+7*s}Z`,[x-9*s,y+5*s,x+10*s,y+30*s],{mat:'metal',field:undefined,color:'#88714f',shadow:w.c0,accent:'#bfa36f',normal:[-.4,.1,1]});
  p.fill(`M${x-12*s} ${y+3*s}Q${x} ${y+19*s} ${x+12*s} ${y+3*s}Z`,'#775237');p.fill(ellipse(x,y+4*s,11*s,3*s),'#e8984c');
  p.fill(`M${x-6*s} ${y+3*s}Q${x-8*s} ${y-4*s} ${x-2*s} ${y-12*s}L${x+1*s} ${y-3*s}L${x+4*s} ${y-15*s}Q${x+11*s} ${y+3*s} ${x+4*s} ${y+5*s}Z`,'#ffbd68');p.fill(ellipse(x,y,2.4*s,5*s),'#ffecb4');p.glow(x,y,40*s,'#f6a457',.2);
 }
 function queue(points){for(let i=0;i<points.length;i++)person(points[i][0],points[i][1],points[i][2]||.8,i%3===0);}
 function terrace(topPath,facePath,box,{material=rule.material,depth=1,...options}={}){
  const own={field:worldField(material,w),...options};
  surf(facePath,box,{...side,...own,height:(x,y)=>fbm(x*.017,y*.006,w.worldSeed)*19*depth+Math.sin(y*.045+x*.014)*3});
  // Weather follows ledges and strata; it is bounded to the actual cliff.
  for(const c of[p.c,p.mc,p.fc]){c.save();c.clip(new Path2D(facePath));}
  for(let j=0;j<11;j++){const yy=box[1]+(box[3]-box[1])*(j+.5)/11,x=box[0],wid=box[2]-box[0];p.stroke(`M${x} ${yy}Q${x+wid*.3} ${yy+17} ${x+wid*.58} ${yy-9}T${x+wid} ${yy+6}`,j%3?C.stoneShadow:C.salt,1.2,.2);}
  for(const c of[p.c,p.mc,p.fc])c.restore();
  surf(topPath,box,{...top,...own,height:(x,y)=>fbm(x*.017,y*.024,w.worldSeed)*4});
  if(['sand','frost','basalt','bone','ridge'].includes(material)){
   for(const c of[p.c,p.mc,p.fc]){c.save();c.clip(new Path2D(topPath));}
   for(let j=0;j<10;j++)for(let i=0;i<11;i++){const x=box[0]+i*33-j*11,y=box[1]+j*21+i*8;if(r()<.35)continue;p.line(`M${x} ${y}l29,7l-10,15`,C.stoneShadow,1,.25);if(r()>.7)p.stroke(`M${x+3} ${y+2}l20,5`,C.salt,1.2,.28);}
   for(const c of[p.c,p.mc,p.fc])c.restore();
  }
  p.stroke(topPath,C.salt,1.3,.14);
 }
 function stair(x,y,dx,dy,n,width,options={}){
  for(let i=0;i<n;i++){const a=x+i*dx,b=y+i*dy;
   surf(`M${a-width/2} ${b}l${width},${-width*.19}l${dx},${dy}l${-width},${width*.19}Z`,[a-width/2-7,b-width*.21-4,a+width/2+12,b+dy+8],{...top,...options,bump:.35});
   p.line(`M${a-width/2} ${b+dy}l${width},${-width*.19}`,w.c0,1.8,.72);p.stroke(`M${a-width/2+3} ${b}l${width-6},${-width*.19}`,C.salt,1.2,.6);
  }
 }
 function opening(x,y,width,height,tilt=0){
  const d=`M${x-width/2} ${y}L${x-width/2} ${y-height*.53}Q${x-width*.43} ${y-height*.85} ${x} ${y-height}Q${x+width*.4} ${y-height*.8+tilt} ${x+width/2} ${y-height*.53+tilt}L${x+width/2} ${y+tilt}Z`;
  p.fill(d,w.c0,.97);p.stroke(`M${x-width/2-2} ${y}L${x-width/2-2} ${y-height*.53}Q${x-width*.4} ${y-height*.87} ${x} ${y-height}`,C.salt,3,.65);
  p.line(`M${x+width/2-4} ${y+tilt}v${-height*.5}`,mix(w.c2,w.c0,.4),3,.8);
 }
 function hall(x,y,width,height,{material='masonry',roof='tile',tower=false,windows=3}={}){
  // A sloping courtyard facade and a receding return, not a front-view icon.
  const a=width*.36,h=height,mat=material==='masonry'?built:{...base,mat:material,field:worldField(material,w)},far=x+width;
  p.shadow(`M${x-10} ${y}L${far+30} ${y+width*.26}L${far-26} ${y+width*.48}L${x-34} ${y+28}Z`,.45,5);
  surf(`M${x} ${y-h}Q${x+a*.42} ${y-h-a*.7} ${x+a} ${y-h-a*.5}L${x+a} ${y-a*.5}L${x} ${y}Z`,[x-4,y-h-a*.75,far+4,y+10],{...mat,normal:[-.65,0,.76],ambient:[.1,.13,.16]});
  surf(`M${x} ${y-h}Q${x+width*.4} ${y-h+width*.07} ${far} ${y-h+width*.24}L${far} ${y+width*.25}Q${x+width*.45} ${y+width*.1} ${x} ${y}Z`,[x-4,y-h-4,far+4,y+width*.28],{...mat,normal:[.16,.12,.98]});
  if(roof==='tile'){
   surf(`M${x-10} ${y-h+4}Q${x+a*.55} ${y-h-a*.65} ${x+a} ${y-h-a*.59}L${far+17} ${y-h+width*.06}L${far+5} ${y-h+width*.27}Q${x+width*.45} ${y-h+width*.11} ${x-10} ${y-h+4}Z`,[x-15,y-h-a*.7,far+24,y-h+width*.3],{...top,mat:'metal',field:undefined,color:mix(w.c2,C.copper,.4),shadow:C.stoneShadow,height:(u,v)=>Math.sin((u+v*.3)*.24)*1.6});
   for(let i=1;i<8;i++){const xx=x+width*i/8,yy=y-h+width*i*.24/8;p.stroke(`M${xx} ${yy}l${a*.44},${-a*.5}`,C.salt,1,.35);}
  }else if(roof==='snow'){
   surf(`M${x-13} ${y-h+6}Q${x+a*.5} ${y-h-a*.82} ${x+a} ${y-h-a*.64}L${far+12} ${y-h+width*.09}L${far+9} ${y-h+width*.3}Q${x+width*.4} ${y-h+width*.09} ${x-13} ${y-h+6}Z`,[x-18,y-h-a*.87,far+19,y-h+width*.32],{...top,field:worldField('frost',w),color:mix(w.c3,w.star,.28),accent:w.star,bump:.2});
  }else if(roof==='broken'){
   for(let i=0;i<5;i++){const xx=x+width*i/5,yy=y-h+width*.24*i/5;surf(`M${xx} ${yy}l4,-12l12,3l2,14Z`,[xx-2,yy-15,xx+20,yy+10],{...mat,color:C.salt});}
  }
  for(let i=0;i<windows;i++)opening(x+width*(i+.5)/windows,y+width*.24*(i+.5)/windows-7,width/(windows*2.4),height*(i===0?.74:.55),width*.035);
  for(let i=0;i<=windows;i++){let xx=x+width*i/windows,yy=y+width*.24*i/windows;p.stroke(`M${xx} ${yy}l2,${-h*.8}`,C.salt,3,.48);}
  // Continuous base ledge, recessed doorway floors and a few occupied windows.
  surf(`M${x-5} ${y}L${far+5} ${y+width*.25}L${far+7} ${y+width*.25+9}L${x-6} ${y+8}Z`,[x-10,y-4,far+12,y+width*.25+14],{...mat,normal:[.4,.1,.9],exposure:.65});
  for(let i=0;i<windows;i++){const xx=x+width*(i+.5)/windows,yy=y+width*.24*(i+.5)/windows-4;p.stroke(`M${xx-width/(windows*5)} ${yy}l${width/(windows*2.6)},${width*.025}`,C.salt,1.6,.5);}
  return [x+width*.5,y+width*.1];
 }
 function cloth(x,y,width,height,color=C.violet){
  const d=`M${x} ${y}Q${x+width*.5} ${y+12} ${x+width} ${y+5}L${x+width-8} ${y+height}L${x+width*.5} ${y+height-8}L${x+5} ${y+height+5}Z`;
  surf(d,[x-4,y-4,x+width+4,y+height+10],{mat:'cloth',field:undefined,color,shadow:w.c1,accent:C.salt,normal:[.2,0,1],height:foldField([[[x+width*.25,y+5],[x+width*.5,y+20],[x+width*.2,y+height*.7],[x+width*.3,y+height],10,7]])});
  p.line(`M${x-4} ${y-2}l${width+8},7`,C.copper,2,.85);
 }
 function bridge(x,y,xx,yy,width=30,{rope=true}={}){
  const dx=xx-x,dy=yy-y;
  surf(`M${x} ${y}Q${x+dx*.45} ${y+dy*.5-10} ${xx} ${yy}L${xx+4} ${yy+width}Q${x+dx*.5} ${y+dy*.5+width+2} ${x+3} ${y+width}Z`,[Math.min(x,xx)-5,Math.min(y,yy)-15,Math.max(x,xx)+10,Math.max(y,yy)+width+7],{...wood,normal:[0,-.65,.76],height:(u,v)=>Math.sin(u*.23)*1.3});
  for(let i=0;i<Math.abs(dx)/12;i++){const t=i/(Math.abs(dx)/12),a=x+dx*t,b=y+dy*t;p.line(`M${a} ${b}l4,${width}`,w.c0,1,.65);}
  if(rope)for(let side=0;side<2;side++){const offset=side*width;p.line(`M${x} ${y-28+offset}Q${(x+xx)*.5} ${(y+yy)*.5+offset} ${xx} ${yy-28+offset}`,C.copper,1.5,.85);for(let t=0;t<=1;t+=.25){const a=x+dx*t,b=y+dy*t+offset;p.line(`M${a} ${b}v-28`,C.stone,2,.8);}}
 }
 function basin(x,y,rx,ry,{liquid='water',color=w.c2,emission=.08}={}){
  surf(ellipse(x,y,rx,ry),rect(x,y,rx,ry),{...top,color:C.stone});
  surf(ellipse(x,y,rx*.85,ry*.78),rect(x,y,rx,ry),{...side,color:mix(w.c1,w.c0,.4)});
  p.shadow(ellipse(x,y-3,rx*.76,ry*.63),.4,4);
  surf(ellipse(x,y+ry*.18,rx*.72,ry*.56),rect(x,y,rx,ry),{mat:liquid,field:liquid==='water'?undefined:worldField(liquid,w),color,shadow:w.c0,accent:C.salt,cx:x,cy:y,normal:[0,-.8,.6],emission,glow:w.c4,bump:.25});
  p.stroke(`M${x-rx*.8} ${y+ry*.42}Q${x} ${y+ry*1.26} ${x+rx*.8} ${y+ry*.42}`,C.salt,3,.5);
 }
 function supplies(x,y,n=4){for(let i=0;i<n;i++){const a=x+i*12,b=y+(i%2)*6;p.surface(`M${a-4} ${b}q4,-4 8,0l1,12q-5,5 -10,0Z`,[a-7,b-6,a+8,b+17],{...wood,color:C.copper});p.fill(ellipse(a,b,4,2),w.c0);}}
 function gallery(x,y,width=95){
  surf(`M${x-width*.5} ${y}Q${x} ${y-13} ${x+width*.5} ${y+4}L${x+width*.5-6} ${y+24}Q${x} ${y+9} ${x-width*.5-5} ${y+17}Z`,[x-width*.6,y-17,x+width*.6,y+30],{...wood,normal:[-.2,-.7,.7]});
  for(let i=0;i<7;i++){const xx=x-width*.5+i*width/6,yy=y+Math.sin(i/6*Math.PI)*-6;p.line(`M${xx} ${yy+13}v-25`,C.copper,2);p.line(`M${xx} ${yy+15}l-4,35`,C.stoneShadow,3,.8);}
  p.line(`M${x-width*.5} ${y-10}Q${x} ${y-23} ${x+width*.5} ${y-6}`,C.salt,1.6,.7);
 }
 function table(x,y,width=58){
  p.fill(`M${x} ${y+4}v17l4,2v-17Z`,w.c0);p.fill(`M${x+width-7} ${y+width*.2}v18l4,1v-19Z`,w.c0);
  surf(`M${x-3} ${y}l12,-8l${width},${width*.2}l-12,9Z`,[x-7,y-12,x+width+18,y+width*.2+15],{...wood,normal:[0,-.7,.7]});
 }
 function finish(extra={}){for(const e of lights)if(e.marker!==false)lightMark(e);p.fade(873);return{p:p.output(),features:{worldSeed:w.worldSeed,archetype:w.archetype,styleSid:w.styleSid,palette:w.palette,institution:rule.institution,construction:rule.translation,activity:rule.activity,materialAlgorithm:rule.material,lights,scope:'视觉候选，非正式游戏机构',...extra}};}
 return{actor,brazier,w,C,r,p,base,top,side,built,wood,surf,lamp,lightMark,person,queue,terrace,stair,opening,hall,cloth,bridge,basin,supplies,gallery,table,finish};
}
