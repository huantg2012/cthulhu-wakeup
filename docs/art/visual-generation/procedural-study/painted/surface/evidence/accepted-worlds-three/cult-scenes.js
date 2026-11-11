import {ellipse,mix,fbm,foldField} from './engine.js';
import {worldField} from './world-fields.js';
import {cultKit} from './cult-kit.js';

function pod(k,x,y,rx,h,material='shell',door=true){
 const {surf,side,top,p,C,w}=k;
 surf(`M${x-rx} ${y}C${x-rx*1.15} ${y-h*.45} ${x-rx*.8} ${y-h*.87} ${x} ${y-h}C${x+rx*.75} ${y-h*.84} ${x+rx*1.15} ${y-h*.34} ${x+rx} ${y}Q${x} ${y+rx*.35} ${x-rx} ${y}Z`,[x-rx*1.2,y-h-5,x+rx*1.2,y+rx*.4],{...side,field:worldField(material,w),color:C.stone,normal:[-.25,-.05,1],height:(u,v)=>16*Math.exp(-(((u-x)/(rx*.78))**2))});
 for(let i=-2;i<=2;i++){const s=i/3;p.stroke(`M${x+s*rx*.3} ${y-h+18}Q${x+s*rx*1.55} ${y-h*.6} ${x+s*rx*.86} ${y-7}`,C.salt,2,.33);}
 if(door)k.opening(x,y-4,rx*.62,h*.42);
 for(const dir of[-1,1]){const a=x+dir*rx*.68,b=y-h*.39;k.opening(a,b,rx*.19,h*.12,dir*3);}
 if(material==='flesh')for(let i=0;i<13;i++){const yy=y-h*.75+i*h*.052,xx=x-rx*.62+Math.sin(i*.3)*7;p.line(`M${xx-4} ${yy-3}l9,6`,C.copper,1.6,.75);}
}
function mushroom(k,x,y,rx,h,habitable=true){
 const {surf,p,C,w,side}=k;
 const stem=habitable?29:13;
 surf(`M${x-stem} ${y}Q${x-stem*1.25} ${y-h*.5} ${x-stem*.6} ${y-h*.75}L${x+stem*.8} ${y-h*.74}Q${x+stem*.4} ${y-h*.35} ${x+stem*1.3} ${y+3}Z`,[x-stem*1.4,y-h*.8,x+stem*1.5,y+9],{...side,field:worldField('silk',w),color:mix(C.linen,w.c2,.35),height:(u,v)=>4*Math.sin((u-x)*.13),normal:[-.35,0,1]});
 surf(`M${x-rx} ${y-h*.65}Q${x-rx*.75} ${y-h*.92} ${x-8} ${y-h}Q${x+rx*.65} ${y-h*1.03} ${x+rx} ${y-h*.62}Q${x+rx*.2} ${y-h*.4} ${x-rx} ${y-h*.65}Z`,[x-rx-4,y-h*1.05,x+rx+4,y-h*.38],{...k.top,field:worldField('fungus',w),color:mix(w.c2,w.c3,.6),height:(u,v)=>8*Math.exp(-(((u-x)/rx)**2)),glow:w.c4});
 p.shadow(`M${x-rx+7} ${y-h*.64}Q${x} ${y-h*.49} ${x+rx-5} ${y-h*.62}Q${x} ${y-h*.35} ${x-rx+7} ${y-h*.64}Z`,.37,2);
 for(let i=0;i<10;i++){const t=i/9;p.stroke(`M${x-5} ${y-h*.54}Q${x-rx*.8+rx*1.6*t} ${y-h*.43} ${x-rx+rx*2*t} ${y-h*(.62+.03*Math.sin(t*3))}`,C.salt,1,.35);}
 if(habitable){k.opening(x+2,y-3,26,42);k.opening(x-8,y-h*.28,14,24);k.gallery(x,y-h*.20,rx*.72);}
}
function spire(k,x,y,rx,h){
 const {surf,p,side,top,w,C}=k;
 surf(`M${x-rx} ${y}L${x-rx*.8} ${y-h*.61}L${x+rx*.15} ${y-h}L${x+rx*.85} ${y-h*.5}L${x+rx} ${y-10}L${x+5} ${y+15}Z`,[x-rx-5,y-h-5,x+rx+5,y+20],{...side,field:worldField('prism',w),normal:[-.45,-.1,.88],height:()=>0,bump:.15});
 surf(`M${x+rx*.15} ${y-h}L${x+rx*.85} ${y-h*.5}L${x+rx} ${y-10}L${x+5} ${y+15}L${x-rx*.14} ${y-h*.55}Z`,[x-rx*.2-4,y-h-4,x+rx+4,y+20],{...top,field:worldField('prism',w),normal:[.6,.1,.75],u:(u,v)=>u+190,bump:.15});
 p.stroke(`M${x+rx*.15} ${y-h}L${x-rx*.14} ${y-h*.55}L${x+5} ${y+15}`,C.salt,2,.6);
}

function watcher(k){
 const {terrace,surf,top,side,hall,stair,basin,lamp,cloth,queue,p,C,w,r}=k;
 lamp(381,390,.65,mix(w.c4,w.star,.45));lamp(657,611,.7,w.c4,180);
 terrace('M171 400Q189 333 269 325L343 290Q415 311 458 366L477 418L425 469L353 475L289 512L203 473Z','M171 400L203 473L289 512L353 475L425 469L477 418L468 535L412 604L370 651L309 628L245 658L204 603L161 559L147 486Z',[140,287,483,662]);
 terrace('M405 607Q484 563 537 503Q597 470 669 493L758 541L804 602L755 676L661 709L573 745L496 714L420 683Z','M405 607L420 683L496 714L573 745L661 709L755 676L804 602L795 695L744 758L665 777L602 818L535 800L479 823L427 768Z',[400,468,810,826]);
 hall(214,380,183+r()*30,151+r()*32,{material:'ridge',roof:'broken',windows:3});
 // A long slitted hood screens the observer from the eye instrument.
 surf('M550 548Q550 400 637 353Q699 401 726 493L708 564L667 529L618 530Z',[546,349,731,570],{...side,field:worldField('ridge',w),height:(x,y)=>fbm(x*.02,y*.02,w.worldSeed)*7});
 k.opening(639,533,76,137,13);cloth(572,429,28,89,C.violet);
 stair(366,457,-7,9,12,62);k.bridge(332,573,519,604,31);
 basin(651,622,109,56,{color:w.c2});
 // Iris lives on a horizontal observing surface, not a front-facing logo.
 for(let j=0;j<36;j++){const a=j/36*Math.PI*2;p.stroke(`M${651+Math.cos(a)*27} ${629+Math.sin(a)*12}L${651+Math.cos(a)*68} ${629+Math.sin(a)*29}`,j%3?C.copper:C.salt,1.8,.65);}
 p.fill(ellipse(651,629,13,25),w.c0);p.glow(652,622,80,w.c4,.12);
 queue([[245,435],[288,471],[345,492],[429,606],[555,678],[608,700],[712,672],[751,628]]);k.supplies(220,474);
 k.table(262,441,47);k.gallery(625,501,83);
 for(let i=0;i<3;i++)cloth(494+i*37,552-i*6,19,40,C.violet);
}

function flesh(k){
 const {terrace,surf,side,top,stair,bridge,queue,lamp,C,w,p,r}=k;
 lamp(318,435,.5,w.c4,185);lamp(635,628,.55,mix(w.c4,w.star,.3),170);
 terrace('M147 440C115 383 190 323 256 340Q318 298 382 332Q462 314 497 391Q526 454 466 501L378 533Q302 573 241 534Q166 545 147 440Z','M147 440Q166 545 241 534Q302 573 378 533L466 501L497 460Q539 545 490 604Q480 669 418 679Q337 720 292 668Q208 715 179 636Q124 604 139 545Z',[120,295,539,720]);
 terrace('M430 635Q455 557 528 549Q586 506 657 543Q731 524 776 595Q822 648 779 704Q728 748 663 738Q580 788 527 747Q445 762 430 635Z','M430 635Q445 762 527 747Q580 788 663 738Q728 748 779 704Q817 770 754 801Q700 851 638 821Q580 854 531 813Q467 831 448 776Z',[426,504,824,858]);
 pod(k,297,408,85,207+r()*40,'flesh');pod(k,443,467,58,145,'flesh');
 // A stretched membrane shelters the inhabited treatment terrace.
 surf('M505 566Q569 462 625 433Q678 486 757 566Q674 547 630 576Q566 553 505 566Z',[500,429,762,584],{...top,field:worldField('silk',w),color:mix(w.c3,w.star,.25),height:foldField([[[625,438],[594,490],[560,532],[510,563],15,9],[[628,439],[651,484],[702,533],[753,564],15,9]])});
 for(const [x,y]of[[510,566],[754,567]]){p.line(`M${x} ${y}v101`,C.copper,5);p.line(`M${x} ${y}l-20,110`,C.salt,1.2,.55);}
 k.basin(628,641,78,39,{liquid:'flesh',color:w.c3});
 stair(384,511,-7,8,10,56);bridge(356,590,493,651,34);
 for(let i=0;i<18;i++){const x=178+i*14,y=546+Math.sin(i*.4)*22;p.line(`M${x-4} ${y-5}l9,14`,C.salt,1.5,.7);}
 k.supplies(543,673,5);queue([[245,474],[297,492],[379,586],[527,638],[585,689],[689,687],[735,640]]);
 k.table(548,614,61);k.table(665,615,50);k.gallery(290,433,94);
}

function fungal(k){
 const {terrace,stair,queue,lamp,C,w,p,surf,side,top}=k;
 const hearth=lamp(606,635,.85,'#ffad60',154);hearth.marker=false;lamp(390,453,.35,w.c4,125);lamp(230,688,.25,w.c4,85);
 Object.assign(k.wood,{mat:'canvas',field:undefined,color:[111,87,63],shadow:[27,27,32],accent:[173,147,103]});
 // A single giant canopy covers the inhabited trunk; small growth is subordinate.
 terrace('M168 544Q154 467 219 421Q301 377 405 400Q513 369 610 436L702 502L716 580L650 637L539 658L433 638L318 678L225 625Z',
 'M168 544L225 625L318 678L433 638L539 658L650 637L716 580L727 695L661 756L560 779L453 751L357 791L270 748L207 703L170 633Z',[153,370,733,798],{exposure:.68});
 terrace('M143 704Q180 652 244 655L329 693L402 680L456 717L529 688L627 712L702 684L787 741L771 796L679 823L566 809L459 841L348 817L252 839L178 791Z',
 'M143 704L178 791L252 839L348 817L459 841L566 809L679 823L771 796L787 741L799 810L736 850L658 864L559 847L468 873L349 853L246 871L176 831Z',[137,649,805,879],{exposure:.76});
 // Thick inhabited stem, asymmetrical cap, under-cap dark space and hanging gills.
 surf('M298 544Q316 416 322 287L463 265Q441 415 496 550Q398 599 298 544Z',[292,260,503,604],{...side,field:worldField('silk',w),color:mix(C.linen,w.c2,.3),normal:[-.3,.1,.95],height:(x,y)=>9*Math.sin(x*.027+y*.008)});
 surf('M132 287Q172 181 326 157Q472 143 613 246L649 294Q524 356 401 326Q238 367 132 287Z',[127,144,655,374],{...top,field:worldField('fungus',w),normal:[-.3,-.6,.74],shadowField:(x,y)=>Math.max(.48,1-(x-220)*.0008),height:(x,y)=>70*Math.exp(-(((x-370)/250)**2+((y-222)/92)**2))});
 p.shadow('M137 290Q280 323 400 302Q551 330 644 294Q534 377 402 342Q241 386 137 290Z',.65,3);
 for(let i=0;i<29;i++){const x=151+i*16;p.stroke(`M390 316Q${x} 362 ${x} ${295+Math.sin(i*.17)*16}`,C.salt,1.2,.23);}
 k.opening(372,523,54,106);k.opening(434,418,22,44);k.opening(337,409,19,35);
 k.gallery(399,535,206);k.gallery(389,424,138);stair(447,566,-7,9,9,61);
 // Small attached shelters inhabit the side hollow; they do not repeat the main mass.
 mushroom(k,610,567,73,137);mushroom(k,691,603,48,94);k.bridge(473,558,568,594,22);
 // Work yards under the shadow of the canopy, then a brighter near specimen terrace.
 p.shadow('M247 526Q404 589 556 542L621 619Q431 690 251 603Z',.25,12);
 k.table(290,586,74);k.table(539,665,67);k.table(612,694,48);k.supplies(552,662,6);k.supplies(297,588,4);
 for(let i=0;i<5;i++){const x=509+i*22,y=613+i*3;p.line(`M${x} ${y}v-57`,C.copper,3);p.line(`M${x-9} ${y-47}l22,3`,C.salt,2);k.cloth(x-6,y-43,12,26,mix(w.c3,w.c2,.3));}
 k.gallery(590,750,193);stair(283,714,9,6,8,53);k.opening(233,738,37,56,-3);
 for(const [x,y,a,b]of[[174,697,42,78],[733,758,52,99],[377,759,21,40],[215,589,27,62],[493,461,28,52]])mushroom(k,x,y,a,b,false);
 // Harvest lines hang from the cap and connect to baskets below.
 for(let i=0;i<6;i++){const x=206+i*19,y=311+i*4;p.line(`M${x} ${y}Q${x+12} 409 ${x+6} ${490+i*5}`,C.copper,1,.6);p.fill(ellipse(x+6,490+i*5,5,8),C.copper,.8);}


 // Wooden braces and weathered curtains mark occupied thresholds.
 k.cloth(357,459,24,59,mix('#596e62',C.linen,.25));k.cloth(424,377,17,33,'#977c62');
 for(const [x,y]of[[352,529],[448,538],[564,582],[651,608]])p.line(`M${x} ${y}l-12,49l30,-41`,C.copper,3,.8);
 k.brazier(hearth,.76);
 // Open specimen boxes, a drying screen and spores caught in woven trays.
 for(const [x,y]of[[554,672],[580,677],[620,704]]){p.fill(`M${x} ${y}l17,3l8,-7l-16,-4Z`,'#29252c');for(let j=0;j<4;j++)p.fill(ellipse(x+5+j*3,y-1,1.7,2),'#a7ae80');}
 p.line('M166 602L211 613L211 655L166 644Z','#8b775b',2);for(let i=0;i<6;i++){p.line(`M${170+i*7} ${605+i*2}v36`,'#aa9270',.8,.6);p.line(`M169 ${610+i*6}l40,10`,'#aa9270',.8,.6);}
 // Irregular cap scars and clustered gills, not a uniform dome with a dark stripe.
 for(let i=0;i<13;i++){const x=174+i*32,y=282+Math.sin(i*.53)*17;p.stroke(`M${x} ${y}q10,11 21,4`,mix(C.salt,w.c2,.4),2,.32);}
 for(const [x,y,a,lit]of[[350,549,'torch',false],[432,550,'carry',false],[309,620,'work',true],[571,712,'work',true],[641,737,'carry',false],[264,786,'carry',true],[423,791,'bow',false],[627,615,'kneel',false]])k.actor(x,y,y>700?1.05:.84,a,lit);
}

function fire(k){
 const {terrace,surf,side,top,hall,stair,lamp,queue,w,C,p}=k;
 lamp(501,614,1.16,w.c4,237).marker=false;const hearth=lamp(629,416,.65,'#ffac62',142),gateFire=lamp(264,671,.63,'#ffb46c',118);hearth.marker=false;gateFire.marker=false;
 // Dominant rear kiln wall and an excavated furnace court. A narrow near quay
 // turns around the pit; the furnace and service outbuildings differ in scale.
 terrace('M187 474L208 387L310 322L413 333L487 288L607 306L697 363L749 449L727 538L659 572L555 553L488 585L378 566L286 594L218 550Z',
 'M187 474L218 550L286 594L378 566L488 585L555 553L659 572L727 538L749 449L774 574L720 653L615 691L514 666L410 704L310 681L235 625L195 555Z',[182,281,780,710]);
 hall(445,427,242,189,{roof:'broken',windows:4});hall(245,455,145,90,{roof:'tile',windows:3});
 // Scorched side return and buttresses provide a long lit/dark transition.
 for(const [x,y,h]of[[478,251,128],[589,273,169],[663,296,109]]){
  surf(`M${x-18} ${y}L${x-14} ${y-h}L${x+12} ${y-h-7}L${x+25} ${y+9}Z`,[x-24,y-h-12,x+31,y+16],{...side,field:worldField('basalt',w),color:w.c2,normal:[.3,.1,.94]});
  p.fill(ellipse(x,y-h,14,5),w.c0);p.glow(x,y-h+3,19,w.c4,.1);
 }
 for(const x of[464,542,620,687])surf(`M${x} 474l-19,-13l4,-130l13,-5l5,105l24,39Z`,[x-23,321,x+30,479],{...side,mat:'masonry',field:undefined,color:C.stone,normal:[-.6,.1,.8]});
 k.gallery(571,467,199);stair(409,489,-9,8,12,69);
 // Foreground mass overlaps the rear cliff. Its inner wall descends into heat.
 terrace('M146 655L226 599L315 614L374 654L431 676L501 701L596 682L692 634L775 658L808 726L758 794L670 825L558 807L466 845L350 817L247 833L166 768Z',
 'M146 655L166 768L247 833L350 817L466 845L558 807L670 825L758 794L808 726L823 794L766 841L681 870L572 847L472 881L346 853L241 869L170 817Z',[140,593,829,888]);
 surf('M365 617Q442 551 550 556Q665 568 692 629Q647 696 522 716Q425 704 365 617Z',[360,548,698,722],{...side,normal:[.1,.2,.97],color:w.c1,exposure:.49});
 surf('M420 634Q455 596 529 599Q601 601 639 638Q591 681 521 690Q459 681 420 634Z',[415,593,645,696],{...top,field:worldField('lava',w),color:w.c4,exposure:.7});
 p.shadow('M369 618Q449 552 549 557L556 591Q452 579 419 636Z',.5,4);
 // Inset furnace mouths, casting shelves, crane and suspended charging vessel.
 k.opening(570,553,38,55);k.opening(649,541,28,43);p.glow(568,537,44,w.c4,.2);
 k.bridge(291,681,406,714,27,{rope:false});k.gallery(710,685,110);stair(725,707,-8,8,8,47);
 p.line('M327 671L334 481L483 523',C.copper,8);p.line('M334 481L410 539L483 523',C.stone,3);
 p.line('M477 524v70',C.copper,2);p.line('M491 527v69',C.copper,2);
 surf('M463 591L506 599L498 623L474 619Z',[458,586,511,628],{mat:'metal',field:undefined,color:C.copper,normal:[-.4,.2,.9]});
 hall(173,668,91,69,{roof:'tile',windows:2});k.table(266,746,68);k.table(625,747,71);k.supplies(632,749,5);k.supplies(207,711,4);
 for(let i=0;i<8;i++){const x=369+i*23,y=774+i%3*6;surf(`M${x} ${y}l8,-10l15,3l-5,13Z`,[x-3,y-14,x+27,y+17],{mat:'metal',field:undefined,color:C.copper,normal:[-.3,-.6,.74]});}
 // A drain exposes the lower level, separating the near lip from the pit floor.
 surf('M532 704Q570 733 570 776L598 826L581 838L552 783Q552 742 518 716Z',[512,698,604,844],{...top,field:worldField('lava',w),exposure:.55});


 // Recessed hearths have a floor, a jamb return and a hot inner face.
 for(const [x,y,ww,hh]of[[492,442,44,93],[570,457,35,73]]){
  k.opening(x,y,ww,hh);surf(`M${x-ww*.4} ${y-3}l${ww*.4},-15l${ww*.4},19l${-ww*.4},6Z`,[x-ww*.5,y-22,x+ww*.5,y+11],{...top,mat:'masonry',field:undefined,color:'#9c7c53'});
  p.glow(x,y-17,ww*.6,w.c4,.12);p.line(`M${x+ww*.35} ${y-4}v${-hh*.52}`,w.c2,4,.7);
 }
 k.brazier(hearth,.72);k.brazier(gateFire,.78);
 // Main chimney has a neck, collar and a broken cap; left service flues remain subordinate.
 surf('M572 141L606 149L606 163L570 154Z',[566,137,611,168],{...side,mat:'metal',field:undefined,color:C.copper});
 for(let i=0;i<5;i++){const yy=157+i*21;p.line(`M575 ${yy}l23,6`,C.stoneShadow,2,.7);}
 k.cloth(451,323,21,63,'#635f50');k.cloth(641,357,17,46,'#8d7858');
 // An ore chute crosses the side wall and ends at the furnace mouth.
 surf('M682 501L699 507L633 605L615 598Z',[610,497,705,610],{mat:'metal',field:undefined,color:'#7a6247',shadow:w.c0,accent:'#c89a61',normal:[-.4,-.6,.7]});p.line('M687 506L622 599',w.c0,4,.7);
 for(let i=0;i<5;i++){const x=642+i*8,y=552-i*12;p.fill(`M${x} ${y}l5,-6l6,5l-5,7Z`,'#302622');}
 // Cooling racks, tongs and hammering stones sit next to the workers.
 for(const [x,y]of[[299,754],[653,760]]){surf(`M${x-8} ${y}l17,-7l12,8l-8,12l-19,-3Z`,[x-12,y-10,x+24,y+16],{...side,mat:'metal',field:undefined,color:'#615d4f'});p.line(`M${x} ${y-8}l17,-12`,C.copper,2);}
 p.line('M377 802l16,-19m-11,18l16,-18','#918374',2);p.line('M694 738l22,7m-19,-1l16,-8',C.copper,2);
 // Cast shadows anchor the crane and the nearer wall to the work floor.
 p.shadow('M325 675L337 675L387 739L374 742Z',.4,3);p.shadow('M172 686L265 709L298 739L208 716Z',.3,4);
 for(const [x,y,a,lit]of[[480,476,'torch',true],[607,499,'bow',false],[350,550,'carry',false],[279,596,'carry',false],[233,713,'torch',false],[307,780,'work',true],[656,791,'work',true],[412,761,'bow',false],[716,746,'carry',false]])k.actor(x,y,y>700?1.1:.78,a,lit);
}

function frozen(k){
 const {terrace,hall,stair,lamp,queue,cloth,w,C,p,surf,top,side}=k;
 // One sheltering escarpment, a recessed inhabited court, and a small near gate.
 // The principal mass runs across the back; routes turn into depth, not a diagonal row.
 const hearth=lamp(453,461,.83,'#ff9c50',135),gateFire=lamp(280,622,.67,'#ffab60',112);hearth.marker=false;gateFire.marker=false;lamp(653,566,.12,'#b2d6e7',77);
 terrace('M167 445L155 353L205 265L305 232L381 251L463 209L583 241L683 301L740 377L717 470L625 517L521 505L447 538L350 508L256 521Z',
 'M167 445L256 521L350 508L447 538L521 505L625 517L717 470L740 377L759 528L708 609L620 649L538 630L462 667L366 630L276 647L205 591L170 521Z',[150,204,766,673]);
 // Tall cold return catches little direct light, while snow ledges face upwards.
 surf('M583 241L683 301L740 377L759 528L708 609L663 568L680 423L630 359Z',[580,237,764,613],{...side,normal:[.78,.16,.6],exposure:.64});
 terrace('M208 583L277 541L351 558L430 527L514 550L587 524L677 553L754 615L731 690L636 735L541 747L452 721L349 761L258 727L193 657Z',
 'M208 583L193 657L258 727L349 761L452 721L541 747L636 735L731 690L754 615L769 729L718 786L627 814L546 799L468 832L383 805L302 834L230 783L185 711Z',[180,520,774,840]);
 // Excavated communal hall: a low, wide roof tucked beneath the ice ridge.
 hall(303,436,277,116,{roof:'snow',windows:5});hall(216,504,93,78,{roof:'snow',windows:2});
 p.shadow('M305 450L582 515L657 563L571 580L322 509Z',.32,9);
 k.gallery(442,472,242);stair(465,499,-8,8,10,78);
 // Forecourt is protected by a crescent parapet with a smaller service passage.
 surf('M220 629Q286 695 385 696L396 728Q270 744 204 658Z',[198,622,402,749],{...side,normal:[-.55,.1,.82],exposure:.94});
 surf('M220 629Q286 695 385 696L395 686Q283 680 229 615Z',[216,610,402,704],{...top,color:C.salt});
 hall(541,634,119,69,{roof:'snow',windows:2});k.opening(266,746,40,67,-4);stair(275,755,-7,7,6,48);
 // Survey instrument is small and exposed, set against the distant wall.
 p.line('M666 533L669 349',C.copper,4);p.line('M630 389L710 402',C.salt,3);p.line('M645 375L692 419',C.copper,2);
 for(let i=0;i<5;i++){const x=617+i*23,y=595+i*3;p.line(`M${x} ${y}v-57`,C.copper,3);cloth(x,y-55,21,29,mix(w.c2,w.c3,.45));}
 // Ice fractures terminate at ledges. A dark melt channel passes under the gate.
 surf('M505 676Q468 719 486 756L455 817L432 825L458 755Q445 714 480 682Z',[427,670,510,832],{...top,mat:'water',field:undefined,color:w.c2,shadow:w.c0,cx:900,cy:100,bump:.2});
 k.table(304,623,65);k.supplies(316,622,4);k.table(554,688,42);k.supplies(223,589,3);
 for(const [x,y]of[[373,375],[493,401],[554,420]]){k.opening(x,y,14,26);p.fill(ellipse(x,y-10,3,5),'#edb16d',.55);}

 // Sled, stakes and stacked fuel occupy the near working court.
 p.line('M311 679l56,11m-60,-5l56,11',C.copper,3);for(let i=0;i<6;i++)p.line(`M${319+i*6} ${673+i}l4,15`,C.stone,3);
 for(const [x,y]of[[228,569],[282,533],[524,561],[579,576]]){p.line(`M${x} ${y}v-21`,C.copper,2);p.stroke(`M${x-7} ${y+3}l16,3`,C.salt,1,.5);}

 // Ice buttresses meet the wall, exposing small dark pockets and warm occupied niches.
 for(const [x,y,hh]of[[304,442,110],[389,469,104],[484,488,108],[583,506,101]]){
  surf(`M${x-7} ${y}L${x-3} ${y-hh}L${x+6} ${y-hh+4}L${x+8} ${y-18}L${x+19} ${y+10}L${x+4} ${y+15}Z`,[x-11,y-hh-4,x+23,y+19],{...side,mat:'masonry',field:undefined,color:mix(C.salt,'#958c72',.3),normal:[-.55,.1,.83],exposure:.73});
  p.shadow(`M${x+8} ${y-hh+8}L${x+9} ${y-18}L${x+19} ${y+10}L${x+11} ${y+13}Z`,.38);
 }
 // Hewn ice has directional seams and broken ledges rather than a single smooth rear plate.
 for(const d of['M203 320L247 344L237 381L262 406','M330 265L349 288L343 312','M535 278L562 310L552 336','M664 335L655 371L681 400L675 429']){p.line(d,w.c1,2,.55);p.stroke(d,C.salt,1,.3);}
 for(const [x,y]of[[209,362],[535,312],[615,419]]){surf(`M${x} ${y}l30,-13l21,11l-23,16Z`,[x-3,y-17,x+55,y+19],{...top,color:C.salt,exposure:.73});p.shadow(`M${x+2} ${y+5}l44,-1l-20,15Z`,.35,2);}
 k.brazier(hearth,.77);k.brazier(gateFire,.78);
 k.cloth(312,358,18,52,'#717166');k.cloth(551,402,22,55,'#7f6a58');
 // Firewood, water vessels, a small work shelter and the loaded sled explain use.
 for(let i=0;i<7;i++){const x=212+i*7,y=607+i%2*5;p.line(`M${x} ${y}l22,6`,'#796448',4);p.fill(ellipse(x,y,2,3),'#ae9064');}
 surf('M559 674L574 646L629 658L641 690L593 682Z',[554,641,647,695],{mat:'cloth',field:undefined,color:'#897c5e',shadow:w.c1,accent:C.salt,normal:[-.2,-.65,.75],height:(x,y)=>Math.sin(x*.15)*2});
 p.line('M564 674v38M638 689v27',C.copper,3);k.supplies(584,704,3);
 for(let i=0;i<5;i++)p.fill(`M${321+i*7} ${671+i}l7,-9l9,4l-3,10Z`,'#665b4c');
 for(const [x,y,a,lit]of[[353,502,'torch',false],[493,527,'carry',false],[418,557,'bow',false],[322,655,'work',true],[269,664,'bow',false],[373,716,'carry',false],[596,741,'work',true],[694,611,'torch',false],[252,786,'carry',true]])k.actor(x,y,y>650?1.04:.78,a,lit);
}

function colour(k){
 const {terrace,stair,bridge,queue,lamp,hall,basin,cloth,w,C,r}=k;
 lamp(358,412,.55,w.c4,200);lamp(671,654,.6,w.corruption,190);
 terrace('M153 464L179 384L245 338L332 327L425 371L471 441L421 502L337 541L259 518L194 540Z','M153 464L194 540L259 518L337 541L421 502L471 441L459 572L411 619L354 666L290 633L242 680L195 617L165 574Z',[148,322,477,687]);
 terrace('M477 647L527 563L609 543L706 563L775 616L798 684L728 737L633 766L548 746L489 706Z','M477 647L489 706L548 746L633 766L728 737L798 684L790 760L733 811L665 842L601 813L539 830L493 773Z',[472,537,804,848]);
 spire(k,263,415,46,208+r()*35);spire(k,352,419,60,263+r()*40);spire(k,433,459,31,163);
 hall(205,490,167,91,{roof:'broken'});
 stair(359,527,-7,9,9,55);bridge(352,610,547,662,30);
 basin(667,665,91,48,{liquid:'prism'});spire(k,748,628,29,143);spire(k,580,613,23,108);
 queue([[217,517],[275,546],[314,583],[423,642],[569,702],[636,740],[724,721]]);k.supplies(525,710);cloth(227,435,19,47,C.violet);
 k.table(534,694,50);k.gallery(298,490,127);
}

function archive(k){
 const {terrace,hall,stair,basin,queue,lamp,cloth,w,C,p,r,surf,top}=k;
 lamp(354,386,.65,w.c4,170);lamp(549,591,.7,mix(w.c4,w.star,.3),175);
 surf('M122 715Q263 664 378 704Q460 733 499 779Q380 817 253 827Q147 801 122 715Z',[115,655,505,834],{...top,mat:'water',field:undefined,color:w.c1,shadow:w.c0,cx:-900,cy:1600,bump:.25,emission:0});
 terrace('M168 453L193 380L255 337L337 317L405 351L461 403L441 478L366 525L280 548L209 507Z','M168 453L209 507L280 548L366 525L441 478L461 403L479 529L420 576L357 620L277 649L216 607L173 553Z',[162,310,485,655]);
 terrace('M338 650L382 566L457 532L553 539L626 570L716 592L795 653L781 721L704 771L604 800L528 769L449 789L375 739Z','M338 650L375 739L449 789L528 769L604 800L704 771L781 721L795 653L797 759L732 812L664 846L595 826L534 854L467 827L414 845L357 780Z',[332,526,803,860]);
 // A dense stepped town, not one freestanding temple on a plate.
 hall(245,330,118,157+r()*28,{roof:'broken',windows:2});hall(173,436,136,95,{roof:'tile',windows:3});hall(324,445,143,113,{roof:'broken'});
 hall(505,556,197,131,{roof:'tile',windows:4});hall(661,643,111,98,{roof:'broken',windows:2});hall(409,666,117,77,{roof:'tile',windows:2});
 stair(370,495,-7,9,11,61);stair(572,614,-9,9,9,69);
 cloth(278,255,27,70,mix(w.c3,w.star,.28));cloth(526,499,31,83,C.linen);cloth(688,597,18,45,C.violet);
 basin(597,746,53,27,{color:w.c0,emission:0});
 queue([[218,478],[292,501],[323,551],[387,667],[473,721],[554,688],[665,735],[727,713]]);k.supplies(527,733,6);
 // Written tablets and working tables belong to the court, below the roofs.
 for(let i=0;i<5;i++){const x=440+i*17,y=715-i*4;p.fill(`M${x} ${y}l12,-4l-1,16l-13,4Z`,C.linen);p.line(`M${x+2} ${y+4}l7,-2`,w.c1,1,.8);}
 k.table(536,713,60);k.table(620,714,51);k.opening(242,607,33,61,-6);k.opening(447,781,31,57,-5);k.gallery(609,576,133);
}

function chaos(k){
 const {terrace,bridge,stair,lamp,queue,cloth,w,C,p,r,surf,top}=k;
 const island=(a,b,c)=>terrace(a,b,c,{material:'ridge',color:mix(w.c2,C.stone,.35)});
 lamp(300,363,.65,w.c4,190);lamp(673,586,.65,w.corruption,185);
 // The stream is a separate domain-warped field, not a disc under all objects.
 surf('M135 689Q193 570 360 613Q511 715 615 608Q746 494 832 604L858 644Q755 595 669 701Q536 813 382 703Q243 640 171 732Z',[130,490,864,819],{...top,field:worldField('flux',w),color:w.c3});
 island('M169 365L226 305L310 287L390 330L417 392L368 439L282 468L205 428Z','M169 365L205 428L282 468L368 439L417 392L390 486L343 537L296 558L264 513L219 501L183 449Z',[163,282,423,565]);
 island('M398 623L431 563L497 547L553 584L571 639L529 684L459 704L410 667Z','M398 623L410 667L459 704L529 684L571 639L546 731L507 771L471 786L437 736L411 722Z',[392,542,577,793]);
 island('M600 507L634 449L706 440L777 483L816 550L768 601L688 628L622 585Z','M600 507L622 585L688 628L768 601L816 550L794 654L747 705L704 733L673 676L629 651Z',[594,434,822,740]);
 // Tethered sail shelters bend with the same support ropes.
 for(const [x,y,s]of[[276,397,1],[698,558,.93],[485,659,.55]]){
  p.line(`M${x} ${y}v${-176*s}`,C.copper,4*s);surf(`M${x} ${y-176*s}Q${x-110*s} ${y-111*s} ${x-83*s} ${y-32*s}Q${x-16*s} ${y-74*s} ${x+69*s} ${y-22*s}Q${x+39*s} ${y-109*s} ${x} ${y-176*s}Z`,[x-116*s,y-181*s,x+76*s,y-17*s],{mat:'cloth',field:undefined,color:C.linen,shadow:w.c1,accent:C.salt,height:foldField([[[x,y-168*s],[x-31*s,y-115*s],[x-52*s,y-67*s],[x-80*s,y-35*s],15,11]]),normal:[-.25,-.15,1]});
  p.line(`M${x} ${y-176*s}L${x+85*s} ${y+10*s}`,C.salt,1.5);p.line(`M${x} ${y-176*s}L${x-109*s} ${y+3*s}`,C.copper,1.5);
 }
 bridge(328,447,427,601,25);bridge(531,643,643,579,26);
 queue([[228,409],[302,440],[381,542],[456,667],[519,682],[652,573],[729,603]]);k.supplies(661,599);
 k.table(245,402,51);k.table(663,557,56);k.gallery(481,684,82);
}

function cocoon(k){
 const {terrace,bridge,queue,lamp,w,C,p,r,surf,side}=k;
 lamp(456,595,.64,w.c4,190);lamp(712,495,.58,w.c4,155);lamp(217,653,.4,w.c4,100);
 // Side shelves hang independently. The inhabited central shell dominates;
 // this is not the two-shore layout of the accepted tide scene.
 terrace('M637 487L667 451L722 430L775 459L812 506L774 546L707 564L662 537Z','M637 487L662 537L707 564L774 546L812 506L791 590L751 641L718 664L690 611L656 585Z',[632,425,818,671]);
 pod(k,719,493,54,157,'shell');k.gallery(718,515,100);
 terrace('M148 620L182 583L244 575L294 614L277 659L224 685L175 667Z','M148 620L175 667L224 685L277 659L294 614L282 712L240 763L212 784L186 729L160 713Z',[142,570,299,792]);
 pod(k,214,630,39,112,'shell');k.gallery(215,650,83);
 terrace('M310 644Q334 565 418 537L510 541L580 572L644 642L652 708L601 767L530 805L452 786L379 808L334 755Z','M310 644L334 755L379 808L452 786L530 805L601 767L652 708L651 782L593 843L532 870L477 842L424 867L368 843L332 799Z',[304,531,659,878]);
 bridge(570,665,685,539,28);bridge(267,646,364,715,27);
 pod(k,464,632,130,432+r()*28,'shell');
 for(const [x,dir]of[[334,-1],[588,1]]){
  surf(`M${x} 716Q${x-dir*28} 464 ${464+dir*31} 195Q${464+dir*86} 353 ${x+dir*24} 520L${x+dir*20} 727Z`,[Math.min(x-50,420),189,Math.max(x+50,517),734],{...side,field:worldField('shell',w),color:C.salt,normal:[-.3,.02,1]});
 }
 k.gallery(465,650,182);k.stair(464,673,-5,9,10,65);
 // Load-bearing fibres run between the shell and inhabited shelves.
 for(let i=0;i<7;i++){const y=316+i*23;p.line(`M501 ${y}Q594 ${y+70} ${702+i*7} 492`,C.copper,1,.48);p.line(`M426 ${y+45}Q312 ${y+167} ${190+i*8} 619`,C.salt,1,.28);}
 k.cloth(413,547,27,65,C.violet);k.table(523,737,50);k.supplies(551,756,4);
 queue([[190,651],[242,672],[367,718],[416,753],[490,767],[585,734],[685,528],[755,541]]);
}

function bone(k){
 const {terrace,basin,hall,stair,lamp,queue,w,C,p,surf,side}=k;
 lamp(333,439,.56,'#f3ba78',155);lamp(613,665,.56,w.c4,180);
 // A single excavated crescent surrounds a deep court. Rear archives and
 // burial passages occupy the rim; there is no disconnected bridge island.
 terrace('M140 520Q149 390 263 356Q373 326 483 376L548 403Q660 377 751 461L810 574L788 696Q746 784 630 807L510 790Q399 817 292 754L192 674Z','M140 520L192 674L292 754Q399 817 510 790L630 807Q746 784 788 696L810 574L826 718L778 796L705 852L626 879L552 851L490 879L417 849L349 866L285 823L223 785L180 708L148 649Z',[134,320,833,886]);
 hall(220,430,184,129,{roof:'broken'});
 hall(591,481,134,83,{roof:'broken',windows:2});
 basin(543,647,171,88,{liquid:'bone',color:w.c1,emission:0});
 stair(382,497,9,9,12,63);stair(502,584,4,7,9,40,{color:C.salt});
 for(const [x,y,h]of[[406,595,116],[505,552,133],[612,558,119],[695,624,135]]){
  surf(`M${x-11} ${y}Q${x-16} ${y-h*.6} ${x+38} ${y-h}Q${x+84} ${y-h*.67} ${x+81} ${y+7}L${x+68} ${y+5}Q${x+74} ${y-h*.58} ${x+39} ${y-h+18}Q${x-3} ${y-h*.45} ${x+1} ${y}Z`,[x-22,y-h-5,x+89,y+13],{...side,field:worldField('ivory',w),color:mix(w.c3,w.star,.16),height:(u,v)=>Math.sin(v*.04)*2});
 }
 for(let i=0;i<8;i++){const x=193+i*22,y=548+i*12;surf(`M${x-6} ${y}l2,-31q6,-9 11,-1l2,35Z`,[x-10,y-40,x+13,y+9],{...side,color:C.salt});p.line(`M${x} ${y-24}v12`,w.c1,1.3,.7);}
 k.opening(351,774,42,73,-7);k.opening(440,811,36,65,-5);k.opening(681,789,38,64,-6);
 k.table(300,658,63);k.table(560,760,59);k.supplies(612,747,4);k.cloth(269,363,25,57,C.violet);
 queue([[249,483],[326,516],[372,563],[290,653],[415,734],[517,760],[630,747],[729,685],[713,536]]);
}

const SCENES={watcher,flesh,fungal,fire,frozen,colour,archive,chaos,cocoon,bone};
export function newCult(w,rule){const scene=SCENES[rule.layout];if(!scene)throw Error('未实现的教团组织 '+rule.layout);const k=cultKit(w,rule);scene(k);return k.finish({compositionRevision:['fungal','fire','frozen'].includes(rule.layout)?3:1});}
