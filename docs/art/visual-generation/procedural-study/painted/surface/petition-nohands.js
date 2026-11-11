import {SurfacePainter,foldField,mix,rng} from './engine.js';
import {mapPath,vectorEllipse,painterFor} from './design-space.js';
import {roles} from './world.js';

// Whole illustrated clothing envelopes, not assembled arms or finished images.
// Occupation picks a cut; the person's seed modulates stance, cloth and material.
export function drawPetitioner(recipe,world){
 const id=recipe.background.caseId,cold=world.archetype===5,C=roles(world),r=rng(recipe.personSeed),d=recipe.dimensions;
 const father=id==='fever_child',judge=id==='judge_letter',sculptor=id==='shaking_hand';
 if(!father&&!judge&&!sculptor)throw Error('这个姿态小样只覆盖三个已有背景');
 const hunch=father?22+r()*17:sculptor?10+r()*12:-5+r()*10;
 const tilt=father?-.12-r()*.07:sculptor?.12+r()*.06:-.06+r()*.12;
 const broad=judge?1.05:father?1:.96, posture=father?'蜷肩守候':judge?'执杖守势':cold?'垂首护持':'垂首静立';
 const headX=father?-13:sculptor?13:4,headY=father?13:sculptor?16:-5;
 const outer=cold?mix(world.c2,'#5e6e7d',.54):mix(world.c2,judge?'#4a3635':'#795441',.45);
 const dark=mix(world.c0,outer,.22),light=mix(world.c3,cold?'#aabec8':'#d0ad84',.46),mid=mix(outer,light,.36);
 const angle=father?(cold?-.13:-.05):judge?.07:sculptor?(cold?.07:-.08):0,cs=Math.cos(angle),sn=Math.sin(angle);
 const personWidth=1.06-d.presentation*.16;
 const map=(x,z)=>[470+(x-470)*personWidth*cs-(z-470)*sn,470+(x-470)*personWidth*sn+(z-470)*cs];
 const inverse=(x,z)=>[470+((x-470)*cs+(z-470)*sn)/personWidth,470-(x-470)*sn+(z-470)*cs];
 const Painter=painterFor({map,inverse});
 const p=new Painter(recipe.personSeed,{light:[-.55,-.54,.64],emitters:cold?[]:[{x:735,y:640,z:120,r:550,power:.25,color:[255,135,71]}]});
 const cloth={mat:'cloth',color:outer,shadow:dark,accent:light,salt:.05,bump:.66};
 const pale={...cloth,color:mix(light,'#bbbea9',.18),shadow:mix(dark,mid,.15)};
 const leather={mat:'leather',color:mix(outer,'#765b46',.48),shadow:dark,accent:light,bump:.55};
 const metal={mat:'metal',color:mix(outer,light,.46),shadow:dark,accent:light,bump:.55};
 const F=foldField([[[360,410],[367,512],[381,678],[362,906],21,15],[[421,407],[448,548],[411,734],[431,936],19,14],[[492,415],[532,553],[510,764],[543,930],23,13],[[581,420],[612,554],[583,735],[604,900],19,10]],(x,y)=>23*Math.exp(-(((x-456)/142)**2))-.055*(x-450));
 const sw=35*(broad-1), y=hunch;
 // One torso/sleeve silhouette keeps shoulder, elbow and hanging cloth together.
 const outline=father?`M407 ${356+y} Q362 ${364+y} ${329-sw} ${416+y} Q293 ${474+y} 270 550 Q250 619 291 654 Q316 672 351 650 L333 913 Q460 962 625 914 L609 664 Q650 676 680 649 Q708 621 680 555 Q655 485 621 ${432+y} Q582 ${385+y} 522 ${358+y} Q461 ${380+y} 407 ${356+y}Z`:
 judge?`M410 ${358+y} Q354 ${365+y} ${323-sw} ${416+y} Q299 459 282 531 Q272 585 308 613 Q324 627 354 627 L337 914 Q473 954 639 911 L619 631 Q651 640 675 614 Q696 591 680 541 Q657 467 619 ${428+y} Q580 ${383+y} 523 ${361+y} Q461 ${375+y} 410 ${358+y}Z`:
 `M411 ${356+y} Q356 ${369+y} ${325-sw} ${417+y} Q298 467 280 540 Q269 590 308 625 Q325 643 352 637 L335 914 Q467 957 632 914 L611 647 Q645 661 674 632 Q695 610 678 559 Q651 476 619 ${432+y} Q582 ${386+y} 521 ${358+y} Q464 ${377+y} 411 ${356+y}Z`;
 p.surface(outline,[250,330,715,966],{...cloth,height:F,normal:[.04,-.2,1],exposure:.88});
 // Receding side, and the top-facing shoulder planes. They meet at the collar.
 p.surface(`M523 ${362+y} Q585 ${386+y} 620 ${428+y} Q640 455 652 495 L606 524 Q572 477 518 ${412+y} L483 ${391+y}Z`,[479,350,660,534],{...cloth,color:mix(outer,dark,.18),normal:[.46,-.38,.8],height:F,exposure:.8});
 p.surface(`M409 ${359+y} Q360 ${365+y} 327 ${418+y} L309 462 Q365 455 415 420 L459 ${397+y}Z`,[301,347,466,470],{...cloth,color:mix(outer,light,.22),normal:[-.2,-.62,.72],height:F});
 // The person's identity controls major construction, not a colored overlay.
 if(sculptor){
  p.surface(`M387 ${396+y} Q459 ${425+y} 548 ${397+y} L561 885 Q472 918 372 884Z`,[363,385,572,923],{...pale,color:mix(mid,light,.36),height:F});
  p.surface('M395 480 Q470 500 546 476 L568 903 Q470 923 369 899Z',[362,470,577,929],{...leather,height:foldField([[[407,493],[405,605],[398,754],[386,899],20,9],[[520,493],[540,608],[529,766],[548,904],19,10]])});
  for(const [x,dir] of [[402,-1],[537,1]])p.surface(`M${x} 490 L${x+dir*27} ${390+y} L${x+dir*12} ${385+y} L${x+dir*8} 487Z`,[x-40,370,x+40,500],{...leather,height:F});
  p.stroke('M392 705 Q467 721 546 703 L548 778 Q466 797 392 777Z',dark,2,.64);
  for(let j=0;j<4;j++)p.line(`M${410+j*29} 714 l-3 61`,light,1.2,.38);
 }else if(father){
  // Patched working shirt and quilted winter vest; warm lining, practical cut.
  p.surface(`M418 ${388+y} Q465 ${410+y} 517 ${390+y} L551 875 Q462 905 393 873Z`,[386,370,557,911],{...pale,height:F});
  for(const side of[-1,1]){
   const path=side<0?`M404 ${370+y} L449 ${413+y} Q423 618 421 852 L352 868 L341 468Z`:`M524 ${372+y} L488 ${413+y} Q524 626 520 852 L597 870 L609 477Z`;
   p.surface(path,side<0?[331,355,457,880]:[481,355,617,882],{...cloth,color:cold?mix(outer,'#5b6c7b',.25):mix(light,'#a38b70',.32),height:F});
   for(let j=0;j<7;j++){let q=473+j*54;p.line(side<0?`M350 ${q} Q392 ${q+15} 426 ${q+8}`:`M516 ${q+8} Q557 ${q+16} 601 ${q-2}`,dark,1.4,.38);}
  }
  p.surface('M356 704 L402 711 L397 760 L354 752Z',[349,698,408,766],{...pale,color:mix(mid,outer,.45),height:F});
  for(let j=0;j<6;j++)p.line(`M357 ${710+j*7} l6 2`,light,1,.35);
 }else{
  // Formal split coat, dark waistcoat, lapels and an office chain.
  p.surface(`M414 ${385+y} Q463 ${407+y} 513 ${385+y} L551 898 L394 908Z`,[385,370,560,918],{...pale,color:mix(light,outer,.25),height:F});
  p.surface('M418 441 Q464 460 516 439 L536 839 Q466 857 405 841Z',[397,432,544,864],{...cloth,color:mix(outer,dark,.25),height:F});
  p.surface(`M408 ${371+y} L464 423 L430 502 L367 418Z`,[361,358,471,510],{...cloth,color:mix(outer,light,.25),normal:[-.2,-.56,.8],height:F});
  p.surface(`M522 ${373+y} L485 423 L519 508 L577 423Z`,[479,360,583,515],{...cloth,color:mix(outer,light,.1),normal:[.35,-.38,.8],height:F});
  p.line('M399 467 Q463 534 535 466',C.copper,2.5,.75);
  p.surface('M459 501 L477 503 L477 522 L459 525Z',[454,497,483,531],{...metal,exposure:.8});
 }
 // The sleeves converge around the body; cuffs disappear behind fabric. No hands.
 if(sculptor&&cold){
  p.surface('M301 565 Q338 582 377 578 L386 729 Q352 737 326 710 Q309 676 301 565Z',[294,557,394,749],{...cloth,color:mix(outer,dark,.2),height:F});
  p.surface('M570 578 Q619 583 655 566 Q658 675 638 710 Q609 735 569 730Z',[562,557,663,750],{...cloth,color:mix(outer,dark,.25),height:F});
 }
 if(father){
  p.surface('M300 565 Q318 575 353 568 Q401 550 445 526 L466 564 Q416 613 356 644 Q318 658 293 638 Q275 619 300 565Z',[268,516,474,663],{...cloth,color:mix(outer,light,.12),height:foldField([[[305,592],[338,612],[387,582],[448,546],18,11],[[323,635],[360,631],[412,595],[452,567],12,8]])});
  p.surface('M650 568 Q618 584 585 571 L510 540 L493 578 Q538 617 592 642 Q633 661 660 635 Q679 616 650 568Z',[487,533,681,666],{...cloth,color:mix(outer,dark,.12),height:foldField([[[648,593],[615,610],[563,582],[508,556],16,11],[[641,632],[610,629],[560,598],[501,579],11,8]])});
  p.surface('M435 534 Q466 516 503 536 L521 584 Q467 601 418 580Z',[410,510,528,609],{...pale,color:mix(outer,light,.29),height:foldField([[[427,556],[450,541],[485,558],[511,578],13,10]])});
 }else if(sculptor&&!cold){
  p.surface('M300 541 Q321 558 350 552 Q374 546 394 534 L405 585 Q377 640 358 696 L348 810 Q320 827 296 806 L286 674 Q272 597 300 541Z',[278,534,413,838],{...cloth,color:mix(outer,light,.08),height:foldField([[[305,555],[303,635],[322,724],[309,802],23,12]])});
  p.surface('M643 541 Q666 558 668 612 L650 806 Q624 822 600 804 L595 698 Q572 638 549 587 L564 542 Q601 563 643 541Z',[543,535,678,833],{...cloth,color:mix(outer,dark,.1),height:foldField([[[636,554],[657,624],[630,735],[627,802],20,12]])});
 }else if(sculptor){
  p.surface('M300 563 Q307 627 350 662 Q397 696 447 688 L455 727 Q405 745 352 715 Q308 692 288 648 Q275 610 300 563Z',[268,550,475,753],{...cloth,color:mix(outer,light,.17),height:foldField([[[305,589],[340,611],[393,600],[454,577],17,12],[[319,628],[353,631],[410,614],[459,595],12,9]])});
  p.surface('M650 559 Q664 616 626 658 Q583 700 515 690 L504 729 Q552 748 604 720 Q651 694 669 650 Q683 609 650 559Z',[497,552,681,754],{...cloth,height:foldField([[[646,587],[622,605],[573,593],[518,578],18,12]])});
  p.surface('M430 680 Q469 666 509 684 L517 730 Q474 747 424 730Z',[418,672,525,755],{...leather,color:mix(outer,light,.21),height:foldField([[[439,575],[463,558],[493,574],[517,595],13,9]])});
 }else{
  // A staff lies behind the sleeve; a broad hanging sleeve conceals the grip.
  p.surface('M627 256 Q632 246 638 256 L646 906 L629 908Z',[620,244,653,918],{...leather,color:mix(outer,C.copper,.28),height:(x,z)=>3*Math.exp(-(((x-635)/8)**2)),normal:[-.3,0,1],exposure:.8});
  p.surface('M604 248 Q621 218 640 228 Q660 218 670 248 Q662 272 639 282 Q615 270 604 248Z',[596,210,678,290],{...metal,color:C.copper,height:(x,z)=>5*Math.exp(-(((x-636)/20)**2)),normal:[0,-.4,1],exposure:.85});
  p.surface('M295 521 Q315 540 344 532 Q366 524 387 512 L405 564 Q381 620 349 675 L336 815 Q303 831 282 805 L275 675 Q267 591 295 521Z',[266,505,413,838],{...cloth,color:mix(outer,light,.09),height:foldField([[[301,535],[296,617],[310,702],[294,801],22,11],[[367,543],[357,627],[345,725],[337,805],17,9]])});
  p.surface('M652 510 Q677 535 676 581 Q675 623 660 660 L654 721 Q632 732 611 710 L613 656 Q600 611 617 568Z',[601,502,685,740],{...cloth,color:mix(outer,dark,.12),height:foldField([[[649,523],[672,568],[649,629],[643,707],19,11]])});
  p.surface('M609 610 Q630 588 657 602 L659 645 Q637 656 610 642Z',[603,582,666,662],{...cloth,color:mix(outer,light,.16),height:F});
  if(!cold){
   p.surface(`M394 ${374+y} Q340 ${376+y} 314 ${433+y} L335 487 Q389 479 432 438 L458 ${405+y}Z`,[307,361,466,494],{...metal,color:mix(outer,C.copper,.45),normal:[-.2,-.6,.75],height:F});
   p.surface(`M523 ${375+y} Q584 ${396+y} 625 ${446+y} L601 489 Q560 465 510 420 L485 ${404+y}Z`,[478,364,635,496],{...metal,color:mix(outer,C.copper,.3),normal:[.3,-.48,.75],height:F});
  }

 }
 // Thick shoulder/collar planes and the throat join the torso directly.
 if(father&&cold){
  p.surface(`M400 ${355+y} Q352 ${369+y} 317 ${418+y} Q292 468 292 531 Q355 573 437 545 Q517 554 634 520 L644 473 Q609 397 523 ${357+y} Q464 ${374+y} 400 ${355+y}Z`,[284,341,653,580],{...cloth,color:mix(outer,light,.25),normal:[-.12,-.5,.8],height:foldField([[[335,408+y],[347,462+y],[394,503],[447,531],20,14],[[485,385+y],[519,431],[565,478],[627,503],23,16],[[321,490],[377,528],[424,544],[477,534],13,11]])});
 }
 p.surface(`M397 ${361+y} Q462 ${340+y} 529 ${359+y} L554 ${405+y} Q474 ${439+y} 382 ${402+y}Z`,[375,330,561,455],{...pale,color:mix(mid,light,cold?.48:.25),normal:[0,-.72,.7],height:foldField([[[396,375+y],[427,404+y],[489,411+y],[545,387+y],17,11]])});
 if(cold)p.surface(`M386 ${368+y} Q463 ${347+y} 541 ${368+y} L569 ${421+y} Q470 ${466+y} 367 ${421+y}Z`,[359,337,576,477],{...cloth,color:mix(mid,light,.34),normal:[-.1,-.62,.75],height:foldField([[[379,387+y],[421,427+y],[504,436+y],[560,401+y],20,14]])});
 p.shadow(`M431 ${367+y} Q467 ${353+y} 507 ${367+y} L518 ${399+y} Q472 ${417+y} 429 ${398+y}Z`,.48,3);
 // Tilt skull about its neck root. Its own rim and forehead indicate orientation.
 const cx=470+headX,cy=350+y, ca=Math.cos(tilt),sa=Math.sin(tilt);
 const H=(x,z)=>{const dx=x-470,dy=z-350;return[cx+dx*ca-dy*sa,cy+headY+dx*sa+dy*ca];};
 const hs=(path,box,o)=>{const pts=[[box[0],box[1]],[box[2],box[1]],[box[0],box[3]],[box[2],box[3]]].map(q=>H(...q));p.surface(mapPath(path,H),[Math.min(...pts.map(v=>v[0]))-5,Math.min(...pts.map(v=>v[1]))-5,Math.max(...pts.map(v=>v[0]))+5,Math.max(...pts.map(v=>v[1]))+5],o);};
 const hair={mat:'hair',color:mix(dark,'#514a42',.45),shadow:dark,accent:light,bump:.3};
 hs('M434 301 Q469 319 507 298 L512 350 Q481 373 448 354Z',[427,294,519,380],{mat:'skin',color:mix(mid,'#8c7a68',.4),shadow:dark,normal:[.2,0,1],exposure:.46,height:(x,z)=>2*Math.sin(x*.1)});
 hs('M405 249 Q398 208 432 187 Q472 168 510 197 Q537 221 530 260 L522 304 Q504 330 472 344 Q438 338 416 310Z',[398,165,540,351],{...hair,color:mix(mid,'#5b584f',.38),normal:[-.15,-.48,.85],height:(x,z)=>7*Math.exp(-(((x-459)/60)**2))});
 // Face remains concealed by shadow with a muted lower-plane rim.
 hs('M420 245 Q460 218 516 244 L521 281 Q502 316 472 331 Q441 324 422 304Z',[414,215,527,339],{mat:'plain',color:mix(dark,'#0c151b',.4),normal:[.1,-.38,.8],exposure:.3});
 hs('M424 292 Q449 315 472 316 Q500 311 520 287 Q508 324 472 336 Q443 328 424 310Z',[418,281,526,342],{...cloth,color:mix(mid,light,.16),normal:[.2,-.48,.8],exposure:.65,height:(x,z)=>3*Math.sin(x*.04)});
 if(judge){
  hs('M407 237 L414 197 Q463 173 510 199 L528 236Z',[401,170,535,245],{...cloth,color:mix(outer,dark,.22),normal:[-.18,-.55,.8],height:(x,z)=>5*Math.sin(x*.026)});
  hs('M385 237 Q450 216 521 231 L550 249 Q517 266 470 260 Q424 258 385 247Z',[378,211,558,273],{...cloth,color:mix(outer,dark,.35),normal:[0,-.75,.7],height:(x,z)=>4*Math.sin(x*.023)});
 }else if(father){
  hs('M403 245 Q397 204 428 183 Q471 164 513 196 Q529 213 532 245 Q506 231 479 231 Q440 234 403 251Z',[396,159,539,259],{...hair,height:(x,z)=>6*Math.sin(x*.03)});
 }else{
  if(cold)hs('M407 241 Q402 200 432 184 Q474 170 512 199 L529 238 Q466 227 407 251Z',[400,164,537,258],{...cloth,color:mix(outer,dark,.18),normal:[-.2,-.45,.8],height:(x,z)=>5*Math.sin(x*.027)});
  if(cold)hs('M404 239 Q467 229 528 238 L540 254 Q480 266 412 258Z',[398,222,547,272],{...cloth,color:mix(outer,dark,.38),normal:[0,-.75,.7]});
 }
 p.reframe(1.18,-85,-75);
 p.fade(870);
 return {p:p.output(),features:{version:'no-hands-1',recipe,role:recipe.background.role,pose:posture,construction:sculptor?'工作衫与围裙':father?(cold?'厚披覆与绗缝夹衣':'工作背心与修补内衫'):(cold?'正式外衣与权杖':'翻领外衣、金属护肩与权杖'),expression:d.presentation<.34?'偏男性':d.presentation>.66?'偏女性':'中性表达',method:'直接二维衣着包络、肩颈与受力褶场；双手由衣袖和遮挡表达；原作 NPR',scope:'视觉候选，未作审美认可'}};
}
