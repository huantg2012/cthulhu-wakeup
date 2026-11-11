import {foldField,mix,clamp} from './engine.js';
import {vectorEllipse} from './design-space.js';

export const OUTFIT_NAMES={oilcoat:'防潮短外衣',jerkin:'工作马甲与衬衣',waistcoat:'排扣背心与衬衣',workshirt:'日常衬衣',apron:'皮围裙与工作衫',tailored:'挺括翻领外衣',drivercoat:'车夫短外套'};
export const HEAD_NAMES={workcap:'劳作软帽',brim:'压低帽檐',short_hair:'短发与面部阴影',tiedhair:'束发与面部阴影',swept_hair:'侧分发与面部阴影'};

// Occupation restricts useful cuts/materials. A new drawing is constructed from
// these rules each run; no profession selects a finished portrait or uniform.
export function configureCivilian(config,recipe,C){
 const d=recipe.dimensions,k=recipe.construction,b=recipe.background,waist=137-d.presentation*27,hip=164+d.presentation*16,hem=743+d.hem*57;
 const F=foldField([[[377,400],[392,509],[363,639],[369,hem],18,11],[[439,425],[465,540],[424,647],[446,hem],18,12],[[545,418],[566,532],[552,670],[580,hem],19,13]],(x,y)=>17*Math.exp(-(((x-449)/151)**2)));
 config.sleeveMaterial=['oilcoat','drivercoat'].includes(k.garment)?b.material:'cloth';
 config.root=`M372 346 Q354 365 343 412 Q348 531 ${470-waist} 664 L${470-hip} 949 Q465 968 ${470+hip} 949 L${470+waist} 664 Q590 512 568 416 Q539 375 491 345Z`;
 config.rootBox=[290,337,660,966];config.rootHeight=F;config.emitters=[];
 const cloth={mat:'cloth',color:C.cloth,shadow:C.clothShadow,accent:C.salt,salt:.1,bump:.7};
 config.layers.underSleeves=(p,{pale,bronze})=>{
  // Trousers are visibly separated from the short upper garment.
  p.surface(`M${470-waist} 697 Q470 726 ${470+waist} 699 L${470+hip} 949 Q545 968 480 945 L465 804 L456 950 Q365 967 ${470-hip} 948Z`,[290,690,658,964],{...cloth,color:mix(C.clothShadow,'#53574d',.48),height:foldField([[[389,740],[374,814],[370,886],[352,949],19,9],[[552,750],[568,824],[562,891],[585,951],21,10]]),exposure:.78});
  const shirt=`M370 347 Q356 366 350 416 Q350 541 ${470-waist+10} 668 L${470-waist-2} ${hem} Q449 ${hem+23} ${470+waist} ${hem-3} L${470+waist-10} 665 Q580 521 561 418 Q536 377 489 345Z`;
  p.surface(shirt,[299,340,640,hem+31],{...cloth,color:k.garment==='workshirt'?C.cloth:C.linen,height:F});
  p.shadow(`M${470-waist-1} ${hem} Q449 ${hem+23} ${470+waist} ${hem-3} L${470+waist} ${hem+8} Q441 ${hem+31} ${470-waist-3} ${hem+10}Z`,.33,2);
  // A shirt placket remains visible under open garments.
  p.stroke(`M461 394 Q474 532 465 ${hem-8}`,C.clothShadow,2,.5);
  for(let j=0;j<5;j++){let y=443+j*52;p.surface(vectorEllipse(466+Math.sin(j)*3,y,3.5,3.5),[458,y-6,474,y+6],{...bronze,color:C.copper,exposure:.7});}
  if(k.garment==='apron'){
   const a=374+d.panel*.12,r=561+d.panel*.1;
   p.surface(`M${a+12} 458 Q466 478 ${r-8} 460 L${r} ${hem+43} Q464 ${hem+67} ${a-12} ${hem+40}Z`,[a-18,452,r+8,hem+72],{mat:'leather',color:C.outer,shadow:mix(C.outer,C.clothShadow,.6),accent:C.salt,height:foldField([[[a+22,478],[a+3,579],[a+13,686],[a+3,hem+31],17,11],[[510,485],[532,600],[509,699],[529,hem+49],23,9]])});
   for(const x of[a+15,r-25])p.surface(`M${x} 458 L${x-14} 376 L${x+2} 374 L${x+16} 460Z`,[x-20,369,x+22,466],{mat:'leather',color:C.outer,shadow:C.clothShadow,height:(x,y)=>2*Math.sin(x*.11)});
   p.stroke(`M${a+27} 642 Q471 652 ${r-26} 641 L${r-31} 705 Q475 720 ${a+28} 706Z`,C.copper,2,.65);
  }else if(['jerkin','waistcoat'].includes(k.garment)){
   const bottom=k.garment==='jerkin'?hem-12:hem-54;
   for(const [l,r,side]of[[326,453,-1],[481,611,1]]){
    const vest=`M${side<0?376:487} 356 Q${side<0?349:544} 377 ${side<0?l+10:r-35} 426 L${side<0?l+20:r-18} ${bottom} L${side<0?r+10:l-8} ${bottom+20} Q${side<0?461:470} 543 ${side<0?431:496} 418Z`;
    p.surface(vest,[l-8,349,r+17,bottom+28],{mat:k.garment==='jerkin'?'leather':'cloth',color:C.outer,shadow:C.clothShadow,accent:C.salt,height:foldField([[[side<0?355:575,408],[side<0?367:568,515],[side<0?370:560,628],[side<0?368:572,bottom],16,10]])});
   }
   p.line(`M440 431 Q459 535 455 ${bottom+8}`,C.copper,2,.65);
   if(k.garment==='waistcoat')for(let j=0;j<5;j++)p.surface(vectorEllipse(472,475+j*40,4,4),[466,469+j*40,478,481+j*40],{...bronze,exposure:.7});
  }else if(k.garment!=='workshirt'){
   // Short coats have a hem, openings and pockets, not the continuous robe fall.
   for(const [side,x]of[[-1,411],[1,513]]){
    const outer=side<0?313:621,shoulder=side<0?340:575,edge=x+side*13;
    p.surface(`M${x} 353 Q${shoulder} 371 ${shoulder} 425 Q${outer-side*19} 575 ${outer-side*10} ${hem+9} L${edge} ${hem+18} Q${x+side*8} 551 ${x} 353Z`,[Math.min(outer,x)-10,346,Math.max(outer,x)+15,hem+26],{mat:b.material,color:C.outer,shadow:C.clothShadow,accent:C.salt,height:foldField([[[x+side*35,400],[x+side*58,526],[x+side*39,665],[x+side*57,hem+10],19,11]])});
    const px=side<0?355:548;
    p.stroke(`M${px} 651 l49,2 l-4,57 q-20,10 -44,-2Z`,mix(C.outer,C.clothShadow,.5),2.5,.75);
   }
   if(k.garment==='tailored'){
    for(let j=0;j<4;j++)for(const x of[439,497])p.surface(vectorEllipse(x,503+j*42,4,5),[x-6,496+j*42,x+6,510+j*42],{...bronze,exposure:.85});
   }
  }
  if(['net','harness','medical_bag'].includes(b.workDetail)){
   const strap='M369 383 Q452 502 586 688 L569 706 Q427 527 355 391Z';
   p.surface(strap,[349,377,595,712],{mat:'leather',color:mix(C.copper,C.clothShadow,.38),shadow:C.clothShadow,height:(x,y)=>3*Math.sin((x+y)*.04),exposure:.8});
   if(b.workDetail==='medical_bag'){
    p.surface('M551 650 Q589 640 617 668 L626 754 Q586 783 542 751Z',[536,637,633,790],{mat:'leather',color:C.outer,shadow:C.clothShadow,accent:C.copper,height:foldField([[[551,664],[580,685],[610,677],[620,701],12,6]])});
    p.stroke('M551 657 Q584 695 618 669',C.salt,2,.4);
    for(let j=0;j<3;j++)p.line(`M${559+j*13} 671l3,27`,C.copper,2,.55);
   }
  }
  if(b.workDetail==='net'){
   // Empty, folded netting rests at the hip. No fish or resolved catch is added.
   const net='M343 685 Q378 701 403 675 L422 804 Q379 844 331 808Z';p.fill(net,mix(C.outer,C.clothShadow,.6),.8);
   for(let j=0;j<7;j++){const y=692+j*17;p.line(`M341 ${y} Q376 ${y+32} ${404+j*2} ${y-4}`,C.salt,1.8,.4);}
   for(let j=0;j<5;j++){const x=344+j*14;p.line(`M${x} 693 Q${x+9} 758 ${x+2} 816`,C.copper,1.5,.55);}
  }
  if(b.workDetail==='repair'){
   p.surface('M357 625 L397 631 L392 679 L351 672Z',[347,620,403,685],{...cloth,color:mix(C.linen,C.outer,.5),height:(x,y)=>1.5*Math.sin(y*.17)});
   for(let j=0;j<8;j++)p.line(`M355 ${630+j*5}l5,1`,C.salt,1,.5);
  }
  if(b.workDetail==='office_chain'){
   p.line('M391 444 Q447 503 527 440',C.copper,2.4,.7);
   p.surface('M462 479 L478 480 L480 498 L465 504Z',[457,474,486,510],{...bronze,color:C.copper,exposure:.7});
  }
 };
 config.collar=(p,{pale})=>{
  const sturdy=['tailored','oilcoat','drivercoat'].includes(k.garment),color=sturdy?C.outer:C.linen;
  p.surface('M383 346 Q407 358 438 374 L415 421 L366 384Z',[360,340,445,427],{...cloth,color,height:foldField([[[385,354],[391,377],[407,393],[417,410],10,7]])});
  p.surface('M477 346 Q470 369 438 374 L477 419 L515 380Z',[431,340,522,426],{...cloth,color,height:foldField([[[484,355],[492,375],[480,390],[476,409],10,7]]),normal:[.18,.02,1]});
  if(sturdy){
   p.surface('M377 360 L417 420 L393 470 L346 393Z',[340,354,424,477],{...cloth,color:mix(C.outer,C.linen,.12),height:foldField([[[361,386],[380,415],[397,438],[396,462],11,9]])});
   p.surface('M494 355 L461 418 L494 460 L533 392Z',[455,349,539,468],{...cloth,color:C.outer,height:foldField([[[519,390],[499,414],[486,429],[492,451],10,8]]),normal:[.22,0,1]});
  }
 };
 config.headwork=(p)=>drawHead(p,recipe,C);
}

function drawHead(p,recipe,C){
 const d=recipe.dimensions,k=recipe.construction,hair= {mat:'hair',color:C.hair,shadow:mix(C.hair,'#061619',.66),accent:C.salt,bump:.4},skin={mat:'skin',color:mix('#a28d78',C.clothShadow,.33),shadow:C.clothShadow,bump:.3,exposure:.58};
 // Neck/head anatomy exists under a cast shadow. The face is not a hood hole.
 p.surface('M413 304 Q439 327 471 310 L478 352 Q456 384 432 373 L402 346Z',[396,299,485,390],{...skin,height:foldField([[[417,316],[421,334],[433,354],[444,365],10,3]]),normal:[.2,.1,1],shadowField:()=>.55});
 if(k.head==='tiedhair')p.surface('M485 207 Q535 172 549 211 Q551 241 520 249 L506 290 L479 272Z',[474,171,557,298],{...hair,height:foldField([[[520,189],[548,208],[531,228],[510,233],12,6]])});
 const skull='M378 244 Q377 203 409 186 Q452 170 486 197 Q512 219 510 255 L505 303 Q484 338 453 348 Q424 343 401 320 L384 287Z';
 p.surface(skull,[371,172,518,356],{...skin,color:mix(C.clothShadow,'#766957',.48),exposure:.35,normal:[.38,.15,1],height:(x,y)=>5*Math.exp(-(((x-430)/58)**2))-2*Math.exp(-(((x-463)/17)**2))});
 p.shadow('M391 242 Q438 210 506 249 L505 300 Q479 326 455 342 Q424 332 406 316Z',.66,9);
 // A dim cheek/ear rim, while eyes and facial identity remain in shadow.
 p.surface('M383 263 Q372 260 375 280 Q378 296 391 296 L394 278Z',[369,255,400,302],{...skin,exposure:.44,height:(x,y)=>2*Math.exp(-(((x-383)/8)**2))});
 p.stroke('M398 300 Q419 335 451 340',mix(C.hair,C.salt,.2),1.7,.32);
 const swept=k.head==='swept_hair'||k.head==='tiedhair';
 const hairline=swept?'M374 276 Q357 222 387 194 Q409 169 449 174 Q492 174 512 213 L514 260 Q492 252 483 217 Q456 238 413 233 Q396 252 391 283Z':'M374 280 L365 246 L373 226 L367 213 L389 192 L390 181 L417 183 L433 174 L456 182 L472 179 L495 196 L513 213 L512 267 L496 269 Q488 243 477 236 L465 244 L441 230 L420 240 L409 231 L393 266 L390 289Z';
 p.surface(hairline,[352,165,521,296],{...hair,height:foldField([[[390,204],[409,181],[463,184],[497,219],13,8],[[385,233],[411,209],[462,205],[492,233],11,7]]),u:(x,y)=>x+(y-210)*.35,flow:()=>.45,exposure:.85});
 for(let j=0;j<7;j++)p.stroke(`M${383+j*8} ${224-j*4}Q${421+j*6} ${184+j*2} ${484+j*3} ${213+j*5}`,mix(C.hair,C.salt,.2),1.5,.25);
 if(k.head==='workcap'){
  const rise=8+d.capRise*20;
  p.surface(`M365 237 Q363 ${191-rise} 410 ${181-rise} Q466 ${170-rise} 506 ${205-rise*.5} L516 239 Q437 252 365 237Z`,[356,140,524,260],{mat:'cloth',color:mix(C.outer,C.hair,.2),shadow:C.clothShadow,accent:C.salt,height:foldField([[[383,201-rise],[406,180-rise],[461,180-rise],[494,212-rise*.5],16,11]])});
  p.surface('M366 231 Q438 241 514 230 L528 249 Q460 271 388 257 L357 248Z',[350,223,535,280],{mat:'canvas',color:mix(C.outer,C.clothShadow,.35),shadow:C.clothShadow,height:(x,y)=>3*Math.exp(-(((y-246)/10)**2)),normal:[0,-.3,1]});
  p.shadow('M388 260 Q451 263 508 253 L503 297 Q451 285 398 293Z',.47,4);
 }else if(k.head==='brim'){
  const crown=10+d.capRise*25;
  p.surface(`M381 229 L390 ${190-crown} Q439 ${173-crown} 486 ${197-crown} L503 237Z`,[374,137,511,245],{mat:'canvas',color:C.outer,shadow:C.clothShadow,height:foldField([[[396,192-crown],[404,180-crown],[462,189-crown],[485,205-crown],13,8]])});
  p.surface('M335 239 Q390 222 443 231 Q501 234 543 257 Q508 278 456 270 Q384 264 335 239Z',[328,216,550,285],{mat:'canvas',color:mix(C.outer,C.clothShadow,.2),shadow:C.clothShadow,normal:[-.25,-.45,.8],height:foldField([[[342,240],[398,240],[477,261],[534,257],11,6]])});
  p.shadow('M393 266 Q446 263 507 277 L499 311 Q444 295 403 306Z',.55,5);
 }
}
