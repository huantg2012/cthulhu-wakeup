import {SurfacePainter,clamp,smooth} from './engine.js';

// Deform vector contours and surface coordinates BEFORE synthesis. No finished
// bitmap is stretched. The same map moves folds, cuffs, hands and local light.
export function designSpace(d){
 const bell=(x,y,cx,cy,rx,ry)=>Math.exp(-(((x-cx)/rx)**2)-((y-cy)/ry)**2);
 function map(x,y){
  const head=1-smooth(326,416,y),crown=1-smooth(170,310,y);
  const a=d.headTilt*head,c=Math.cos(a),s=Math.sin(a),hx=x-440,hy=y-302;
  let xx=440+(hx*c-hy*s)*(1+head*(d.headWidth-1));
  let yy=302+hx*s+hy*c+crown*d.crown;
  xx+=head*d.headShift;
  const grip=bell(x,y,480,595,125,79),el=bell(x,y,281,641,76,97),er=bell(x,y,650,645,76,97);
  xx+=grip*d.gripX+el*d.elbowSpread-er*d.elbowSpread;
  yy+=grip*d.gripY+el*(d.gripY*.42+d.elbowDrop)+er*(d.gripY*.42-d.elbowDrop);
  const shoulder=bell(x,y,470,405,260,82);yy+=shoulder*(x-470)*d.shoulderSlope;
  const body=1-head;xx=470+(xx-470)*(1+body*(d.width-1))+d.lean*(y-470);
  yy=470+(yy-470)*d.height;
  if(d.viewPitch){
   // An illustrated elevated view: shoulder plane remains broad, the waist
   // recedes; the upturned head overlaps a shortened neck. Applied to all fields.
   const depth=smooth(390,930,y),pitch=d.viewPitch;
   xx=455+(xx-455)*(1-pitch*depth*.52);
   yy=390+(yy-390)*(1-pitch*.42)+head*(12+d.headLift*10);
   yy-=bell(x,y,370,520,125,120)*pitch*28;
   // Raised chin: the lower facial plane foreshortens, neck remains behind it.
   yy-=head*smooth(240,345,y)*(7+d.headLift*11);
  }
  return [xx,yy];
 }
 // Cache inverse samples: all channels use the same original cloth coordinates.
 const cache=new Map();
 function inverse(x,y){
  const key=y*960+x;if(Number.isInteger(x)&&Number.isInteger(y)&&cache.has(key))return cache.get(key);
  let u=x,v=y;
  for(let i=0;i<9;i++){
   const [a,b]=map(u,v),ex=x-a,ey=y-b;
   if(Math.abs(ex)+Math.abs(ey)<.02)break;
   const [ax,ay]=map(u+.3,v),[bx,by]=map(u,v+.3),j00=(ax-a)/.3,j10=(ay-b)/.3,j01=(bx-a)/.3,j11=(by-b)/.3,det=j00*j11-j01*j10;
   if(Math.abs(det)<.08)break;
   u+=clamp((ex*j11-ey*j01)/det,-60,60);v+=clamp((ey*j00-ex*j10)/det,-60,60);
  }
  const q=[u,v];if(Number.isInteger(x)&&Number.isInteger(y))cache.set(key,q);return q;
 }
 return {map,inverse,cache};
}

// Dense curve sampling preserves bends under a non-affine illustration map.
export function mapPath(source,map){
 if(typeof source!=='string')throw Error('Generated portrait requires vector path data');
 const tokens=source.match(/[MLCQZHVmlcqzhv]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?/g);
 let i=0,command='',x=0,y=0,sx=0,sy=0,out='';
 const point=(px,py,move=false)=>{const q=map(px,py);out+=(move?'M':'L')+q[0].toFixed(2)+' '+q[1].toFixed(2);};
 const number=()=>Number(tokens[i++]);
 while(i<tokens.length){
  if(/^[a-z]$/i.test(tokens[i]))command=tokens[i++];
  const rel=command===command.toLowerCase(),cmd=command.toUpperCase(),ox=x,oy=y;
  const pair=()=>[number()+(rel?ox:0),number()+(rel?oy:0)];
  if(cmd==='Z'){out+='Z';x=sx;y=sy;command='';continue;}
  if(cmd==='M'){[x,y]=pair();point(x,y,true);sx=x;sy=y;command=rel?'l':'L';continue;}
  if(cmd==='L'||cmd==='H'||cmd==='V'){
   let q=cmd==='L'?pair():cmd==='H'?[number()+(rel?x:0),y]:[x,number()+(rel?y:0)];
   const n=Math.max(1,Math.ceil(Math.hypot(q[0]-x,q[1]-y)/12));
   for(let k=1;k<=n;k++)point(x+(q[0]-x)*k/n,y+(q[1]-y)*k/n);[x,y]=q;continue;
  }
  if(cmd==='Q'||cmd==='C'){
   const a=pair(),b=pair(),e=cmd==='C'?pair():b;
   for(let k=1;k<=18;k++){const t=k/18,u=1-t;point(cmd==='Q'?u*u*x+2*u*t*a[0]+t*t*e[0]:u*u*u*x+3*u*u*t*a[0]+3*u*t*t*b[0]+t*t*t*e[0],cmd==='Q'?u*u*y+2*u*t*a[1]+t*t*e[1]:u*u*u*y+3*u*u*t*a[1]+3*u*t*t*b[1]+t*t*t*e[1]);}[x,y]=e;continue;
  }
  throw Error('Unsupported contour command '+command);
 }
 return out;
}
export function vectorEllipse(x,y,rx,ry){
 const k=.55228475;
 return `M${x+rx} ${y}C${x+rx} ${y+k*ry} ${x+k*rx} ${y+ry} ${x} ${y+ry}C${x-k*rx} ${y+ry} ${x-rx} ${y+k*ry} ${x-rx} ${y}C${x-rx} ${y-k*ry} ${x-k*rx} ${y-ry} ${x} ${y-ry}C${x+k*rx} ${y-ry} ${x+rx} ${y-k*ry} ${x+rx} ${y}Z`;
}
export function painterFor(space){
 const {map,inverse}=space;
 return class DesignedPainter extends SurfacePainter{
  constructor(seed,options){super(seed,{...options,emitters:options.emitters.map(e=>{const [x,y]=map(e.x,e.y);return{...e,x,y};})});}
  surface(d,box,o={}){
   const corners=[];for(let y=box[1];y<=box[3]+12;y+=12)for(let x=box[0];x<=box[2]+12;x+=12)corners.push(map(x,y));
   const b=[Math.min(...corners.map(q=>q[0]))-4,Math.min(...corners.map(q=>q[1]))-4,Math.max(...corners.map(q=>q[0]))+4,Math.max(...corners.map(q=>q[1]))+4];
   const fields={...o};
   for(const key of['height','u','v','wet','ao','corrupt','shadowField','flow'])if(o[key])fields[key]=(x,y,...rest)=>o[key](...inverse(x,y),...rest);
   fields.u ||= (x,y)=>inverse(x,y)[0];fields.v ||= (x,y)=>inverse(x,y)[1];
   super.surface(mapPath(d,map),b,fields);
  }
  fill(d,...args){super.fill(mapPath(d,map),...args);}
  line(d,...args){super.line(mapPath(d,map),...args);}
  shadow(d,...args){super.shadow(mapPath(d,map),...args);}
  stroke(d,...args){super.stroke(mapPath(d,map),...args);}
  glow(x,y,...args){const q=map(x,y);super.glow(...q,...args);}
 };
}
