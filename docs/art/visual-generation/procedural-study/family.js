// Candidate subject translations for the original archetypes. Direct 2D paths;
// seeded construction, not canonical lore or original planet meshes.
import {random} from './paint.js';
export function familyCult(p,c){
 const id=c.archetype,r=random((c.seed^0xa63ce7)>>>0),s=0.85+r()*.3,n=4+Math.floor(r()*4),o=Math.round((r()-.5)*35),F=(d,m='stone',v=.5)=>p.path(d,m,{light:v,relief:.7,shadow:false}),E=(x,y,rx,ry,m='stone',v=.5)=>p.ellipse(x,y,rx,ry,m,{light:v,relief:.7,shadow:false}),L=(a,b,w=3,col=c.palette.light)=>p.stroke([a,b],col,w);
 p.ctx.save();p.ctx.translate(384+o*.35,460);p.ctx.scale(s,1+(s-1)*.65);p.ctx.translate(-384,-460);
 // Low uneven plinth supports every society; its silhouette is not a sphere.
 F(`M 112 552 Q 165 520 248 526 Q 337 506 415 520 Q 525 503 653 548 L 630 583 Q 554 607 473 604 Q 385 621 302 605 Q 206 609 137 584 Z`,'rock',.38);
 F('M 112 552 Q 217 516 311 529 Q 448 503 653 548 Q 561 568 467 560 Q 290 577 112 552 Z','stone',.64);
 if(id===1){ // Watcher: concentric observatory and veiled aperture.
  F('M 228 526 L 239 330 Q 250 223 384 198 Q 510 224 529 330 L 540 526 Z','stone',.34);
  E(384,337,144,121,'metal',.52);E(384,337,112,93,'void');E(384,337,85,61,'stone',.48);E(384,337,60,38,'void');E(384,337,12,13,'glow');
  F('M 221 360 Q 292 302 384 310 Q 477 304 547 360 Q 462 330 384 331 Q 298 332 221 360 Z','cloth',.55);
  for(let i=0;i<4;i++){let x=254+i*86; F(`M ${x} 508 l 9 -84 l 8 0 l 8 84 Z`,'stone',.42);}
 }else if(id===2){ // Tissue and sutured chambers.
  F('M 206 534 Q 184 455 224 405 Q 193 337 248 299 Q 264 221 346 227 Q 390 186 442 233 Q 529 226 537 305 Q 581 354 550 411 Q 576 479 535 534 Z','skin',.43);
  for(let i=0;i<n;i++){let x=242+i*47,y=325+Math.sin(i*1.3)*35;E(x,y,20+r()*10,36+r()*18,'skin',.34+r()*.22);}
  F('M 323 528 Q 315 437 346 414 Q 384 386 422 414 Q 454 445 446 528 Z','void');
  for(let i=0;i<6;i++){let x=275+i*42;L([x,462],[x+17,453],2,c.palette.dark);L([x+4,453],[x+12,463],2,c.palette.light);}
 }else if(id===3){ // Spore canopies on clustered stalks.
  for(let i=0;i<n;i++){let x=220+i*45+o,y=330+Math.sin(i*2)*42,rr=42+r()*25;F(`M ${x-11} 536 Q ${x+6} 443 ${x} ${y+20} L ${x+13} ${y+14} Q ${x+17} 453 ${x+14} 536 Z`,'cloth',.47);F(`M ${x-rr} ${y+12} Q ${x-rr*.8} ${y-rr*.55} ${x} ${y-rr*.6} Q ${x+rr*.9} ${y-rr*.48} ${x+rr} ${y+12} Q ${x} ${y-3} ${x-rr} ${y+12} Z`,'rock',.52);E(x+rr*.28,y-10,3,3,'glow');}
  F('M 317 535 Q 322 463 385 454 Q 449 462 451 535 Z','void');
 }else if(id===4){ // A volcanic furnace split by a luminous shaft.
  F('M 185 540 L 244 340 L 292 362 L 326 221 L 378 200 L 427 218 L 463 355 L 512 338 L 581 540 Z','rock',.38);
  F('M 335 512 L 355 433 L 345 382 L 370 324 L 362 254 L 381 224 L 393 308 L 380 371 L 400 420 L 390 510 Z','glow');
  F('M 273 523 L 293 427 L 333 410 L 337 524 Z','stone',.52);F('M 438 524 L 434 409 L 476 428 L 495 524 Z','stone',.4);
  for(let i=0;i<5;i++)L([240+i*55,522],[250+i*55,492],3,c.palette.glow);
 }else if(id===5){ // Stepped plateau and wind fences.
  F('M 176 535 L 176 478 L 219 478 L 219 422 L 263 422 L 263 366 L 304 366 L 304 298 L 466 298 L 466 366 L 510 366 L 510 422 L 548 422 L 548 479 L 590 479 L 590 535 Z','stone',.46);
  for(let i=0;i<4;i++)F(`M ${214+i*30} ${469-i*45} L ${553-i*30} ${469-i*45} L ${543-i*30} ${480-i*45} L ${224+i*30} ${480-i*45} Z`,'paper',.57);
  F('M 336 326 L 337 258 L 429 258 L 431 326 L 410 326 L 410 278 L 355 278 L 355 326 Z','stone',.3);
  L([383,259],[383,197],5); F('M 387 203 Q 429 216 459 200 L 443 222 Q 416 230 387 218 Z','cloth',.56);
 }else if(id===6){ // Fractured prism and suspended shards.
  for(let i=0;i<5;i++){let x=229+i*77,h=110+r()*110;F(`M ${x-31} 520 L ${x-23} ${520-h*.66} L ${x} ${520-h} L ${x+33} ${520-h*.38} L ${x+23} 520 Z`,'metal',.42+r()*.25);L([x,520-h],[x+2,513],2,c.palette.glow);}
  E(385,451,58,21,'void');E(385,445,32,11,'glow');
  for(let i=0;i<3;i++){let x=287+i*96,y=225+(i%2)*42;F(`M ${x} ${y-30} l 22 30 l -22 37 l -22 -37 Z`,'metal',.58);}
 }else if(id===8){ // Open spiral of fragmented tracks, no cathedral.
  for(let i=0;i<5;i++){const y=477-i*51,x=260+i*25;F(`M ${x-83} ${y} Q ${x+15} ${y-49} ${x+131} ${y-5} L ${x+113} ${y+9} Q ${x+12} ${y-21} ${x-66} ${y+18} Z`,i%2?'stone':'metal',.42+i*.04);}
  E(405+o,317,34,34,'glow');
  for(let i=0;i<4;i++){let x=222+i*103;F(`M ${x} ${510-i%2*35} l 20 -56 l 17 60 Z`,'rock',.4);}
 }else if(id===9){ // Concentric cocoon envelopes and taut fibres.
  F('M 239 526 Q 205 420 245 310 Q 277 216 384 187 Q 493 216 523 310 Q 563 419 529 526 Z','cloth',.43);
  F('M 273 526 Q 244 417 275 320 Q 302 248 384 222 Q 466 250 493 320 Q 524 416 495 526 Z','stone',.5);
  F('M 315 526 Q 286 424 312 338 Q 330 285 384 270 Q 438 287 456 338 Q 482 420 454 526 Z','void');
  for(let i=0;i<7;i++){let y=292+i*34;L([257+(i%2)*10,y],[509-(i%2)*10,y+20],2,c.palette.light);}
  F('M 378 282 L 388 282 L 392 467 L 380 491 L 375 423 Z','glow');
 }else{ // Ossuary: nested crater terraces and carved memorials.
  E(384,496,194,53,'stone',.42);E(384,485,151,39,'void');E(384,480,120,27,'rock',.55);
  for(let i=0;i<n;i++){let x=235+i*50,y=447-Math.sin(i/(n-1)*Math.PI)*30;F(`M ${x-9} ${y} Q ${x-16} ${y-78} ${x} ${y-100} Q ${x+16} ${y-78} ${x+9} ${y} Z`,'paper',.48);L([x-4,y-53],[x+4,y-53],2,c.palette.dark);}
  E(385,471,43,12,'void');
 }
 p.ctx.restore();
 return {features:{template:c.template,archetype:id,construction:['sea','watching aperture','sutured chambers','fungal canopies','furnace fissure','stepped plateau','refractive shards','archive','drifting arcs','cocoon layers','crater terraces'][id],parts:n,offset:o,scale:s}};
}
export function familyPersonAdornment(p,c){
 const id=c.archetype,r=random((c.seed^0x97b3)>>>0),f=(d,m='metal',v=.48)=>p.path(d,m,{light:v,relief:.7,shadow:false}),l=(pts,w=3,col=c.palette.light)=>p.stroke(pts,col,w),E=(x,y,rx,ry,m='metal')=>p.ellipse(x,y,rx,ry,m,{light:.55,relief:.5,shadow:false});
 // These marks are deliberately placed on top of the shared portrait scaffold.
 // They are cultural proposals, not claims about established in-game factions.
 if(id===1){f('M 282 210 Q 285 143 363 113 Q 448 115 477 212 Q 449 162 384 157 Q 320 159 282 210 Z');l([[302,213],[456,198]],8,c.palette.dark);E(385,203,27,10,'void');}
 if(id===2){for(let i=0;i<7;i++){let y=299+i*19;l([[275,y],[300,y+10]],4,c.palette.light);l([[282,y-3],[292,y+12]],2,c.palette.dark);}}
 if(id===3){for(let i=0;i<5;i++){let x=265+i*52,y=309+(i%2)*13;f(`M ${x-21} ${y} Q ${x} ${y-25} ${x+21} ${y} Q ${x} ${y-5} ${x-21} ${y} Z`,'rock');l([[x,y],[x,y+21]],3);}}
 if(id===4){f('M 303 306 L 337 325 L 351 390 L 306 368 Z','rock');for(let i=0;i<3;i++)l([[315+i*9,320],[325+i*9,362]],2,c.palette.glow);}
 if(id===5){f('M 270 291 Q 378 329 478 291 L 490 330 Q 386 366 258 330 Z','paper');l([[281,315],[462,317]],3,c.palette.shadow);}
 if(id===6){for(let i=0;i<5;i++){let x=282+i*46;f(`M ${x} 320 l 15 25 l -13 32 l -13 -27 Z`,'metal',.6);l([[x,322],[x+2,368]],2,c.palette.glow);}}
 if(id===7){f('M 265 327 L 294 340 L 294 383 L 266 373 Z','paper');l([[270,341],[290,348]],2,c.palette.shadow);}
 if(id===8){for(let i=0;i<4;i++)l([[270+i*15,322+i*10],[330+i*25,359+i*12],[390+i*24,337+i*15]],3,c.palette.light);}
 if(id===9){for(let i=0;i<7;i++)l([[299,296+i*12],[454,315+i*11]],2,c.palette.light);}
 if(id===10){for(let i=0;i<5;i++){let x=278+i*44;f(`M ${x} 326 q 9 -15 18 0 l -2 28 l -14 0 Z`,'paper');E(x+9,338,3,4,'void');}}
 return {motif:['潮历','遮目','缝线','孢伞','余烬','风雪围领','折光片','记录页','航迹','茧丝','骨牌'][id],variation:Math.floor(r()*1000)};
}

export function familyPerson(p,c){
 const id=c.archetype,rand=random((c.seed^0x831a77)>>>0),dx=Math.round((rand()-.5)*24),scale=.92+rand()*.16;
 const F=(d,m='cloth',v=.45)=>p.path(d,m,{light:v,relief:.8,folds:.22,shadow:false}),E=(x,y,rx,ry,m='cloth',v=.45)=>p.ellipse(x,y,rx,ry,m,{light:v,relief:.65,shadow:false}),L=(pts,w=3,col=c.palette.light)=>p.stroke(pts,col,w);
 // Three distinct figure silhouettes; the hands remain concealed in sleeves.
 const body=id===3||id===5||id===9?'wrapped':id===6||id===8?'angular':'mantle';
 if(body==='wrapped'){
  F('M 282 258 Q 236 270 205 315 Q 169 371 168 468 L 178 699 Q 282 737 381 720 Q 477 741 590 695 L 594 468 Q 584 364 542 316 Q 511 277 466 259 Z','cloth',.36);
  F('M 217 342 Q 299 319 371 353 Q 463 320 547 346 L 556 405 Q 464 376 376 410 Q 285 380 202 405 Z','cloth',.57);
  F('M 203 421 Q 295 386 378 420 Q 471 393 562 420 L 564 475 Q 468 450 378 479 Q 288 449 200 479 Z','cloth',.46);
  F('M 202 495 Q 298 460 380 492 Q 472 466 567 492 L 574 548 Q 469 524 378 552 Q 293 525 204 552 Z','cloth',.39);
 } else if(body==='angular'){
  F('M 328 251 L 265 285 L 160 390 L 208 418 L 164 666 L 319 728 L 382 695 L 479 726 L 615 641 L 558 415 L 600 374 L 473 285 L 429 251 Z','cloth',.34);
  F('M 267 294 L 380 358 L 248 461 L 176 398 Z','cloth',.53);F('M 474 295 L 381 358 L 500 456 L 584 377 Z','cloth',.43);
  F('M 247 461 L 380 358 L 384 697 L 312 719 L 204 670 Z','cloth',.4);
 }else{
  F('M 305 255 Q 234 270 188 330 Q 151 389 166 494 L 192 695 Q 279 727 382 714 Q 483 731 579 691 L 602 496 Q 614 386 568 330 Q 518 276 455 255 Z','cloth',.36);
  F('M 235 306 Q 304 290 377 331 Q 450 290 528 309 Q 503 363 457 397 Q 380 414 302 393 Q 253 363 235 306 Z','cloth',.53);
  F('M 194 378 Q 217 353 239 353 Q 268 383 290 428 L 337 466 L 314 501 L 251 469 Q 206 450 194 420 Z','cloth',.45);
  F('M 564 378 Q 540 351 520 353 Q 487 383 468 428 L 419 466 L 443 501 L 503 470 Q 549 451 564 420 Z','cloth',.36);
 }
 // Seed shifts hood, while prototype controls the actual silhouette.
 p.ctx.save();p.ctx.translate(dx,0);p.ctx.translate(384,246);p.ctx.scale(scale,scale);p.ctx.translate(-384,-246);
 if(id===3){
  F('M 283 233 Q 279 170 309 141 Q 343 111 384 110 Q 436 112 463 148 Q 486 181 477 235 L 448 301 Q 385 324 319 300 Z','cloth',.42);
  F('M 230 169 Q 261 104 383 91 Q 502 103 536 169 Q 472 158 383 161 Q 293 158 230 169 Z','rock',.58);
 }else if(id===9){
  F('M 283 248 Q 282 151 342 111 Q 384 86 428 111 Q 489 153 485 248 L 455 304 Q 380 322 313 303 Z','cloth',.46);
 }else if(id===6){
  F('M 281 246 L 302 143 L 383 97 L 464 143 L 487 246 L 451 310 L 313 310 Z','metal',.45);
 }else{
  F('M 285 250 Q 274 173 315 133 Q 344 103 383 105 Q 433 106 461 139 Q 493 177 476 250 L 451 304 Q 381 324 316 304 Z','cloth',.45);
 }
 F('M 326 233 Q 326 174 382 164 Q 440 167 447 229 Q 446 273 413 289 Q 377 305 344 283 Q 322 266 326 233 Z','void');
 F('M 301 220 Q 305 151 375 137 Q 443 132 468 205 Q 436 174 383 174 Q 333 174 301 220 Z','cloth',.56);
 p.ctx.restore();
 // An implied held relic replaces exposed hands; each pose has a distinct mass.
 if(body==='wrapped'){
  F('M 228 504 Q 283 470 326 467 L 365 488 L 344 516 Q 294 505 247 538 Z','cloth',.51);F('M 536 504 Q 480 470 437 467 L 398 488 L 419 516 Q 469 505 516 538 Z','cloth',.37);
  E(382,497,34,33,'metal',.5);E(382,497,20,20,'void');
 }else if(body==='angular'){
  F('M 210 494 L 290 428 L 357 457 L 342 485 L 290 468 L 238 531 Z','cloth',.48);
  F('M 547 500 L 482 448 L 420 463 L 430 490 L 481 484 L 527 535 Z','cloth',.35);
  F('M 357 452 L 384 418 L 411 452 L 411 495 L 384 513 L 357 495 Z','metal',.58);
 }else{
  F('M 314 462 Q 345 445 379 466 Q 412 445 445 462 L 443 502 Q 410 488 379 511 Q 346 488 314 502 Z','cloth',.43);
  E(380,480,24,24,'metal',.53);E(380,480,12,12,'void');
 }
 // Each archetype has a silhouette or clothing construction, not just recolouring.
 familyPersonAdornment(p,c);
 return {features:{template:c.template,seed:c.seed,pose:body==='wrapped'?'veiled-relic':body==='angular'?'angled-relic':'sleeves-folded',costume:body,hoodPeak:Math.round(105*scale),shoulderWidth:body,faceLean:dx,motif:{motif:['潮历','遮目','缝线','孢伞','余烬','风雪围领','折光片','记录页','航迹','茧丝','骨牌'][id]}}};
}
