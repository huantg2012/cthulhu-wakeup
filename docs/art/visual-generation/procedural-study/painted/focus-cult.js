import {Brush,rng,mix,noise,fbm} from './brush.js';
// One inhabited ritual ravine. Screen-space painted silhouettes and masks only.
// There is deliberately no common base disk, projected solid or building primitive.
export function sanctuary(seed=1339){
 const b=new Brush(seed),r=rng(seed),C={black:'#040d13',deep:'#0c2029',shadow:'#183a3c',blue:'#173847',mid:'#3d6555',sage:'#789078',light:'#b5b394',mint:'#68ba98',water:'#123c42',violet:'#342b49'};
 function stone(d,box,light=.6,flow=-.5){
  b.wash(d,[[0,mix(C.sage,C.light,light*.45)],[.28,mix(C.mid,C.sage,light*.4)],[.61,C.shadow],[.85,C.deep],[1,C.black]],[box[0],box[1],box[2],box[3]]);
  b.wash(d,[[0,'#b1a779'],[.28,'#8b8764'],[.55,'#244951'],[.8,'#2d2a43'],[1,'#081c29']],[box[0],box[1],box[2],box[3]],.20);
  b.pigment(d,box,{count:Math.min(1400,Math.round((box[2]-box[0])*(box[3]-box[1])/45)),scale:12,flow,colors:[C.sage,'#747254',C.blue,C.violet],alpha:.6});
 }
 function crack(d,a=.6,w=2){b.stroke(d,C.black,w,a);}
 function person(x,y,s=1,lit=false,bow=false){
  b.group(x,y,s*1.22,()=>{b.ellipse(4,3,7,3,'#040d14',.7);const d=bow?'M-6 -17Q-10 -8 -9 0Q-2 6 8 3Q9 -7 0 -16Z':'M-4 -20Q-9 -8 -8 0Q0 5 8 0Q5 -12 2 -20Z';b.wash(d,[[0,lit?'#b6b18d':'#697e75'],[.4,'#3a6251'],[1,'#10272d']],[-7,-18,9,3]);b.ellipse(bow?1:0,-21,3.3,4.5,lit?'#a3ab8c':'#718c73');b.line('M-3 -14Q-6 -5 -5 -1','#c2bf97',.8,.5);b.line('M2 -13L5 -2','#071a22',1,.7);});
 }
 function fire(x,y,s=1,cold=false){b.group(x,y,s,()=>{b.glow(0,-9,23,cold?'#60d8b0':'#c6a765',.23);b.ellipse(0,1,5,3,'#07151b');b.wash('M-4 -12L-3 0Q0 3 4 -1L5 -11Z',[[0,'#8f9573'],[1,'#263d36']],[-4,-12,4,1]);b.ellipse(0,-12,5,2,'#b8aa79');b.path('M-2 -12Q-4 -17 0 -22Q4 -17 2 -12Z',cold?'#95f3c9':'#ecd6a1');});}
 function step(x,y,w,dx=0){b.wash(`M${x-w/2},${y}Q${x},${y+6} ${x+w/2},${y-4}L${x+w/2+dx},${y+3}Q${x},${y+12} ${x-w/2+dx},${y+6}Z`,[[0,'#91a084'],[.35,'#4d7460'],[.6,'#244b44'],[1,'#122d32']],[x-w/2,y,x+w/2,y+8]);b.stroke(`M${x-w/2},${y}Q${x},${y+6} ${x+w/2},${y-4}`,'#b0b293',1.7,.55);}
 // Lost rear edges are cooler and lower-contrast than the inhabited ledges.
 b.wash('M129 486L153 380L190 356L213 291L242 278L265 219L299 252L312 330L329 420L285 540Z',[[0,'#1f4245'],[.45,'#1a343e'],[1,'#07121c']],[168,244,319,540],.7);
 b.wash('M490 337L527 292L546 312L570 264L596 308L612 390L642 422L635 535L550 577Z',[[0,'#30504c'],[.55,'#162d36'],[1,'#070e18']],[523,291,627,540],.75);
 // Lower sea washes BETWEEN the spurs, not around the outline of a flat tray.
 const sea='M87 610Q116 568 179 559Q272 575 316 553Q363 522 408 551Q447 580 525 590Q647 581 703 635Q678 697 568 711Q466 720 376 701Q274 734 192 708Q105 705 73 666Z';
 b.wash(sea,[[0,'#0e3039'],[.3,'#1b4a49'],[.6,'#102f3b'],[.82,'#111e2e'],[1,'#050e17']],[92,580,677,710],.9);
 b.pigment(sea,[72,548,704,733],{count:600,scale:17,flow:0,colors:['#4a9a81','#172847','#658e8a'],alpha:.28});
 for(let i=0;i<38;i++){const x=86+r()*586,y=616+r()*103;b.stroke(`M${x},${y}q${10+r()*18},${-5+r()*8} ${20+r()*36},-1`,i%5?'#2c665e':'#577786',.7+r()*1.7,.3);}
 // A broken, towering left buttress carries the approach and the cave sanctuary.
 const mass='M104 608L128 532L143 480L163 458L178 380L214 363L238 304L265 312L286 245L320 259L341 222L377 258L401 342L429 383L418 450L365 503L350 564L314 590L285 651L226 682L170 652L131 654Z';
 stone(mass,[97,214,439,691],.95,-.8);
 // Salt-dried upper rock is warmer than the wet wall beneath the same light.
 b.clip(mass,()=>{b.wash('M171 382L244 303L299 250L323 310L270 420L231 490L170 531Z',[[0,'#bbb18b66'],[.38,'#8c90603d'],[.7,'#52725218'],[1,'#193b3500']],[190,326,279,516]);});
 // Large broken planes and fissures establish height before small stone texture.
 const planes=[
  ['M178 384L216 369L231 402L215 478L237 537L205 599L170 641L143 627L162 550L153 483Z',.9],
  ['M247 316L267 321L269 402L249 478L272 544L252 605L226 651L213 609L235 536L222 464Z',.65],
  ['M290 255L319 270L312 347L326 410L297 469L300 550L279 585L269 538L283 447L268 391Z',.65],
  ['M346 234L375 266L382 346L403 385L375 430L343 464L333 420L358 367L337 325Z',.5]
 ];
 for(const[d,light]of planes)stone(d,[137,229,407,663],light,-.95);
 b.wash('M216 374L233 410L216 476L239 537L219 609L190 650L205 582L217 535L201 468Z',[[0,'#112d2d'],[.5,'#091d27'],[1,'#040d16']],[207,386,230,626]);
 b.wash('M319 273L327 359L342 416L316 474L322 556L294 590L305 489L313 431L304 348Z',[[0,'#29483d'],[.4,'#0b2027'],[1,'#030e17']],[310,270,327,586]);
 for(const d of ['M153 483L183 459L190 406','M177 550L193 521L180 482','M229 403L257 382L264 331','M265 539L285 511L283 459','M332 377L353 355L353 316','M243 604L267 580L270 557']){b.stroke(d,'#a6ae8d',3,.4);crack(d,.5,1);}
 // Front retaining cliffs surround a deep central ravine, exposing negative space.
 const front='M315 522Q342 492 380 482L428 508L468 539L448 594L461 652L431 693L402 682L389 621L366 582L346 631L330 670L294 672L301 613L283 579Z';
 stone(front,[279,479,473,699],.65,1.35);
 b.wash('M347 560Q366 535 382 553Q401 574 405 624L401 672L377 653L366 606L352 636L331 656Q332 599 347 560Z',[[0,'#040e18'],[.6,'#071922'],[1,'#0c252d']],[337,548,397,671]);
 b.stroke('M348 561Q366 536 383 559','#6c9179',4,.55);
 b.wash('M419 556L448 561L434 615L446 655L431 682L418 655L423 607Z',[[0,'#3d6355'],[.6,'#132e32'],[1,'#081722']],[416,552,449,683]);
 // Three distinct ground levels: ascent, receiving ledge, and the lower sunken choir.
 stone('M176 493Q201 455 248 443L283 451L282 482L232 502L205 527L171 523Z',[167,437,290,534],.9,.15);
 stone('M247 420L277 390L325 385L364 405L351 435L300 450L260 449Z',[241,382,368,456],.95,.1);
 stone('M352 377Q399 338 445 342L492 358L497 389L443 414L389 417L344 403Z',[340,333,505,423],.7,.15);
 // Embedded shrine: an open, shadowed chamber within the high tide-worn rock.
 const shrine='M286 347L292 268Q301 211 345 178Q390 195 413 244L423 319Q391 348 356 365Z';
 stone(shrine,[281,173,427,370],.8,-.25);
 b.wash('M310 331L313 274Q317 235 347 216Q379 230 389 267L394 320Q352 345 310 331Z',[[0,'#040b11'],[.55,'#081a21'],[1,'#203631']],[313,230,391,338]);
 b.wash('M295 274Q305 218 344 193Q384 208 403 253L395 265Q375 224 346 208Q315 230 308 277L305 327L294 337Z',[[0,'#a3ac87'],[.3,'#658367'],[.67,'#315b4b'],[1,'#152d32']],[296,200,409,337]);
 b.stroke('M299 273Q307 224 345 198Q379 213 399 254','#b6bb97',2.4,.55);
 b.wash('M304 258Q310 222 344 196L354 203Q322 226 316 261Z',[[0,'#d0be8e'],[.3,'#aaa277'],[1,'#667f5c']],[305,207,346,264],.45);
 // Broken outer archivolt exposes water-cut seams instead of a neat freestanding roof.
 for(let i=0;i<7;i++){const x=299+i*15,y=247-Math.sin(i/6*Math.PI)*46;crack(`M${x},${y}l8,12`,.85,2);b.stroke(`M${x+2},${y-2}l8,10`,'#a1ab86',1.2,.5);}
 stone('M295 335Q344 350 398 327L410 341Q361 367 288 352Z',[284,324,414,373],.8,0);
 step(341,355,102);step(338,364,111);step(335,373,118);
 // Small side niches and a communal working ledge belong to the rock sanctuary.
 b.wash('M236 366L239 336Q241 315 254 307Q267 318 268 338L267 366Z',[[0,'#030c14'],[.6,'#0b2029'],[1,'#2b4b3b']],[238,314,267,369]);
 b.stroke('M235 364L237 337Q238 315 254 305','#a4ad83',2.7,.52);
 b.wash('M269 362L273 336Q276 320 286 319L290 344L288 362Z',[[0,'#07121c'],[1,'#24443d']],[270,324,290,364]);
 b.stroke('M272 363L276 336Q278 327 284 324','#768f70',1.7,.6);
 b.wash('M225 373Q254 359 285 368L290 378L254 390L225 383Z',[[0,'#9b9f78'],[.3,'#536d4e'],[1,'#1e3533']],[225,365,290,388]);
 for(let i=0;i<6;i++){const x=235+i*7;b.line(`M${x},372l2,-${5+i%2*4}`,'#c0b88c',1.6,.75);}
 // Sacred measuring table and votive lights are set inside the actual recess.
 b.wash('M328 310L362 303L376 315L367 322L333 327Z',[[0,'#9a9a79'],[1,'#243d36']],[328,303,377,328]);
 b.path('M335 325L338 339L343 338L342 324Z','#0c1a21');b.path('M362 320L365 333L369 331L369 317Z','#0b1b23');
 for(let i=0;i<5;i++)fire(337+i*7,311-i%2*2,.4);
 b.glow(350,294,47,'#d0a565',.13);
 // A hanging tidecloth marks the rite without becoming a central decorative logo.
 b.line('M275 252L271 365','#263c34',5,.9);b.line('M271 257L305 264','#899578',2,.7);
 const cloth='M275 261Q287 270 301 266L298 328L289 346L278 332Q284 308 275 293Z';
 b.wash(cloth,[[0,'#8c9d7f'],[.4,'#3d7160'],[1,'#162f35']],[274,261,299,340]);b.pigment(cloth,[274,259,304,346],{count:100,scale:5,flow:1.55,alpha:.35});b.line('M280 275Q287 293 284 321','#b0b596',1,.55);
 // The sunken tide well is excavated into a lower spur, not placed on a flat plate.
 const spur='M414 370Q487 338 560 375L606 416L623 474L600 514L605 565L571 622L521 642L481 613L473 564L441 546L426 505L393 463Z';
 stone(spur,[387,337,628,650],.7,.4);
 b.wash('M588 427L620 467L595 516L601 559L570 615L531 637L526 598L554 541L548 494Z',[[0,'#254a43'],[.42,'#112a34'],[1,'#060f1c']],[552,420,616,626]);
 b.wash('M428 398Q481 364 541 394Q585 418 585 449Q580 497 515 517Q448 525 416 487Q388 453 428 398Z',[[0,'#7e9479'],[.33,'#4f7662'],[.56,'#203f3d'],[1,'#10252e']],[412,390,578,508]);
 // Recess wall: the back lip occludes the dark inner wall, which meets the water below.
 b.wash('M430 414Q483 380 538 405Q579 427 566 464Q543 500 493 503Q442 502 420 475Q399 443 430 414Z',[[0,'#040c14'],[.4,'#091a25'],[.7,'#153e3d'],[1,'#366455']],[426,410,539,501]);
 b.wash('M435 441Q478 412 530 434Q556 445 551 464Q534 489 490 490Q448 489 429 471Q416 455 435 441Z',[[0,'#11433f'],[.3,'#10333a'],[.6,'#071e2b'],[.85,'#1b3a43'],[1,'#2a514a']],[424,437,549,484]);
 // Spiral currents reinterpret the sea vortex in the original, restricted to water.
 for(let i=0;i<9;i++){const radius=10+i*5.5,offset=i*.46;let d='';for(let j=0;j<=35;j++){const a=j/35*Math.PI*1.65+offset,rr=radius*(.64+.36*j/35);const x=491+Math.cos(a)*rr,y=457+Math.sin(a)*rr*.45;d+=(j?'L':'M')+x+','+y;}b.stroke(d,i%3?'#4a8c78':'#92bba0',.6+i*.08,.18+(i%3)*.1);}
 b.ellipse(489,458,9,4,'#030e1a',.8);
 b.stroke('M422 427Q470 388 524 404Q553 411 570 439','#a4b69a',4,.7);
 b.stroke('M419 475Q444 510 494 510Q549 510 574 467','#678f77',6,.7);
 b.stroke('M424 478Q453 506 492 506','#bdd0ac',1.6,.65);
 // Cold waterlight is confined to the recess and adjoining wet stone.
 b.clip('M435 441Q478 412 530 434Q556 445 551 464Q534 489 490 490Q448 489 429 471Q416 455 435 441Z',()=>{b.glow(483,450,63,'#63dcc1',.38);});
 b.stroke('M434 447Q457 429 490 433Q520 433 538 452','#94ddbc',1.8,.5);
 b.stroke('M440 481Q478 507 529 487','#75bc9c',5,.38);
 b.ellipse(489,458,8,3.5,'#030e1a',.88);
 // Broken copings interrupt the otherwise overly regular lip.
 for(const [x,y,dx,dy]of[[429,419,-5,-9],[452,405,-3,-11],[480,399,1,-10],[511,402,4,-8],[540,414,7,-7],[562,434,8,-3],[549,492,4,9],[476,511,-1,9]]){b.line(`M${x},${y}l${dx},${dy}`,'#0c2429',1.9,.72);b.line(`M${x+2},${y}l${dx},${dy}`,'#b1bd96',.7,.65);}
 // The processional path climbs the actual separated ledges.
 for(let i=0;i<12;i++){const t=i/11;step(182+t*69,586-t*79,41+t*9,-2);}
 for(let i=0;i<7;i++){const t=i/6;step(246+t*43,474-t*53,47,-1);}
 for(let i=0;i<6;i++){const t=i/5;step(346+t*42,432-t*33,40,0);}
 // Netting and suspended tide-measures show daily work at the landing.
 b.line('M175 489Q204 503 239 485','#8d9879',1.3,.65);
 for(let i=0;i<6;i++){const x=181+i*10;b.line(`M${x},${493+Math.sin(i)*4}q-1,13 4,29`,'#486957',.8,.65);}
 for(let i=0;i<3;i++)b.line(`M183,${501+i*7}q27,8 53,-5`,'#61785f',.8,.55);
 // A narrow bridge crosses the dark ravine into the lower choir.
 b.wash('M351 486Q381 463 414 460L424 476Q389 482 360 506Z',[[0,'#8a9b7d'],[.32,'#557c62'],[1,'#1c3d37']],[351,478,423,503]);
 b.path('M358 505Q391 487 424 477L420 489Q387 498 361 515Z','#102a2f');
 for(let i=0;i<7;i++)b.line(`M${359+i*8},${486-i*2.3}l5,13`,'#1a3533',1.2,.8);
 b.stroke('M355 484Q386 464 416 462','#b1b595',2,.7);
 // Tide-gauge tower is an open, spindly measuring instrument on the high right bank.
 b.stroke('M592 434L582 235','#132b2f',6,.9);b.stroke('M582 235L590 426','#839781',1.8,.8);
 b.stroke('M563 426L572 280','#233b3a',4,.8);
 for(let i=0;i<5;i++){let y=265+i*28;b.line(`M568,${y+8}L594,${y-3}`,'#5b806c',2,.8);b.line(`M577,${y+4}l2,-9`,'#b3b28a',1,.7);}
 b.line('M581 247Q556 265 531 249','#637969',1,.8);
 const ribbon='M533 250Q544 268 558 261L551 303L543 333L537 319L540 291Z';b.wash(ribbon,[[0,'#718e75'],[.55,'#305d4e'],[1,'#142d32']],[534,250,554,334]);b.stroke('M538 267Q548 293 542 318','#a2ad8f',1.5,.5);
 // Believers face the water; their spacing and directed path express the ritual.
 for(const [x,y,s,lit,bow]of[[418,506,1.05,true,true],[449,528,1.12,false,true],[491,536,1.12,true,true],[541,518,1.05,false,true],[575,487,1,true,true],[307,405,.9,true,false],[276,469,.92,false,false],[217,549,1.0,true,false],[373,484,.95,false,true]])person(x,y,s,lit,bow);
 for(const [x,y,s]of[[406,463,.8],[436,514,.75],[519,523,.8],[576,457,.9],[313,382,.7]])fire(x,y,s);
 // Drains carry the upper ritual water down a broken wall into the surrounding sea.
 b.wash('M543 493Q548 516 536 540Q521 568 524 594L505 636L518 643Q540 613 542 588Q544 565 554 549Q566 520 555 492Z',[[0,'#245b52'],[.33,'#70a78c'],[.65,'#183b46'],[1,'#123044']],[539,496,526,645],.88);
 b.stroke('M548 501Q557 527 542 549Q530 574 533 591L513 637','#8dc6aa',2.2,.65);
 b.stroke('M552 511Q558 534 545 549','#d2dbc2',1,.55);
 b.glow(515,639,24,'#65b89a',.12);
 for(let i=0;i<11;i++)b.stroke(`M${495+r()*33},${639+r()*15}q12,5 24,-1`,'#7fb49e',.6+r(),.4);
 // Wet lower strata catch sea bounce; higher salt faces stay warmer and matte.
 b.stroke('M147 626L172 643L209 660L234 655','#619e8e',3,.55);
 b.stroke('M310 645L329 660L344 625','#417c7c',2,.5);
 b.stroke('M552 622L575 605L586 575','#3f7b82',2,.45);
 b.clip(mass,()=>{for(let i=0;i<80;i++){const x=134+r()*247,y=397+r()*250;if(noise(x*.03,y*.04,seed)>.53)b.stroke(`M${x},${y}l${5+r()*15},${-4-r()*7}`,'#c2bb96',.8+r()*1.8,.16);}});
 b.clip(front,()=>{b.glow(376,617,67,'#5d598f',.24);});
 b.stroke('M358 588Q357 606 366 621','#53657c',1.6,.4);
 // A modest tide landing provides an inhabited foreground without enclosing the diorama.
 b.wash('M150 634L217 650L234 664L182 682L130 666Z',[[0,'#5d7965'],[.5,'#233f3c'],[1,'#0b1d29']],[135,636,233,685]);
 for(let i=0;i<5;i++){const x=144+i*17,y=650+i*3;b.line(`M${x},${y}l-2,27`,'#101f29',4,.8);b.line(`M${x},${y}l1,-13`,'#8b9c7c',2,.7);}
 b.line('M141 639Q182 655 215 650','#657e6d',1,.7);
 for(let i=0;i<5;i++){const x=247+i*14,y=419+i%2*6;b.wash(`M${x-4},${y-5}Q${x-8},${y+3} ${x-4},${y+10}Q${x},${y+14} ${x+5},${y+9}L${x+4},${y-5}Z`,[[0,'#8b9874'],[1,'#183832']],[x-5,y-5,x+6,y+11]);b.ellipse(x,y-5,4,2,'#0b2024');}
 b.fade();
 return {p:b.output(),features:{construction:'潮汐裂谷、三级祭径、洞窟祭所与下沉潮井',seed,method:'direct-2d-light-and-occlusion-composition'}};
}
