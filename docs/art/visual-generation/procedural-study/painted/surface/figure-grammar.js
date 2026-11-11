import {foldField,mix,clamp} from './engine.js';
import {mapPath} from './design-space.js';

// Semantic gesture constraints define wrist targets and occlusion. Each sleeve
// is ONE draped contour from shoulder to cuff, never two joined shaded tubes.
export const GESTURES=['offering','appeal','prayer','staff','folded','cradle'];
export const GESTURE_NAMES={entreat:'伸掌求援',bargain:'摊掌陈情',offering:'双手奉潮',appeal:'抚胸伸掌',prayer:'合掌求援',staff:'持杖求告',folded:'拢臂守望',cradle:'抱持潮录',injured:'护住伤手',guarded:'收臂戒备'};
export const GARMENTS=['crosswrap','mantle','tabard','coat'];
export const GARMENT_NAMES={crosswrap:'交襟束腰衣',mantle:'宽披肩长袍',tabard:'垂带祭衣',coat:'敞襟长衣'};

function hand(p,w,angle,scale,kind,C){
 const c=Math.cos(angle),s=Math.sin(angle),to=(x,y)=>[w[0]+scale*(x*c-y*s),w[1]+scale*(x*s+y*c)],local=(x,y)=>[((x-w[0])*c+(y-w[1])*s)/scale,(-(x-w[0])*s+(y-w[1])*c)/scale];
 const contour=kind==='palm'?'M-12 7 Q-19 -2 -16 -17 L-25 -29 Q-28 -36 -22 -35 L-10 -25 L-8 -45 Q-7 -51 -3 -49 L2 -29 L3 -51 Q6 -57 10 -51 L12 -28 L17 -47 Q21 -51 24 -46 L22 -24 L28 -40 Q33 -43 34 -37 L29 -10 Q26 8 13 12Z':
  kind==='prayer'?'M-12 6 Q-15 -6 -10 -22 L0 -53 Q3 -58 6 -54 L7 -28 L12 -49 Q15 -52 18 -48 L16 -23 L21 -41 Q25 -44 27 -39 L23 -16 Q28 -19 31 -15 Q33 -10 25 -2 L12 9Z':
  kind==='fist'?'M-13 7 Q-21 -4 -17 -16 Q-11 -23 4 -23 L21 -20 Q28 -17 25 -11 Q31 -7 25 -2 Q29 3 22 7 L6 10 Q-2 17 -10 10Z':
  'M-13 5 Q-14 -5 -8 -17 L5 -37 Q8 -41 12 -37 L8 -23 L19 -36 Q23 -39 26 -35 L17 -19 L29 -29 Q33 -32 35 -28 L24 -13 L33 -21 Q38 -23 38 -18 L26 -2 Q16 11 4 10Z';
 const corners=[to(-32,-62),to(45,-62),to(45,22),to(-32,22)],box=[Math.min(...corners.map(v=>v[0])),Math.min(...corners.map(v=>v[1])),Math.max(...corners.map(v=>v[0])),Math.max(...corners.map(v=>v[1]))];
 p.surface(mapPath(contour,to),box,{mat:'skin',color:mix(C.copper,'#b99b7e',.68),shadow:'#5b5145',accent:'#cdb58d',bump:.35,exposure:.76,normal:[-.15,-.08,1],height:(x,y)=>{const[u,v]=local(x,y);return 3*Math.exp(-(u*u/380+(v+8)**2/530));}});
 for(const line of kind==='fist'?['M-7 -13 Q8 -9 23 -12','M-7 -6 Q6 -3 23 -4','M-6 1 Q6 5 20 4']:['M-5 -13 Q4 -6 14 -10','M7 -24 L13 -16','M17 -17 L22 -12'])p.line(mapPath(line,to),'#645848',.9,.55);
 p.stroke(mapPath('M-8 -6 Q-5 2 5 4',to),'#cdbd98',1.2,.55);
}

function sleeve(p,S,E,W,side,volume,C,material,civilian=false,rolled=false){
 if(rolled){
  const dx=W[0]-E[0],dy=W[1]-E[1],l=Math.hypot(dx,dy),nx=-dy/l*16,ny=dx/l*16,mid=[E[0]+dx*.42,E[1]+dy*.42];
  p.surface(`M${mid[0]+nx*1.2} ${mid[1]+ny*1.2} C${mid[0]+dx*.23+nx*1.3} ${mid[1]+dy*.23+ny*1.3} ${W[0]-dx*.16+nx*.85} ${W[1]-dy*.16+ny*.85} ${W[0]+nx*.85} ${W[1]+ny*.85} Q${W[0]+dx*.04} ${W[1]+dy*.04} ${W[0]-nx*.85} ${W[1]-ny*.85} C${W[0]-dx*.18-nx*.8} ${W[1]-dy*.18-ny*.8} ${mid[0]+dx*.24-nx*1.3} ${mid[1]+dy*.24-ny*1.3} ${mid[0]-nx*1.1} ${mid[1]-ny*1.1}Z`,[Math.min(mid[0],W[0])-29,Math.min(mid[1],W[1])-29,Math.max(mid[0],W[0])+29,Math.max(mid[1],W[1])+29],{mat:'skin',color:mix(C.copper,'#b99b7e',.68),shadow:'#5b5145',normal:[side*.28,-.18,1],height:(x,y)=>{const cross=((x-mid[0])*dy-(y-mid[1])*dx)/l,along=((x-mid[0])*dx+(y-mid[1])*dy)/l;return 7*Math.exp(-((cross/21)**2))*(1-along/l*.2);},exposure:.76});
  W=mid;
 }
 const dx=W[0]-E[0],dy=W[1]-E[1],len=Math.hypot(dx,dy);let n=[-dy/len,dx/len];if(n[1]<0)n=n.map(v=>-v);
 const cuff=18+volume*.075,A=civilian?(side<0?[372,346]:[491,345]):[S[0]-side*35,S[1]-30],B=[S[0]-side*45,S[1]+84],O=[W[0]+n[0]*cuff,W[1]+n[1]*cuff],I=[W[0]-n[0]*cuff,W[1]-n[1]*cuff],drop=32+volume*.55;
 const inward=dx*side<0,dropX=E[0]+side*(inward?-12:27),bendX=E[0]+side*(inward?-43:55);
 const d=`M${A} C${S[0]+side*40} ${S[1]+5} ${E[0]+side*44} ${E[1]-35} ${E[0]+side*40} ${E[1]+8} Q${E[0]+side*35} ${E[1]+drop} ${dropX} ${E[1]+drop} C${bendX} ${E[1]+drop} ${O[0]-dx*.23} ${O[1]-dy*.23+12} ${O} Q${W[0]+dx/len*4} ${W[1]+dy/len*4} ${I} Q${E[0]-side*26} ${E[1]-27} ${B} Q${S[0]-side*16} ${S[1]+12} ${A}Z`;
 const box=[Math.min(A[0],E[0]-65,W[0]-34)-8,A[1]-8,Math.max(A[0],E[0]+65,W[0]+34)+8,Math.max(E[1]+drop,W[1]+35)+8];
 const F=foldField([
  [A,[S[0]+side*38,S[1]+76],[E[0]+side*29,E[1]-8],[E[0]+side*20,E[1]+drop-8],18,7],
  [O,[W[0]-dx*.30,W[1]-dy*.30+20],[E[0]+10,E[1]+drop-6],[E[0]-side*7,E[1]+drop],15,13],
  [[I[0],I[1]+6],[W[0]-dx*.34,W[1]-dy*.34],[E[0]-side*4,E[1]+10],[E[0]+side*18,E[1]+drop-14],10,8],
  [[S[0]-side*9,S[1]+60],[S[0]-side*10,S[1]+103],[E[0]-side*18,E[1]-22],[E[0]-side*20,E[1]-3],13,-4]
 ],(x,y)=>6*Math.exp(-(((x-E[0])/97)**2)));
 p.surface(d,box,{...material,height:F,color:side<0?mix(C.cloth,C.linen,.09):C.cloth,normal:side<0?[-.12,0,1]:[.18,0,1],shadowField:()=>side<0?.98:.73,u:(x,y)=>x-y*.12});
 p.surface(`M${O} L${O[0]+dx/len*11} ${O[1]+dy/len*11} Q${W[0]+dx/len*18} ${W[1]+dy/len*18} ${I[0]+dx/len*11} ${I[1]+dy/len*11} L${I}Z`,[W[0]-38,W[1]-38,W[0]+38,W[1]+38],{...material,color:mix(C.cloth,C.linen,.48),height:(x,y)=>2*Math.sin((x*dx+y*dy)/len*.2),exposure:.85});
 p.stroke(`M${O[0]} ${O[1]} Q${W[0]+dx/len*5} ${W[1]+dy/len*5} ${I[0]} ${I[1]}`,C.salt,1.5,.45);
}

export function configureFigure(config,recipe,C){
 const d=recipe.dimensions,k=recipe.construction,gesture=k.gesture,garment=k.garment,f=d.presentation;
 const waist=132-f*32,hip=173+f*11,volume=k.civilian?10+d.sleeve*22:garment==='mantle'?75:garment==='coat'?25:42+d.sleeve*40;
 config.root=`M365 339 Q327 365 303 410 Q326 510 ${470-waist} 667 L${470-hip} 949 Q470 979 ${470+hip} 947 L${470+waist} 667 Q646 502 618 415 Q568 373 492 340Z`;
 config.rootBox=[285,333,670,965];config.suppressStole=true;
 config.rootHeight=foldField([[[369,383],[381,509],[470-waist+16,680],[470-hip+29,949],18,13],[[424,442],[442,555],[407,758],[425,960],20,15],[[491,410],[540,565],[510,771],[552,958],19,14],[[573,432],[595,551],[584,768],[620,948],14,10]],(x,y)=>26*Math.exp(-(((x-455)/148)**2))-.04*(x-430));
 const S=[[326,414],[610,422]],E=[[285-d.sleeve*6,591],[650+d.sleeve*7,599]];let W,angles,kinds;
 if(gesture==='entreat'){W=[[324,492],[520,516]];E[0]=[277,607];E[1]=[637,606];angles=[-.25,-.8];kinds=['palm','touch'];}
 else if(gesture==='bargain'){W=[[357,559],[514,488]];E[0]=[283,607];angles=[.85,-.6];kinds=['palm','touch'];}
 else if(gesture==='appeal'){W=[[350,637],[514,484]];angles=[1.28,-.7];kinds=['palm','touch'];}
 else if(gesture==='prayer'){W=[[467,516],[498,516]];E[0][1]=626;E[1][1]=629;angles=[.12,-.26];kinds=['prayer','prayer'];}
 else if(gesture==='staff'){W=[[442,573],[683,515]];E[1]=[641,628];angles=[.58,1.3];kinds=['touch','fist'];}
 else if(gesture==='folded'){W=[[509,563],[425,577]];angles=[1.5,-1.5];kinds=['touch','touch'];}
 else if(gesture==='cradle'){W=[[465,627],[529,521]];angles=[1.2,-2.2];kinds=['touch','touch'];}
 else if(gesture==='injured'){W=[[482,583],[503,555]];angles=[1.3,-.2];kinds=['touch','touch'];}
 else if(gesture==='guarded'){W=[[474,612],[508,501]];angles=[.9,-.6];kinds=['fist','touch'];}
 else {W=[[431,596],[530,596]];angles=[1.25,-1.25];kinds=['touch','touch'];}
 // The shared design-space map applies the continuous body/pose modulation.
 config.layers.underSleeves=(p,{dark,pale,bronze})=>{
  if(garment==='crosswrap'){
   p.surface(`M371 347 Q414 405 536 479 L${470+waist-10} 671 L${470+hip-17} 949 L${470-hip+32} 949 Q405 751 439 651 L513 487 Q398 450 340 396Z`,[325,341,654,960],{...pale,color:mix(C.cloth,C.linen,.4),height:foldField([[[365,372],[411,433],[491,454],[521,485],15,15],[[518,491],[490,566],[450,612],[447,659],17,13],[[441,683],[397,786],[370,863],[344,945],19,12]])});
   p.surface(`M${470-waist} 655 Q470 688 ${470+waist} 657 L${470+waist-4} 686 Q470 710 ${470-waist+3} 686Z`,[330,650,610,713],{...dark,color:C.violet,height:(x,y)=>4*Math.sin(y*.16)});
   p.surface('M496 681 Q517 710 503 808 L478 834 Q503 735 482 687Z',[475,677,520,840],{...dark,color:C.violet,height:foldField([[[491,690],[509,732],[490,775],[485,828],9,7]])});
  }else if(garment==='tabard'){
   for(const [x,w]of[[367,42+d.panel*.25],[516,35+d.panel*.2]])p.surface(`M${x} 366 Q${x+4} 516 ${x-14} 947 L${x+w} 957 Q${x+w-11} 570 ${x+w} 388Z`,[x-20,360,x+w+8,962],{...pale,color:C.violet,height:foldField([[[x+13,390],[x+16,545],[x+8,773],[x+9,949],11,10],[[x+w-7,405],[x+w-11,550],[x+w-8,764],[x+w-7,951],8,7]])});
  }else if(garment==='coat'){
   p.surface('M412 370 Q448 391 498 370 L540 955 L392 953Z',[387,365,546,960],{...pale,color:mix(C.violet,C.linen,.36),height:foldField([[[432,406],[452,571],[428,774],[433,951],12,10],[[479,407],[491,610],[487,777],[506,952],12,11]])});
   for(const[x,s]of[[402,-1],[512,1]]){p.surface(`M${x} 351 L${x+s*34} 390 L${x+s*17} 463 L${x+s*61} 945 L${x+s*22} 951 L${x-s*15} 449Z`,[Math.min(x-55,x+s*65),345,Math.max(x+55,x+s*65),958],{...dark,color:mix(C.cloth,C.linen,.23),height:foldField([[[x,376],[x+s*7,452],[x+s*22,687],[x+s*45,949],12,10]])});}
  }else{
   p.surface(`M345 355 Q417 326 479 350 Q571 369 618 418 L653 ${495+d.mantle*.6} Q564 ${576+d.mantle*.3} 462 484 Q363 563 283 478Z`,[275,325,659,635],{...pale,color:mix(C.cloth,C.linen,.38),height:foldField([[[349,375],[361,424],[388,489],[425,508],17,15],[[443,366],[474,436],[530,505],[620,536],20,18],[[530,387],[570,441],[590,495],[642,512],12,11]])});
  }
 };
 config.collar=(p,{dark,pale,bronze})=>{
  if(garment==='mantle'){
   p.surface('M361 322 Q429 348 491 339 Q553 371 600 408 L573 450 Q474 426 383 387 L330 418Z',[324,317,606,457],{...pale,color:C.linen,height:foldField([[[367,336],[405,382],[489,397],[583,429],16,14],[[350,364],[405,397],[474,418],[559,437],10,11]])});
  }else if(garment==='crosswrap'){
   p.surface('M363 324 Q395 356 459 384 L542 433 L523 458 Q403 414 348 368Z',[343,319,547,464],{...pale,height:foldField([[[366,338],[401,380],[464,402],[531,443],12,13]])});
   p.surface('M485 336 Q473 371 422 414 L401 398 Q447 358 453 330Z',[396,325,490,419],{...pale,color:mix(C.linen,C.cloth,.3),height:foldField([[[472,345],[458,373],[439,389],[412,405],10,10]])});
  }else{
   p.surface('M365 326 Q426 349 491 326 L517 377 Q443 415 350 369Z',[345,321,523,420],{...pale,color:C.linen,height:foldField([[[365,342],[416,378],[466,378],[507,365],14,13],[[370,364],[415,397],[467,392],[506,378],9,8]])});
  }
  p.surface('M364 390 Q377 382 386 394 L382 415 Q370 423 363 409Z',[358,378,391,428],{...bronze,height:(x,y)=>3*Math.exp(-(((x-375)/9)**2)),exposure:.75});
 };
 config.arms=(p,{dark,bronze})=>{
  // Staff is behind its gripping hand and connects well above and below it.
  if(gesture==='staff'){
   p.surface('M688 335 Q693 326 697 335 L692 932 L683 934Z',[678,324,702,940],{...bronze,color:mix(C.copper,C.clothShadow,.36),height:(x)=>3*Math.exp(-(((x-690)/4)**2)),exposure:.7});
   p.line('M691 341 Q668 323 682 300 Q704 285 715 309 Q723 328 701 337',C.copper,7,.9);p.stroke('M681 307 Q696 290 707 308',C.salt,2,.7);
  }
  if(gesture==='cradle'){
   p.surface('M451 472 L563 493 L548 642 L433 618Z',[428,466,570,649],{mat:'cloth',color:mix(C.linen,C.copper,.24),shadow:C.linenShadow,accent:C.salt,height:(x,y)=>3*Math.sin((x+y*.15)*.13),exposure:.8});
   p.stroke('M460 484 L551 501 L537 626 L445 609Z',C.copper,2,.7);for(let i=0;i<8;i++)p.line(`M463 ${508+i*11}l69,13`,C.clothShadow,1,.65);
  }
  const armMaterial=k.civilian?{...dark,mat:config.sleeveMaterial||'cloth'}:dark;
  sleeve(p,S[0],E[0],W[0],-1,volume,C,armMaterial,k.civilian,config.rolledSleeves);sleeve(p,S[1],E[1],W[1],1,volume,C,armMaterial,k.civilian,config.rolledSleeves);
 };
 const offering=config.drawObject;
 config.handwork=(p,{bronze,pale,dark})=>{
  if(gesture==='offering'){
   if(offering)offering(p,{bronze,pale,dark});else{
    p.surface('M425 564 Q480 548 538 564 L525 608 Q480 630 438 606Z',[420,545,544,633],{...bronze,color:C.copper,height:(x)=>7*Math.exp(-(((x-480)/52)**2)),normal:[0,.2,1]});
    p.surface('M425 564 C425 542 538 542 538 564 C538 585 425 585 425 564Z',[419,540,544,589],{mat:'water',color:'#72cba1',shadow:'#09262e',cx:480,cy:564,v:(x,y)=>564+(y-564)*3,emission:.13,normal:[0,-.8,.6],bump:.35});p.glow(480,564,55,C.light,.1);
   }
   // Wrapped palms on opposite sides; fingers stay grouped against the vessel.
   hand(p,[434,601],1.2,.84,'touch',C);hand(p,[527,602],-1.2,.84,'touch',C);
  }else if(gesture==='prayer'){
   const skin={mat:'skin',color:mix(C.copper,'#b99b7e',.68),shadow:'#5b5145',accent:'#cdb58d',bump:.35,exposure:.7};
   p.surface('M456 526 Q451 510 458 493 L476 460 Q479 451 484 455 Q487 459 484 470 L478 491 L488 472 Q491 465 495 469 Q499 474 490 490 L487 513 L477 532Z',[447,447,503,537],{...skin,normal:[-.2,-.06,1],height:foldField([[[480,461],[472,480],[464,495],[464,518],4,2.3],[[490,473],[484,488],[480,503],[479,520],4,2]])});
   p.surface('M482 524 Q492 502 490 486 L485 460 Q485 454 489 453 Q494 453 497 461 L512 488 Q519 500 515 516 L505 533Z',[477,447,524,539],{...skin,normal:[.25,0,1],exposure:.58,height:foldField([[[491,461],[495,478],[503,497],[502,520],5,2.6]])});
   p.stroke('M487 468 Q490 482 490 496 Q488 511 482 522',C.clothShadow,1.2,.6);
   p.stroke('M462 505 Q469 488 476 477',C.salt,1,.5);
   p.line('M493 493 Q503 490 509 498',C.clothShadow,.8,.5);
  }else if(gesture==='folded'){
   hand(p,[499,558],1.4,d.handScale*.82,'touch',C);
   p.surface('M415 550 Q441 530 475 548 L491 587 Q451 611 420 590Z',[408,525,497,618],{...dark,color:mix(C.cloth,C.linen,.2),height:foldField([[[421,560],[445,550],[463,566],[480,583],12,10]])});
  }else for(let i=0;i<2;i++)hand(p,W[i],angles[i],d.handScale,kinds[i],C);
 };
 if(gesture!=='offering')config.emitters=[];
 return {shoulders:S,elbows:E,wrists:W,gesture:GESTURE_NAMES[gesture],garment:GARMENT_NAMES[garment]};
}
