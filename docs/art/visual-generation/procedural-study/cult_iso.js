// REJECTED EXPERIMENT: not connected to the live generator; see 本轮独立美术审查.md.
// Direct 2D isometric drawing. P projects a conceptual ground grid to paper;
// these are paths, not meshes or a 3D renderer.
import {random} from './paint.js';
const THEMES=[
 {name:'潮汐观测聚落',roof:'low',core:'pool',material:'stone'},
 {name:'环眼观测院',roof:'spire',core:'eye',material:'stone'},
 {name:'共生疗愈院',roof:'dome',core:'vessel',material:'skin'},
 {name:'菌圃',roof:'dome',core:'spore',material:'rock'},
 {name:'裂炉',roof:'terrace',core:'fire',material:'rock'},
 {name:'测风台',roof:'terrace',core:'wind',material:'stone'},
 {name:'折光台',roof:'spire',core:'prism',material:'metal'},
 {name:'见证书院',roof:'gable',core:'archive',material:'stone'},
 {name:'航迹庭院',roof:'low',core:'orbit',material:'rock'},
 {name:'静茧之庭',roof:'dome',core:'cocoon',material:'cloth'},
 {name:'骨丘名录',roof:'terrace',core:'grave',material:'stone'}
];
export function drawIsoCult(p,c){
 let r=random((c.seed^0x45f3219)>>>0),theme=THEMES[c.archetype],R=(a,b)=>a+(b-a)*r(),I=(a,b)=>Math.floor(R(a,b+1));
 let width=R(112,143),depth=R(89,112),mainW=R(57,75),mainD=R(48,64),height=R(58,104),annex=I(0,1),steps=I(3,5),orient=I(0,1);
 const P=(x,y,z=0)=>[384+(x-y)*1.08,437+(x+y)*.76-z*1.05];
 const pol=(pts,mat='stone',light=.5,norm=[0,.5],extra={})=>p.poly(pts.map(v=>P(...v)),mat,{light,relief:.35,flatNormal:norm,shadow:false,...extra});
 const path=(pts,col=c.palette.shadow,w=2)=>p.stroke(pts.map(v=>P(...v)),col,w);
 const circle=(cx,cy,rx,ry,z,mat,light=.5)=>{let v=[];for(let i=0;i<20;i++){let a=i*Math.PI*2/20;v.push([cx+Math.cos(a)*rx,cy+Math.sin(a)*ry,z]);}pol(v,mat,light,[0,.58]);};
 const quad=(x,y,w,d,z,mat='stone',light=.5)=>pol([[x,y,z],[x+w,y,z],[x+w,y+d,z],[x,y+d,z]],mat,light,[0,.65]);
 // A thick, irregular island with coherent top and two visible cut faces.
 let W=width,D=depth;
 const outline=[[-W*.9,-D], [W*.68,-D], [W,-D*.68], [W,D*.72], [W*.72,D], [-W*.78,D],[-W,D*.72],[-W,-D*.75]];
 pol(outline.map(([x,y])=>[x,y,0]),'stone',.57,[0,.65]);
 pol([[W,-D*.68,0],[W,D*.72,0],[W,D*.72,-25],[W,-D*.68,-25]],'rock',.29,[.64,-.05]);
 pol([[W,D*.72,0],[W*.72,D,0],[-W*.78,D,0],[-W*.78,D,-25],[W*.72,D,-25],[W,D*.72,-25]],'rock',.36,[-.6,-.05]);
 pol([[-W*.78,D,0],[-W,D*.72,0],[-W,D*.72,-25],[-W*.78,D,-25]],'rock',.27,[-.6,-.05]);
 // Structural fissures are subordinate to the island silhouette.
 for(let i=0;i<4;i++){let t=-.7+i*.35;path([[W*t,D,-4],[W*(t+.05),D,-18]],c.palette.dark,2);}
 // Paved courtyard in front, stairs attached to front edge.
 quad(-W*.55,-D*.46,W*1.08,D*1.16,2,'stone',.46);
 for(let i=0;i<3;i++)path([[-W*.5,-D*.25+i*D*.27,3],[W*.5,-D*.25+i*D*.27,3]],c.palette.shadow,1.5);
 for(let i=0;i<steps;i++){let yy=D+i*9;quad(-28,yy,56,11,1-i*4,'stone',.56-i*.025);pol([[-28,yy+11,1-i*4],[28,yy+11,1-i*4],[28,yy+11,-3-i*4],[-28,yy+11,-3-i*4]],'rock',.34,[-.5,0]);}
 function block(x,y,w,d,h,roof,material='stone'){
  // Visible faces and roof share vertices; far faces are hidden.
  pol([[x+w,y,0],[x+w,y+d,0],[x+w,y+d,h],[x+w,y,h]],material,.38,[.65,0]);
  pol([[x,y+d,0],[x+w,y+d,0],[x+w,y+d,h],[x,y+d,h]],material,.48,[-.65,0]);
  quad(x,y,w,d,h,material,.62);
  if(roof==='gable'||roof==='low'){
   let rise=roof==='low'?h*.16:h*.38;
   pol([[x-5,y-4,h],[x+w/2,y-4,h+rise],[x+w/2,y+d+4,h+rise],[x-5,y+d+4,h]],'roof',.60,[-.24,.55]);
   pol([[x+w/2,y-4,h+rise],[x+w+5,y-4,h],[x+w+5,y+d+4,h],[x+w/2,y+d+4,h+rise]],'roof',.37,[.43,.3]);
  }else if(roof==='spire'){
   let rise=h*.58;
   pol([[x-4,y-4,h],[x+w+4,y-4,h],[x+w/2,y+d/2,h+rise]],'roof',.48,[0,.55]);
   pol([[x+w+4,y-4,h],[x+w+4,y+d+4,h],[x+w/2,y+d/2,h+rise]],'roof',.32,[.62,0]);
   pol([[x+w+4,y+d+4,h],[x-4,y+d+4,h],[x+w/2,y+d/2,h+rise]],'roof',.56,[-.5,.2]);
  }else if(roof==='dome'){
   // Concentric narrowing elliptical projected rings imply a curved canopy.
   for(let j=0;j<4;j++){let k=1-j*.18;circle(x+w/2,y+d/2,w*.51*k,d*.52*k,h+j*7,'cloth',.43+j*.04);}
  }else{
   quad(x-3,y-3,w+6,d+6,h+3,'stone',.65);
   for(let j=0;j<3;j++)path([[x+4,y+7+j*(d-14)/2,h+4],[x+w-4,y+7+j*(d-14)/2,h+4]],c.palette.shadow,1.5);
  }
  // Eaves and seams reinforce the roof volume, instead of isolated flat shapes.
  path([[x-3,y+d+2,h],[x+w+3,y+d+2,h]],c.palette.shadow,2);
  if(roof==='gable'||roof==='low'){
   let rise=roof==='low'?h*.16:h*.38;
   for(let i=1;i<=3;i++){let t=i/4;path([[x+w*t,y-3,h+rise*(1.0-Math.abs(t*2.0-1.0))],[x+w*t,y+d+3,h+rise*(1.0-Math.abs(t*2.0-1.0))]],c.palette.shadow,1.0);}
  }
  // Door cut into the face facing viewer; top and sides stay on one plane.
  let dw=w*.23,dh=h*.43,dx=x+w*.34;
  pol([[dx,y+d+.6,0],[dx+dw,y+d+.6,0],[dx+dw,y+d+.6,dh],[dx,y+d+.6,dh]],'void',.25,[-.65,0]);
  for(let k=0;k<2;k++){let wx=x+w*(.12+k*.68),wh=h*.17;pol([[wx,y+d+.7,h*.55],[wx+w*.09,y+d+.7,h*.55],[wx+w*.09,y+d+.7,h*.55+wh],[wx,y+d+.7,h*.55+wh]],k===orient?'glow':'void',.4,[-.65,0]);}
 }
 // Rear building and side wing are sorted from the far side to the near side.
 let bx=-W*.67,by=-D*.72;
 if(c.archetype===3){
  // Spore society is a grove of overlapping canopies rather than houses.
  for(let i=0;i<5;i++){let x=bx+18+i*23,y=by+20+(i%2)*30,h=height*(.7+r()*.65),rad=20+r()*10;
   pol([[x-4,y,0],[x+4,y,0],[x+4,y,h],[x-4,y,h]],'cloth',.48,[-.4,0]);
   circle(x,y,rad,rad*.72,h,'rock',.52);circle(x,y,rad*.75,rad*.52,h+6,'rock',.58);circle(x,y,rad*.45,rad*.30,h+10,'rock',.62);
  }
 }else if(c.archetype===2||c.archetype===9){
  // Layered oval shell, ring terrace and side pods.
  for(let j=0;j<6;j++){let k=1-j*.12;circle(bx+mainW*.55,by+mainD*.55,mainW*.56*k,mainD*.58*k,j*height*.12,theme.material,.42+j*.03);}
  for(let j=0;j<2;j++)circle(W*.1+j*34,-D*.52,21,17,5+j*4,theme.material,.52);
 }else if(c.archetype===6||c.archetype===8){
  // Prism pylons and broken elevated landings; no conventional house shell.
  for(let i=0;i<4;i++){let x=bx+12+i*38,y=by+24+(i%2)*34,h=height*R(.55,1.3);pol([[x-8,y-7,0],[x+8,y-7,0],[x+8,y-7,h*.75],[x,y-7,h],[x-8,y-7,h*.75]],theme.material,.48,[-.5,0]);pol([[x+8,y-7,0],[x+8,y+7,0],[x+8,y+7,h*.75],[x,y-7,h]],theme.material,.34,[.5,0]);}
 }else if(c.archetype===10){
  for(let i=0;i<5;i++){let x=bx+i*35,y=by+((i%2)*22),h=height*R(.45,.95);block(x,y,12,13,h,'terrace','stone');}
 }else{
  block(bx,by,mainW,mainD,height,theme.roof,theme.material);
  if(annex){block(W*.08,-D*.67,R(43,58),R(37,48),height*R(.45,.68),theme.roof==='spire'?'gable':'low',theme.material);}else{block(W*.12,-D*.60,R(34,45),R(32,44),height*R(.55,.80),'terrace',theme.material);}
 }
 // A small community structure: each uses the same paper-space projection.
 let cx=26,cy=10;
 if(theme.core==='pool'||theme.core==='vessel'||theme.core==='archive'||theme.core==='grave'){
  circle(cx,cy,36,29,5,'stone',.67);circle(cx,cy,29,22,7,'void',.3);
  if(theme.core==='pool')circle(cx,cy,24,17,8,'water',.45);
  if(theme.core==='vessel'){circle(cx,cy,18,14,9,'skin',.55);circle(cx,cy,7,5,10,'glow',.5);}
  if(theme.core==='archive'){quad(cx-23,cy-17,46,34,11,'roof',.5);quad(cx-15,cy-10,30,20,13,'paper',.55);path([[cx,cy-10,14],[cx,cy+10,14]],c.palette.shadow,1.5);}
  if(theme.core==='grave'){circle(cx,cy,23,16,8,'rock',.45);for(let i=0;i<3;i++){let x=cx-14+i*14;pol([[x,cy-8,8],[x+5,cy-8,8],[x+5,cy-8,27],[x,cy-8,27]],'paper',.5,[-.5,0]);}}
 }else if(theme.core==='fire'){
  circle(cx,cy,32,24,5,'stone',.55);circle(cx,cy,23,16,7,'void',.3);
  for(let i=0;i<4;i++){let x=cx-17+i*10;pol([[x,cy,8],[x+9,cy,8],[x+4,cy,28+R(0,25)]],'glow',.8,[0,.6]);}
 }else if(theme.core==='spore'){
  for(let i=0;i<5;i++){let x=cx-20+(i%3)*20,y=cy-12+Math.floor(i/3)*22,h=R(22,55);pol([[x-3,y,4],[x+3,y,4],[x+3,y,h],[x-3,y,h]],'cloth',.5,[-.5,0]);circle(x,y,12,9,h,'rock',.65);}
 }else if(theme.core==='eye'){
  circle(cx,cy,31,23,5,'stone',.55);pol([[cx-22,cy,12],[cx+22,cy,12],[cx+22,cy,57],[cx-22,cy,57]],'metal',.48,[-.5,0]);pol([[cx-18,cy-.5,33],[cx,cy-.5,45],[cx+18,cy-.5,33],[cx,cy-.5,21]],'void',.25,[-.5,0]);
 }else if(theme.core==='wind'){
  pol([[cx-3,cy,3],[cx+3,cy,3],[cx+3,cy,79],[cx-3,cy,79]],'roof',.5,[-.5,0]);pol([[cx,cy,75],[cx+30,cy,69],[cx+23,cy,54],[cx,cy,61]],'cloth',.56,[-.4,.1]);
 }else if(theme.core==='prism'){
  for(let i=0;i<4;i++){let x=cx-25+i*15,y=cy+(i%2)*8,h=R(35,76);pol([[x-5,y,4],[x+5,y,4],[x+4,y,h*.7],[x,y,h],[x-4,y,h*.7]],'metal',.55,[-.2,.4]);}
 }else if(theme.core==='orbit'){
  for(let j=0;j<3;j++){let rr=18+j*9;for(let i=0;i<10;i++){let a=i*Math.PI*2/10,b=(i+.55)*Math.PI*2/10;path([[cx+Math.cos(a)*rr,cy+Math.sin(a)*rr*.65,18+j*10],[cx+Math.cos(b)*rr,cy+Math.sin(b)*rr*.65,18+j*10]],c.palette.light,2);}}
 }else if(theme.core==='cocoon'){
  for(let j=0;j<4;j++){let rad=22-j*3;circle(cx,cy,rad,rad*.8,8+j*11,'cloth',.48+j*.04);}circle(cx,cy,5,4,52,'glow',.6);
 }
 // Low boundary posts, cords and a raised workbench establish enclosure and scale.
 for(let i=0;i<4;i++){
  let x=-W*.65+i*W*.34,y=D*.66;
  pol([[x-2,y,1],[x+2,y,1],[x+2,y,19],[x-2,y,19]],'roof',.47,[-.5,0]);
  if(i<3)path([[x,y,16],[x+W*.34,y,16]],c.palette.light,1.7);
 }
 quad(-W*.48,D*.05,31,18,16,'roof',.46);
 pol([[-W*.48,D*.05+18,1],[-W*.48+31,D*.05+18,1],[-W*.48+31,D*.05+18,16],[-W*.48,D*.05+18,16]],'stone',.35,[-.5,0]);
 // Tiny people give the buildings a readable human scale.
 const people=I(2,4);for(let i=0;i<people;i++){let x=-40+i*22,y=55+(i%2)*11;pol([[x-2,y,1],[x+2,y,1],[x+3,y,11],[x,y,15],[x-3,y,11]],'void',.2,[-.5,0]);}
 return {features:{template:c.template,archetype:c.archetype,construction:theme.name,seed:c.seed,roof:theme.roof,structure:theme.core,mainWidth:Math.round(mainW),mainDepth:Math.round(mainD),height:Math.round(height),annex,steps,people,projection:'2D 45-degree inclined ground grid'}};
}
