import {foldField,mix,rgb,fbm,smooth} from './engine.js';
import {vectorEllipse} from './design-space.js';

// Environmental construction is composed with the profession, never a complete
// costume selected by a world. All coordinates precede the illustration map.
export function configureWorldPerson(config,recipe,C,world){
 const d=recipe.dimensions,k=recipe.construction,cold=world.archetype===5;
 const under=config.layers.underSleeves,collar=config.collar,head=config.headwork;
 const fabric={mat:'cloth',color:C.outer,shadow:C.clothShadow,accent:C.salt,bump:.55};
 const lining=mix(C.linen,cold?'#aab4bb':'#8b7667',cold?.3:.4);
 const front=cold?mix(C.outer,'#59697a',.38):mix(C.outer,'#976541',.25);
 config.framing=[1.48,-210,-130];
 config.sleeveMaterial=cold?'cloth':'canvas';
 config.rolledSleeves=!cold&&['apron','workshirt','jerkin'].includes(k.garment);
 const Parent=config.Painter;
 config.Painter=class extends Parent{
  constructor(seed,options){super(seed,{...options,light:cold?[-.52,-.53,.67]:[-.63,-.45,.64]});}
  surface(path,box,o={}){
   const opt={...o};
   if(o.mat==='skin')opt.exposure=(o.exposure??1)*.82;
   if(['cloth','canvas','leather'].includes(o.mat)){
    // Frost or ash and abrasion share a broad field and follow garment coords.
    const old=o.field;
    opt.field=old||(({u,v,broad,mid,seed,base,shade,accent})=>{
     const deposit=smooth(cold?.56:.52,.82,fbm(u*.025,v*.011,seed+83+world.worldSeed*13));
     const worn=smooth(.49,.78,mid),grain=fbm(u*.21,v*.08,seed+8);
     let color=mix(shade,base,.55+broad*.45);
     color=mix(color,accent,worn*.13);
     color=mix(color,cold?'#b6c2cd':'#39302e',deposit*(cold?.25:.34));
     return {color,height:(grain-.5)*.8+(mid-.5)*1.5,spec:o.mat==='leather'?.13:.035};
    });
    opt.ambient=cold?[.10,.13,.19]:[.16,.085,.065];
   }
   super.surface(path,box,opt);
  }
 };
 config.emitters=cold?[{x:235,y:245,z:190,r:750,power:.10,color:rgb(world.c4)}]:[{x:730,y:680,z:170,r:710,power:.27,color:rgb(world.c4),falloff:1.6}];
 config.layers.underSleeves=(p,materials)=>{
  under(p,materials);
  if(cold){
   // A quilted waist layer, a lined open coat, or work apron over a wool shirt.
   if(['workshirt','jerkin','waistcoat'].includes(k.garment)){
    const vest='M372 361 Q348 406 351 467 L341 728 Q396 755 453 737 L464 428 L484 735 Q548 755 593 724 L579 452 Q556 387 489 352 L461 401 L424 391Z';
    p.surface(vest,[334,346,601,765],{...fabric,color:front,height:foldField([[[376,400],[389,515],[366,633],[370,730],20,10],[[531,391],[551,505],[532,620],[551,732],24,12]])});
    // Curving stitched channels respect the torso; no tiled stone on clothing.
    for(let j=0;j<8;j++){
     const y=438+j*37;
     p.line(`M356 ${y} Q400 ${y+18} 452 ${y+8}`,C.clothShadow,1.5,.42);
     p.line(`M481 ${y+7} Q534 ${y+18} 581 ${y-2}`,C.clothShadow,1.5,.42);
    }
    for(let j=0;j<4;j++)p.stroke(`M449 ${461+j*65}q12,5 33,-1`,C.copper,5,.65);
   }
   if(k.garment==='apron'){
    p.surface('M370 384 L390 393 L403 461 L386 465Z',[363,378,410,472],{...fabric,color:lining,height:(x,y)=>2*Math.sin(y*.13)});
    // Segmented working pocket, empty loops: the injured hand holds no tool.
    for(let j=0;j<3;j++)p.stroke(`M${407+j*29} 666l-3,43q9,7 18,0l3,-41`,C.clothShadow,2,.6);
   }
   if(['tailored','drivercoat'].includes(k.garment)){
    for(const [x,side]of[[405,-1],[514,1]])p.surface(`M${x} 397 Q${x+side*15} 528 ${x+side*8} 776 L${x+side*25} 779 Q${x+side*34} 530 ${x+side*14} 394Z`,[x-40,388,x+40,790],{...fabric,color:lining,height:foldField([[[x,400],[x+side*25,512],[x+side*8,659],[x+side*20,773],8,6]])});
   }
  }else{
   if(k.garment==='apron'){
    // Broad worn leather, inset patch and an asymmetric tied waist, not armour.
    p.surface('M401 514 Q451 528 526 517 L532 646 Q465 667 395 640Z',[389,508,540,675],{mat:'leather',color:mix(C.outer,'#4d3327',.5),shadow:C.clothShadow,accent:lining,height:foldField([[[414,528],[438,552],[418,603],[409,635],17,6]])});
    p.stroke('M402 521 Q459 536 521 524',lining,1.5,.5);
   }
   if(['drivercoat','tailored'].includes(k.garment)){
    // Dust coats have a shoulder yoke and split lapels instead of insulation.
    p.surface('M361 365 Q414 390 438 425 L416 464 L330 410Z',[324,359,444,470],{...fabric,mat:'canvas',color:front,normal:[-.2,-.3,1],height:foldField([[[366,377],[386,405],[405,438],[418,451],15,7]])});
    p.surface('M494 360 Q545 376 579 414 L513 460 L477 416Z',[471,354,585,466],{...fabric,mat:'canvas',color:front,normal:[.35,-.24,1],height:foldField([[[502,374],[523,396],[536,418],[520,445],13,6]])});
   }
   // A practical sash ties the short clothing at the waist, with visible ends.
   if(k.garment!=='tailored'){
    p.surface('M347 695 Q461 721 596 688 L593 715 Q469 747 349 722Z',[341,682,602,753],{...fabric,color:mix(C.outer,'#463f48',.5),height:(x,y)=>4*Math.sin(y*.21)});
    p.surface('M534 717 Q567 757 544 814 L526 828 Q543 767 518 719Z',[512,711,574,834],{...fabric,color:mix(C.outer,'#463f48',.5),height:foldField([[[532,724],[552,753],[536,800],[531,818],8,6]])});
   }
  }
 };
 config.collar=(p,materials)=>{
  collar(p,materials);
  if(cold){
   const fur={mat:'hair',color:lining,shadow:mix(C.clothShadow,lining,.3),accent:C.salt,bump:.35,u:(x,y)=>x*.8+y*.35,v:(x,y)=>y*3};
   // Top of a thick collar is visible from above; asymmetry follows head turn.
   p.surface('M386 337 Q391 371 442 387 L425 425 Q357 403 350 370Z',[344,331,448,432],{...fur,normal:[-.12,-.6,.7],height:foldField([[[379,348],[368,378],[403,401],[427,409],14,12]])});
   p.surface('M477 336 Q480 367 443 388 L474 420 Q526 394 519 359Z',[437,330,532,427],{...fur,color:mix(lining,C.clothShadow,.2),normal:[.26,-.45,.8],height:foldField([[[492,346],[511,369],[487,396],[474,406],14,12]])});
  }
 };
 config.headwork=(p)=>{
  head(p);
  if(cold&&k.head==='workcap'){
   for(const [x,side]of[[379,-1],[504,1]])p.surface(`M${x} 228 L${x+side*15} 246 L${x+side*8} 302 L${x-side*13} 300 L${x-side*10} 251Z`,[x-25,221,x+25,309],{...fabric,color:front,normal:[side*.3,0,1],height:(x,y)=>4*Math.exp(-(((x-(side<0?373:509))/15)**2))});
  }
  // A cloth over the lower face makes concealment intentional. Its nose ridge,
  // receding cheek and lower edge convey an upturned face; eyes stay in shadow.
  const cover=cold?mix(C.outer,'#52606c',.48):mix(C.outer,'#796656',.52);
  if(k.head==='brim'){
   // The upturned face remains concealed beneath a practical brim.
   p.stroke('M401 296 Q422 322 452 329',mix(C.salt,C.clothShadow,.76),2,.4);
   return;
  }
  if(d.cover<.3&&k.head==='tiedhair'){
   p.surface('M389 255 Q438 244 504 259 L500 321 Q471 354 446 348 L398 326Z',[383,238,511,359],{...fabric,color:mix(C.outer,C.clothShadow,.65),shadow:C.clothShadow,exposure:.62,normal:[-.1,-.3,1],height:foldField([[[400,258],[407,288],[415,325],[427,340],8,4],[[466,253],[466,285],[480,313],[476,334],9,4]])});
   p.stroke('M391 258 Q442 250 501 263',C.copper,1.5,.45);
   return;
  }
  p.surface('M393 283 Q414 271 437 265 L454 252 Q466 269 504 278 L499 311 Q475 337 454 338 Q419 331 399 311Z',[387,246,511,345],{...fabric,color:cover,shadow:mix(C.clothShadow,cover,.16),normal:[-.16,-.38,.91],exposure:.65,height:foldField([[[453,257],[449,278],[448,299],[454,327],16,7],[[403,294],[429,307],[474,313],[496,291],12,4]])});
  p.stroke('M401 306 Q446 318 495 306',mix(cover,C.clothShadow,.5),1.6,.5);
  if(!cold&&d.cover>.5){
   p.surface('M491 302 Q525 333 512 391 L494 415 Q506 352 478 331Z',[472,296,534,422],{...fabric,color:cover,height:foldField([[[493,316],[520,340],[502,378],[501,406],9,8]])});
  }
  // Small lit brow plane points toward the higher observer, no readable eyes.
  p.stroke('M416 260 Q438 249 450 252',mix(C.salt,C.clothShadow,.63),2,.38);
 };
}
