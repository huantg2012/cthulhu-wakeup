import {SurfacePainter,foldField,mix,rng,smooth} from './engine.js';
import {mapPath,painterFor,vectorEllipse} from './design-space.js';
import {roles} from './world.js';

// Two directly drawn, elevated-view pose studies. No old 440-head / 470-body
// warp: skull, throat, sternum and waist share one continuous support axis.
export function drawPetitioner(recipe,world){
 const reach=recipe.background.caseId==='fever_child';
 if(!reach&&recipe.background.caseId!=='judge_letter')throw Error('此轮只重做求援与交易两种姿态');
 const d=recipe.dimensions,r=rng(recipe.personSeed),C=roles(world),cold=world.archetype===5;
 const width=.95+d.presentation*.03+(r()-.5)*.06,lean=reach?-.045:.11,height=.98+r()*.04;
 const map=(x,y)=>[480+(x-480)*width+lean*(y-430),430+(y-430)*height*(y>430?.48:1)];
 const inverse=(x,y)=>{const v=430+(y-430)/(height*(y>430?.48:1));return[480+(x-480-lean*(v-430))/width,v];};
 const Painter=painterFor({map,inverse}),p=new Painter(recipe.personSeed,{light:[-.56,-.58,.59],emitters:cold?[]:[{x:780,y:730,z:150,r:630,power:.21,color:[255,137,72]}]});
 const coat=cold?mix('#536578',C.cloth,.3):mix('#49373e',C.clothShadow,.25),shirt=mix(C.linen,cold?'#b0b9bf':'#b19b7d',.55);
 const cloth={mat:'cloth',color:coat,shadow:mix(C.clothShadow,coat,.18),accent:C.salt,bump:.6,salt:.045};
 const pale={...cloth,color:shirt,shadow:mix(C.clothShadow,shirt,.22)};
 const skin={mat:'skin',color:mix('#b39578',C.copper,.2),shadow:'#514a45',accent:'#c5b294',bump:.38,exposure:.8};
 const metal={mat:'metal',color:C.copper,shadow:C.clothShadow,accent:C.salt,bump:.4};
 const surf=(path,box,opts)=>p.surface(path,box,opts);
 // A broad visible shoulder roof, compressed chest length and waist receding
 // underneath establish the high observer before head/clothing are added.
 const torso=reach?'M418 373 Q365 376 330 420 Q351 519 358 631 L373 878 Q466 917 592 879 L610 613 Q646 497 614 415 Q565 373 526 369Z':'M417 377 Q357 386 328 426 Q341 540 363 642 L386 913 Q500 947 629 903 L632 621 Q658 531 625 466 Q591 416 527 387Z';
 const F=foldField([[[374,423],[408,495],[373,626],[396,896],24,12],[[440,422],[462,533],[449,676],[455,910],27,12],[[551,431],[580,529],[557,694],[587,905],24,9]],(x,y)=>18*Math.exp(-(((x-478)/134)**2)));
 surf(torso,[320,363,661,949],{...cloth,height:F,normal:[.15,-.12,1],exposure:.83});
 // Side plane and compression at the lower ribs, not a disconnected waist.
 surf(reach?'M562 451 Q622 483 610 613 L592 879 L543 892 Q565 666 562 451Z':'M576 461 Q638 486 632 621 L629 903 L560 924 Q575 673 576 461Z',[537,445,643,930],{...cloth,color:mix(coat,C.clothShadow,.3),height:F,normal:[.55,0,.65],exposure:.75});
 surf(reach?'M432 392 Q470 425 515 395 L549 878 Q483 901 420 876Z':'M434 404 Q479 434 515 410 L550 907 L438 916Z',[411,386,557,925],{...pale,height:foldField([[[455,432],[470,543],[454,711],[468,899],17,10],[[493,437],[512,539],[507,714],[527,902],15,8]])});
 if(reach){
  // Father: quilted short working jacket over wool, patched at the side.
  for(const [side,x]of[[-1,413],[1,538]]){
   surf(side<0?'M415 377 L443 424 Q423 641 421 875 L373 878 L353 610 L337 422Z':'M524 373 Q584 382 613 416 L606 621 L592 879 L547 889 Q542 638 509 418Z',[side<0?331:502,367,side<0?451:621,897],{...cloth,height:F});
   for(let i=0;i<8;i++){const y=466+i*46;p.line(`M${x-47} ${y} Q${x-22} ${y+16} ${x+10} ${y+12}`,mix(coat,C.clothShadow,.5),1.7,.6);}
  }
  surf('M370 710 L406 716 L404 762 L373 754Z',[365,705,412,768],{...pale,color:mix(shirt,coat,.6),height:(x,y)=>2*Math.sin(y*.1)});
  for(let i=0;i<6;i++)p.line(`M371 ${716+i*6}l6,2`,C.salt,1,.4);
 }else{
  // Judge: asymmetric tailored jacket with waistcoat, not a dust worker's tunic.
  surf('M414 388 Q452 422 479 450 L456 555 L449 914 L384 908 Q379 651 337 432Z',[330,382,485,922],{...cloth,height:F});
  surf('M523 394 Q588 425 625 465 L629 903 L558 922 Q572 641 509 454Z',[503,388,637,930],{...cloth,height:F,normal:[.28,0,1]});
  surf('M420 390 L480 450 L450 505 L400 444 L413 430 L385 419Z',[380,384,486,512],{...pale,color:mix(coat,shirt,.3),normal:[-.2,-.42,1],height:foldField([[[411,405],[423,435],[445,463],[452,492],13,9]])});
  surf('M521 396 L508 451 L552 522 L584 467 L556 443 L568 432Z',[502,390,590,529],{...cloth,color:mix(coat,shirt,.2),normal:[.3,-.15,1],height:foldField([[[535,414],[541,449],[551,484],[556,511],12,9]])});
  p.line('M417 505 Q455 546 516 511',C.copper,2,.7);
  surf('M463 535 L481 537 L480 555 L464 557Z',[457,530,487,563],{...metal,exposure:.66});
 }
 for(let i=0;i<5;i++)surf(vectorEllipse(478+i*3,482+i*58,4,5),[471+i*3,475+i*58,485+i*3,489+i*58],{...metal,exposure:.65});
 // Arms are composed as single cloth envelopes. The nearest reaching forearm
 // is visibly foreshortened, its palm larger and above the shoulder line.
 if(reach){
  surf('M523 379 Q601 374 645 445 Q682 501 697 567 Q715 622 674 645 Q642 653 613 625 L532 566 L548 529 L635 566 Q630 518 588 477 Q557 439 523 379Z',[517,369,721,660],{...cloth,height:foldField([[[569,411],[628,442],[660,495],[670,560],24,8],[[546,544],[597,576],[634,617],[673,628],18,14]]),normal:[.35,0,1],exposure:.74});
  surf('M418 376 Q350 371 307 427 Q276 471 261 502 Q244 535 268 553 Q289 566 315 548 Q355 519 367 465 L389 417Z',[241,367,426,574],{...cloth,height:foldField([[[363,397],[327,426],[287,482],[276,533],24,9],[[308,527],[333,496],[353,454],[370,421],17,11]])});
  surf('M268 532 Q250 475 258 424 L271 342 Q292 332 323 350 L325 429 Q333 478 309 533 Q287 555 268 532Z',[248,327,341,561],{...cloth,color:mix(coat,shirt,.2),normal:[-.15,-.4,1],height:foldField([[[280,350],[270,418],[275,483],[281,531],21,13],[[310,356],[307,424],[317,470],[299,532],14,9]])});
  surf('M269 344 Q294 331 324 350 L324 373 Q296 358 266 368Z',[260,325,330,380],{...pale,height:foldField([[[271,351],[289,341],[309,350],[323,359],9,7]]),normal:[-.1,-.7,.8]});
  drawHand(p,[298,348],-.12,1.08,skin,C,true);
  drawHand(p,[545,549],-.9,.72,skin,C,false);
 }else{
  // Far hand presses the jacket near the chest; near palm is extended upward
  // in a three-quarter exchange, with an open negative space below its elbow.
  surf('M421 387 Q353 386 315 445 Q292 482 290 544 Q285 588 325 604 Q351 614 385 592 L467 529 L445 495 L359 537 Q372 477 406 446Z',[279,377,475,619],{...cloth,height:foldField([[[365,413],[326,446],[316,496],[316,558],22,8],[[447,509],[401,550],[359,589],[327,592],18,11]]),normal:[-.25,-.06,1]});
  surf('M525 395 Q610 421 650 478 Q678 529 690 587 Q696 620 674 644 Q647 662 626 636 L602 572 Q578 510 545 466Z',[518,387,706,672],{...cloth,normal:[.35,-.1,1],height:foldField([[[596,438],[630,478],[657,539],[670,611],24,11],[[622,607],[636,621],[659,639],[677,630],13,10]])});
  surf('M631 624 Q646 584 674 552 L722 489 L751 507 Q731 557 704 593 Q686 628 666 646Z',[622,481,760,656],{...cloth,color:mix(coat,shirt,.15),height:foldField([[[738,501],[708,541],[674,589],[653,632],19,15],[[722,497],[691,536],[661,574],[639,614],12,9]])});
  surf('M716 493 L727 473 Q746 476 760 492 L750 513Z',[710,467,767,519],{...pale,normal:[.2,-.6,.9],height:(x,y)=>4*Math.sin(y*.12)});
  drawHand(p,[741,485],.75,.9,skin,C,true);
  drawHand(p,[453,511],.15,.72,skin,C,false);
 }
 // Collar is a visible ellipse seen from above, with back edge behind neck.
 surf('M409 382 Q467 352 529 380 L544 411 Q487 438 412 408Z',[403,345,551,445],{...pale,color:reach?mix(shirt,coat,.24):shirt,normal:[0,-.8,.6],height:foldField([[[415,385],[452,370],[505,378],[531,400],13,9]])});
 p.shadow('M432 381 Q478 360 519 386 L516 403 Q475 422 431 400Z',.65,3);
 drawHead(p,reach,skin,cloth,pale,C,d);
 // Shared structural axis is recorded in actual projected canvas coordinates.
 p.reframe(1.40,-192,-165);
 p.fade(859);
 return{p:p.output(),features:{recipe,role:recipe.background.role,pose:reach?'身体前倾、抬头向高处伸手求援':'侧身仰首、摊掌陈述交易',view:'二维手绘的斜俯视构造；头部朝向画外上方',axis:[[480,300],[480,390],[480,515],[480,830]].map(q=>{const v=map(...q);return[v[0]*1.40-192,v[1]*1.40-165];}),rendererParameters:{width,lean,height,bodyDepthScale:.48,headForeshortening:.28,garment:reach?'绗缝短夹衣与毛织衬衣':'翻领外衣与内背心',poseStrategy:reach?'reach_above':'bargain_up'},version:'petition-view-2',scope:'两种姿态构造，未覆盖其余职业或任意视角'}};
}

function drawHead(p,reach,skin,cloth,pale,C,d){
 // Skull is centered over the throat. Face turns up and to one side; its
 // forehead, nose, cheek, jaw and neck are drawn in that orientation directly.
 const mirror=!reach,head=(path)=>mapPath(path,(x,y)=>[mirror?960-x:x,y+(1-smooth(330,390,y))*(26+(320-y)*.28)]);
 const s=(path,box,o)=>p.surface(head(path),mirror?[960-box[2],box[1],960-box[0],box[3]+65]:[box[0],box[1],box[2],box[3]+65],o);
 s('M454 320 Q479 327 506 309 L516 387 Q488 413 453 385Z',[448,303,523,420],{...skin,exposure:.56,normal:[.2,.35,.9],height:foldField([[[465,330],[465,354],[474,382],[484,396],15,4]])});
 const hair={mat:'hair',color:mix('#514b43',C.clothShadow,.24),shadow:C.clothShadow,accent:C.salt,bump:.35};
 s('M418 281 Q408 239 437 214 Q460 192 494 206 Q529 222 530 255 L546 275 Q549 283 536 289 L529 319 Q508 347 472 355 Q440 348 429 318Z',[401,187,557,364],{...skin,normal:[.24,-.5,.9],height:foldField([[[491,230],[511,248],[513,280],[499,329],25,8]])});
 s('M438 269 Q464 248 490 249 L511 235 L526 255 L548 274 L532 286 L526 316 Q505 335 476 340 L445 321Z',[431,228,554,348],{...pale,color:mix(cloth.color,C.clothShadow,.25),normal:[.25,-.65,.75],exposure:.83,height:foldField([[[510,241],[509,264],[503,285],[510,313],12,9],[[445,287],[462,306],[496,319],[521,305],15,5]])});
 // Shadow band has no visible eyes; its slope, rather than a face-on black
 // oval, locates the brow beneath the lifted forehead.
 s('M432 260 Q466 235 501 238 L513 251 Q475 249 442 279Z',[425,229,519,286],{mat:'plain',color:'#121a20',exposure:.35,normal:[0,-.5,.8]});
 s('M416 302 Q396 265 414 233 Q426 206 457 198 Q482 189 509 210 L532 235 L522 253 Q505 223 483 226 Q454 240 434 263 L433 313Z',[389,181,541,321],{...hair,height:foldField([[[422,244],[428,211],[466,201],[504,221],14,11],[[417,277],[408,247],[432,221],[453,219],15,7]])});
 // Ear below the lifted brow, jaw over the neck, chin contact shadow.
 s('M428 282 Q413 272 416 293 Q417 310 433 312Z',[409,266,441,320],{...skin,exposure:.58,normal:[-.4,0,.8]});
 p.shadow(head('M467 352 Q495 345 520 326 L508 356 Q482 374 462 362Z'),.4,3);
 p.stroke(head('M449 312 Q477 336 518 314'),mix(C.salt,C.clothShadow,.65),1.6,.55);
 if(!reach){
  // Judge's structured cap follows the lifted head plane, not a level brim.
  s('M415 238 L420 202 Q458 177 495 198 L522 223 L528 242 Q480 216 415 253Z',[408,169,536,261],{...cloth,color:mix(cloth.color,'#271e2e',.3),normal:[-.2,-.65,.7],height:foldField([[[430,211],[448,194],[480,200],[509,224],18,10]])});
  s('M420 243 Q462 218 503 231 L544 250 Q523 267 499 262 Q455 246 424 258Z',[413,211,551,274],{...cloth,color:mix(cloth.color,C.clothShadow,.25),normal:[0,-.8,.6],height:foldField([[[428,246],[460,232],[499,244],[536,251],11,6]])});
 }else{
  s('M436 359 Q467 381 511 357 L534 393 Q499 418 459 412 L422 395Z',[415,349,542,426],{...pale,color:mix(pale.color,cloth.color,.3),normal:[-.15,-.55,.8],height:foldField([[[438,370],[461,397],[499,398],[523,382],16,11]])});
 }
}

function drawHand(p,w,a,scale,skin,C,open){
 const c=Math.cos(a),s=Math.sin(a),map=(x,y)=>[w[0]+scale*(x*c-y*s),w[1]+scale*(x*s+y*c)],inv=(x,y)=>[((x-w[0])*c+(y-w[1])*s)/scale,(-(x-w[0])*s+(y-w[1])*c)/scale];
 const shape=open?'M-21 9 Q-24 -7 -32 -23 L-51 -44 Q-56 -55 -49 -55 Q-41 -53 -26 -38 L-22 -70 Q-25 -98 -17 -100 Q-10 -101 -8 -73 L-5 -55 L-3 -103 Q-3 -115 4 -113 Q10 -111 10 -96 L13 -57 L17 -94 Q18 -107 24 -103 Q30 -101 28 -87 L27 -48 L34 -76 Q38 -88 43 -82 Q46 -79 42 -66 L38 -27 Q33 -10 23 5 L20 13Z':'M-17 8 Q-24 -10 -16 -27 L-4 -56 Q0 -66 5 -61 L4 -39 L14 -61 Q20 -65 22 -58 L15 -34 L27 -52 Q33 -56 35 -49 L24 -27 L35 -39 Q41 -41 40 -34 L29 -13 Q18 5 9 9Z';
 p.surface(mapPath(shape,map),[w[0]-scale*130,w[1]-scale*130,w[0]+scale*130,w[1]+scale*130],{...skin,normal:open?[-.15,-.7,.75]:[.1,0,1],height:(x,y)=>{const[u,v]=inv(x,y);return 5*Math.exp(-((u/27)**2)-(((v+30)/37)**2));}});
 for(const line of['M-21 -28 Q-3 -16 17 -29','M-12 -43 Q3 -33 22 -41','M-8 -69 L-5 -53','M12 -73 L13 -58','M27 -67 L25 -50'])p.line(mapPath(line,map),mix(C.clothShadow,'#8d715b',.5),1.1,.45);
}
