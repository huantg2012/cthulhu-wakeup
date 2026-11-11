import {tide,roles} from './world.js';
import {SurfacePainter,foldField,ellipse as baseEllipse,rng,fbm,mix,clamp,smooth,lerp} from './engine.js';

// One constrained pose: a tide-keeper cups a basin. All cloth flow is authored
// relative to the neck, elbow and wrists; the seed modulates dye/fold pressure.
export function portrait(personSeed=1339,worldSeed=1339,world=tide,config={}){
 const r=rng(personSeed),tension=(.92+r()*.15)*(config.tension||1),C=config.colors||roles(world),ellipse=config.ellipse||baseEllipse;
 const Painter=config.Painter||SurfacePainter;
 const p=new Painter(personSeed,{emitters:config.emitters||[{x:480,y:568,z:70,r:245,color:[96,235,178],power:.24}]});
 const dark={mat:'cloth',color:C.cloth,shadow:C.clothShadow,accent:C.salt,salt:.18,bump:.85};
 const pale={mat:'cloth',color:C.linen,shadow:C.linenShadow,accent:C.salt,salt:.34,bump:.8};
 const bronze={mat:'metal',color:C.copper,shadow:C.wet,accent:'#dfc891',bump:.7};
 const root=config.root||'M365 339 Q325 357 298 397 C272 430 253 486 243 535 Q226 586 241 638 C255 674 283 691 307 694 L277 935 Q439 976 691 933 L667 705 Q705 647 691 589 C684 517 651 451 616 414 Q582 375 533 365 L491 340Z';
 const mainFolds=foldField([
  [[359,371],[341,470],[366,539],[337,677],18,16*tension],
  [[381,415],[409,493],[369,700],[345,937],19,18],
  [[425,471],[472,571],[416,738],[429,959],21,17],
  [[475,540],[518,666],[475,804],[498,968],15,13],
  [[550,479],[604,610],[549,736],[611,935],21,16],
  [[601,442],[632,537],[631,660],[657,742],13,10]
 ],(x,y)=>32*Math.exp(-Math.pow((x-425)/163,2))-.065*(x-430));
 p.surface(root,config.rootBox||[225,336,708,960],{...dark,height:config.rootHeight||mainFolds,u:(x,y)=>x+Math.sin(y*.007)*19,shadowField:(x,y)=>clamp(.98-(x-430)*.0014,.42,1),wet:(x,y)=>clamp((y-820)/220)});
 // Far shoulder and sleeve remain within the same cloak mass and light group.
 if(!config.arms){p.shadow('M526 372 Q605 407 647 477 Q682 538 682 604 L644 672 L579 639 Q625 550 584 493 Q552 440 526 372Z',.32,10);
 p.shadow('M337 676 Q372 643 426 634 L579 665 Q554 701 482 699 L374 713Z',.38,12);}
 // A hanging inner stole carries finer vertical cloth structure.
 const stole='M408 402 Q448 421 477 410 L535 944 L406 960 Q424 743 395 538Z';
 if(!config.suppressStole)p.surface(stole,[391,400,540,960],{...dark,color:C.violet,shadow:C.clothShadow,accent:mix(world.nebula,world.c3,.4),height:foldField([
  [[422,423],[443,581],[425,737],[441,954],9,7],[[453,443],[481,612],[457,771],[494,954],12,9]
 ]),normal:[.15,.08,1],exposure:.7});
 config.layers?.underSleeves?.(p,{dark,pale,bronze});
 // Near sleeve: a single loose piece with tension from shoulder to bent elbow
 // and from the elbow to the supporting wrist. No radial cap shading.
 if(config.arms)config.arms(p,{dark,pale,bronze});else {const sleeve='M319 397 Q288 434 272 486 C253 531 239 578 246 618 Q256 666 291 697 Q332 702 362 674 L435 615 L429 578 Q382 598 351 581 Q330 555 332 514 Q343 463 351 424Z';
 const armFolds=foldField([
  [[322,423],[298,486],[271,577],[280,657],22,6],
  [[427,587],[394,622],[332,670],[288,686],15,12],
  [[420,607],[378,643],[334,666],[312,697],10,8],
  [[315,515],[307,551],[343,588],[399,590],10,-3],
  [[287,569],[301,611],[331,626],[367,620],17,5]
 ],(x,y)=>7*Math.exp(-Math.pow((x-300)/100,2)));
 p.surface(sleeve,[239,392,439,707],{...dark,color:mix(C.cloth,C.linen,.15),height:armFolds,u:(x,y)=>x-y*.15,v:(x,y)=>y,shadowField:(x,y)=>clamp(1-(x-300)*.001,.7,1)});
 // The inside elbow is a compressed dark wedge, never a black tube outline.
 p.shadow('M327 535 Q324 565 341 577 L369 586 Q344 591 332 578 Q319 558 327 535Z',.35,3);
 p.stroke('M273 588 Q278 616 306 632','#9ba888',2,.32);
 p.stroke('M307 683 Q345 656 386 632','#526f59',2,.42);
 // Far forearm crosses in front of the torso, with cloth compressed at cuff.
 const far='M628 480 Q663 530 679 578 Q695 626 662 674 L627 694 Q594 682 575 652 L529 613 L539 577 L606 594 Q620 578 613 549 L601 532Z';
 p.surface(far,[525,478,695,699],{...dark,color:config.colors?mix(C.cloth,C.clothShadow,.12):'#4a6a5d',height:foldField([
  [[623,516],[632,556],[641,584],[625,609],18,7],
  [[541,598],[580,632],[627,663],[651,679],17,9],
  [[624,560],[631,581],[632,600],[615,602],6,-7]
 ],(x,y)=>8*Math.exp(-Math.pow((y-611)/57,2))),normal:[.28,0,1],shadowField:()=>.65});
 p.stroke('M562 618 Q602 650 632 665','#749278',2,.32);}
 // Cowl spans both shoulders. Its continuous folds establish the neck-to-
 // shoulder anatomy before any surface detail is added.
 if(config.collar)config.collar(p,{dark,pale,bronze});else {const cowl='M363 319 Q404 337 447 329 L532 351 Q568 379 615 415 L590 474 Q535 471 486 447 Q420 425 371 401 Q337 414 306 450 Q310 405 330 376Z';
 const neckFolds=foldField([
  [[365,334],[378,381],[483,397],[565,423],16,16],
  [[350,366],[402,397],[484,440],[585,448],10,14],
  [[341,392],[368,382],[407,416],[459,422],8,8],
  [[499,352],[529,380],[565,410],[596,421],11,9]
 ],(x,y)=>12*Math.exp(-Math.pow((y-380)/50,2))-.03*(x-400));
 p.surface(cowl,[300,315,620,481],{...pale,height:neckFolds,u:(x,y)=>x,v:(x,y)=>y-.35*x,shadowField:(x,y)=>clamp(1-(x-440)*.002,.5,1)});
 p.shadow('M373 400 Q450 453 514 464 Q554 479 588 471 L583 485 Q518 490 466 465 Q411 438 373 400Z',.55,2);
 p.stroke('M333 392 Q358 369 386 394 Q480 450 574 455','#d2cfaa',2.4,.68);
 // Oxidised clasp and its short chain anchor the shawl, not floating jewellery.
 p.surface('M327 413 Q337 399 347 411 L353 432 Q348 444 337 440 L329 434Z',[325,398,357,447],{...bronze,height:(x,y)=>4*Math.exp(-Math.pow((x-339)/9,2)),normal:[-.4,-.2,1],exposure:.65});
 p.line('M333 415 Q340 410 345 418 L344 432 Q340 436 337 429Z','#d5c18b',1.6,.8);
 for(let i=0;i<9;i++)p.line(`M${344+i*3.3},${437+Math.sin(i/9*Math.PI)*11+i*2}l3,3`,'#8d9b78',1.5,.7);}
 // Hood has an asymmetric brow, an overhanging lip and a long fabric tail.
 if(config.headwork)config.headwork(p,{dark,pale,bronze});else {const hood=config.hood||'M355 348 C331 317 329 267 349 221 C367 182 398 153 425 145 Q458 137 490 164 C519 185 538 222 536 253 Q538 281 516 311 Q495 339 485 365 Q420 382 355 348Z';
 const hoodFolds=foldField([
  [[424,155],[389,187],[361,245],[364,315],13,11],
  [[450,159],[431,180],[397,214],[384,260],12,10],
  [[367,286],[369,331],[405,355],[452,353],10,14],
  [[497,196],[532,234],[527,271],[510,293],9,7]
 ],(x,y)=>23*Math.exp(-Math.pow((x-416)/91,2)-Math.pow((y-242)/143,2)));
 p.surface(hood,config.hoodBox||[328,137,543,382],{...pale,height:config.hoodFolds||hoodFolds,u:(x,y)=>x+(y-190)*.28,shadowField:(x,y)=>clamp(1-(x-418)*.003,.36,1),color:C.linen});
 // Opening is a bowed face plane under a projecting brow. Faceless is intended.
 const opening=config.opening||'M395 247 Q419 217 449 217 Q481 223 503 249 L501 279 Q482 309 460 326 Q428 332 404 312 L390 286Z';
 p.surface(opening,[385,212,509,333],{mat:'plain',color:'#0b1d25',normal:[.3,.3,1],exposure:.3});
 p.shadow('M397 247 Q425 215 453 219 Q481 229 503 252 L502 271 Q465 236 433 248 L393 280Z',.65,3);
 // Veil folds at the jaw hint at head direction while keeping the face hidden.
 p.surface('M402 296 Q430 318 458 312 L491 294 Q475 326 454 340 Q426 341 405 325Z',[398,292,493,345],{...dark,color:'#53766a',height:foldField([[[405,306],[433,332],[461,318],[484,304],5,4]]),normal:[.1,-.1,1],exposure:.6});
 if(!config.headStrokes){p.stroke('M400 246 Q427 213 451 220 Q480 226 501 250','#d0cba2',2.5,.65);
 p.stroke('M350 270 Q350 223 388 184','#d9d4ad',2,.55);
 p.stroke('M370 324 Q402 357 448 357','#8ba88e',2.3,.5);}else config.headStrokes(p);
 config.layers?.face?.(p,{dark,pale,bronze});}
 // A narrow woven border is generated in the cowl's own curve direction.
 if(!config.collar)for(let i=0;i<43;i++){const t=i/42,x=378+t*202,y=415+46*Math.sin(t*1.1),a=.4+t*.2;p.line(`M${x},${y}l${2*Math.cos(a)-4*Math.sin(a)},${2*Math.sin(a)+4*Math.cos(a)}`,'#b3b08a',.75,.5);}
 // Wrist openings and folded cuffs make the sleeve / hand junction legible.
 if(config.handwork)config.handwork(p,{dark,pale,bronze});else {for(const [d,b,flip]of[
  ['M410 581 L429 571 Q447 589 445 610 L427 625 Q421 600 410 581Z',[407,568,450,628],false],
  ['M532 573 L553 581 Q548 606 537 622 L518 611Z',[515,570,558,625],true]
 ]){p.surface(d,b,{...pale,color:'#9aab8c',height:(x,y)=>3*Math.sin(y*.2+x*.1),normal:[flip?.2:-.3,-.2,1],exposure:.75});}
 // Bowl rim and liquid are visible from above. It is a physical support for
 // the gesture, and the sole local emissive source affecting cloth and skin.
 if(config.drawObject)config.drawObject(p,{bronze,pale,dark});else {p.surface('M427 566 Q480 547 535 566 L524 609 Q481 630 440 606Z',[425,550,537,631],{...bronze,color:'#788a65',height:(x,y)=>10*Math.exp(-Math.pow((x-477)/50,2)),normal:[0,.25,1]});
 p.surface(ellipse(480,567,56,17),[423,548,538,586],{...bronze,color:'#cabf89',normal:[0,-.65,.72]});
 p.surface(ellipse(480,567,47,11),[431,555,529,579],{mat:'water',color:'#72cba1',shadow:'#09262e',cx:480,cy:567,v:(x,y)=>567+(y-567)*3,emission:.16,normal:[0,-.8,.6],bump:.35});
 p.glow(479,565,58,'#70f9b1',.11);
 p.line('M437 566 Q478 551 507 563','#a3ce9d',1.2,.55);}
 // Hands: palms support the bowl, grouped fingers wrap its outer wall. The
 // thumb crosses the near rim; the remaining fingers disappear behind it.
 const skin={mat:'skin',color:'#9e8c70',shadow:'#76604e',accent:'#cbb48b',bump:.45,exposure:.66};
 p.surface('M433 585 Q443 582 449 589 L455 600 Q471 606 484 609 Q490 612 486 616 L469 617 Q451 615 443 608 L437 603 L429 606Z',[426,581,491,620],{...skin,height:foldField([[[436,593],[451,605],[468,607],[484,613],5,3]]),normal:[-.25,-.1,1]});
 p.surface('M529 585 Q522 578 514 581 L503 588 Q499 590 502 594 Q505 596 512 591 L515 592 L510 605 Q503 614 491 616 Q486 618 489 622 Q507 624 518 613 L529 604 L537 607Z',[484,576,541,629],{...skin,normal:[.05,-.2,1],height:(x,y)=>3*Math.exp(-Math.pow((y-603)/11,2))});
 p.stroke('M445 601 Q465 611 481 612','#dfcba6',1.2,.65);p.line('M450 608 Q465 615 477 615','#615b46',.85,.6);
 p.stroke('M514 602 Q508 617 495 618','#c9c9a2',1.1,.65);p.line('M519 605 Q512 617 505 619','#685e49',.9,.5);
 p.line('M444 610 Q459 621 478 622','#192e2b',1.7,.7);
 // Salt and stitch marks follow hems/cuffs. They do not tile the entire figure.
 for(let i=0;i<31;i++){const x=426+r()*10,y=582+r()*34;p.stroke(`M${x},${y}l2,-3`,'#d1c99d',.7,.24);}}
 for(let i=0;i<34;i++){const y=703+i*6,x=324+Math.sin(y*.017)*6;p.line(`M${x},${y}l2,3`,'#7b9a80',.75,.35);}
 p.reframe(...(config.framing||[1.14,-60,-48]));
 p.fade(855);
 return {p:p.output(),features:{pose:'俯首托持潮水盏',structure:'颈肩连续披衣；肘与腕约束褶场；掌托与指缘遮挡',personSeed,worldSeed,materials:['染色粗布','盐蚀亚麻','氧化铜','湿润皮肤','发光潮水'],method:'2D masks + constrained cloth fields + coupled surface channels + illustrated lighting → original NPR'}};
}
