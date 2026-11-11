/** 2D programmatic portrait. A deliberately small family of body gestures.
 * No bitmap, generative-AI output, mesh, projection or content handoff is used. */
export function drawPerson(p, config) {
 let state=(Number(config.seed)^0x7352a91)>>>0;
 const rand=()=>{state+=0x6D2B79F5;let t=Math.imul(state^state>>>15,state|1);t^=t+Math.imul(t^t>>>7,t|61);return((t^t>>>14)>>>0)/4294967296;};
 const tide=config.template==='tide', gesture=rand()<.5?'uncovered-hand':'closed-hands';
 const tilt=Math.round((rand()-.5)*20), shoulderWidth=202+Math.round(rand()*18), hoodPeak=332+Math.round(rand()*36),faceLean=tilt;
 const {dark,shadow,mid,light,glow}=config.palette;
 const form=(d,material='cloth',opt={})=>p.path(d,material,{light:.43,relief:.6,grain:.08,folds:.18,shadow:false,...opt});
 const mark=(pts,col=shadow,width=2)=>p.stroke(pts,col,width);
 // Back silhouette: bent neck, asymmetrical shoulders, solid chest and a hanging hem.
 form(`M 322 214 Q 340 184 391 192 Q 435 207 456 257 Q 488 280 ${shoulderWidth+306} 320 Q 571 346 583 413 Q 607 523 589 712 L 490 746 L 373 735 L 269 743 L 159 709 Q 168 605 156 528 Q 142 430 180 353 Q 210 305 272 281 Z`,'cloth',{light:.24,shade:.16,relief:.8});
 // A turned torso, broad uninterrupted light and shadow masses; no geometric collar ring.
 form('M 264 292 Q 306 311 338 337 Q 389 365 448 312 Q 503 301 531 335 Q 501 389 502 461 Q 517 565 500 682 Q 418 697 350 681 Q 288 691 214 666 Q 221 565 228 492 Q 223 392 202 350 Q 222 314 264 292 Z','cloth',{light:.36,relief:.75,folds:.26,flow:1.45});
 form('M 453 314 Q 490 300 532 336 Q 554 378 550 440 Q 525 461 493 459 Q 496 385 463 359 Z','cloth',{light:.21,shade:.35,relief:.65});
 // Wrapped chest: folds share their origin at shoulder and fall toward gravity.
 form('M 220 334 Q 252 302 291 308 Q 319 329 370 349 Q 410 366 459 322 Q 432 376 389 398 Q 315 383 244 358 Z','cloth',{light:.53,relief:.56,folds:.25,flow:.4});
 form('M 245 367 Q 306 393 379 406 Q 420 405 464 374 Q 436 418 389 426 Q 313 416 248 394 Z','cloth',{light:.25,shade:.2,relief:.5});
 form('M 245 403 Q 273 431 291 471 Q 304 535 288 669 L 259 679 Q 271 554 252 499 Q 232 454 217 428 Z','cloth',{light:.43,relief:.65,folds:.36,flow:1.4,opacity:.32});
 form('M 302 426 Q 325 459 333 512 Q 340 578 327 688 L 301 687 Q 313 590 305 533 Q 297 474 285 444 Z','cloth',{light:.24,shade:.2,relief:.65,opacity:.2});
 form('M 401 426 Q 419 487 421 530 Q 422 604 405 686 L 441 685 Q 462 599 451 530 Q 444 476 428 427 Z','cloth',{light:.24,relief:.8,folds:.28,opacity:.2});
 form('M 463 454 Q 478 500 477 558 L 469 676 L 501 681 Q 517 594 503 523 Q 499 484 486 452 Z','cloth',{light:.34,relief:.6,folds:.3,opacity:.25});
 // Bow the head as a unit; the whole hood shares the same neck/shoulder orientation.
 p.ctx.save();p.ctx.translate(363,246);p.ctx.rotate(-.17+tilt*.002);p.ctx.scale(.9,.9);p.ctx.translate(-375,-240);
 // Head is offset and bowed. An intentionally featureless hood interior is valid.
 form(`M ${hoodPeak-42} 112 Q ${hoodPeak+5} 68 404 110 Q 458 137 475 200 Q 485 245 455 290 Q 420 320 367 318 Q 319 307 298 275 Q 279 237 292 190 Q 300 143 ${hoodPeak-42} 112 Z`,'cloth',{light:.42,relief:.9,folds:.16,rim:.78});
 form(`M ${hoodPeak-47} 133 Q ${hoodPeak-19} 85 390 111 Q 350 110 326 147 Q 307 177 306 216 L 291 237 Q 283 184 304 153 Q 310 145 ${hoodPeak-47} 133 Z`,'cloth',{light:.69,relief:.8,folds:.12});
 form('M 369 157 Q 424 143 452 192 Q 471 227 456 263 Q 440 287 405 295 Q 368 296 337 279 Q 315 262 319 233 Q 327 186 369 157 Z','void',{shade:.95,relief:0});
 form('M 364 146 Q 412 127 445 163 Q 470 190 474 231 Q 465 211 452 200 Q 425 167 394 178 Q 356 181 330 216 Q 337 168 364 146 Z','cloth',{light:.32,shade:.2,relief:.65});
 p.ctx.restore();
 // The shadowed shoulder seams establish where each arm starts.
 form('M 251 314 Q 210 318 188 355 Q 174 382 177 422 Q 196 438 229 434 Q 243 394 274 368 Z','cloth',{light:.58,relief:.9,folds:.22,rim:.42});
 form('M 489 321 Q 532 313 556 351 Q 575 380 571 420 Q 551 437 522 430 Q 508 390 476 369 Z','cloth',{light:.31,shade:.14,relief:.8});
 // Left sleeve follows shoulder -> elbow -> wrist in one continuous gesture.
 form('M 184 388 Q 171 419 182 462 Q 190 490 216 503 Q 244 514 280 497 L 360 457 L 350 425 Q 312 430 276 447 Q 245 458 229 452 Q 218 445 228 414 Q 219 397 184 388 Z','cloth',{light:.39,relief:.8,folds:.2,flow:-.4});
 form('M 190 461 Q 205 488 226 489 Q 244 493 277 479 L 339 450 L 342 460 Q 291 492 262 501 Q 212 519 190 486 Z','cloth',{light:.3,shade:.12,relief:.5,opacity:.32});
 form('M 319 432 Q 339 425 355 420 L 373 451 Q 357 464 340 466 Z','cloth',{light:.52,relief:.8});
 // Far arm curves inward behind the hands; the elbow and its load folds are visible.
 form('M 526 397 Q 558 396 567 427 Q 583 468 558 493 Q 548 505 519 506 L 445 481 L 449 449 Q 492 451 514 457 Q 530 457 531 446 Q 528 431 516 416 Z','cloth',{light:.27,shade:.1,relief:.8,folds:.3,flow:.45});
 form('M 540 434 Q 551 455 544 468 Q 539 477 522 477 L 478 465 L 474 477 L 519 493 Q 552 502 558 479 Q 564 458 550 436 Z','cloth',{light:.42,relief:.6});
 form('M 440 449 Q 453 446 467 452 L 463 485 Q 448 489 435 481 Z','cloth',{light:.38,relief:.65});
 // Foreground hands touch at the center. They are small, partially shadowed,
 // and are built from palm, wrist and gently grouped fingers, not bright glyphs.
 const handLight=tide?.42:.46;
 if(gesture==='uncovered-hand'){
  form('M 348 433 Q 357 421 369 413 Q 379 406 389 407 L 416 414 Q 423 417 420 423 Q 418 427 411 425 L 397 422 L 390 424 L 418 432 Q 425 435 422 440 Q 419 443 413 440 L 388 434 L 384 437 L 409 447 Q 415 450 412 454 Q 408 457 403 454 L 381 446 L 377 448 L 395 458 Q 400 462 396 466 Q 392 468 388 465 L 373 456 Q 364 454 354 460 L 347 454 Z','skin',{light:handLight,shade:.05,relief:.8});
  // The far hand stays inside the sleeve; one clearly readable hand carries the gesture.
  form('M 441 448 Q 454 447 466 454 L 462 482 Q 450 482 439 476 Z','cloth',{light:.29,shade:.2,relief:.6});
  mark([[372,438],[382,441],[393,445]],shadow,1.2);mark([[378,447],[386,451],[396,456]],shadow,1.2);
 } else {
  form('M 344 438 Q 355 420 369 415 Q 379 411 390 418 L 409 428 L 424 447 L 409 466 L 391 459 Q 380 462 367 466 L 350 459 Z','skin',{light:handLight,relief:.8});
  form('M 451 455 Q 439 444 430 442 Q 418 440 406 445 L 382 452 Q 375 454 377 459 Q 378 463 385 462 L 405 459 Q 392 466 383 470 Q 379 475 383 478 Q 388 480 393 477 L 413 469 Q 426 467 439 483 L 453 479 Z','skin',{light:.3,shade:.12,relief:.7});
  mark([[387,453],[399,450],[411,448]],shadow,1.2);mark([[388,465],[402,460],[414,458]],shadow,1.2);
 }
 // Material identifying the world, carried at the shoulder rather than a glowing icon.
 if(tide){form('M 261 329 Q 270 323 278 329 L 281 362 Q 274 371 266 362 Z','metal',{light:.42,relief:.8});mark([[269,337],[275,344],[270,353]],mid,1.5);}
 else{form('M 251 340 L 277 347 L 278 376 L 250 369 Z','paper',{light:.29,shade:.2,relief:.35});mark([[254,348],[273,354]],shadow,1.2);mark([[254,355],[270,360]],shadow,1.2);}
 // Portrait exits into surrounding space instead of terminating in a flat hem.
 if(config.style!==2){for(const ctx of [p.ctx,p.ac]){ctx.save();if(ctx===p.ac)ctx.globalCompositeOperation='destination-out';const fade=ctx.createLinearGradient(0,570,0,746);fade.addColorStop(0,'rgba(3,7,13,0)');fade.addColorStop(1,'rgba(3,7,13,0.96)');ctx.fillStyle=fade;ctx.fillRect(0,570,768,198);ctx.restore();}}
 return {features:{template:config.template,seed:config.seed,pose:gesture==='uncovered-hand'?'open-hand':'hands-gathered',costume:tide?'tide-talisman':'record-folio',hoodPeak,shoulderWidth,faceLean}};
}
