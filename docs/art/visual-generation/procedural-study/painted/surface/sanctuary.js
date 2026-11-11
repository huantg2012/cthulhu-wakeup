import {tide,roles} from './world.js';
import {SurfacePainter,ellipse,rng,fbm,noise,mix,clamp,smooth} from './engine.js';

// Screen-space illustration plans. Nothing here is a mesh, extrusion, camera,
// model or ray-traced scene. The oblique planes are drawn 2D footprints.
export function sanctuary(worldSeed=1339,world=tide,config={}){
 const r=rng(worldSeed),C=roles(world);
 // One source definition drives both the visible lamp and received light.
 // Visibility is an illustrated occlusion mask, not a 3D shadow simulation.
 const lights={
  well:{id:'well',x:615,y:580,z:48,r:184,color:[87,238,179],power:.66,falloff:1.7,specular:.20},
  altar:{id:'altar',x:337,y:361,z:52,r:168,color:[255,140,57],power:.92,falloff:1.75,specular:.1,visibility:(x,y)=>smooth(273,310,x)*(1-smooth(420,485,x))},
  stair:{id:'stair',x:270,y:526,z:38,r:118,color:[255,145,62],power:.78,falloff:1.8,specular:.09}
 };
 const Painter=config.Painter||SurfacePainter,p=new Painter(worldSeed,{emitters:Object.values(lights)});
 const rock={mat:'stone',color:C.stone,shadow:C.stoneShadow,accent:C.salt,scale:40,bump:.8};
 const top={...rock,normal:[-.36,-.64,.70],exposure:1.02};
 const wall={...rock,normal:[.10,.17,1],color:mix(C.stone,C.wet,.22),exposure:.96};
 const dark={...rock,normal:[.31,.12,.88],color:'#456457',exposure:.86,ambient:[.16,.22,.27]};
 const riser={...rock,normal:[.48,.18,.82],ambient:[.12,.17,.20],exposure:.85,bump:.62};
 function surface(d,box,o={}){p.surface(d,box,{...rock,...o});}
 function crack(d,width=1){p.line(d,'#102831',width,.65);}
 function flame(x,y,s=1){p.line(`M${x},${y}v${8*s}`,'#776745',2*s);p.fill(ellipse(x,y,2*s,4*s),'#ffdda0');p.fill(ellipse(x,y-1,1*s,2*s),'#fff4cd');p.glow(x,y,24*s,'#e4aa5e',.22);}
 function brazier(e,s=1){
  const {x,y}=e;
  p.fill(ellipse(x+5*s,y+24*s,14*s,4*s),'#0b171d',.55);
  surface(`M${x-4*s},${y+9*s}L${x-3*s},${y+23*s}L${x+4*s},${y+25*s}L${x+5*s},${y+9*s}Z`,[x-6*s,y+7*s,x+8*s,y+27*s],{mat:'metal',color:C.copper,shadow:C.wet,accent:C.salt,normal:[-.3,.1,1]});
  p.fill(`M${x-11*s},${y+4*s}Q${x},${y+19*s} ${x+11*s},${y+4*s}Z`,'#6e5739');
  p.fill(ellipse(x,y+4*s,11*s,3.8*s),'#cf8b46');
  p.glow(x,y,54*s,'#ffa64b',.33);
  p.fill(`M${x-5*s},${y+4*s}Q${x-7*s},${y-3*s} ${x-2*s},${y-10*s}Q${x-2*s},${y-3*s} ${x+2*s},${y-5*s}L${x+4*s},${y-13*s}Q${x+11*s},${y+1*s} ${x+5*s},${y+5*s}Z`,'#ffc069');
  p.fill(ellipse(x+1*s,y,2.5*s,5*s),'#fff0bb');
 }
 function pilgrim(x,y,s=1,light=false,bow=false){
  // Each body is a single hanging cloak with an overlapping head, plus shadow.
  p.fill(ellipse(x+6*s,y+2*s,10*s,3.2*s),'#04131a',.65);
  p.fill(`M${x-5*s},${y-17*s}Q${x-9*s},${y-5*s} ${x-9*s},${y}Q${x},${y+4*s} ${x+7*s},${y}L${x+5*s},${y-17*s}Z`,light?'#788e75':'#233a3a');
  p.fill(`M${x-4*s},${y-17*s}Q${x-2*s},${y-29*s} ${x+2*s},${y-26*s}Q${x+7*s},${y-23*s} ${x+5*s},${y-17*s}Z`,light?'#b7b99a':'#567466');
  p.fill(ellipse(x+(bow?3:1)*s,y-20*s,2.6*s,3.3*s),'#08191f');p.line(`M${x-3*s},${y-15*s}l${-2*s},${12*s}`,light?'#bac29e':'#718977',1.4*s,.8);
  if(bow)p.line(`M${x+3*s},${y-13*s}l${6*s},${3*s}`,light?'#9bac8d':'#566c5d',2*s);
 }
 function stair(x,y,dx,dy,n,width){
  for(let i=0;i<n;i++){const xx=x+dx*i,yy=y+dy*i,w=width*(1+i*.004),d=`M${xx-w*.5},${yy}l${w},${-w*.15}l${dx*.85},${dy*.85}l${-w},${w*.15}Z`;
   surface(d,[xx-w*.55-2,yy-w*.16-2,xx+w*.55+dx+3,yy+dy+6],{...top,scale:21,color:i%3?'#879d80':'#acb18a',bump:.45});
   p.line(`M${xx-w*.5},${yy+dy*.9}l${w},${-w*.15}`,'#172f30',1.8,.9);p.stroke(`M${xx-w*.45},${yy}l${w*.82},${-w*.15}`,'#b6bf98',1.4,.65);
  }
 }
 function arch(x,y,w,h,tilt=0){return`M${x-w/2},${y}L${x-w/2},${y-h*.55}Q${x-w*.45},${y-h*.85} ${x},${y-h}Q${x+w*.4},${y-h*.77+tilt} ${x+w/2},${y-h*.53+tilt}L${x+w/2},${y+tilt}Z`;}
 function opening(x,y,w,h,lit=false,tilt=0){
  const d=arch(x,y,w,h,tilt);surface(d,[x-w/2-3,y-h-3,x+w/2+3,y+tilt+3],{mat:'plain',color:lit?'#20322e':'#071922',normal:[0,0,1],exposure:.35});
  p.line(`M${x-w/2-2},${y}L${x-w/2-2},${y-h*.55}Q${x-w*.45},${y-h*.85} ${x},${y-h}Q${x+w*.4},${y-h*.77+tilt} ${x+w/2+2},${y-h*.53+tilt}`,'#b3b28b',3,.62);
  p.line(`M${x-w/2+5},${y-2}L${x-w/2+5},${y-h*.53}Q${x-w*.4},${y-h*.8} ${x},${y-h+7}`,'#445d4c',3,.7);
  if(lit){p.glow(x,y-h*.42,w*1.2,'#d9a965',.17);for(let k=0;k<3;k++)flame(x-9+k*9,y-12+k%2*3,.65);}
 }
 // Broken tide patches recede into the background. There is no shared disc.
 for(const [d,b,exp]of[
  ['M104 735Q135 696 198 714L282 740Q352 774 423 749Q466 740 491 769Q421 813 344 798Q279 826 198 794Q123 794 104 735Z',[100,695,498,830],.75],
  ['M488 751Q584 711 687 730L822 700Q871 715 855 754Q828 794 737 785Q648 826 572 798L488 785Z',[485,700,876,832],.65]
 ])surface(d,b,{mat:'water',color:'#1e655b',shadow:'#061822',cx:-1600,cy:2000,v:(x,y)=>760+(y-760)*2.1,normal:[0,-.75,.5],exposure:exp,bump:.3,emission:.01});
 // Far shoals and the rear retaining wall establish receding planes.
 surface('M422 292L470 263L496 279L511 266L530 303L574 319L568 378L541 410L462 395Z',[420,260,577,415],{...dark,scale:48,height:(x,y)=>fbm(x*.025,y*.018,worldSeed)*7});
 surface('M575 401L615 371L655 378L662 404L700 413L723 454L706 501L634 496L594 465Z',[573,370,727,504],{...dark,color:'#33594f',scale:53});
 // Main sea-cut cliff. A broken edge falls in several depths rather than
 // tracing a flat common base. Large seams guide smaller mineral fields.
 const cliff='M170 431L207 408L246 422L284 400L327 419L368 413L400 438L454 443L484 478L467 532L446 558L450 610L420 641L402 710L366 728L342 692L318 726L294 706L282 760L249 776L213 754L188 719L151 704L132 658L146 623L128 576L151 549L143 496Z';
 surface(cliff,[125,398,489,780],{...wall,scale:46,height:(x,y)=>26*fbm(x*.008,y*.011,worldSeed+7)+8*fbm(x*.023,y*.024,worldSeed)+3*Math.sin(y*.08+x*.04),corrupt:(x,y)=>Math.exp(-Math.pow((x-304)/82,2)-Math.pow((y-704)/67,2))*.65,glow:world.corruption,wet:(x,y,n)=>smooth(560,750,y)*(.6+n*.3),shadowField:(x,y)=>clamp(1-(x-220)*.0015,.42,1)});
 // Broad shared shadow establishes the inlet before any cracks are painted.
 p.shadow('M391 477L458 485L442 552L445 606L417 642L402 711L365 727L363 669L379 627L365 584Z',.52,5);
 p.shadow('M173 487L184 546L168 585L185 614L170 674L151 686L134 654L148 619L132 577L154 545Z',.32,3);
 surface('M205 549L244 529L263 573L245 613L257 660L235 707L212 751L189 715L197 673L180 640L198 599Z',[177,526,267,755],{...wall,color:'#8c9b7b',normal:[.04,.22,1],height:(x,y)=>fbm(x*.025,y*.04,worldSeed)*6,wet:(x,y)=>smooth(625,760,y),scale:32});
 for(const d of['M184 507L203 541L198 581L214 605L205 658','M290 481L309 516L298 548L321 578L313 629L324 658','M355 508L343 544L353 584L340 621L347 673','M232 689L252 681L268 692L277 722'])crack(d,2.3);
 // Two roofless sea caves explain undercut thickness, not front-face symbols.
 opening(281,705,54,102,false,-9);opening(363,653,37,73,false,-4);
 p.stroke('M250 700Q246 640 282 601Q311 625 310 674','#70917b',3,.5);
 // Upper inhabited terrace: footprint is skewed, eroded and interrupted.
 const terrace='M161 424L213 388L259 388L293 370L359 389L414 417L469 430L491 464L460 493L418 507L382 534L338 530L300 561L264 551L219 568L192 544L204 515L170 501L179 465Z';
 // Return faces share the exact top footprint. They describe a drop in
 // elevation at the blue-arrow locations instead of an arbitrary dark patch.
 surface('M491 464L460 493L418 507L382 534L338 530L300 561L264 551L219 568L216 589L263 575L302 586L340 555L383 559L420 532L459 517L477 501Z',[213,461,494,592],{...riser,scale:35,wet:(x,y,n)=>smooth(490,590,y)*n*.35});
 surface('M161 424L179 465L170 501L204 515L192 544L219 568L216 589L178 563L186 530L151 516L158 468L146 444Z',[143,421,222,592],{...wall,color:mix(C.stone,C.wet,.3),normal:[-.13,.30,1],scale:35,exposure:.8});
 surface(terrace,[158,368,494,572],{...top,scale:35,height:(x,y)=>fbm(x*.025,y*.023,worldSeed)*4,wet:(x,y,n)=>smooth(485,575,y)*n});
 // Paving follows a single oblique chart and is clipped to the terrace.
 p.c.save();p.c.clip(new Path2D(terrace));
 for(let v=0;v<7;v++)for(let u=0;u<12;u++){const x=202+u*21-v*14,y=392+u*7+v*18;if(r()<.16)continue;p.stroke(`M${x},${y}l18,6l-11,12`,'#283f37',.9,.5);if(r()>.68)p.stroke(`M${x+2},${y+2}l14,4`,'#b2b693',1.2,.35);}
 p.c.restore();
 // Chapel's side wall recedes back, its roof is partly lost. The interior floor
 // and doorway are visible from the same oblique view as the terraces.
 surface('M219 366L223 244L303 190L341 218L329 389L274 421Z',[216,187,345,425],{...wall,mat:'masonry',color:'#516f5c',normal:[-.52,.06,.85],scale:30,height:(x,y)=>fbm(x*.03,y*.04,worldSeed)*3,pointVisibility:(e)=>e.id==='altar'?.18:1});
 surface('M222 245L242 229L245 221L261 223L280 202L304 191L329 207L341 218L311 235L275 245L247 269Z',[219,188,345,273],{...top,color:'#a3ad87',scale:27});
 opening(252,355,24,67,false,-15);opening(290,330,22,67,false,-15);
 // A surviving sliver of patinated roof lies behind the broken facade.
 // Its material differs from the dry masonry below and the wet cliff foot.
 surface('M232 244L251 223L270 221L286 201L306 194L332 209L349 220L362 230L351 241L329 238L311 254L292 257L276 271L258 263L246 266Z',[229,191,365,274],{mat:'metal',color:mix(C.copper,C.wet,.48),shadow:C.wet,accent:C.copper,normal:[-.35,-.7,.65],height:(x,y)=>3*fbm(x*.035,y*.04,worldSeed+11),exposure:.7});
 for(let i=0;i<7;i++){const x=249+i*13,y=238+i*3;p.stroke(`M${x},${y}l16,-22`,'#7b977b',1.8,.5);}
 // The main facade has three unequal arches, buttresses, salt staining and a
 // broken parapet, with a taller central opening and an occupied inner altar.
 const facade='M290 260L305 251L312 234L329 237L345 213L363 230L374 261L396 272L405 259L419 269L425 288L451 294L459 286L477 298L481 322L502 332L505 440L473 463L429 450L394 440L352 423L306 413L287 393Z';
 surface(facade,[284,210,510,469],{...wall,mat:'masonry',color:mix(C.stone,C.salt,.15),scale:26,height:(x,y)=>fbm(x*.029,y*.041,worldSeed+9)*4,shadowField:(x,y)=>clamp(1-(x-325)*.0019,.5,1)});
 // Interior openings reveal the dark volume. The floor plane is independently lit.
 opening(336,400,57,140,true,17);opening(413,425,38,98,false,12);opening(475,445,28,78,false,9);
 surface('M315 402L347 385L363 409L338 421Z',[312,383,366,425],{...top,color:'#b6ad7f',scale:18});
 p.shadow('M351 282L361 304L363 413L348 407Z',.5,2);
 // Buttress geometry is only a painted silhouette and two material planes.
 for(const [x,y,h]of[[292,406,122],[375,438,125],[447,460,111],[501,458,99]]){
  surface(`M${x-7},${y}L${x-3},${y-h}L${x+6},${y-h+4}L${x+10},${y-21}L${x+17},${y+5}L${x+5},${y+11}Z`,[x-10,y-h-3,x+20,y+15],{...wall,color:'#b4b58b',scale:21,normal:[-.5,-.1,.85],height:(xx,yy)=>fbm(xx*.04,yy*.05,worldSeed)*1.7});
  p.shadow(`M${x+6},${y-h+5}L${x+10},${y-21}L${x+17},${y+5}L${x+9},${y+8}Z`,.4);
 }
 // Masonry joints run along the facade's own slope, not screen horizontal.
 for(let i=0;i<10;i++){const y=282+i*13;p.stroke(`M296,${y}l35,12`,'#445443',.8,.4);p.stroke(`M370,${y+26}l31,10`,'#435743',.8,.4);p.stroke(`M434,${y+46}l30,10`,'#344c3e',.8,.4);}
 // Occlusion under stone ledges separates the built institution from the
 // cliff it inhabits. Only illuminated upper edges get a broken highlight.
 p.shadow('M308 411L351 423L393 440L429 450L475 463L489 460L477 479L430 466L390 453L350 437L308 424Z',.56,3);
 p.stroke('M304 412L352 429L394 443L431 456','#b5b38b',2,.5);
 p.stroke('M306 256L330 244L345 222L360 235','#d1c594',2.5,.8);
 // Small bell frame and a hanging tidal shroud give the ruin a living role.
 p.line('M270 254L269 166L291 153L303 160L302 238','#374e43',4);
 p.line('M271 166L291 156L301 160','#b4b38c',1.7,.9);
 p.surface('M280 171Q286 182 293 176L296 191L291 198L280 195L277 188Z',[275,168,298,201],{mat:'metal',color:'#a69765',shadow:'#2a594c',accent:'#d0c38d',normal:[-.5,0,1]});
 p.line('M287 198v7','#8d9c74',1.5,.7);
 const banner='M237 285Q250 299 267 290L264 354L257 379L249 366L243 374Q245 341 237 316Z';
 surface(banner,[234,282,270,382],{mat:'cloth',color:'#759580',shadow:'#153e3d',accent:'#c2c09a',height:(x,y)=>4*Math.sin((x-237)*.21+(y-285)*.03),normal:[-.2,0,1],u:(x,y)=>x+y*.08});
 p.stroke('M242 295Q255 316 250 359','#b0b999',1.4,.7);
 p.line('M237 284L268 291','#9d9f77',2,.75);
 // Altar and records in the recess, rather than an emblem on the roof.
 surface('M320 368L337 359L352 368L338 378Z',[317,357,355,380],{...top,color:'#b0a77c',scale:14});
 p.fill('M325 374L325 390L331 392L332 376Z','#20332e');p.fill('M344 373L344 391L350 388L350 370Z','#13282b');
 brazier(lights.altar,.8);
 // Main stair and turn at the mid-level landing, visibly descending.
 stair(340,434,-5.8,7.5,11,65);
 surface('M250 516L293 497L323 511L308 539L273 553L244 538Z',[241,494,326,556],{...top,scale:24});
 stair(268,550,-4.8,8.3,10,49);
 brazier(lights.stair,.82);
 // Lower choir grows from a separate undercut rock spur, with a tall dark
 // face below the basin and water in the fissure between the two rock masses.
 const spur='M460 530L495 503L531 506L565 487L620 493L649 510L697 505L729 536L772 550L801 594L783 637L796 670L768 693L760 742L728 765L686 749L653 779L620 759L585 781L554 749L520 741L505 699L476 678L487 632L452 603Z';
 surface(spur,[449,483,805,784],{...dark,color:'#738c71',scale:42,height:(x,y)=>23*fbm(x*.009,y*.012,worldSeed+5)+5*fbm(x*.024,y*.022,worldSeed+5),wet:(x,y,n)=>smooth(615,785,y)*(.55+n*.4)});
 surface('M485 603L519 612L529 662L549 678L541 710L564 744L586 778L554 747L520 738L503 698L477 676L487 633Z',[474,600,589,783],{...wall,scale:31,color:'#879c7b',wet:(x,y)=>smooth(660,780,y)});
 p.shadow('M670 606L731 619L746 659L729 700L740 740L723 763L686 748L653 776L638 738L654 699L648 650Z',.23,4);
 for(const d of['M582 652L573 686L593 709L582 746','M744 628L759 651L747 683L756 704','M613 661L629 682L619 723L633 753'])crack(d,2);
 const choir='M457 539L495 511L532 517L566 495L618 500L648 520L694 516L729 544L767 559L784 591L759 626L714 643L676 673L638 665L594 684L556 669L525 677L493 646L468 637L474 597L453 574Z';
 surface(choir,[450,491,788,688],{...top,color:mix(C.stone,C.wet,.12),scale:33,wet:(x,y,n)=>smooth(480,670,y)*n*.65});
 // Processional bridge crosses the fissure; its underside is in shared shadow.
 surface('M340 575Q398 545 469 550L492 569Q410 574 356 602Z',[337,542,495,605],{...top,scale:23});
 surface('M355 601Q420 573 492 569L486 583Q412 589 359 614Z',[352,567,495,617],{...dark,scale:27});
 for(let i=0;i<12;i++){const x=353+i*11,y=577-i*1.2;p.line(`M${x},${y}l8,17`,'#273f36',1,.7);}
 p.stroke('M345 574Q402 546 471 551','#b7c09c',2.3,.8);
 // Excavated basin has an upper lip, inner wall and a lower water surface.
 surface(ellipse(615,573,116,64),[496,506,734,640],{...top,color:C.stone,scale:24,wet:()=>.4});
 surface(ellipse(615,575,97,51),[515,521,715,629],{...dark,color:'#39594b',normal:[0,.5,.8],scale:23});
 p.shadow(ellipse(614,571,88,45),.4,4);
 p.surface(ellipse(615,588,83,35),[529,550,701,626],{mat:'water',color:'#438c72',shadow:'#041b25',cx:615,cy:588,v:(x,y)=>588+(y-588)*2.1,normal:[0,-.85,.52],bump:.5,emission:.055});
 p.glow(lights.well.x,lights.well.y,92,'#4bdf9e',.23);
 for(let k=0;k<6;k++){const rad=17+k*9;let d='';for(let j=0;j<54;j++){const a=j/53*Math.PI*1.6+k*.6,rr=rad*(.64+.36*j/53);d+=(j?'L':'M')+(615+Math.cos(a)*rr)+','+(588+Math.sin(a)*rr*.42);}p.stroke(d,k%2?'#73be91':'#32675c',1,.4);}
 p.fill(ellipse(615,588,10,4.5),'#03131d',.9);
 p.stroke('M517 566Q550 520 612 523Q673 519 710 562','#c1c6a0',3,.7);
 p.stroke('M531 610Q611 660 698 611','#7da482',4,.7);
 // Chipped coping stones have coordinated joint/height/colour variations.
 for(let i=0;i<19;i++){const a=i/19*Math.PI*2,x=615+Math.cos(a)*107,y=575+Math.sin(a)*58;
  p.line(`M${x-Math.cos(a)*6},${y-Math.sin(a)*4}l${Math.cos(a)*11},${Math.sin(a)*7}`,'#254538',1.5,.7);
  if(i%3===0)p.stroke(`M${x},${y}l${-Math.sin(a)*7},${Math.cos(a)*4}`,'#c8cba3',1.3,.7);
 }
 // Rear choir columns frame the water, allowing the viewer to see inside.
 for(const [x,y,h,w]of[[519,543,73,14],[567,516,83,15],[669,532,70,14],[723,571,91,16]]){
  surface(`M${x-w/2},${y}L${x-w*.35},${y-h}L${x+w*.3},${y-h-3}L${x+w*.5},${y}Z`,[x-w,y-h-6,x+w,y+4],{...wall,color:C.stone,scale:19,height:(xx,yy)=>2*Math.sin((xx-x)*.5),normal:[-.4,0,1]});
  surface(ellipse(x,y-h,w*.6,w*.25),[x-w,y-h-w*.3,x+w,y-h+w*.3],{...top,color:'#b2bc92',scale:12});
  p.line(`M${x+w*.3},${y-h+6}L${x+w*.4},${y}`,'#2d5146',1.6,.7);
 }
 p.line('M518 472Q541 488 567 433Q617 469 669 462Q697 493 723 480','#617e68',1.3,.7);
 // Two hanging votive cloths follow the curve of the choir. Their quiet
 // violet underside echoes this world's corruption hue without stone cells.
 for(const [x,y,w,h]of[[544,470,21,46],[693,485,18,44]]){
  surface(`M${x-w/2},${y}Q${x},${y+7} ${x+w/2},${y+2}L${x+w*.3},${y+h-5}L${x+2},${y+h}L${x-4},${y+h-9}L${x-w*.4},${y+h-3}Z`,[x-w,y-3,x+w,y+h+3],{mat:'cloth',color:mix(C.violet,C.linen,.25),shadow:C.violet,accent:C.salt,normal:[-.2,0,1],height:(xx,yy)=>3*Math.sin((xx-x)*.28+(yy-y)*.03),bump:.6});
  p.stroke(`M${x-3},${y+8}l2,${h-19}`,'#a2a484',1.2,.6);
 }
 // Offerings and a choir of people make this a used institution.
 for(const [x,y,s,lit,bow]of[[509,597,.88,true,true],[546,639,.95,false,true],[589,656,1.05,true,true],[648,652,1.02,false,true],[699,625,.94,true,true],[742,604,.94,false,true],[392,577,.82,true,false],[295,520,.83,false,false],[250,583,.88,true,false],[351,448,.82,true,false],[219,446,.72,false,false]])pilgrim(x,y,s,lit,bow);
 for(const [x,y,s]of[[490,566,.9],[533,630,.85],[627,651,.9],[715,606,.9],[307,480,.8],[230,607,.85],[270,539,.65]])flame(x,y,s);
 // Drain follows the lowest breach. Wet bands and reflections share its path.
 surface('M700 604Q713 629 703 652Q694 679 704 699L692 727L703 758L717 757Q705 728 719 706Q711 679 722 651Q730 628 716 600Z',[689,598,732,763],{mat:'water',color:'#6ba68d',shadow:'#103947',cx:704,cy:690,normal:[-.15,.1,1],bump:.3,emission:.035,u:(x,y)=>x,v:(x,y)=>y*.3});
 p.stroke('M709 610Q725 636 712 666Q705 681 712 701Q701 727 711 750','#9bcbb0',2,.7);
 p.glow(710,760,34,'#50b98b',.12);
 // Lowest landing: work sheds, drying net and a tied boat in the inlet.
 surface('M163 680L201 671L246 699L234 727L199 741L158 717Z',[155,668,250,745],{...top,color:'#796f52',scale:24});
 for(let i=0;i<6;i++){const x=169+i*11,y=692+i*4;p.line(`M${x},${y}l-7,28`,'#253d37',1.5,.8);p.line(`M${x},${y}v-15`,'#778975',2,.8);}
 p.line('M169 676Q199 696 235 699','#97a286',1.3,.8);
 p.surface('M180 751Q220 731 258 752Q225 778 180 751Z',[177,730,261,781],{mat:'plain',color:'#6d7155',normal:[0,-.65,.7]});
 p.fill('M188 751Q220 741 249 753Q221 768 188 751Z','#0b2228');p.line('M218 747L220 766','#7f9577',3,.8);p.line('M229 750L245 713','#64856d',.9,.8);
 // Inhabited store alcove in the side terrace, with baskets and rolled ropes.
 opening(201,491,26,45,false,-3);
 for(let i=0;i<5;i++){const x=216+i*12,y=477+i%2*8;surface(`M${x-4},${y}L${x-5},${y+11}Q${x},${y+15} ${x+5},${y+10}L${x+4},${y}Z`,[x-7,y-2,x+8,y+17],{mat:'plain',color:'#a39168',normal:[-.3,-.2,1]});p.fill(ellipse(x,y,4,2),'#18312d');}
 p.line('M153 524L187 535L184 572L150 560Z','#67846d',.9,.7);
 for(let i=0;i<5;i++){p.line(`M${156+i*6},${526+i*2}l-1,33`,'#536b58',.7,.65);p.line(`M152,${532+i*6}l32,10`,'#536b58',.7,.65);}
 // Local marine bioluminescence in cracks, never outlining the whole island.
 for(const d of['M236 711L229 732L235 745','M563 709L570 723L568 736','M341 675L349 686L347 699']){p.stroke(d,'#458e79',2,.55);p.stroke(d,'#86c89d',.65,.6);}
 for(let i=0;i<28;i++){const x=144+r()*675,y=767+r()*42;p.stroke(`M${x},${y}q${8+r()*16},${3+r()*2} ${19+r()*22},-2`,'#427c72',.7+r()*.8,.26);}
 p.reframe(1.04,-13,-9);
 p.fade(852);
 return{p:p.output(),features:{worldSeed,construction:'潮蚀断崖上的残顶礼拜堂、上行祭径、跨隙桥、下沉环井与潮汐登陆点',method:'2D oblique footprints + correlated dry/wet stone fields + recessed water flow + local ritual lighting → original NPR',materials:['干盐石灰岩','湿岩','铜钟','织物','流动潮水','旧木'],activity:'持灯入会、围井祈求、潮水量测、供物存放与码头作业',lighting:{revision:'cliff-fill-plane-separation-local-sources',backPlaneAmbient:dark.ambient,topNormal:top.normal,wallNormal:wall.normal,lights:Object.values(lights).map(({visibility,...source})=>source),occlusion:'二维表面与光源遮罩；非三维阴影模拟'}}};
}
