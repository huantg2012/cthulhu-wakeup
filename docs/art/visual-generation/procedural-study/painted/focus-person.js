import {Brush,mix,rng} from './brush.js';
// One authored posture grammar: a bowed tide-keeper supports a bound tide ledger.
// The arms are read through cloth overlaps INSIDE a single garment silhouette.
export function portrait(seed=1339){
 const b=new Brush(seed),r=rng(seed),C={black:'#061016',deep:'#12242c',violet:'#27263a',dark:'#193d3c',mid:'#3f6c5a',sage:'#76947b',light:'#b0b498',ochre:'#aaa17d',salt:'#d2ccb0'};
 const robe='M327 302 C291 305 252 323 225 351 C198 385 183 419 169 466 C152 510 165 550 197 579 Q202 666 173 783 L585 786 C562 702 556 620 569 557 C587 503 563 447 542 399 Q518 345 461 324 L416 296 Z';
 // One uninterrupted silhouette and one principal light-to-shadow mass.
 b.wash(robe,[[0,C.sage],[.26,C.mid],[.54,C.dark],[.82,C.deep],[1,C.black]],[193,334,593,640]);
 b.pigment(robe,[151,301,590,788],{count:1700,scale:13,flow:(x,y)=>1.3+(x-370)*.002,colors:[C.ochre,C.sage,C.violet],alpha:.27});
 // Far arm and ribcage recede together, rather than becoming a second lit tube.
 b.wash('M444 329 Q518 340 541 402 Q576 476 554 547 Q551 578 514 581 L454 536 Q506 530 504 495 Q489 439 458 407Z',[[0,'#284e48'],[.52,'#172e35'],[1,'#0a151f']],[440,338,557,567]);
 b.wash('M445 408 Q474 497 459 581 L473 775 L571 778 Q535 661 535 590 Q503 535 511 481Z',[[0,'#12252b'],[.6,'#172b30'],[1,'#0b151d']],[438,460,557,749]);
 // Broad shawl follows neck -> sloping shoulder -> elbow, with a weighted edge.
 const shawl='M333 291 C297 306 260 322 236 349 Q201 394 180 476 C194 454 215 453 235 460 Q243 402 274 376 C308 395 346 413 386 411 Q443 408 478 351 Q433 363 401 340Z';
 b.wash(shawl,[[0,'#a1ac8a'],[.24,'#6f8e70'],[.57,'#416e5a'],[.84,'#173c39'],[1,'#111f2a']],[210,319,469,443]);
 b.pigment(shawl,[174,286,484,478],{count:850,scale:11,flow:(x,y)=>.5+(x-310)*.005,alpha:.32});
 // The lower cowl edge is an occlusion boundary, not an outlined collar ring.
 b.wash('M273 375 Q329 424 387 416 Q441 414 477 358 Q443 433 391 441 Q323 432 273 391Z',[[0,'#243c34'],[.6,'#0c222a'],[1,'#080e16']],[269,380,476,440]);
 b.stroke('M252 346 C282 343 323 391 374 397 Q412 409 452 379','#b3b694',4,.42);
 b.stroke('M248 364 Q302 401 345 411','#73947a',9,.5);
 // Drawn cloth folds converge on support points and dissolve before the hem.
 const folds=[
  ['M260 418 C278 469 270 536 248 614 Q233 682 232 771 L262 778 Q262 672 281 607 C300 530 291 470 273 426Z','#6a8c72','#193c3b'],
  ['M314 438 Q337 499 320 579 Q297 665 310 782 L339 782 Q323 680 343 594 Q365 505 329 442Z','#66866c','#203f3b'],
  ['M370 451 Q402 522 389 610 Q375 697 391 780 L426 781 Q402 683 421 597 Q434 512 395 449Z','#426754','#102e31'],
  ['M455 542 Q467 618 450 694 L457 784 L482 785 Q474 704 485 649 Q489 592 474 550Z','#385249','#121d29']
 ];
 for(const[d,a,z]of folds){b.wash(d,[[0,a],[.46,z],[1,'#0e1b26']],[215,456,510,780],.8);b.pigment(d,[210,425,493,786],{count:220,scale:10,flow:1.5,alpha:.34});}
 b.stroke('M285 421 Q307 492 289 554','#9eac87',3,.32);
 b.stroke('M337 568 Q323 659 336 716','#9aa681',2,.25);
 // Left upper arm and bent forearm are one painted sleeve with a soft shoulder.
 const sleeve='M238 367 Q217 390 199 432 C185 465 183 506 205 534 Q220 559 248 564 C288 568 336 532 378 507 L365 477 Q304 499 268 514 Q247 516 240 494 Q232 467 252 427 Q263 395 266 386Z';
 b.wash(sleeve,[[0,'#8b9f7b'],[.25,'#5a8265'],[.55,'#2a5347'],[.76,'#53735b'],[1,'#283e37']],[190,378,379,558]);
 b.pigment(sleeve,[179,361,383,574],{count:900,scale:10,flow:(x,y)=>y<480?1.6:-.43,alpha:.32});
 // Fold masses describe the bent elbow; none uses a circular cap or radial normal.
 b.wash('M212 402 Q198 465 218 512 Q232 541 261 533 Q320 513 364 485 L371 502 Q317 543 265 556 Q219 567 201 531 Q186 489 205 441Z',[[0,'#54765c'],[.44,'#95a17e'],[.65,'#436951'],[1,'#1a3432']],[196,405,341,563],.9);
 b.wash('M228 433 Q218 479 239 510 L278 512 Q251 526 233 518 Q209 494 228 433Z',[[0,'#193d36'],[1,'#0b2429']],[220,442,277,522]);
 b.stroke('M214 474 Q211 516 244 537 Q275 544 325 516','#a7ac87',3.7,.65);
 b.stroke('M216 504 Q227 523 246 526','#254436',4,.8);
 b.stroke('M230 543 Q247 552 275 540','#b6b494',1.6,.55);
 b.stroke('M251 551 Q292 544 343 513','#182e2e',2,.8);
 // Ledger is held against the torso and overlaps the far sleeve.
 const book='M374 432 Q399 426 422 430 L482 463 L458 551 Q431 539 397 541 L355 508Z';
 b.wash(book,[[0,'#8e8263'],[.3,'#494f3b'],[.69,'#182b2a'],[1,'#091a21']],[359,430,484,553]);
 b.stroke('M378 437 L416 435 L475 465 L453 541 Q424 532 399 535 L361 506','#bbb18a',2.3,.7);
 b.stroke('M415 436 L396 534','#070f17',4,.9);
 for(let i=0;i<9;i++){let x=427+i%2*3,y=460+i*7;b.line(`M${x},${y}l${21+(i%3)*4},11`,'#b4ab82',.9,.42);}
 b.pigment(book,[352,427,485,554],{count:160,scale:6,flow:.4,colors:['#bdb586','#335249','#24263e'],alpha:.4});
 // Far forearm returns beneath the ledger; its shoulder stays in the cloak's dark mass.
 b.wash('M521 438 Q553 485 541 520 Q534 550 507 555 L453 528 L460 503 Q490 515 503 507 Q516 493 501 463Z',[[0,'#233e3c'],[.42,'#31564b'],[.68,'#566d56'],[1,'#172c30']],[489,439,537,560]);
 b.stroke('M526 484 Q535 516 508 536 L480 522','#879477',3,.55);
 b.stroke('M536 517 Q526 548 506 544','#0b1922',3,.7);
 // Small hands: grouped fingers, partly submerged in cuffs and occlusion.
 b.wash('M363 483 Q374 470 388 468 Q400 468 411 478 L419 490 Q418 495 411 494 L397 485 Q388 484 385 492 L391 504 Q388 514 379 510 L365 503Z',[[0,'#b9af88'],[.44,'#928d6b'],[1,'#424b3a']],[367,470,417,514]);
 b.line('M386 478 Q399 479 409 488','#62674c',1.3,.8);
 b.line('M381 487 Q384 497 390 502','#d2c3a0',1.1,.65);
 b.wash('M463 508 Q452 503 441 505 L429 512 Q425 518 433 520 L448 517 L455 529 L467 531Z',[[0,'#8f9470'],[1,'#3a503f']],[428,503,470,535]);
 b.stroke('M361 480 L376 505','#b3b18d',3,.65);
 b.wash('M352 481 L364 477 L381 512 L365 520Z',[[0,'#5b7b60'],[1,'#203e38']],[351,481,381,520]);
 b.stroke('M224 417Q216 445 225 466','#bbc09d',1.2,.33);
 b.stroke('M240 519Q260 534 287 522','#cec5a0',1.0,.42);
 b.stroke('M484 488Q500 509 507 511','#739985',1.1,.32);
 // Neckcloth, hood and its empty interior form a bowed, asymmetrical head.
 b.wash('M330 286 Q360 305 409 291 Q433 299 459 324 Q433 363 394 362 Q354 351 321 326Z',[[0,'#81977a'],[.4,'#3f6d56'],[1,'#10282b']],[320,289,448,364]);
 const hood='M303 292 C290 256 308 200 332 164 C353 130 383 108 412 113 C454 117 481 152 490 188 Q509 230 488 272 Q467 313 428 332 Q364 346 321 315Z';
 b.wash(hood,[[0,'#a0ad87'],[.22,'#7c9b79'],[.47,'#416d53'],[.67,'#254840'],[.9,'#102c31'],[1,'#0a1520']],[300,157,493,307]);
 b.pigment(hood,[290,106,507,350],{count:700,scale:10,flow:(x,y)=>-1.4+(y-200)*.006,colors:['#a6ad82','#183844','#60516b'],alpha:.30});
 b.wash('M315 278 C304 238 332 171 366 143 Q385 126 409 124 Q371 149 353 183 Q325 224 330 264 L339 302Z',[[0,'#b3b68f'],[.5,'#789771'],[1,'#42624a']],[315,155,349,309],.8);
 b.stroke('M315 268 C307 221 349 147 385 129','#c1c5a0',2.3,.55);
 b.stroke('M328 281 Q315 227 360 170','#526e51',4,.68);
 const face='M357 206 C384 182 416 180 439 199 Q467 221 470 251 Q465 278 443 293 Q408 315 373 298 Q338 286 340 260 Q344 230 357 206Z';
 b.wash(face,[[0,'#030b11'],[.56,'#030b13'],[1,'#162631']],[356,206,461,305]);
 b.wash('M347 218 Q376 174 414 175 Q450 174 475 211 L482 244 Q465 220 445 211 Q411 186 382 205 L350 242Z',[[0,'#718a69'],[.48,'#34513f'],[1,'#15292a']],[347,183,475,242]);
 b.stroke('M352 216 Q390 174 427 190 Q450 200 469 222','#a8ae84',2,.6);
 b.wash('M338 270 Q344 309 384 318 Q440 333 476 278 Q458 322 420 337 Q365 347 335 310Z',[[0,'#5e7d62'],[.5,'#21443a'],[1,'#0c1d25']],[339,276,468,334]);
 b.stroke('M343 297 Q383 336 429 321','#7c9271',2.4,.5);
 b.clip(robe,()=>{
  b.wash('M474 355Q551 389 568 477L593 784L427 786Q436 691 445 606Q468 504 474 355Z',[[0,'#09222f00'],[.3,'#151e3438'],[.65,'#24223766'],[1,'#07131e99']],[435,383,569,779]);
 });
 // Frayed fabric and salt staining remain local to cuffs, edges and the lower robe.
 b.clip(robe,()=>{for(let i=0;i<110;i++){const x=185+r()*355,y=615+r()*140;b.stroke(`M${x},${y}l${2+r()*7},${-2-r()*8}`,i%3?'#658471':'#b1b493',1+r()*2,.12);}});
 for(let i=0;i<10;i++)b.line(`M${239+i*4},${354+i*3}l-3,${6+r()*6}`,'#aab18d',.7,.3);
 // Sea-keeper identification: dull bronze clasp, cord, a few salt-dark beads.
 b.line('M268 352 Q270 381 285 389','#152a28',3,.8);
 b.wash('M264 346 Q274 340 282 347 L283 369 Q276 381 269 371Z',[[0,'#c3b58a'],[.4,'#6f876a'],[1,'#213c39']],[263,343,283,376]);
 b.line('M271 350 L277 356 L272 365','#152f32',2,.85);
 b.glow(270,355,35,'#63bba0',.055);
 b.clip(hood,()=>{b.wash('M300 143L352 136Q341 191 318 242L328 279L302 290Z',[[0,'#d2c39a66'],[.55,'#9dac7522'],[1,'#2f5c4b00']],[302,141,342,282]);});
 b.fade();
 return {p:b.output(),features:{pose:'俯首抱持潮历',construction:'完整披衣轮廓内的明暗、遮挡与弯臂关系',seed,method:'direct-2d-pigment-composition'}};
}
