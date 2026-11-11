/** Programmatic 2D place, based on tide-watching and communal record keeping.
 * No pre-rendered image, mesh, generated image or 3D modelling. */
export function drawCult(p,config){
 let seed=(Number(config.seed)^0x5ca1ab1e)>>>0;const rand=()=>{seed+=0x6D2B79F5;let t=Math.imul(seed^seed>>>15,seed|1);t^=t+Math.imul(t^t>>>7,t|61);return((t^t>>>14)>>>0)/4294967296;};
 const tide=config.template==='tide', towerHeight=168+Math.round(rand()*55),towerPosition=215+Math.round(rand()*40),sideHallWidth=120+Math.round(rand()*50),archCount=2+Math.floor(rand()*3),stairCount=5+Math.floor(rand()*4),basinRadius=60+Math.floor(rand()*21),roofType=rand()<.5?'layered':'leaning',bannerShape=rand()<.5?'short':'long',r=config.palette;
 const fill=(d,mat,opt={})=>p.path(d,mat,{light:.45,relief:.65,grain:.1,shadow:false,...opt});
 const line=(pts,c=r.mid,w=2)=>p.stroke(pts,c,w);
 // One uneven headland: dark sea below, rock undercut, top surface and coast.
 if(tide){
  fill('M 67 575 Q 109 551 146 558 Q 206 541 269 559 Q 347 579 404 565 Q 482 538 541 549 Q 624 537 699 580 Q 661 632 579 647 Q 470 676 392 670 Q 243 694 144 650 Q 94 633 67 605 Z','water',{light:.23,shade:.48,relief:.2,flow:.08});
  for(let i=0;i<6;i++){const y=597+i*12,shift=(i%2)*32;line([[104+shift,y],[174+shift,y-5],[213+shift,y-3]],r.light,i===1?2:1);line([[500-shift,y+4],[551-shift,y+2],[607-shift,y+4]],r.mid,1);}
 }
 fill('M 104 493 Q 132 452 191 439 Q 208 411 260 406 Q 289 373 349 383 Q 388 367 446 390 Q 488 390 514 415 Q 560 408 599 439 Q 650 455 666 491 L 650 558 Q 628 581 592 591 Q 565 626 526 633 Q 499 659 452 657 Q 421 679 375 662 Q 336 670 301 652 Q 257 656 224 632 Q 179 629 154 603 Q 116 596 104 569 Z','rock',{light:.28,shade:.25,relief:.8,grain:.13});
 fill('M 104 493 Q 132 452 191 439 Q 208 411 260 406 Q 289 373 349 383 Q 388 367 446 390 Q 488 390 514 415 Q 560 408 599 439 Q 650 455 666 491 Q 634 501 599 495 Q 558 511 521 503 Q 491 523 455 518 Q 420 542 385 532 Q 347 544 302 527 Q 261 530 230 508 Q 196 509 170 493 Q 134 506 104 493 Z','rock',{light:.72,relief:.8,grain:.13,rim:.58});
 // The lower strata turn, overlap and leave a dark, eroded recess.
 fill('M 126 516 Q 158 519 184 509 Q 209 539 247 536 L 262 595 Q 238 614 212 606 Q 184 605 171 582 Q 139 575 126 548 Z','rock',{light:.34,shade:.15,relief:.8});
 fill('M 260 531 Q 290 546 319 543 L 341 628 Q 323 645 300 637 Q 287 609 275 593 Z','rock',{light:.45,shade:.15,relief:.8});
 fill('M 391 541 Q 429 550 466 527 L 479 591 Q 466 622 437 639 Q 413 629 406 611 Z','rock',{light:.25,shade:.36,relief:.7});
 fill('M 487 528 Q 527 522 557 509 L 578 566 Q 564 594 530 605 Q 504 596 494 572 Z','rock',{light:.22,shade:.38,relief:.7});
 fill('M 329 614 Q 343 580 369 572 Q 392 574 406 606 L 406 633 Q 376 646 337 637 Z','void',{shade:.98,relief:0});
 // Irregular path carved through the stone links the shelter and the pool.
 fill('M 249 469 Q 290 450 329 449 Q 379 440 425 454 Q 459 467 497 480 L 481 505 Q 434 484 396 484 Q 339 483 287 502 Z','stone',{light:.38,shade:.12,relief:.4});
 // The tide marker is a working communal landmark: two weathered poles,
 // a suspended scale, and a slack awning, connected to both house and basin.
 if(tide){
 fill('M 470 242 Q 474 229 479 242 L 485 435 L 477 439 Z','roof',{light:.46,relief:.65});
 fill('M 535 265 Q 539 254 544 267 L 547 444 L 540 441 Z','roof',{light:.27,shade:.2,relief:.6});
 fill('M 475 270 Q 505 261 542 274 L 542 281 Q 505 273 477 280 Z','roof',{light:.5,relief:.45});
 line([[489,274],[490,316]],r.shadow,2);line([[527,277],[527,320]],r.shadow,2);
 fill('M 489 315 Q 507 310 527 319 L 528 326 Q 509 319 490 324 Z','metal',{light:.39,relief:.5});
 fill('M 481 296 Q 507 317 539 300 L 541 339 Q 511 347 481 320 Z','cloth',{light:.38,shade:.12,relief:.55,folds:.22,flow:.2,opacity:.8});
 }else{
 fill('M 475 230 Q 479 221 483 230 L 489 438 L 481 440 Z','roof',{light:.4,relief:.55});
 fill('M 535 247 Q 539 239 543 248 L 546 445 L 539 441 Z','roof',{light:.25,relief:.5});
 fill('M 478 259 Q 507 251 542 265 L 542 273 Q 509 266 479 269 Z','roof',{light:.5,relief:.4});
 for(let i=0;i<4;i++){const x=486+i*12;fill(`M ${x} 270 l 9 2 l 2 60 l -11 -3 Z`,'paper',{light:.3+(i%2)*.05,shade:.15,relief:.25});}
 }
 // Shelter and lean-to: a low working place, no monumental church or shrine tower.
 const x=towerPosition-31,y=270+(260-towerHeight)*.20,w=sideHallWidth;
 fill(`M ${x} ${y+58} Q ${x+42} ${y+29} ${x+97} ${y+42} L ${x+w} ${y+67} L ${x+w-2} ${y+154} Q ${x+96} ${y+142} ${x+54} ${y+155} L ${x-9} ${y+140} Z`,'stone',{light:.35,shade:.16,relief:.65});
 fill(`M ${x+w-2} ${y+70} L ${x+w+48} ${y+91} L ${x+w+47} ${y+163} L ${x+w-2} ${y+154} Z`,'stone',{light:.18,shade:.4,relief:.5});
 fill(`M ${x-22} ${y+61} Q ${x+27} ${y+17} ${x+94} ${y+23} L ${x+w+(roofType==='layered'?61:38)} ${y+80} L ${x+w+40} ${y+94} Q ${x+75} ${y+50} ${x+23} ${y+74} L ${x-17} ${y+86} Z`,'roof',{light:.4,shade:.15,relief:.6});
 fill(`M ${x-5} ${y+81} Q ${x+26} ${y+58} ${x+63} ${y+64} L ${x+63} ${y+146} L ${x-6} ${y+142} Z`,'void',{shade:.95,relief:0});
 fill(`M ${x+1} ${y+89} L ${x+10} ${y+84} L ${x+10} ${y+142} L ${x+1} ${y+140} Z`,'stone',{light:.28,shade:.25,relief:.3});
 // Posts hold drying nets and a long shared observation/recording shelf.
 line([[x+7,y+77],[x+4,y+146]],r.shadow,5);line([[x+62,y+74],[x+62,y+146]],r.shadow,5);
 fill(`M ${x+8} ${y+112} L ${x+62} ${y+104} L ${x+89} ${y+116} L ${x+34} ${y+127} Z`,'roof',{light:.53,relief:.3});
 for(let i=0;i<4;i++){const xx=x+20+i*12;fill(`M ${xx} ${y+102-i} l 8 -1 l 0 12 l -8 1 Z`,'paper',{light:.35+(i%2)*.08,relief:.2});}
 line([[x-12,y+75],[x-34,y+155]],r.mid,3);line([[x+w+28,y+85],[x+w+26,y+159]],r.shadow,3);
 fill(`M ${x-18} ${y+82} Q ${x+4} ${y+93} ${x+19} ${y+90} Q ${x+2} ${y+125} ${x-31} ${y+(bannerShape==='long'?148:123)} Z`,'cloth',{light:.4,shade:.1,folds:.3,flow:.4,relief:.6});
 // Small working lights nested under eaves, restrained, not a field of icons.
 fill(`M ${x+76} ${y+92} q 6 -8 12 0 l 0 12 l -12 0 Z`,'glow',{relief:0});
 // Tide society watches a recessed pool linked to the shore. The record
 // society uses the same sheltered terrace for a shared archive table.
 if(tide){
 // Basin is recessed into the stone and joined to the sea by a carved tidal channel.
 const cx=432,cy=474,rx=basinRadius,ry=basinRadius*.35;
 p.ellipse(cx,cy+7,rx+14,ry+10,'stone',{light:.35,shade:.25,relief:.55,shadow:false});
 p.ellipse(cx,cy,rx+10,ry+5,'stone',{light:.58,relief:.4,shadow:false});
 p.ellipse(cx,cy+1,rx,ry,'void',{shade:.96,relief:0,shadow:false});
 p.ellipse(cx,cy+4,rx-5,ry-3,'water',{light:.35,shade:.25,relief:.25,flow:0,shadow:false});
 fill(`M ${cx-11} ${cy+3} Q ${cx+4} ${cy-4} ${cx+19} ${cy+1} Q ${cx+9} ${cy+4} ${cx+1} ${cy+8} Z`,'glow',{light:.5,relief:0});
 fill(`M ${cx+rx-3} ${cy+4} Q 571 513 573 546 Q 575 568 599 586 L 591 591 Q 560 574 557 550 Q 552 524 ${cx+rx-8} ${cy+16} Z`,'water',{light:.32,shade:.35,relief:.35});
 }else{
 fill('M 385 457 L 455 436 L 503 455 L 432 480 Z','roof',{light:.4,relief:.4});
 fill('M 385 457 L 432 480 L 432 493 L 385 471 Z','stone',{light:.24,shade:.15,relief:.45});
 fill('M 432 480 L 503 455 L 503 468 L 432 493 Z','stone',{light:.17,shade:.25,relief:.45});
 fill('M 399 454 Q 420 444 439 450 L 450 463 Q 428 458 410 467 Z','paper',{light:.4,relief:.2});
 fill('M 439 450 Q 456 444 476 453 L 450 463 Z','paper',{light:.35,relief:.2});
 line([[405,455],[425,451]],r.shadow,1);line([[410,460],[431,456]],r.shadow,1);
 }
 // A sheltered descending stair; riser rhythm varies with seed.
 const n=stairCount;
 for(let i=0;i<n;i++){const t=i/n,xx=255-t*94,yy=500+t*80;fill(`M ${xx} ${yy} l 43 13 l -13 8 l -45 -12 Z`,'stone',{light:.38-t*.13,shade:.14,relief:.35});}
 // A few human-scale traces convey use; seed varies number and placement.
 for(let i=0;i<archCount;i++){const xx=331+i*31,yy=432+i*2;p.ellipse(xx,yy-11,4.6,5.5,'void',{relief:0,shadow:false});fill(`M ${xx-4} ${yy-6} Q ${xx} ${yy-11} ${xx+4} ${yy-6} L ${xx+6} ${yy+8} L ${xx-5} ${yy+8} Z`,'void',{relief:0});line([[xx-3,yy+8],[xx-4,yy+14]],r.shadow,2);line([[xx+3,yy+8],[xx+4,yy+14]],r.shadow,2);line([[xx-2,yy-3],[xx+2,yy+5]],r.mid,1);}
 // Soft, sparse material seams follow load-bearing contours.
 line([[150,497],[184,491],[216,506]],r.shadow,2);line([[303,533],[311,574],[322,610]],r.shadow,2);line([[521,510],[534,546],[535,577]],r.shadow,1.5);
 return {features:{template:config.template,purpose:tide?'tidal-observation':'testimony-records',shelterElevation:towerHeight,shelterPosition:towerPosition,roofSpan:sideHallWidth,roofType,gatherers:archCount,stairCount,basinRadius,bannerShape}};
}
