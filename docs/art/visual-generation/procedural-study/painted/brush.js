// Direct 2D pigment painter. There are no per-part normals, swept limb volumes,
// relief maps, projected models or finished bitmaps in this renderer.
import {rng,noise,fbm,mix,rgb,css,clamp} from './field.js';
export {rng,noise,fbm,mix,rgb,css,clamp};
export class Brush {
 constructor(seed){this.seed=seed;this.r=rng(seed);this.canvas=document.createElement('canvas');this.canvas.width=this.canvas.height=960;this.c=this.canvas.getContext('2d',{willReadFrequently:true});this.c.scale(1.25,1.25);this.count=0;}
 path(d,color,alpha=1){this.c.save();this.c.globalAlpha=alpha;this.c.fillStyle=typeof color==='string'?color:css(color);this.c.fill(new Path2D(d));this.c.restore();this.count++;}
 wash(d,colors,axis=[180,200,600,700],alpha=1){const g=this.c.createLinearGradient(...axis);colors.forEach(([t,col])=>g.addColorStop(t,typeof col==='string'?col:css(col)));this.c.save();this.c.globalAlpha=alpha;this.c.fillStyle=g;this.c.fill(new Path2D(d));this.c.restore();this.count++;}
 ellipse(x,y,rx,ry,color,alpha=1){const c=this.c;c.save();c.globalAlpha=alpha;c.fillStyle=typeof color==='string'?color:css(color);c.beginPath();c.ellipse(x,y,rx,ry,0,0,Math.PI*2);c.fill();c.restore();}
 line(d,color,width=1,alpha=1){const c=this.c;c.save();c.strokeStyle=typeof color==='string'?color:css(color);c.lineWidth=width;c.lineJoin='round';c.lineCap='round';c.globalAlpha=alpha;c.stroke(new Path2D(d));c.restore();}
 // Bristles follow the same drawn gesture at several pressures, preserving
 // the fold/stratum direction rather than covering the canvas with isotropic noise.
 stroke(d,color,width=5,alpha=.6){const c=this.c;c.save();for(let i=0;i<5;i++){c.save();c.translate((this.r()-.5)*width*.3,(this.r()-.5)*width*.18);this.line(d,mix(color,i%2?'#a9b39b':'#081719',i%2?.07:.1),width*(.35+this.r()*.7),alpha*.24);c.restore();}c.restore();}
 clip(d,fn){this.c.save();this.c.clip(new Path2D(d));fn();this.c.restore();}
 group(x,y,s,fn,angle=0){this.c.save();this.c.translate(x,y);this.c.rotate(angle);this.c.scale(s,s);fn();this.c.restore();}
 glow(x,y,r,color,alpha=.5){const c=this.c,g=c.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,css(color));g.addColorStop(.22,css(mix(color,'#284c49',.45)));g.addColorStop(1,'#001a2500');c.save();c.globalCompositeOperation='screen';c.globalAlpha=alpha;c.fillStyle=g;c.fillRect(x-r,y-r,r*2,r*2);c.restore();}
 // Multiscale pigment clusters are clipped to a material. Their value derives
 // from the existing painted light mass; the random seed changes broken brush edges.
 pigment(d,box,{count=500,scale=8,flow=0,colors=['#6f9581','#102e3c','#acaa7b'],alpha=.22}={}){
  const c=this.c,local=rng(this.seed+this.count*191);this.clip(d,()=>{for(let i=0;i<count;i++){
   const x=box[0]+local()*(box[2]-box[0]),y=box[1]+local()*(box[3]-box[1]),n=fbm(x*.027,y*.025,this.seed);
   // Large masses decide which marks survive, leaving quiet shadow areas.
   if(local()>n*.9+.12)continue;
   const a=typeof flow==='function'?flow(x,y):flow,w=scale*(.5+local()*1.7),h=scale*(.15+local()*.45);
   c.save();c.translate(x,y);c.rotate(a+(local()-.5)*.5);c.globalCompositeOperation='soft-light';c.globalAlpha=alpha*(.4+local()*.7);c.fillStyle=colors[Math.floor(local()*colors.length)];
   c.beginPath();c.moveTo(-w*.5,-h*.3);c.lineTo(w*.25,-h*.5);c.lineTo(w*.6,h*.15);c.lineTo(w*.35,h*.55);c.lineTo(-w*.5,h*.3);c.closePath();c.fill();c.restore();
  }});this.count++;
 }
 fade(){const c=this.c;c.save();c.globalCompositeOperation='destination-in';const g=c.createLinearGradient(0,660,0,768);g.addColorStop(0,'#fff');g.addColorStop(.6,'#ffffffdb');g.addColorStop(1,'#fff0');c.fillStyle=g;c.fillRect(0,0,768,768);c.restore();}
 output(){const n=document.createElement('canvas');n.width=n.height=960;return {albedo:this.canvas,normals:n,count:this.count};}
}
