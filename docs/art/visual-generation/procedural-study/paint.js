// Deterministic 2D surface painter. Every pixel is computed; no external art or 3D geometry.
export function random(seed){let a=seed>>>0;return()=>{a+=0x6D2B79F5;let t=a;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return((t^(t>>>14))>>>0)/4294967296;};}
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
const rgb=s=>s.startsWith('#')?[1,3,5].map(i=>parseInt(s.slice(i,i+2),16)):[70,90,110];
const mix=(a,b,t)=>a.map((v,i)=>v+(b[i]-v)*t);
function hash(x,y,s){let h=Math.imul(x,374761393)^Math.imul(y,668265263)^Math.imul(s,1274126177);h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967295;}
function noise(x,y,s){let X=Math.floor(x),Y=Math.floor(y),u=x-X,v=y-Y;u=u*u*(3-2*u);v=v*v*(3-2*v);return (hash(X,Y,s)*(1-u)+hash(X+1,Y,s)*u)*(1-v)+(hash(X,Y+1,s)*(1-u)+hash(X+1,Y+1,s)*u)*v;}
const SURFACES={stone:[.07,.12],rock:[.1,.15],roof:[.035,.12],cloth:[.02,.06],metal:[.015,.7],skin:[.012,.1],paper:[.035,.05],water:[.03,.35],void:[0,0],glow:[.04,.1]};
export class Painter{
 constructor(canvas,config){this.ctx=canvas.getContext('2d',{willReadFrequently:true});this.canvas=canvas;this.config=config;this.rng=random(config.seed);this.size=768;canvas.width=canvas.height=768;this.mask=document.createElement('canvas');this.mask.width=this.mask.height=768;this.m=this.mask.getContext('2d',{willReadFrequently:true});this.layer=document.createElement('canvas');this.layer.width=this.layer.height=768;this.l=this.layer.getContext('2d');this.albedo=document.createElement('canvas');this.albedo.width=this.albedo.height=768;this.ac=this.albedo.getContext('2d');this.normals=document.createElement('canvas');this.normals.width=this.normals.height=768;this.nc=this.normals.getContext('2d');this.aux=document.createElement('canvas');this.aux.width=this.aux.height=768;this.ax=this.aux.getContext('2d');this.palette=config.palette;this.shapes=0;this.coverage=new Uint8Array(768*768);this.fields=new Float32Array(768*768*3);this.cells=new Float32Array(192*192);this.prepareFields();this.prepareCells();this.background();}
 prepareFields(){const f=this.fields,s=this.config.seed;for(let y=0;y<768;y++)for(let x=0;x<768;x++){const i=(y*768+x)*3;f[i]=noise(x*.012,y*.012,s);f[i+1]=noise(x*.047,y*.065,s+7);f[i+2]=noise(x*.31,y*.27,s+39);}}
 // The accepted planet uses Voronoi cell variation inside its surface shader.
 // This is a two-dimensional approximation for material planes, not the 3D planet shader.
 prepareCells(){const seed=this.config.seed,grid=28,step=9.5,points=[];
  for(let y=0;y<grid;y++){points[y]=[];for(let x=0;x<grid;x++)points[y][x]=[x+.2+hash(x,y,seed+71)*.6,y+.2+hash(x,y,seed+97)*.6,hash(x,y,seed+121)];}
  for(let y=0;y<192;y++)for(let x=0;x<192;x++){
   const gx=x/step+2,gy=y/step+2,ix=Math.floor(gx),iy=Math.floor(gy);let best=100,value=.5;
   for(let j=-1;j<=1;j++)for(let i=-1;i<=1;i++){const pt=points[iy+j]?.[ix+i];if(!pt)continue;const dx=pt[0]-gx,dy=pt[1]-gy,d=dx*dx+dy*dy;if(d<best){best=d;value=pt[2];}}
   this.cells[y*192+x]=value;
  }
 }
 background(){for(const c of [this.ctx]){if(this.config.style===2){c.fillStyle='#ededed';c.fillRect(0,0,768,768);continue;}c.fillStyle='#03070d';c.fillRect(0,0,768,768);const g=c.createRadialGradient(330,340,30,390,400,410);g.addColorStop(0,this.palette.shadow+'66');g.addColorStop(1,'#03070d00');c.fillStyle=g;c.fillRect(0,0,768,768);}}
 poly(points,material,opts={}){const p=new Path2D();p.moveTo(...points[0]);for(const a of points.slice(1))p.lineTo(...a);p.closePath();this.surface(p,material,opts);}
 path(d,material,opts={}){this.surface(new Path2D(d),material,opts);}
 ellipse(x,y,rx,ry,material,opts={}){const p=new Path2D();p.ellipse(x,y,rx,ry,0,0,Math.PI*2);this.surface(p,material,opts);}
 stroke(points,color,width=1){for(const c of [this.ctx,this.ac]){c.save();c.setTransform(this.ctx.getTransform());c.beginPath();c.moveTo(...points[0]);for(const a of points.slice(1))c.lineTo(...a);c.strokeStyle=color;c.lineWidth=width;c.lineJoin='round';c.lineCap='round';c.stroke();c.restore();}}
 line(x,y,x2,y2,color,width=1){this.stroke([[x,y],[x2,y2]],color,width);}
 surface(path,material='stone',opts={}){
  this.shapes++;const m=this.m;m.clearRect(0,0,768,768);m.fillStyle='#fff';m.fill(path);const mask=m.getImageData(0,0,768,768);let x0=768,y0=768,x1=0,y1=0;
  for(let y=0;y<768;y++)for(let x=0;x<768;x++)if(mask.data[(y*768+x)*4+3]){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);}
  if(x1<x0)return;const w=x1-x0+1,h=y1-y0+1,out=this.l.createImageData(w,h),d=out.data,normal=this.l.createImageData(w,h),nd=normal.data,albedo=this.l.createImageData(w,h),ad=albedo.data,pal=this.palette;
  const dark=rgb(pal.dark),mid=rgb(opts.color||pal.mid),lit=rgb(pal.light),glow=rgb(pal.glow),rough=SURFACES[material]||SURFACES.stone;
  const light=opts.light??.65,shade=opts.shade??0,grain=opts.grain??rough[0],flow=opts.flow??.35;
  const spec=rough[1],fold=opts.folds??(material==='cloth'?.55:0);const cs=Math.cos(flow),sn=Math.sin(flow);
  const relief=opts.relief??0; let distance=null;
  if(relief>0){
   // 2D signed-mask distance gives soft surface transitions at the actual contour;
   // a common light direction connects the transitions across drawn parts.
   distance=new Float32Array(w*h);
   for(let yy=0;yy<h;yy++)for(let xx=0;xx<w;xx++){
    const k=yy*w+xx, inside=mask.data[((yy+y0)*768+(xx+x0))*4+3]>8;
    distance[k]=(!inside||xx===0||yy===0||xx===w-1||yy===h-1)?0:10000;
   }
   for(let yy=1;yy<h;yy++)for(let xx=1;xx<w;xx++){const k=yy*w+xx;distance[k]=Math.min(distance[k],distance[k-1]+1,distance[k-w]+1,distance[k-w-1]+1.414);}
   for(let yy=h-2;yy>=0;yy--)for(let xx=w-2;xx>=0;xx--){const k=yy*w+xx;distance[k]=Math.min(distance[k],distance[k+1]+1,distance[k+w]+1,distance[k+w+1]+1.414);}
  }
  for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){
   const index=y*768+x,alpha=mask.data[index*4+3];if(!alpha)continue;this.coverage[index]=Math.max(this.coverage[index],alpha);const i=((y-y0)*w+x-x0)*4,u=(x-x0)/w,v=(y-y0)/h;
   const a=this.fields[index*3],b=this.fields[index*3+1],n=this.fields[index*3+2];
   let broad=.76+.29*Math.cos(u*2.7)+.10*Math.cos(v*3.2),texture=(a-.5)*.16+(b-.5)*(material==='cloth'?.025:.065)+(n-.5)*Math.min(grain,.07)*.10;
   const cell=this.cells[(y>>2)*192+(x>>2)]-.5;
   if(material==='rock'||material==='stone'||material==='roof')texture+=cell*.17;
   else if(material==='cloth')texture+=cell*.055;
   const wave=Math.sin((u*cs+v*sn)*22+3*a)*fold;
   let value=clamp((light*broad+texture+wave*.10)*(1-shade*.9)+(this.config.style===2?.12:0)),rim=0;
   if(distance){const k=(y-y0)*w+x-x0,xx=x-x0,yy=y-y0,dx=xx>0&&xx<w-1?(distance[k+1]-distance[k-1])*.5:0,dy=yy>0&&yy<h-1?(distance[k+w]-distance[k-w])*.5:0;const d=Math.hypot(dx,dy,.95),ndl=clamp((-.60*dx-.40*dy+.69*.95)/d,0,1);value=clamp(value*(1-relief*.42)+ndl*relief*.42);rim=clamp((dx*.8+dy*.55),0,1)*Math.exp(-distance[k]/8)*(opts.rim??0);}
   let col;
   if(material==='void')col=mix(dark,[1,4,9],.7);
   else if(material==='glow')col=mix(glow,[225,248,255],.35+.45*b);
   else{
    let base=mid,high=lit;if(material==='rock')base=mix(mid,[65,73,78],.23);if(material==='roof')base=mix(mid,dark,.16);if(material==='stone')base=mix(mid,lit,.08);
    if(material==='paper'){base=mix(lit,[175,151,110],.5);high=[223,211,176];}
    if(material==='skin'){base=mix(lit,[128,111,100],.62);high=mix(lit,[224,192,161],.6);}
    if(material==='metal'){base=mix(mid,[104,111,112],.3);high=mix(glow,[221,219,170],.4);}
    if(material==='water'){value+=.12*Math.sin(y*.21+a*7);base=mix(mid,glow,.18);}
    if(this.config.style===4)value=Math.round(value*6)/6;
    col=value<.42?mix(dark,base,value/.42):mix(base,high,clamp((value-.42)/.65));
    const ridge=Math.pow(clamp(1-Math.abs(u-.24)*4),12)*spec*.18;
    col=mix(col,glow,ridge);if(value>.75)col=mix(col,glow,clamp((value-.75)*.75));if(rim>0)col=mix(col,glow,clamp(rim*.8));
    // Share the source palette's secondary nebula hue as a restrained shadow bounce.
    if(pal.nebula_shadow&&['cloth','stone','rock','water'].includes(material))col=mix(col,rgb(pal.nebula_shadow),clamp((.48-value)*.22,0,.085));
   }
   d[i]=col[0];d[i+1]=col[1];d[i+2]=col[2];d[i+3]=alpha;
   // The second pair of images is the actual shader input: pigment/occlusion
   // and an independently encoded 2D relief normal + material ID.
   let pigment;
   if(material==='void')pigment=mix(dark,[1,4,9],.7);
   else if(material==='glow')pigment=mix(glow,[235,250,255],.5);
   else if(material==='skin')pigment=mix(lit,[168,137,117],.55);
   else if(material==='paper')pigment=mix(lit,[202,190,157],.68);
   else if(material==='metal')pigment=mix(mid,[140,150,145],.4);
   else if(material==='water')pigment=mix(mid,glow,.17);
   else pigment=mix(mid,lit,clamp(.22+.25*a));
   const occlusion=clamp(.62+light*.65-shade*.28,.35,1.18);
   for(let c=0;c<3;c++)ad[i+c]=clamp(pigment[c]*occlusion,0,255);
   ad[i+3]=alpha;
   const k=(y-y0)*w+x-x0,xx=x-x0,yy=y-y0;
   let dx=0,dy=0;if(distance){dx=xx>0&&xx<w-1?(distance[k+1]-distance[k-1])*.5:0;dy=yy>0&&yy<h-1?(distance[k+w]-distance[k-w])*.5:0;}
   let nx=(u-.5)*1.18-dx*.28,ny=(.5-v)*1.12+dy*.28;
   if(opts.flatNormal){nx=opts.flatNormal[0];ny=opts.flatNormal[1];}
   if(material==='water'&&!opts.flatNormal){nx*=.18;ny*=.18;}
   nd[i]=Math.round((clamp(nx,-1,1)*.5+.5)*255);nd[i+1]=Math.round((clamp(ny,-1,1)*.5+.5)*255);
   const id={cloth:32,rock:96,stone:96,roof:96,skin:145,paper:145,metal:210,water:210}[material]||0;
   nd[i+2]=id;nd[i+3]=alpha;
  }
  this.l.clearRect(0,0,768,768);this.l.putImageData(out,x0,y0);
  const ctx=this.ctx;
  this.ax.clearRect(0,0,768,768);this.ax.putImageData(albedo,x0,y0);
  this.ac.save();this.ac.setTransform(ctx.getTransform());this.ac.globalAlpha=opts.opacity??1;this.ac.drawImage(this.aux,0,0);this.ac.restore();
  this.ax.clearRect(0,0,768,768);this.ax.putImageData(normal,x0,y0);
  this.nc.save();this.nc.setTransform(ctx.getTransform());this.nc.globalAlpha=opts.opacity??1;
  if(material==='void'||material==='glow')this.nc.globalCompositeOperation='destination-out';
  this.nc.drawImage(this.aux,0,0);this.nc.restore();
  ctx.save();ctx.globalAlpha=opts.opacity??1;if(opts.shadow!==false&&material!=='void'&&material!=='glow'){ctx.shadowColor='#000a';ctx.shadowBlur=5;ctx.shadowOffsetX=2;ctx.shadowOffsetY=3;}ctx.drawImage(this.layer,0,0);ctx.restore();
  // Authored material-direction marks are clipped to a painted shape; no image lookup.
  if(w*h>500&&['stone','rock','roof','cloth','paper','water'].includes(material)){
   ctx.save();ctx.globalAlpha=opts.opacity??1;ctx.clip(path);const rand=random((this.config.seed*37+this.shapes*997)>>>0);const count=Math.min(material==='cloth'?36:120,Math.floor(w*h/(material==='cloth'?2200:1000)));
   for(let j=0;j<count;j++){
    const x=x0+rand()*w,y=y0+rand()*h,bright=rand()>.5;
    ctx.globalAlpha=(opts.opacity??1)*(material==='rock'?.10:material==='cloth'?.025:.07);ctx.fillStyle=bright?pal.light:pal.dark;
    if(material==='cloth'){ctx.save();ctx.translate(x,y);ctx.rotate(flow+.2);ctx.fillRect(-2,-8,1+rand()*3,10+rand()*18);ctx.restore();}
    else if(material==='water'){ctx.globalAlpha=.12;ctx.fillStyle=pal.glow;ctx.fillRect(x,y,12+rand()*25,1+rand()*2);}
    else{const bw=8+rand()*26,bh=3+rand()*11;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x+bw*.8,y-bh*.2);ctx.lineTo(x+bw,y+bh*.8);ctx.lineTo(x+bw*.2,y+bh);ctx.closePath();ctx.fill();}
   }
   ctx.restore();
  }
  if(opts.edge){ctx.save();ctx.strokeStyle=pal.light+'66';ctx.lineWidth=1.25;ctx.stroke(path);ctx.restore();}
 }
 finish(){return {shapes:this.shapes,renderer:'2D albedo/relief normals; original Godot noise, style_shade and post'};}
}
