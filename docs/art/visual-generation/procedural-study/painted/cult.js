import {Paint,rng,mix,noise,fbm,drape,smoothPath,bounds,clamp} from './field.js';
function terrain(p,d,box,{sand=false,top=false,color=p.p.mid}={}){
 const s=p.seed,height=(x,y)=>{
  const u=x*.013,v=y*.014,w=fbm(u,v,s);
  if(sand)return top?7*Math.sin(x*.033+y*.065+w*7)+15*w:25*fbm(u,v*2,s)+5*Math.sin(y*.16+w*4);
  return top?21*fbm(u+w*.8,v,s)+3*noise(x*.08,y*.08,s):18*fbm(x*.019,y*.008,s)+9*Math.sin(x*.072+fbm(x*.025,y*.025,s)*6)+3*noise(x*.13,y*.14,s);
 };
 p.paint(d,box,{mat:sand?'sand':'stone',color,height,bump:top?.45:1.1,normal:top?[0,.7,.7]:undefined,slope:top?.7:0,pigment:(x,y)=>.65+fbm(x*.023,y*.018,s)*.52,texture:.13});
 p.dots(d,box,mix(color,p.p.light,.5),top?150:90);
}
function pool(p,x,y,rx,ry,{tide=true}={}){
 const c=p.p;
 p.ellipse(x+4,y+15,rx+9,ry+8,{mat:'void',color:mix(c.dark,'#010507',.55)});
 p.ellipse(x,y,rx+7,ry+6,{mat:'stone',color:mix(c.mid,c.light,.6),height:(xx,yy)=>8*Math.sin(Math.hypot((xx-x)/rx,(yy-y)/ry)*4),normal:[-.2,.75,.65]});
 p.ellipse(x,y-2,rx,ry,{mat:'void',color:mix(c.dark,'#01070a',.6)});
 p.ellipse(x,y+3,rx-7,ry-5,{mat:'water',color:mix(c.shadow,c.mid,.4),height:(xx,yy)=>.8*Math.sin(xx*.07+yy*.27)+.5*Math.sin(yy*.7),normal:[0,.75,.65],pigment:(xx,yy)=>.7+.35*Math.sin(xx*.035+yy*.03),texture:.03});
 for(let i=0;i<6;i++){const r=(i+1)/7;p.stroke(`M${x-rx*r},${y+6}Q${x},${y+ry*r*.8} ${x+rx*r},${y+2}`,mix(c.mid,c.glow,.3),.7,{mat:'water',alpha:.4});}
 p.ellipse(x-15,y+1,4,2,{mat:'glow',color:mix(c.glow,c.light,.65)});
 if(tide)for(let i=0;i<11;i++){const a=i/11*Math.PI*2,xx=x+Math.cos(a)*(rx+3),yy=y+Math.sin(a)*(ry+3);p.stroke(`M${xx},${yy}l3,-2`,c.light,1,{mat:'stone',alpha:.6});}
}
function stairs(p,x,y,width,steps,dx=-4,dy=6){
 for(let i=steps-1;i>=0;i--){const xx=x+dx*i,yy=y+dy*i;
  p.paint(`M${xx-width/2},${yy}Q${xx},${yy+7} ${xx+width/2},${yy-2}L${xx+width/2},${yy+5}Q${xx},${yy+14} ${xx-width/2-1},${yy+7}Z`,[xx-width/2-3,yy-4,xx+width/2+3,yy+15],{mat:'stone',color:mix(p.p.mid,p.p.light,.28),normal:[-.18,.3,.95],texture:.15});
  p.stroke(`M${xx-width/2},${yy}Q${xx},${yy+7} ${xx+width/2},${yy-2}`,mix(p.p.light,p.p.mid,.25),2,{mat:'stone',alpha:.8});
 }
}
function inhabitant(p,x,y,scale=1,light=false){
 p.group(x,y,scale,()=>{
  p.ellipse(3,2,7,3,{mat:'void',color:p.p.dark});
  p.paint('M-3,-20 Q-9,-11 -7,0 Q0,5 7,1 Q5,-13 2,-20Z',[-10,-23,10,7],{mat:'cloth',color:mix(p.p.mid,p.p.light,light?.7:.2),height:(x,y)=>5*Math.cos(x*.21)});
  p.ellipse(0,-22,3.5,4.7,{mat:'cloth',color:mix(p.p.mid,p.p.light,.55),height:(x,y)=>3*Math.exp(-(x*x+(y+22)**2)/15)});
 });
}
function lantern(p,x,y,s=1){
 p.group(x,y,s,()=>{p.stroke('M0,0L0,-17',p.p.light,2,{mat:'metal'});p.ellipse(0,-21,4,6,{mat:'glow',color:mix(p.p.glow,'#e9f3c7',.55)});p.stroke('M-5,-17L-4,-27L4,-27L5,-17Z',p.p.mid,1.5,{mat:'metal'});});
}
function jar(p,x,y,s=1){
 p.group(x,y,s,()=>{p.paint('M-6,-11Q-5,-5 -10,-1Q-13,14 0,15Q13,14 10,-1Q5,-5 6,-11Z',[-15,-14,15,18],{mat:'stone',color:mix(p.p.mid,p.p.light,.4),height:(x,y)=>10*Math.cos(x*.11),texture:.15});p.ellipse(0,-11,6,3,{mat:'void',color:p.p.dark});p.stroke('M-6,-12Q0,-16 6,-12',p.p.light,1,{mat:'stone'});});
}
function shelter(p,x,y,scale,{city=false,wide=1}={}){
 p.group(x,y,scale,()=>{
  const c=p.p;
  // Oblique painted apse; the high roof recedes to the back, the porch shows floor.
  const wall='M-95,-18 C-95,-53 -60,-76 -18,-78 Q42,-77 95,-37 L96,44Q32,82 -89,44Z';
  p.paint(wall,[-101,-125,102,86],{mat:'stone',color:mix(c.mid,c.light,.38),height:(x,y)=>35*Math.exp(-(((x+12)/92)**2))+3*fbm(x*.06,y*.04,p.seed),pigment:(x,y)=>.65+.35*fbm(x*.04,y*.03,p.seed),texture:.15});
  // Several recesses sit behind one continuous wall, avoiding independent boxes.
  for(const [a,b,w]of[[-53,20,24],[14,28,29],[65,17,15]]){
   const d=`M${a-w},${b+27}L${a-w},${b-8}Q${a-w+2},${b-47} ${a+7},${b-48}Q${a+w},${b-40} ${a+w},${b-8}L${a+w},${b+19}Z`;
   p.paint(d,[a-w-2,b-51,a+w+3,b+31],{mat:'void',color:mix(c.dark,'#020605',.7),texture:.1});
   p.stroke(`M${a-w-2},${b+24}L${a-w-2},${b-8}Q${a-w},${b-49} ${a+7},${b-50}`,mix(c.light,c.mid,.4),3,{mat:'stone'});
  }
  const roof='M-108,-26 C-113,-60 -89,-77 -52,-94 Q-13,-108 21,-88 L111,-40 Q80,-45 55,-30 L21,-42 Q-44,-21 -108,-26Z';
  p.paint(roof,[-114,-138,116,-20],{mat:'stone',color:mix(c.mid,c.light,city?.68:.48),height:(x,y)=>21*Math.exp(-(((y+60)/35)**2))+8*Math.sin(x*.025)+5*fbm(x*.06,y*.08,p.seed),normal:undefined,texture:.12});
  p.a.save();p.n.save();p.a.clip(new Path2D(roof));p.n.clip(new Path2D(roof));
  for(let i=0;i<9;i++){const yy=-32-i*8;
   const xx=98-i*7;p.stroke(`M${-xx},${yy}Q-10,${yy+17} ${xx},${yy-5}`,mix(c.mid,c.dark,.2),1.4,{mat:'stone',alpha:.5});
  }
  for(let i=0;i<10;i++){const xx=-80+i*17;p.stroke(`M${xx},-42Q${xx-12},-73 ${xx*.45},-118`,mix(c.light,c.mid,.2),.8,{mat:'stone',alpha:.45});}
  p.a.restore();p.n.restore();
  // Inside floor, benches, offerings and hanging light provide institutional scale.
  p.paint('M-66,39Q-8,25 56,41L47,54Q-5,65 -70,50Z',[-74,23,60,69],{mat:'stone',color:mix(c.mid,c.light,.44),normal:[0,.8,.6]});
  p.stroke('M-49,34L-43,49M23,37L25,54M-49,34Q-13,46 23,37',c.shadow,4,{mat:'stone'});
  for(let i=0;i<5;i++)p.stroke(`M${-40+i*9},36l0,-${6+i%2*4}`,c.light,2,{mat:'paper'});
  lantern(p,42,32,.65);
  p.dots(wall,[-95,-30,96,45],mix(c.light,c.mid,.2),70);
 });
}
function banner(p,x,y,h,{city=false,seed=p.seed}={}){
 p.stroke(`M${x},${y}L${x+2},${y-h}`,mix(p.p.light,p.p.shadow,.5),3,{mat:'metal'});
 const d=`M${x+3},${y-h+5}Q${x+28},${y-h+18} ${x+57},${y-h+4}L${x+48},${y-h+67}Q${x+22},${y-h+54} ${x+3},${y-h+70}Z`;
 p.paint(d,[x,y-h,x+61,y-h+75],{mat:'cloth',color:mix(p.p.light,p.p.mid,city?.2:.4),height:drape({top:y-h,bottom:y-h+80,cx:x+29,width:31,seed,depth:4,folds:4,bulge:2}),texture:.14});
 p.stroke(`M${x+17},${y-h+27}q16,15 24,-1m-17,-9l-5,29`,p.p.shadow,1.7,{mat:'cloth'});
}
function tide(p,r){
 const c=p.p,dx=(r()-.5)*35,dy=(r()-.5)*18,terrace=r()>.5;
 const coast=[[91,545],[111,485],[167,419],[260,372],[361,363],[447,397],[538,418],[620,478],[656,546],[617,598],[552,633],[432,649],[320,670],[209,638],[142,600]];
 const lower=coast.map(([x,y],i)=>[x+Math.sin(i*1.7)*9,y+(i>6?60+Math.sin(i*2)*14:15)]),low=smoothPath(lower),land=smoothPath(coast);
 // An irregular waterline surrounds a fractured, inhabited rock shelf.
 p.paint('M80,537 Q150,476 247,510 Q408,501 629,518Q719,560 650,636Q576,710 399,719Q187,724 88,644Q45,597 80,537Z',[44,473,721,730],{mat:'water',color:mix(c.shadow,c.mid,.4),normal:[0,.75,.65],height:()=>0,pigment:(x,y)=>.6+.25*Math.sin(y*.12+fbm(x*.02,y*.02,p.seed)*7),texture:.06});
 terrain(p,low,bounds(lower,12),{color:mix(c.mid,c.light,.3)});
 // Deep cliff openings follow the eroded shoreline; rock pillars share the land mass.
 for(let i=0;i<6;i++){const x=180+i*73,y=624+Math.sin(i)*17,w=15+r()*11;
  p.paint(`M${x-w},${y+21}Q${x-w+3},${y-40} ${x+3},${y-48}Q${x+w},${y-30} ${x+w+7},${y+14}Z`,[x-w-2,y-51,x+w+9,y+24],{mat:'void',color:mix(c.dark,'#01070a',.6)});
 }
 terrain(p,land,bounds(coast,15),{top:true,color:mix(c.mid,c.light,.52)});
 // A worn curving route links porch, work area and water steps.
 p.stroke('M198,586 C235,526 301,517 331,472Q367,436 430,448',mix(c.light,c.mid,.45),30,{normal:[0,.8,.6],alpha:.75});
 for(let i=0;i<14;i++){const x=212+i*13,y=568-i*6+Math.sin(i*.6)*12;p.stroke(`M${x-9},${y}l20,5`,c.shadow,1,{alpha:.45});}
 p.ellipse(331+dx,420+dy,105,35,{mat:'void',color:mix(c.dark,c.mid,.18)});
 p.ellipse(516,464,65,25,{mat:'void',color:mix(c.dark,c.mid,.18)});
 shelter(p,316+dx,376+dy,.97);
 shelter(p,509+dx*.2,439,.61);
 // Riparian fabric screens bend around poles, with a working drying rack.
 banner(p,560,487,170,{seed:p.seed+9});
 p.stroke('M179,459L177,380M239,460L239,377M177,385Q206,397 239,385',c.light,2,{mat:'metal'});
 for(let i=0;i<4;i++){const x=182+i*14;p.paint(`M${x},388L${x+9},391L${x+7},435Q${x+1},440 ${x-2},431Z`,[x-4,385,x+12,443],{mat:'cloth',color:mix(c.light,c.mid,.6),height:drape({top:385,bottom:440,cx:x+4,width:7,seed:p.seed+i,depth:2,folds:2})});}
 p.paint('M157,473Q188,445 235,459L235,490Q191,515 157,495Z',[154,440,239,520],{mat:'stone',color:mix(c.mid,c.light,.4),normal:[0,.7,.7]});
 p.stroke('M156,473L158,436M235,461L233,421',c.shadow,4);
 p.paint('M158,435Q191,450 233,420L246,445Q197,481 148,459Z',[145,416,250,485],{mat:'cloth',color:mix(c.light,c.mid,.4),height:(x,y)=>8*Math.sin((x+y*.6)*.06),texture:.2});
 pool(p,440+dx,527,78,46);
 // The outflow is painted as a falling sheet and horizontal spreading ripples.
 p.stroke(`M${510+dx},529C${562+dx},550 542,604 598,651`,mix(c.shadow,c.glow,.25),11,{mat:'water',normal:[-.2,.3,1]});
 p.stroke(`M${510+dx},528C${558+dx},548 541,604 597,647`,mix(c.light,c.glow,.3),2,{mat:'water',alpha:.65});
 stairs(p,262,539,56,9,-7,8);
 for(let i=0;i<7;i++)jar(p,333+i%3*16,452+Math.floor(i/3)*13,.55+r()*.15);
 for(let i=0;i<5;i++){const x=572+i*11,y=559-i*3;p.stroke(`M${x},${y}l-2,-${37+r()*18}`,c.mid,3,{mat:'stone'});p.stroke(`M${x-3},${y-25}l7,-2`,c.light,1);}
 inhabitant(p,362,482,1.2,true);inhabitant(p,403,579,1.3);inhabitant(p,525,491,1.1);inhabitant(p,247,576,1.15,true);
 lantern(p,338,453,.8);lantern(p,490,562,.7);
 for(let i=0;i<16;i++){const x=140+r()*510,y=616+r()*60;p.stroke(`M${x},${y}q14,6 33,-1`,mix(c.mid,c.light,.5),.9,{mat:'water',alpha:.3});}
 return {construction:'岩岸潮池与观潮聚所',layout:{dx,dy,terrace},activities:['观潮','晒网','储存供物','沿阶汲水'],view:'约45°斜俯视二维绘景'};
}
function tower(p,x,y,s,seed){
 p.group(x,y,s,()=>{const c=p.p;
  p.paint('M-38,12Q-32,-51 -30,-139L28,-151Q34,-54 39,-6Q14,31 -38,12Z',[-43,-156,44,34],{mat:'sand',color:mix(c.mid,c.light,.58),height:(x,y)=>22*Math.exp(-x*x/1300)+2*Math.sin(y*.09),texture:.16,pigment:(x,y)=>.7+.3*fbm(x*.05,y*.04,seed)});
  p.paint('M-38,-135Q-39,-165 -4,-187Q31,-175 35,-150L34,-137Q1,-123 -38,-135Z',[-44,-191,40,-121],{mat:'sand',color:mix(c.light,c.mid,.16),height:(x,y)=>22*Math.exp(-x*x/1800-(y+149)**2/1500),texture:.15});
  for(let i=0;i<4;i++){const yy=-116+i*32;p.paint(`M-8,${yy+16}L-8,${yy}Q-2,${yy-13} 5,${yy-4}L7,${yy+12}Z`,[-10,yy-15,10,yy+19],{mat:'void',color:c.dark});p.stroke(`M-25,${yy+26}Q3,${yy+34} 30,${yy+17}`,c.shadow,1,{alpha:.45});}
  p.stroke('M-28,-145Q-10,-137 27,-146',c.light,3);
 });
}
function city(p,r){
 const c=p.p,dx=(r()-.5)*34,dy=(r()-.5)*14;
 // Wind erodes an elongated shelf, unlike the drowned circular cove.
 const pts=[[93,508],[131,432],[225,397],[274,345],[391,344],[452,377],[565,403],[634,453],[644,528],[590,589],[468,636],[349,642],[271,605],[161,586]],land=smoothPath(pts),low=smoothPath(pts.map(([x,y],i)=>[x+(i%2?8:-6),y+48]));
 terrain(p,low,[75,332,671,704],{sand:true,color:mix(c.mid,c.light,.42)});
 terrain(p,land,[75,330,665,653],{sand:true,top:true,color:mix(c.mid,c.light,.6)});
 for(let i=0;i<11;i++){const y=581+i*7;p.stroke(`M${136+i*5},${y}Q330,${y+53} ${611-i*7},${y-22}`,mix(c.mid,c.shadow,.15),1,{alpha:.45});}
 tower(p,506+dx,341,.95,p.seed);tower(p,302+dx,322,.74,p.seed+7);
 // Back sanctuary and enclosing arcade differ in mass, material and use from tide.
 shelter(p,420+dx,385+dy,1.05,{city:true});
 for(let i=0;i<4;i++){
  const x=166+i*34,y=428-i*13;
  p.paint(`M${x-13},${y+63}L${x-11},${y-9}Q${x+8},${y-27} ${x+25},${y-14}L${x+24},${y+49}L${x+16},${y+52}L${x+16},${y+1}Q${x+7},${y-13} ${x-3},${y+3}L${x-4},${y+60}Z`,[x-16,y-29,x+28,y+66],{mat:'sand',color:mix(c.mid,c.light,.62),height:(xx,yy)=>7*Math.sin(xx*.13),texture:.15});
 }
 p.stroke('M147,420Q211,407 297,363',mix(c.light,c.mid,.2),12,{normal:[0,.8,.6]});
 // A broad fabric canopy casts a dark pool and makes a place for recording rites.
 p.ellipse(274,480,83,44,{mat:'void',color:mix(c.dark,c.shadow,.25)});
 for(const[x,y]of[[185,485],[298,449],[347,497]])p.stroke(`M${x},${y}l0,-91`,mix(c.light,c.shadow,.5),3,{mat:'metal'});
 const canopy='M185,394Q247,414 298,358Q309,409 347,406L352,437Q274,484 179,423Z';
 p.paint(canopy,[173,354,358,489],{mat:'cloth',color:mix(c.light,'#dfc58c',.38),height:(x,y)=>12*Math.sin((x-184)*.04)+7*Math.sin((y-395)*.08),texture:.1});
 for(let i=0;i<6;i++)p.stroke(`M${188+i*25},${398-i*3}Q${217+i*21},441 ${188+i*28},435`,mix(c.mid,c.light,.2),1.4,{mat:'cloth',alpha:.6});
 // Lower court: sealed cistern, writing tables, stacked folios, steps and votive lamps.
 pool(p,455,531,58,36,{tide:false});
 stairs(p,351,576,72,8,-7,7);
 for(let i=0;i<3;i++){
  const x=223+i*36,y=503+i*12;
  p.stroke(`M${x-13},${y+3}l0,16M${x+19},${y}l0,14`,c.shadow,3);
  p.paint(`M${x-17},${y}l27,-11l17,9l-29,12Z`,[x-20,y-14,x+31,y+15],{mat:'paper',color:mix(c.light,'#e7d1a7',.4),normal:[0,.8,.6]});
  for(let j=0;j<4;j++)p.stroke(`M${x-7+j*4},${y-1}l12,-4`,c.shadow,.7,{mat:'paper'});
 }
 for(let i=0;i<5;i++)jar(p,520+i%2*22,472+Math.floor(i/2)*16,.7);
 banner(p,567,499,144,{city:true,seed:p.seed+3});
 inhabitant(p,294,526,.86,true);inhabitant(p,330,495,.8);inhabitant(p,473,585,.95,true);inhabitant(p,381,449,.7);
 lantern(p,410,551,.8);lantern(p,513,564,.85);
 // Wind tracks are confined to exposed paving and ledges, never copied to cloth.
 for(let i=0;i<18;i++){const x=125+r()*485,y=594+r()*55;p.stroke(`M${x},${y}q18,7 38,-2`,mix(c.light,c.mid,.3),.8,{alpha:.45});}
 return {construction:'风蚀拱廊、抄录庭院与封存水井',layout:{dx,dy},activities:['抄录','封卷','持灯守候','积沙清扫'],view:'约45°斜俯视二维绘景'};
}
export function drawCult(config){const p=new Paint(config),r=rng(config.seed*491+config.archetype*781);if(![0,7].includes(config.archetype))throw Error('本轮只实现原型0与7；其他原型仅完成算法研究。');return {p,features:config.archetype===0?tide(p,r):city(p,r)};}
