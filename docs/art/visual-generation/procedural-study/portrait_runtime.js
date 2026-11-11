// REJECTED EXPERIMENT: not connected to the live generator; see 本轮独立美术审查.md.
// Runtime direct-2D portrait assembly. Random choices are per-character, not
// pre-rendered images; proportions and gesture joints are continuous variables.
import {random} from './paint.js';
const heads=['深兜帽','长面纱','折边头巾','高领遮面'];
const poses=['双手祈求','一手按胸','持杖求告','低手祈求'];
const garments=['交领长衣','披肩长袍','斜襟罩衣'];
const archetypeMotif=['潮历','遮目','缝线','菌纹','余烬','风雪','折光','见证','航迹','茧丝','骨牌'];
export function drawRuntimePerson(p,c){
 const personSeed=Number(c.personSeed),world=Number(c.seed),r=random((Math.imul(personSeed^0x52ca41f1,2654435761)^Math.imul(world,1597334677)^c.archetype)>>>0);
 const range=(a,b)=>a+(b-a)*r(),pick=n=>Math.floor(r()*n),round=x=>Math.round(x*10)/10;
 const pose=pick(4),head=pick(4),garment=pick(3),turn=range(-.16,.16),shoulder=range(130,172),headWidth=range(65,84),headHeight=range(99,124),neckX=384+range(-23,23),neckY=282+range(-13,12),waist=shoulder*range(.55,.72),breastY=neckY+90,elbowY=neckY+range(139,179),wristY=neckY+range(185,232),tilt=range(-12,12),hoodRise=head===2?range(80,115):headHeight,handLight=.43;
 const F=(d,mat='cloth',light=.46,opt={})=>p.path(d,mat,{light,relief:.62,folds:.17,shadow:false,...opt});
 const E=(x,y,rx,ry,mat='cloth',light=.45)=>p.ellipse(x,y,rx,ry,mat,{light,relief:.65,shadow:false});
 const L=(a,w=2,col=c.palette.shadow)=>p.stroke(a,col,w);
 // Coordinate choices preserve shoulder -> elbow -> wrist continuity.
 const leftShoulder=[neckX-shoulder,neckY+42+tilt],rightShoulder=[neckX+shoulder,neckY+42-tilt];
 const leftElbow=[neckX-shoulder-15,elbowY],rightElbow=[neckX+shoulder+13,elbowY-10];
 let leftWrist,rightWrist;
 if(pose===0){leftWrist=[neckX-25,wristY];rightWrist=[neckX+28,wristY-8];}
 else if(pose===1){leftWrist=[neckX-45,wristY+45];rightWrist=[neckX+14,neckY+108];}
 else if(pose===2){leftWrist=[neckX-34,wristY+32];rightWrist=[neckX+shoulder+38,wristY+10];}
 else{leftWrist=[neckX-55,wristY+48];rightWrist=[neckX+55,wristY+48];}
 // Organic tapered sleeve shape between anatomical joints; curved ends avoid
 // treating limbs as rigid triangles and the far arm sits behind the torso.
 function sleeve(a,b,ra,rb,light){let vx=b[0]-a[0],vy=b[1]-a[1],len=Math.hypot(vx,vy),nx=-vy/len,ny=vx/len;let A=[a[0]+nx*ra,a[1]+ny*ra],B=[b[0]+nx*rb,b[1]+ny*rb],C=[b[0]-nx*rb,b[1]-ny*rb],D=[a[0]-nx*ra,a[1]-ny*ra],mx=(a[0]+b[0])/2,my=(a[1]+b[1])/2;F(`M ${A[0]} ${A[1]} Q ${mx+nx*(ra+rb)*.51} ${my+ny*(ra+rb)*.51} ${B[0]} ${B[1]} Q ${b[0]+vx*.05} ${b[1]+vy*.05} ${C[0]} ${C[1]} Q ${mx-nx*(ra+rb)*.51} ${my-ny*(ra+rb)*.51} ${D[0]} ${D[1]} Q ${a[0]-vx*.04} ${a[1]-vy*.04} ${A[0]} ${A[1]} Z`,'cloth',light);}
 // Back mantle: asymmetry, arm openings and open bottom; no closed jar shape.
 let hemL=neckX-waist-range(0,25),hemR=neckX+waist+range(0,25);
 F(`M ${neckX-44} ${neckY-15} Q ${neckX-91} ${neckY+5} ${leftShoulder[0]-20} ${leftShoulder[1]+3} Q ${leftShoulder[0]-45} ${neckY+118} ${leftShoulder[0]-18} ${neckY+210} L ${hemL-50} 752 L ${neckX+turn*100} 768 L ${hemR+58} 752 L ${rightShoulder[0]+26} ${neckY+212} Q ${rightShoulder[0]+47} ${neckY+126} ${rightShoulder[0]+14} ${rightShoulder[1]} Q ${neckX+90} ${neckY+4} ${neckX+42} ${neckY-15} Z`,'cloth',.25,{shade:.13});
 // Upper arms emerge from shoulder masses and bend at their elbows.
 sleeve(leftShoulder,leftElbow,36,34,.36);sleeve(rightShoulder,rightElbow,36,33,.29);
 // Torso tapers at waist and is cut by the frame; neck and collar sit above it.
 F(`M ${neckX-57} ${neckY+4} Q ${neckX-100} ${neckY+15} ${leftShoulder[0]+12} ${leftShoulder[1]+16} Q ${neckX-shoulder*.75} ${breastY+65} ${neckX-waist} ${breastY+166} L ${hemL} 768 L ${hemR} 768 L ${neckX+waist} ${breastY+166} Q ${neckX+shoulder*.76} ${breastY+60} ${rightShoulder[0]-14} ${rightShoulder[1]+16} Q ${neckX+97} ${neckY+14} ${neckX+55} ${neckY+4} Z`,'cloth',.40);
 // A second garment is a large anatomical wrap, not a band across the entire figure.
 if(garment===0){F(`M ${neckX-82} ${neckY+20} Q ${neckX-48} ${neckY+49} ${neckX-10} ${neckY+64} L ${neckX+waist*.8} ${breastY+177} L ${neckX+waist*.25} 768 L ${neckX-waist*.4} 768 L ${neckX+12} ${neckY+81} Q ${neckX-70} ${neckY+63} ${neckX-82} ${neckY+20} Z`,'cloth',.53,{opacity:.72});}
 else if(garment===1){F(`M ${leftShoulder[0]+12} ${leftShoulder[1]} Q ${neckX-80} ${neckY-4} ${neckX-42} ${neckY+3} Q ${neckX+8} ${neckY+52} ${rightShoulder[0]-8} ${rightShoulder[1]} Q ${rightShoulder[0]-28} ${neckY+98} ${neckX+44} ${neckY+117} Q ${neckX-24} ${neckY+103} ${leftShoulder[0]+12} ${leftShoulder[1]} Z`,'cloth',.54);}
 else{F(`M ${neckX+58} ${neckY+9} Q ${neckX+112} ${neckY+39} ${rightShoulder[0]-7} ${rightShoulder[1]+15} L ${neckX+waist*.85} 744 L ${neckX+waist*.15} 768 Q ${neckX+26} ${neckY+218} ${neckX-67} ${neckY+56} Z`,'cloth',.50,{opacity:.8});}
 // Neck and head occupy a realistic proportion of shoulder width.
 F(`M ${neckX-32} ${neckY-32} L ${neckX+30} ${neckY-32} L ${neckX+39} ${neckY+18} Q ${neckX} ${neckY+44} ${neckX-39} ${neckY+18} Z`,'cloth',.3);
 let hx=neckX+turn*55,hy=neckY-headHeight*.7,hw=headWidth,hh=hoodRise;
 if(head===0){F(`M ${hx-hw-15} ${hy+35} Q ${hx-hw-20} ${hy-hh*.45} ${hx-30} ${hy-hh*.78} Q ${hx+4} ${hy-hh} ${hx+hw*.7} ${hy-hh*.55} Q ${hx+hw+26} ${hy-hh*.12} ${hx+hw+12} ${hy+50} Q ${hx+hw*.7} ${hy+95} ${hx} ${hy+99} Q ${hx-hw*.8} ${hy+95} ${hx-hw-15} ${hy+35} Z`,'cloth',.43);}
 else if(head===1){F(`M ${hx-hw-12} ${hy+25} Q ${hx-hw} ${hy-hh*.7} ${hx} ${hy-hh*.75} Q ${hx+hw} ${hy-hh*.7} ${hx+hw+7} ${hy+25} L ${hx+hw+34} ${neckY+125} Q ${hx} ${neckY+91} ${hx-hw-25} ${neckY+125} Z`,'cloth',.49);}
 else if(head===2){F(`M ${hx-hw-12} ${hy+25} Q ${hx-hw-6} ${hy-hh*.45} ${hx} ${hy-hh*.55} Q ${hx+hw} ${hy-hh*.44} ${hx+hw+6} ${hy+25} L ${hx+hw*.8} ${hy+81} Q ${hx} ${hy+102} ${hx-hw*.8} ${hy+81} Z`,'cloth',.4);F(`M ${hx-hw-26} ${hy-5} Q ${hx} ${hy-hh*.62} ${hx+hw+29} ${hy-5} Q ${hx+9} ${hy-20} ${hx-hw-26} ${hy-5} Z`,'cloth',.60);}
 else{F(`M ${hx-hw-4} ${hy+45} Q ${hx-hw-8} ${hy-hh*.45} ${hx} ${hy-hh*.72} Q ${hx+hw+8} ${hy-hh*.43} ${hx+hw+2} ${hy+45} L ${hx+hw*.7} ${hy+80} L ${hx-hw*.7} ${hy+80} Z`,'cloth',.41);}
 // Hollow face is permitted, but its opening changes with head and angle.
 F(`M ${hx-hw*.66} ${hy+8} Q ${hx-hw*.5} ${hy-hh*.37} ${hx+hw*.10} ${hy-hh*.35} Q ${hx+hw*.64} ${hy-hh*.32} ${hx+hw*.67} ${hy+12} Q ${hx+hw*.57} ${hy+64} ${hx+hw*.14} ${hy+72} Q ${hx-hw*.50} ${hy+70} ${hx-hw*.66} ${hy+8} Z`,'void',.12);
 F(`M ${hx-hw*.78} ${hy+4} Q ${hx-hw*.63} ${hy-hh*.55} ${hx} ${hy-hh*.55} Q ${hx+hw*.7} ${hy-hh*.53} ${hx+hw*.83} ${hy+7} Q ${hx+hw*.49} ${hy-hh*.25} ${hx} ${hy-hh*.26} Q ${hx-hw*.49} ${hy-hh*.26} ${hx-hw*.78} ${hy+4} Z`,'cloth',.57);
 if(head===3){F(`M ${neckX-88} ${neckY-7} Q ${neckX} ${neckY+32} ${neckX+88} ${neckY-7} L ${neckX+76} ${neckY+39} Q ${neckX} ${neckY+63} ${neckX-76} ${neckY+39} Z`,'cloth',.55);}
 // Front forearms overlap torso; wrists end where hands or implements begin.
 sleeve(leftElbow,leftWrist,34,23,.45);sleeve(rightElbow,rightWrist,33,23,.38);
 // Grouped glove/palm silhouettes without individually drawn stick fingers.
 for(const [x,y] of [leftWrist,rightWrist]){F(`M ${x-15} ${y-11} Q ${x-3} ${y-18} ${x+10} ${y-10} Q ${x+19} ${y-2} ${x+12} ${y+11} Q ${x+2} ${y+18} ${x-11} ${y+10} Z`,'skin',handLight);}
 if(pose===2){F(`M ${rightWrist[0]-3} ${rightWrist[1]-170} L ${rightWrist[0]+4} ${rightWrist[1]-171} L ${rightWrist[0]+6} 750 L ${rightWrist[0]-2} 750 Z`,'roof',.46);E(rightWrist[0],rightWrist[1]-175,10,10,'metal',.6);}
 // World-specific construction rather than a single attached icon.
 const a=c.archetype;
 if(a===2||a===9){for(let i=0;i<5;i++){let y=neckY+35+i*17;L([[neckX-70,y],[neckX-45,y+9]],2,c.palette.light);L([[neckX-62,y-3],[neckX-56,y+10]],1.5,c.palette.dark);}}
 if(a===3){for(let i=0;i<3;i++){let x=neckX-80+i*19;E(x,neckY+30+i*3,5,3,'glow',.5);}}
 if(a===4){for(let i=0;i<3;i++)L([[neckX+40+i*12,neckY+38],[neckX+48+i*12,neckY+56]],1.5,c.palette.glow);}
 if(a===5){F(`M ${neckX-73} ${neckY+15} Q ${neckX} ${neckY+52} ${neckX+73} ${neckY+15} L ${neckX+65} ${neckY+32} Q ${neckX} ${neckY+64} ${neckX-65} ${neckY+32} Z`,'paper',.55,{opacity:.7});}
 if(a===6){for(let i=0;i<3;i++){let x=neckX-58+i*50;F(`M ${x} ${neckY+30} l 10 16 l -9 19 l -10 -17 Z`,'metal',.6);}}
 if(a===7){F(`M ${neckX-90} ${neckY+43} l 20 6 l 0 24 l -20 -6 Z`,'paper',.5);}
 if(a===10){for(let i=0;i<4;i++){let x=neckX-57+i*34;E(x,neckY+39,5,8,'paper',.52);}}
 return {features:{template:c.template,archetype:a,worldSeed:world,personSeed,pose:poses[pose],head:heads[head],costume:garments[garment],motif:{motif:archetypeMotif[a]},shoulderWidth:round(shoulder*2),headWidth:round(headWidth*2),bodyTurn:round(turn),leftShoulder,leftElbow,leftWrist,rightShoulder,rightElbow,rightWrist}};
}
