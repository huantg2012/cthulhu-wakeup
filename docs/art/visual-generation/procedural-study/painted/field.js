// Two-dimensional pigment painting. Height is a DRAWING field used for slopes,
// not geometry: no camera, mesh, triangles, extrusion or 3D subject exists here.
export const S=768, clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
export const rgb=s=>Array.isArray(s)?s:[1,3,5].map(i=>parseInt(s.slice(i,i+2),16));
export const mix=(a,b,t)=>rgb(a).map((v,i)=>v+(rgb(b)[i]-v)*t);
export const css=c=>`rgb(${rgb(c).map(v=>Math.round(clamp(v,0,255))).join(',')})`;
export function rng(seed){let a=seed>>>0;return()=>{a+=0x6D2B79F5;let t=a;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return((t^(t>>>14))>>>0)/4294967296;};}
export function hash(x,y,s){let h=Math.imul(x,374761393)^Math.imul(y,668265263)^Math.imul(s,1274126177);h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967295;}
export function noise(x,y,s){const ix=Math.floor(x),iy=Math.floor(y);let u=x-ix,v=y-iy;u=u*u*(3-2*u);v=v*v*(3-2*v);return (hash(ix,iy,s)*(1-u)+hash(ix+1,iy,s)*u)*(1-v)+(hash(ix,iy+1,s)*(1-u)+hash(ix+1,iy+1,s)*u)*v;}
export const fbm=(x,y,s)=>noise(x,y,s)*.58+noise(x*2.03+1.7,y*2.03+9.2,s)*.28+noise(x*4.13+4.1,y*4.13+7.1,s)*.14;
const canvas=()=>{const c=document.createElement('canvas');c.width=c.height=S;return c;};
export function smoothPath(pts,closed=true){let d=`M${pts[0]}`;const n=pts.length;for(let i=0;i<(closed?n:n-1);i++){const a=pts[(i-1+n)%n],b=pts[i],c=pts[(i+1)%n],e=pts[(i+2)%n];const p=i===0&&!closed?b:a,q=i===n-2&&!closed?c:e;d+=` C${b[0]+(c[0]-p[0])/6},${b[1]+(c[1]-p[1])/6} ${c[0]-(q[0]-b[0])/6},${c[1]-(q[1]-b[1])/6} ${c}`;}return d+(closed?'Z':'');}
export const bounds=(pts,pad=3)=>{const x=pts.map(p=>p[0]),y=pts.map(p=>p[1]);return [Math.min(...x)-pad,Math.min(...y)-pad,Math.max(...x)+pad,Math.max(...y)+pad];};
const ids={void:0,cloth:36,stone:92,sand:110,skin:135,paper:145,water:174,metal:216,glow:250};
export class Paint {
 constructor(config){this.config=config;this.seed=config.seed;this.p=config.palette;this.r=rng(this.seed);this.albedo=canvas();this.normals=canvas();this.a=this.albedo.getContext('2d');this.n=this.normals.getContext('2d');this.mask=canvas();this.m=this.mask.getContext('2d',{willReadFrequently:true});this.tile=canvas();this.t=this.tile.getContext('2d');this.count=0;this.mirror=1;}
 group(x,y,s,fn,flip=1){this.a.save();this.n.save();for(const c of[this.a,this.n]){c.translate(x,y);c.scale(s*flip,s);}const old=this.mirror;this.mirror*=flip;fn();this.mirror=old;this.a.restore();this.n.restore();}
 paint(d,box,o={}){
  this.count++;const path=d instanceof Path2D?d:new Path2D(d),[xa,ya,xb,yb]=box;const x0=Math.floor(xa),y0=Math.floor(ya),w=Math.ceil(xb)-x0+1,h=Math.ceil(yb)-y0+1;
  this.mask.width=w;this.mask.height=h;const mc=this.m;mc.setTransform(1,0,0,1,-x0,-y0);mc.fillStyle='#fff';mc.fill(path);const mask=mc.getImageData(0,0,w,h).data;
  const alb=mc.createImageData(w,h),nor=mc.createImageData(w,h);const col=rgb(o.color||this.p.mid),id=ids[o.mat||'stone'],height=o.height||(()=>0),amount=o.bump??1,s=this.seed;
  for(let yy=0;yy<h;yy++)for(let xx=0;xx<w;xx++){
   const i=(yy*w+xx)*4;if(!mask[i+3])continue;const x=xx+x0,y=yy+y0;
   let nx=o.normal?.[0]??-(height(x+1,y)-height(x-1,y))*.5*amount,ny=o.normal?.[1]??(height(x,y+1)-height(x,y-1))*.5*amount;
   if(o.slope){nx-= (height(x+1,y)-height(x-1,y))*.5*o.slope;ny+=(height(x,y+1)-height(x,y-1))*.5*o.slope;}
   const nz=o.normal?.[2]??1,l=Math.hypot(nx,ny,nz);nx=nx/l*this.mirror;ny/=l;
   const grain=(fbm(x*.055,y*.055,s+13)-.5)*(o.texture??.12)+(hash(x,y,s)-.5)*.022;
   const value=(o.pigment?o.pigment(x,y):1)+(o.ao?o.ao(x,y)-1:0)+grain;
   for(let k=0;k<3;k++)alb.data[i+k]=clamp(col[k]*value,0,255);
   alb.data[i+3]=mask[i+3];nor.data[i]=Math.round((nx*.5+.5)*255);nor.data[i+1]=Math.round((ny*.5+.5)*255);nor.data[i+2]=id;nor.data[i+3]=mask[i+3];
  }
  this.tile.width=w;this.tile.height=h;this.t.putImageData(alb,0,0);this.a.drawImage(this.tile,x0,y0);this.t.putImageData(nor,0,0);this.n.drawImage(this.tile,x0,y0);
 }
 ellipse(x,y,rx,ry,o={}){const p=new Path2D();p.ellipse(x,y,rx,ry,0,0,Math.PI*2);this.paint(p,[x-rx-1,y-ry-1,x+rx+1,y+ry+1],o);}
 stroke(d,color,width=1,{mat='stone',normal=[0,.55,.8],alpha=1}={}){const path=new Path2D(d),N=Math.hypot(...normal);for(const [c,isNormal]of[[this.a,false],[this.n,true]]){c.save();c.globalAlpha=alpha;c.strokeStyle=isNormal?`rgb(${(normal[0]/N*this.mirror*.5+.5)*255},${(normal[1]/N*.5+.5)*255},${ids[mat]})`:css(color);c.lineWidth=width;c.lineCap='round';c.lineJoin='round';c.stroke(path);c.restore();}}
 solid(d,color,mat='void'){for(const[c,isNormal]of[[this.a,false],[this.n,true]]){c.fillStyle=isNormal?`rgb(128,128,${ids[mat]})`:css(color);c.fill(new Path2D(d));}}
 dots(path,box,color,count,mat='stone'){this.a.save();this.n.save();const p=new Path2D(path);this.a.clip(p);this.n.clip(p);const r=rng(this.seed+this.count*113);for(let i=0;i<count;i++){const x=box[0]+r()*(box[2]-box[0]),y=box[1]+r()*(box[3]-box[1]);this.stroke(`M${x},${y}l${2+r()*5},${-1+r()*2}`,color,.5+r()*1.4,{mat,alpha:.25+r()*.3});}this.a.restore();this.n.restore();}
}
// Cloth folds run between support and hem. Their widths, lengths and spacing are
// correlated, rather than independently puffing up every closed outline.
export function drape({top=200,bottom=760,cx=380,end=cx,width=170,endWidth=width,seed=1,depth=15,folds=8,bulge=24}={}){
 const r=rng(seed),ridges=Array.from({length:folds},(_,i)=>({u:(i+.25+r()*.5)/folds*2-1,w:.12+r()*.13,a:.3+r()*.65,bend:(r()-.5)*.65,start:r()*.58}));
 return (x,y)=>{const v=clamp((y-top)/(bottom-top),-.4,1.3),c=cx+(end-cx)*v,w=width+(endWidth-width)*v,u=(x-c)/w;let h=bulge*Math.exp(-u*u*1.3);for(const f of ridges){const pos=f.u+f.bend*Math.sin(v*2.7),z=(u-pos)/f.w,hang=clamp((v-f.start)*3,0,1)*(1-.35*clamp(v));h+=depth*f.a*hang*(Math.exp(-z*z*.5)-.4*Math.exp(-Math.pow(z+1.35,2)*.8));}return h;};
}
// A curved sleeve is a continuous 2D brush envelope. The elbow changes both
// its silhouette and cloth flow; it is never assembled from hard arm segments.
export function sleeve(p,points,radii,color,seed){
 const samples=[];for(let k=0;k<points.length-1;k++){const a=points[Math.max(k-1,0)],b=points[k],c=points[k+1],d=points[Math.min(k+2,points.length-1)];for(let j=0;j<14;j++){const t=j/14,t2=t*t,t3=t2*t;const q=[0,1].map(i=>.5*((2*b[i])+(-a[i]+c[i])*t+(2*a[i]-5*b[i]+4*c[i]-d[i])*t2+(-a[i]+3*b[i]-3*c[i]+d[i])*t3));const flow=(k+t)/(points.length-1);q[1]+=Math.sin(flow*Math.PI)*14;samples.push([...q,radii[k]+(radii[k+1]-radii[k])*t]);}}samples.push([...points.at(-1),radii.at(-1)]);
 const left=[],right=[];samples.forEach((q,i)=>{const a=samples[Math.max(i-1,0)],b=samples[Math.min(i+1,samples.length-1)],len=Math.hypot(b[0]-a[0],b[1]-a[1])||1,nx=-(b[1]-a[1])/len,ny=(b[0]-a[0])/len;left.push([q[0]+nx*q[2],q[1]+ny*q[2]]);right.push([q[0]-nx*q[2],q[1]-ny*q[2]]);});
 const outline=[...left,...right.reverse()],d=smoothPath(outline),box=bounds(outline,8),coarse=samples.filter((_,i)=>i%3===0);
 const field=(x,y)=>{let best=1e9,rad=1,along=0;
  for(let i=0;i<coarse.length-1;i++){const a=coarse[i],b=coarse[i+1],dx=b[0]-a[0],dy=b[1]-a[1],t=clamp(((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy)),dd=(x-a[0]-dx*t)**2+(y-a[1]-dy*t)**2;if(dd<best){best=dd;rad=a[2]+(b[2]-a[2])*t;along=(i+t)/(coarse.length-1);}}
  const u=Math.sqrt(best)/(rad+1),bend=Math.exp(-(((along-.53)/.15)**2));
  return Math.sqrt(Math.max(.025,1-u*u))*rad*.37+Math.sin(along*25+u*4)*2.7*bend;
 };
 p.paint(d,box,{mat:'cloth',color,height:field,texture:.14,pigment:(x,y)=>.92+.12*fbm(x*.025,y*.031,seed)});
 const first=points[0],rr=radii[0];p.ellipse(first[0],first[1],rr,rr,{mat:'cloth',color,height:field,texture:.1});
 // Pinched transverse creases collect on the inside of the bent elbow.
 const e=points[1],r=rng(seed);for(let i=0;i<3;i++){const yy=e[1]-2+i*10,xx=e[0]-r()*10;p.stroke(`M${xx-17},${yy-6}Q${xx+4},${yy+5} ${xx+22},${yy+2}`,mix(color,p.p.dark,.32),1.5,{mat:'cloth',alpha:.5});}
 return {outline,points,radii};
}
