import {ellipse,mix,fbm,foldField} from './engine.js';
import {worldField} from './world-fields.js';
import {cultKit} from './cult-kit.js';

function pod(k,x,y,rx,h,material='shell',door=true){
 const {surf,side,top,p,C,w}=k;
 const body=material==='flesh'?`M${x-rx} ${y}C${x-rx*1.1} ${y-h*.35} ${x-rx*1.25} ${y-h*.6} ${x-rx*.7} ${y-h*.77}C${x-rx*.45} ${y-h*1.02} ${x+rx*.3} ${y-h*1.02} ${x+rx*.65} ${y-h*.78}C${x+rx*1.18} ${y-h*.63} ${x+rx*.8} ${y-h*.39} ${x+rx} ${y}Q${x} ${y+rx*.35} ${x-rx} ${y}Z`:`M${x-rx} ${y}C${x-rx*1.15} ${y-h*.45} ${x-rx*.8} ${y-h*.87} ${x} ${y-h}C${x+rx*.75} ${y-h*.84} ${x+rx*1.15} ${y-h*.34} ${x+rx} ${y}Q${x} ${y+rx*.35} ${x-rx} ${y}Z`;
 surf(body,[x-rx*1.2,y-h-5,x+rx*1.2,y+rx*.4],{...side,field:worldField(material,w),color:C.stone,normal:[-.25,-.05,1],height:(u,v)=>16*Math.exp(-(((u-x)/(rx*.78))**2))});
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
 const {terrace,surf,side,top,hall,stair,p,C,w}=k;
 const fire=k.lamp(367,558,.85,'#efae67',150),lamp=k.lamp(628,461,.65,w.c4,135);fire.marker=lamp.marker=false;
 // An enveloping blinded ridge; the instrument court is sheltered in its hollow.
 terrace('M152 447L177 334L245 269L336 274L417 238L512 277L570 350L551 451L491 505L396 525L307 504L225 536Z','M152 447L225 536L307 504L396 525L491 505L551 451L570 350L597 504L553 598L463 651L371 629L289 666L216 613L170 552Z',[146,232,603,672]);
 surf('M413 282Q472 191 564 207Q697 231 728 392L699 518L658 503L650 370Q612 304 566 325L550 461L495 495Z',[408,186,734,524],{...side,field:worldField('ridge',w),normal:[.5,.12,.85],exposure:.65,height:(x,y)=>fbm(x*.013,y*.012,w.worldSeed)*15});
 terrace('M179 625L251 573L337 587L411 550L501 573L582 546L683 580L769 648L776 722L701 780L601 804L506 787L399 824L300 792L205 802L152 729Z','M179 625L152 729L205 802L300 792L399 824L506 787L601 804L701 780L776 722L788 800L715 844L609 866L504 842L410 874L297 844L206 858L155 795Z',[146,540,794,880]);
 hall(228,442,171,126,{roof:'broken',windows:2});k.cloth(255,336,32,80,C.violet);k.gallery(314,473,142);
 // Slit wall blocks direct sight from the living quarters to the lower instrument.
 surf('M442 466L490 382L530 402L518 543L474 574L438 553Z',[432,377,536,579],{...side,normal:[-.6,.1,.8],color:C.stone});k.opening(479,530,13,89,7);
 stair(351,489,-7,8,10,64);stair(345,595,7,8,8,58);
 k.basin(595,659,139,74,{color:w.c2});
 for(let i=0;i<48;i++){const a=i/48*Math.PI*2;p.stroke(`M${595+Math.cos(a)*34} ${670+Math.sin(a)*14}L${595+Math.cos(a)*99} ${670+Math.sin(a)*42}`,i%3?C.copper:C.salt,1.6,.65);}
 p.fill(ellipse(595,670,18,32),w.c0);p.glow(592,668,80,w.c4,.14);
 for(const [x,y,h]of[[494,623,79],[547,594,105],[679,618,91]]){surf(`M${x-7} ${y}l2,${-h}l12,1l2,${h}Z`,[x-11,y-h-4,x+13,y+5],{...side,mat:'masonry',field:undefined,color:C.salt});p.line(`M${x} ${y-h}l${595-x},${590-y+h}`,C.copper,1,.5);}
 hall(188,681,94,67,{roof:'tile',windows:2});k.opening(271,788,39,67,-4);k.table(293,686,62);k.supplies(302,688,4);k.table(656,751,48);
 k.brazier(fire,.82);k.brazier(lamp,.72);
 for(const [x,y]of[[238,461],[387,495],[468,554]])p.shadow(`M${x} ${y}l31,9l26,28l-37,-8Z`,.35,3);
 for(let i=0;i<5;i++){const x=203+i*21,y=728+i*4;p.line(`M${x} ${y}v-31`,C.copper,2);k.cloth(x-7,y-29,14,18,C.violet);}
 for(const [x,y,a,l]of[[303,481,'carry',false],[309,552,'torch',true],[391,627,'bow',false],[320,721,'work',true],[516,734,'kneel',false],[619,759,'bow',true],[716,715,'torch',false],[247,811,'carry',false]])k.actor(x,y,y>700?1.05:.8,a,l);
}

function flesh(k){
 const {terrace,surf,side,top,stair,p,C,w}=k;
 const fire=k.lamp(293,602,.85,'#ffc080',142),inner=k.lamp(569,414,.62,w.c4,125);fire.marker=inner.marker=false;
 // A dominant living sac rises on the far right; care yards occupy a concave
 // slope in front. The left membrane shelter is broad and low, not a twin pod.
 terrace('M188 491Q144 383 263 342Q372 312 428 360Q493 287 610 317Q729 348 756 468L718 555Q641 608 537 578Q451 635 346 595Q234 623 188 491Z','M188 491Q234 623 346 595Q451 635 537 578Q641 608 718 555L756 468Q795 582 730 667Q641 727 540 683Q431 750 344 697Q235 735 186 645Z',[157,284,796,755]);
 terrace('M149 668Q205 600 293 629L392 671L491 635L603 670L696 644Q782 681 802 747L759 808L656 835L550 814L436 854L323 819L223 843L158 789Z','M149 668L158 789L223 843L323 819L436 854L550 814L656 835L759 808L802 747L815 814L754 856L661 876L552 852L443 882L323 851L218 876L158 832Z',[142,594,821,888]);
 pod(k,565,480,125,320,'flesh');k.gallery(564,486,187);pod(k,703,523,41,108,'flesh');
 surf('M188 492Q230 393 328 374Q402 405 449 506Q350 461 296 503Q231 474 188 492Z',[182,369,455,512],{...top,mat:'cloth',field:worldField('silk',w),color:mix('#b3987c',w.c3,.28),height:foldField([[[328,378],[282,421],[239,459],[189,491],22,12],[[330,379],[373,427],[407,466],[447,504],18,12]])});
 for(const [x,y]of[[191,492],[444,504],[328,378]]){p.line(`M${x} ${y}v94`,C.copper,4);p.line(`M${x} ${y}l-21,105`,C.salt,1,.5);}
 p.shadow('M192 496Q321 475 447 509L469 571Q320 551 190 566Z',.3,9);
 k.table(233,543,89);k.table(345,562,62);k.supplies(239,548,5);k.cloth(250,487,18,45,'#879387');
 stair(508,519,-9,8,10,70);stair(392,608,-6,8,8,58);
 k.basin(583,714,90,46,{liquid:'flesh',color:w.c3});k.table(655,727,57);k.supplies(665,731,5);
 // Tension seams follow the incision and end at metal fastenings.
 for(let i=0;i<16;i++){const x=191+i*16,y=652+Math.sin(i*.32)*16;p.line(`M${x-3} ${y-6}l8,13`,C.copper,2,.75);}
 k.opening(244,780,43,70,-3);k.gallery(341,737,111);k.cloth(539,355,25,68,C.violet);
 for(const [x,y]of[[528,414],[605,437]]){p.line(`M${x} ${y}v30`,C.copper,1.2,.6);p.fill(ellipse(x,y+32,6,9),C.salt,.7);}
 k.brazier(fire,.8);k.brazier(inner,.7);
 for(const [x,y,a,l]of[[524,502,'bow',true],[619,516,'carry',false],[271,579,'work',true],[366,599,'work',false],[432,595,'carry',true],[321,701,'torch',false],[550,762,'kneel',false],[687,771,'work',true],[235,811,'carry',false]])k.actor(x,y,y>700?1.08:.83,a,l);
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
 const {terrace,surf,side,top,hall,stair,p,C,w}=k;
 const light=k.lamp(527,563,.78,'#e8c78a',147),prism=k.lamp(615,409,.48,w.c4,123);light.marker=prism.marker=false;
 // A tall crystal cliff dominates the right rear. The excavated court sweeps
 // across the near left, with one small raised viewing platform at its edge.
 terrace('M382 487L409 373L491 313L590 296L676 345L745 427L759 511L697 568L596 602L484 570L408 589Z','M382 487L408 589L484 570L596 602L697 568L759 511L780 624L714 703L605 747L505 700L422 724L387 623Z',[376,290,786,754]);
 spire(k,581,414,88,283);spire(k,700,459,39,188);spire(k,445,456,30,130);
 terrace('M139 607L205 542L302 532L401 573L473 558L558 615L658 637L723 698L696 771L605 811L505 791L414 833L302 804L205 824L140 757L121 678Z','M139 607L121 678L140 757L205 824L302 804L414 833L505 791L605 811L696 771L723 698L741 787L680 839L594 861L500 832L414 874L299 843L204 865L138 818L115 741Z',[109,526,747,881]);
 // Inhabited masonry holds a distinct palette and does not become crystal.
 hall(463,525,188,118,{roof:'broken',windows:3});k.gallery(556,557,173);stair(479,581,-8,8,11,65);
 hall(175,618,105,65,{roof:'tile',windows:2});k.cloth(488,445,21,62,C.violet);
 k.basin(384,704,113,57,{liquid:'prism'});spire(k,260,733,28,115);spire(k,600,747,21,80);
 // Excavated sampling cuts reveal dark inner returns and a work bench nearby.
 surf('M465 669L496 645L540 654L527 689L487 710Z',[460,640,545,715],{...side,field:undefined,mat:'masonry',color:w.c1,exposure:.55});
 k.table(504,704,74);k.table(193,694,56);k.supplies(513,708,4);k.opening(209,796,36,63,-4);
 k.brazier(light,.78);k.brazier(prism,.65);
 for(let i=0;i<7;i++){const x=534+i*9,y=751+i%3*4;surf(`M${x} ${y}l3,-13l7,5l-2,11Z`,[x-3,y-17,x+13,y+7],{...top,field:worldField('prism',w),exposure:.7});}
 for(const [x,y,a,l]of[[509,564,'torch',false],[616,588,'bow',true],[425,630,'carry',false],[230,731,'work',true],[527,750,'work',true],[348,778,'kneel',false],[639,783,'carry',false],[203,824,'torch',false]])k.actor(x,y,y>700?1.05:.8,a,l);
}

function archive(k){
 const {terrace,hall,stair,basin,queue,lamp,cloth,w,C,p,r,surf,top}=k;
 const upperFire=lamp(354,386,.47,'#efba73',131),courtFire=lamp(549,651,.58,'#ffbc6f',137);upperFire.marker=courtFire.marker=false;
 surf('M122 715Q263 664 378 704Q460 733 499 779Q380 817 253 827Q147 801 122 715Z',[115,655,505,834],{...top,mat:'water',field:undefined,color:w.c1,shadow:w.c0,cx:-900,cy:1600,bump:.25,emission:0});
 terrace('M168 453L193 380L255 337L337 317L405 351L461 403L441 478L366 525L280 548L209 507Z','M168 453L209 507L280 548L366 525L441 478L461 403L479 529L420 576L357 620L277 649L216 607L173 553Z',[162,310,485,655]);
 terrace('M338 650L382 566L457 532L553 539L626 570L716 592L795 653L781 721L704 771L604 800L528 769L449 789L375 739Z','M338 650L375 739L449 789L528 769L604 800L704 771L781 721L795 653L797 759L732 812L664 846L595 826L534 854L467 827L414 845L357 780Z',[332,526,803,860]);
 // A dense stepped town, not one freestanding temple on a plate.
 hall(245,330,162,182+r()*28,{roof:'broken',windows:3});hall(173,436,136,95,{roof:'tile',windows:3});hall(324,445,143,113,{roof:'broken'});
 hall(505,606,159,86,{roof:'tile',windows:3});hall(680,670,81,63,{roof:'broken',windows:2});hall(409,666,117,77,{roof:'tile',windows:2});
 stair(370,495,-7,9,11,61);stair(572,614,-9,9,9,69);
 cloth(278,255,27,70,mix(w.c3,w.star,.28));cloth(526,499,31,83,C.linen);cloth(688,597,18,45,C.violet);
 basin(597,746,53,27,{color:w.c0,emission:0});
 k.supplies(527,733,6);
 // Written tablets and working tables belong to the court, below the roofs.
 for(let i=0;i<5;i++){const x=440+i*17,y=715-i*4;p.fill(`M${x} ${y}l12,-4l-1,16l-13,4Z`,C.linen);p.line(`M${x+2} ${y+4}l7,-2`,w.c1,1,.8);}
 k.table(536,713,60);k.table(620,714,51);k.opening(242,607,33,61,-6);k.opening(447,781,31,57,-5);k.gallery(609,576,133);

 // Stone ribs and deep returns make the upper record hall distinct from its
 // lower reading houses. A quay occupies the lowest level beside the dark lake.
 for(const [x,y,h]of[[247,334,166],[309,349,160],[400,369,147]]){
  surf(`M${x-6} ${y}l3,${-h}l11,4l4,${h-19}l9,23l-13,7Z`,[x-11,y-h-4,x+26,y+18],{...k.side,mat:'masonry',field:undefined,color:C.salt,normal:[-.55,.05,.85]});p.shadow(`M${x+8} ${y-h+9}l6,${h-22}l9,22l-10,7Z`,.4,1);
 }
 k.gallery(328,380,153);k.brazier(upperFire,.76);k.brazier(courtFire,.84);
 k.opening(333,302,31,84,4);surf('M321 305L333 293L348 309L335 316Z',[316,288,353,320],{...top,color:C.salt});
 k.bridge(290,587,420,650,34);k.actor(359,630,.8,'carry',false);
 // A reading desk contains open leaves and scrolls instead of generic jars.
 for(const [x,y]of[[546,716],[631,718],[468,694]]){p.fill(`M${x} ${y}l11,-4l12,5l-10,5Z`,'#c4b48a');p.line(`M${x+11} ${y-4}l2,8`,w.c1,1);p.line(`M${x+3} ${y}l6,-1m8,3l5,-1`,w.c1,.7,.7);}
 surf('M188 723L252 694L311 723L273 754L209 760Z',[182,688,317,766],{...top,mat:'wood',field:worldField('wood',w),color:'#817052'});
 for(let i=0;i<8;i++)p.line(`M${199+i*11} ${724+i*2}l-5,28`,w.c0,1.5,.6);
 p.fill('M190 776Q233 751 272 776Q238 802 190 776Z','#6c6247');p.fill('M199 776Q234 762 262 777Q237 791 199 776Z',w.c0);p.line('M238 777L260 737',C.copper,1);
 k.supplies(223,722,4);k.cloth(680,621,21,51,C.violet);
 for(const [x,y,a,l]of[[287,397,'carry',true],[218,480,'torch',false],[324,554,'carry',false],[473,724,'work',true],[555,744,'work',false],[646,749,'work',true],[721,723,'carry',false],[235,744,'carry',true]])k.actor(x,y,y>650?1.03:.78,a,l);
}

function chaos(k){
 const {terrace,surf,top,side,hall,stair,p,C,w}=k;
 const fire=k.lamp(446,581,.76,'#eebc7c',153),far=k.lamp(662,348,.45,w.c4,105);fire.marker=far.marker=false;
 const island=(a,b,c)=>terrace(a,b,c,{material:'ridge',color:mix(w.c2,'#777567',.42)});
 Object.assign(top,{field:worldField('ridge',w),color:mix(w.c2,'#777567',.42)});Object.assign(side,{field:worldField('ridge',w)});
 const flux=worldField('flux',w),quietFlux=q=>{const f=flux(q);return {...f,emission:f.emission*.46};};
 // One large occupied anchor-rock and two unequal fragments in depth. The
 // flowing void bends around them instead of joining three equal pedestals.
 surf('M112 544Q216 410 398 507Q500 571 607 434Q702 317 825 454L851 504Q734 420 641 540Q525 698 364 588Q220 495 136 606Z',[105,310,858,705],{...top,field:quietFlux,color:w.c3});
 island('M587 334L624 285L687 277L745 318L763 374L720 408L653 423L607 392Z','M587 334L607 392L653 423L720 408L763 374L746 466L697 516L664 533L644 472L607 455Z',[581,271,769,540]);
 hall(622,347,88,66,{roof:'broken',windows:2});k.gallery(667,377,89);
 island('M138 620L183 525L281 477L395 501L474 477L577 533L645 613L622 709L546 762L433 786L341 759L238 803L166 743Z','M138 620L166 743L238 803L341 759L433 786L546 762L622 709L645 613L661 755L595 831L501 863L422 843L344 881L252 849L208 877L160 803Z',[131,471,667,888]);
 // A broad sail pavilion wraps a central mast; small stores fit under its lee.
 p.line('M391 611L399 251',C.copper,7);
 surf('M399 251Q317 327 212 481Q326 448 395 477Q487 437 581 532Q493 365 399 251Z',[206,245,587,539],{mat:'cloth',field:undefined,color:mix(C.linen,'#9b9d85',.45),shadow:w.c1,accent:C.salt,normal:[-.35,-.17,1],height:foldField([[[399,257],[360,346],[287,427],[215,480],24,18],[[400,258],[445,367],[507,447],[579,530],24,17]])});
 p.shadow('M212 488Q368 472 581 537L594 616Q426 590 253 571Z',.32,10);
 for(const [x,y]of[[212,481],[581,532]]){p.line(`M${x} ${y}v104`,C.copper,5);p.line(`M399 251L${x-28} ${y+128}`,C.salt,1.5,.7);}
 hall(221,598,105,65,{roof:'tile',windows:2});k.gallery(434,628,194);stair(415,655,-7,8,10,62);
 k.bridge(553,563,633,410,23);k.table(459,702,69);k.supplies(470,704,5);k.table(242,686,59);
 // Lines and anchor winches carry the institution's central activity.
 for(const [x,y]of[[235,756],[554,734],[652,417]]){p.fill(ellipse(x,y,14,7),C.copper);p.fill(ellipse(x,y,7,3),w.c0);p.line(`M${x} ${y-10}l22,8`,C.salt,3);}
 for(let j=0;j<3;j++)p.line(`M${235+j*4} 754Q138 772 ${108+j*4} 681`,C.copper,1.3,.7);
 k.cloth(383,295,23,62,C.violet);k.opening(216,789,33,54,-4);k.brazier(fire,.82);k.brazier(far,.6);
 for(const [x,y,a,l]of[[653,395,'torch',false],[606,481,'carry',false],[359,583,'bow',true],[473,621,'carry',false],[274,722,'work',true],[495,747,'work',false],[545,777,'work',true],[340,784,'torch',false],[211,824,'carry',true]])k.actor(x,y,y>650?1.08:.8,a,l);
}

function cocoon(k){
 const {terrace,bridge,queue,lamp,w,C,p,r,surf,side}=k;
 const centralFire=lamp(457,601,.78,'#f4b572',160),sideFire=lamp(712,495,.48,w.c4,121);centralFire.marker=sideFire.marker=false;lamp(217,653,.26,w.c4,83);
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
 

 // The main cavity is an inhabited volume: receding floor, asymmetric jamb,
 // inner screen and an altar; outer ribs remain shell rather than masonry.
 k.opening(464,628,83,183,9);
 surf('M427 627L461 596L503 634L469 650Z',[422,591,509,656],{...k.top,field:worldField('silk',w),color:C.salt,exposure:.8});
 surf('M490 468Q511 535 504 633L490 624Q498 538 482 483Z',[477,464,515,638],{...side,field:worldField('shell',w),normal:[.65,.1,.74],exposure:.52});
 k.cloth(439,488,23,69,mix(C.violet,w.c1,.35));k.table(443,609,37);k.brazier(centralFire,.72);k.brazier(sideFire,.64);
 // Occupied niches and rib-bound balconies break the large unworked shell.
 for(const [x,y]of[[410,413],[513,449],[395,509],[535,536]]){k.opening(x,y,17,35);p.stroke(`M${x-11} ${y+3}q13,8 26,1`,C.salt,2,.6);}
 k.gallery(461,458,117);p.line('M411 465l-6,42M514 465l8,44',C.copper,2.5,.7);
 for(let i=0;i<9;i++){const x=480+i*8,y=707+i*3;p.line(`M${x} ${y}l-4,22`,C.copper,2);p.line(`M${x-5} ${y+3}l12,3`,C.salt,1.3,.5);}
 // Spools and mending frames are handled at the near landing.
 p.line('M538 722L577 733L575 774L538 763Z',C.copper,3);for(let i=0;i<6;i++)p.line(`M${542+i*6} ${727+i*2}l-1,31`,C.salt,.8,.65);
 for(const [x,y]of[[525,749],[538,751],[553,753]]){p.fill(ellipse(x,y,4,7),C.linen);p.line(`M${x-4} ${y-6}h8m-8,12h8`,C.copper,1.2);}
 k.opening(411,806,32,52,-4);k.cloth(357,643,23,57,C.violet);
 for(const [x,y,a,l]of[[208,665,'carry',false],[700,538,'torch',true],[465,650,'bow',true],[403,704,'carry',false],[417,766,'kneel',false],[555,789,'work',true],[590,747,'carry',false],[375,790,'torch',false]])k.actor(x,y,y>700?1.08:.78,a,l);
}

function bone(k){
 const {terrace,basin,hall,stair,lamp,queue,w,C,p,surf,side}=k;
 const archiveFire=lamp(333,439,.78,'#f3ba78',143),courtFire=lamp(561,675,.7,'#d2bd95',157);archiveFire.marker=courtFire.marker=false;
 // A single excavated crescent surrounds a deep court. Rear archives and
 // burial passages occupy the rim; there is no disconnected bridge island.
 terrace('M140 520Q149 390 263 356Q373 326 483 376L548 403Q660 377 751 461L810 574L788 696Q746 784 630 807L510 790Q399 817 292 754L192 674Z','M140 520L192 674L292 754Q399 817 510 790L630 807Q746 784 788 696L810 574L826 718L778 796L705 852L626 879L552 851L490 879L417 849L349 866L285 823L223 785L180 708L148 649Z',[134,320,833,886]);
 // Worked chalk paving is reserved for paths and the processional court.
 surf('M203 487L260 452L348 477L420 507L461 557L421 598L363 570L313 606L249 572L192 538Z',[187,447,467,612],{...k.top,mat:'masonry',field:undefined,color:mix(w.c3,w.c1,.36),exposure:.75});
 surf('M265 620L326 584L406 611L444 655L480 726L563 751L651 711L713 657L763 675L744 740L657 787L558 807L465 778L377 797L298 747Z',[259,578,769,813],{...k.top,mat:'masonry',field:undefined,color:mix(w.c3,w.c1,.4),exposure:.75});
 hall(220,430,184,129,{roof:'broken'});
 hall(591,481,134,83,{roof:'broken',windows:2});
 basin(543,647,171,88,{liquid:'ivory',color:w.c1,emission:0});
 stair(382,497,9,9,12,63);stair(502,584,4,7,9,40,{color:C.salt});
 for(const [x,y,h]of[[406,595,116],[505,552,133],[612,558,119],[695,624,135]]){
  surf(`M${x-11} ${y}Q${x-16} ${y-h*.6} ${x+38} ${y-h}Q${x+84} ${y-h*.67} ${x+81} ${y+7}L${x+68} ${y+5}Q${x+74} ${y-h*.58} ${x+39} ${y-h+18}Q${x-3} ${y-h*.45} ${x+1} ${y}Z`,[x-22,y-h-5,x+89,y+13],{...side,field:worldField('ivory',w),color:mix(w.c3,w.star,.16),height:(u,v)=>Math.sin(v*.04)*2});
 }
 for(let i=0;i<8;i++){const x=193+i*22,y=548+i*12;surf(`M${x-6} ${y}l2,-31q6,-9 11,-1l2,35Z`,[x-10,y-40,x+13,y+9],{...side,color:C.salt});p.line(`M${x} ${y-24}v12`,w.c1,1.3,.7);}
 k.opening(351,774,42,73,-7);k.opening(440,811,36,65,-5);k.opening(681,789,38,64,-6);
 k.table(300,658,63);k.table(560,760,59);k.supplies(612,747,4);k.cloth(269,363,25,57,C.violet);
 

 // A lit mortuary recess occupies the large rear archive; the low second
 // building stores tablets. Their interior floors turn away from the viewer.
 k.opening(306,445,57,109,9);surf('M281 445L306 426L335 452L310 464Z',[276,421,341,470],{...k.top,mat:'masonry',field:undefined,color:C.salt});
 k.brazier(archiveFire,.78);k.brazier(courtFire,.8);
 // Drawn rib returns and contact shadows give the bone arcade thickness.
 for(const [x,y,h]of[[406,595,116],[505,552,133],[612,558,119],[695,624,135]]){
  p.shadow(`M${x+69} ${y+4}Q${x+76} ${y-h*.6} ${x+39} ${y-h+16}Q${x+87} ${y-h*.65} ${x+82} ${y+8}Z`,.35,1);
  p.stroke(`M${x-5} ${y-3}Q${x-6} ${y-h*.5} ${x+36} ${y-h+6}`,C.salt,2,.6);
 }
 // A descent, votive ledges and a central slab make the depression a place.
 k.stair(591,605,-6,6,9,47);
 surf('M501 670L538 651L584 674L545 698Z',[495,645,590,704],{...k.top,field:worldField('ivory',w),color:C.salt});
 surf('M501 670L545 698L584 674L584 694L546 717L501 691Z',[495,665,590,722],{...side,mat:'masonry',field:undefined,color:w.c2,normal:[.3,.2,.92]});
 for(let i=0;i<5;i++){const x=516+i*10,y=670+i*3;p.line(`M${x} ${y}l11,-5`,C.salt,3);p.fill(ellipse(x,y,3,2),w.c1,.4);}
 for(const [x,y]of[[316,662],[575,763]]){p.fill(`M${x} ${y}l13,-5l15,5l-12,7Z`,'#b7a481');p.line(`M${x+3} ${y}l13,2`,w.c1,1);}
 k.cloth(618,430,19,41,C.violet);k.supplies(260,705,4);
 for(const [x,y,a,l]of[[268,481,'torch',false],[327,516,'carry',true],[393,565,'bow',false],[317,688,'work',true],[505,726,'kneel',false],[589,728,'bow',true],[574,790,'work',true],[711,718,'carry',false],[378,806,'torch',false]])k.actor(x,y,y>650?1.06:.8,a,l);
}

const SCENES={watcher,flesh,fungal,fire,frozen,colour,archive,chaos,cocoon,bone};
export function newCult(w,rule){const scene=SCENES[rule.layout];if(!scene)throw Error('未实现的教团组织 '+rule.layout);const k=cultKit(w,rule);scene(k);return k.finish({compositionRevision:['fungal','fire','frozen'].includes(rule.layout)?3:2});}
