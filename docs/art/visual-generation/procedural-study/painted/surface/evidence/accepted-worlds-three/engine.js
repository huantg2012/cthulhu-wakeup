// A 2D surface synthesizer. Paths are illustration masks, not projected meshes.
// Material fields own colour, micro-height and reflectance together. Fold fields
// live in cloth coordinates; no swept limbs, shoulder spheres or 3D subjects.
export const SIZE=960, clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
export const lerp=(a,b,t)=>a+(b-a)*t;
export const smooth=(a,b,x)=>{const t=clamp((x-a)/(b-a));return t*t*(3-2*t);};
export const rgb=c=>Array.isArray(c)?c:[1,3,5].map(i=>parseInt(c.slice(i,i+2),16));
export const mix=(a,b,t)=>rgb(a).map((v,i)=>lerp(v,rgb(b)[i],clamp(t)));
export const css=c=>`rgb(${rgb(c).map(v=>Math.round(clamp(v,0,255))).join(',')})`;
export function rng(seed){let a=seed>>>0;return()=>{a+=0x6D2B79F5;let t=a;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return((t^(t>>>14))>>>0)/4294967296;};}
export function hash(x,y,s){let h=Math.imul(x,374761393)^Math.imul(y,668265263)^Math.imul(s,1274126177);h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967295;}
export function noise(x,y,s){const ix=Math.floor(x),iy=Math.floor(y);let u=x-ix,v=y-iy;u=u*u*(3-2*u);v=v*v*(3-2*v);return lerp(lerp(hash(ix,iy,s),hash(ix+1,iy,s),u),lerp(hash(ix,iy+1,s),hash(ix+1,iy+1,s),u),v);}
export const fbm=(x,y,s)=>noise(x,y,s)*.57+noise(x*2.03+1.7,y*2.03+9.2,s)*.28+noise(x*4.13+4.1,y*4.13+7.1,s)*.15;
export function cell(x,y,s){const ix=Math.floor(x),iy=Math.floor(y);let a=9,b=9,id=0;for(let j=-1;j<=1;j++)for(let i=-1;i<=1;i++){const xx=ix+i,yy=iy+j,dx=xx+.15+.7*hash(xx,yy,s)-x,dy=yy+.15+.7*hash(xx,yy,s+81)-y,d=dx*dx+dy*dy;if(d<a){b=a;a=d;id=hash(xx,yy,s+7);}else if(d<b)b=d;}return [Math.sqrt(a),Math.sqrt(b)-Math.sqrt(a),id];}
const canvas=(w=SIZE,h=SIZE)=>{const c=document.createElement('canvas');c.width=w;c.height=h;return c;};
export const path=p=>p instanceof Path2D?p:new Path2D(p);
export const ellipse=(x,y,rx,ry)=>{const p=new Path2D();p.ellipse(x,y,rx,ry,0,0,Math.PI*2);return p;};

// Cubic cloth crease, with smoothly vanishing ends. Sampled into a spatial grid
// once, then used to produce a continuous scalar field, not a visible tube.
export function foldField(curves,base=()=>0){
 const grid=new Map(),tile=48;
 for(const q of curves){const [p0,p1,p2,p3,width,amp]=q;let prev=p0;for(let k=1;k<=26;k++){
  const t=k/26,u=1-t,p=[u*u*u*p0[0]+3*u*u*t*p1[0]+3*u*t*t*p2[0]+t*t*t*p3[0],u*u*u*p0[1]+3*u*u*t*p1[1]+3*u*t*t*p2[1]+t*t*t*p3[1]];
  const seg={a:prev,b:p,t0:(k-1)/26,w:width,amp,id:q};
  for(let y=Math.floor((Math.min(prev[1],p[1])-width*3)/tile);y<=Math.floor((Math.max(prev[1],p[1])+width*3)/tile);y++)for(let x=Math.floor((Math.min(prev[0],p[0])-width*3)/tile);x<=Math.floor((Math.max(prev[0],p[0])+width*3)/tile);x++){const key=x+','+y;if(!grid.has(key))grid.set(key,[]);grid.get(key).push(seg);}prev=p;
 }}
 return(x,y)=>{let h=base(x,y);const candidates=grid.get(Math.floor(x/tile)+','+Math.floor(y/tile));if(!candidates)return h;const nearest=new Map();for(const s of candidates){const dx=s.b[0]-s.a[0],dy=s.b[1]-s.a[1],l=dx*dx+dy*dy,t=clamp(((x-s.a[0])*dx+(y-s.a[1])*dy)/(l||1)),px=x-s.a[0]-dx*t,py=y-s.a[1]-dy*t,d=px*px+py*py,old=nearest.get(s.id);if(!old||d<old.d)nearest.set(s.id,{s,d,t:s.t0+t/26,side:Math.sign(px*-dy+py*dx)*Math.sqrt(d)});}
  for(const {s,side,t}of nearest.values()){const z=side/s.w,fade=Math.sin(Math.PI*t)**.85;h+=s.amp*fade*(Math.exp(-z*z*.65)-.34*Math.exp(-Math.pow(z+1.35,2)*1.7));}return h;
 };
}

export class SurfacePainter{
 constructor(seed,{light=[-.7,-.26,.665],emitters=[],styleSid=0}={}){
  this.seed=seed;this.r=rng(seed);this.light=light;this.emitters=emitters;this.styleSid=styleSid;this.canvas=canvas();this.c=this.canvas.getContext('2d');
  this.material=canvas();this.mc=this.material.getContext('2d');this.form=canvas();this.fc=this.form.getContext('2d');this.layers=0;
 }
 surface(d,box,o={}){
  this.layers++;const x0=Math.max(0,Math.floor(box[0])-3),y0=Math.max(0,Math.floor(box[1])-3),w=Math.min(SIZE,Math.ceil(box[2])+3)-x0,h=Math.min(SIZE,Math.ceil(box[3])+3)-y0;
  if(w<=0||h<=0)return;const tile=canvas(w,h),tc=tile.getContext('2d',{willReadFrequently:true});tc.translate(-x0,-y0);tc.fillStyle='#fff';tc.fill(path(d));const mask=tc.getImageData(0,0,w,h).data;
  const height=new Float32Array(w*h),colors=new Float32Array(w*h*3),spec=new Float32Array(w*h),occ=new Float32Array(w*h),em=new Float32Array(w*h),wetness=new Float32Array(w*h);
  const seed=this.seed+(o.seed||0),mat=o.mat||'stone',base=rgb(o.color||'#758e70'),shade=rgb(o.shadow||'#17333b'),accent=rgb(o.accent||'#b9b58b'),normal=o.normal||[0,0,1],sc=o.scale||32;
  for(let yy=0;yy<h;yy++)for(let xx=0;xx<w;xx++){
   const i=yy*w+xx;if(!mask[i*4+3])continue;const x=x0+xx,y=y0+yy,u=o.u?o.u(x,y):x,v=o.v?o.v(x,y):y;
   const broad=fbm(u*.012,v*.014,seed),mid=fbm(u*.045,v*.049,seed+2),wet=o.wet?clamp(o.wet(x,y,broad)):0;
   let H=o.height?o.height(x,y):0,col=base.slice(),S=.04,E=0,A=o.ao?clamp(o.ao(x,y),.03,1):1;
   if(o.field){
    const f=o.field({x,y,u,v,broad,mid,seed,base,shade,accent,wet,normal});col=f.color;H+=f.height||0;S=f.spec??.08;E=f.emission||0;
   }else if(mat==='hair'){
    const strands=noise(u*.25,v*.025,seed+4),wave=noise(u*.08+v*.009,v*.012,seed+2);
    col=mix(shade,base,.4+wave*.6);col=mix(col,accent,smooth(.68,.84,strands)*.12);
    H+=(strands-.5)*.55;S=.06;
   }else if(mat==='leather'||mat==='canvas'){
    const worn=smooth(.48,.78,mid),grain=noise(u*.32,v*.34,seed+7);
    col=mix(shade,base,.57+broad*.43);col=mix(col,accent,worn*(mat==='leather'?.23:.12));
    H+=(grain-.5)*.42+(mid-.5)*.7;S=mat==='leather'?.16:.07;
   }else if(mat==='cloth'){
    const fibre=noise(u*.17,v*.037,seed+4),dye=smooth(.28,.73,broad),salt=smooth(.59,.78,mid)*clamp(o.salt||.08);
    col=mix(mix(shade,base,.48+dye*.52),accent,salt);H+=(fibre-.5)*1.15+(mid-.5)*1.8;
    const weave=(noise(u*.9,v*.12,seed)-.5)*.025;col=col.map(c=>c*(.97+weave+mid*.06));S=.035;
   }else if(mat==='stone'||mat==='masonry'){
    const wx=u+(fbm(u*.013,v*.014,seed+9)-.5)*24,wy=v+(fbm(u*.017,v*.018,seed+18)-.5)*20;
    const vo=cell(wx/sc,wy/(sc*.7),seed),seam=1-smooth(.015,.085,vo[1]),strata=Math.sin((v+u*.13+(broad-.5)*36)*.13);
    const mineral=clamp((broad-.3)*1.5+vo[2]*.25),salt=smooth(.6,.8,mid)*(1-wet);
    col=mix(shade,base,.27+mineral*.73);col=mix(col,accent,salt*.64);col=col.map(c=>c*(1-seam*.09));
    H+=(mid-.5)*7+(vo[2]-.5)*.65*smooth(0,.16,vo[1])-seam*.38+strata*.9;S=.05+wet*.4;col=mix(col,'#133d3e',wet*.58);
    E=(o.emission||0)*seam*smooth(.80,.95,vo[2])*smooth(.56,.72,broad);
    if(mat==='masonry'){
     const rowY=v-u*.31+(broad-.5)*3,row=Math.floor(rowY/19),bx=(u+row%2*17+(mid-.5)*2)/37,fx=bx-Math.floor(bx),fy=rowY/19-row,joint=1-smooth(.012,.07,Math.min(fx,1-fx,fy,1-fy));
     const block=hash(Math.floor(bx),row,seed);col=mix(col,accent,block*.17);col=col.map(c=>c*(1-joint*.14));H-=joint*.32;
    }
   }else if(mat==='water'){
    const dx=(u-(o.cx||0)),dy=(v-(o.cy||0)),rad=Math.hypot(dx,dy),angle=Math.atan2(dy,dx),spiral=Math.sin(angle*3+Math.log(rad+8)*10+(mid-.5)*2.2);
    const current=(.5+.5*spiral)*smooth(6,27,rad)*(1-smooth(85,220,rad));
    col=mix(shade,base,clamp(.15+current*.55+mid*.2));col=mix(col,'#020e16',1-smooth(5,25,rad));
    H+=(mid-.5)*2+spiral*.6;S=.65;E=current*(o.emission||.08);
   }else if(mat==='metal'){
    const patina=smooth(.38,.69,broad);col=mix(base,shade,patina*.8);col=mix(col,accent,smooth(.7,.83,mid)*.7);H+=(mid-.5)*1.3;S=.38;
   }else if(mat==='skin'){
    col=mix(base,shade,(1-broad)*.25);H+=(mid-.5)*.35;S=.13;
   }else{col=base.map(c=>c*(.92+mid*.16));H+=(mid-.5)*.5;}
   if(o.corrupt){const mask=clamp(o.corrupt(x,y))*smooth(.27,.65,broad),vein=(1-Math.abs(mid*2-1))**12;col=mix(col,'#2c183d',mask*.72);H+=mask*vein*.7;E+=mask*vein*.26;}
   height[i]=H;colors.set(col,i*3);spec[i]=S;occ[i]=A;em[i]=E;wetness[i]=wet;
  }
  const out=tc.createImageData(w,h),albedo=tc.createImageData(w,h),shape=tc.createImageData(w,h),L=this.light,illum=o.exposure??1;
  for(let yy=0;yy<h;yy++)for(let xx=0;xx<w;xx++){
   const i=yy*w+xx,j=i*4,alpha=mask[j+3];if(!alpha)continue;const x=x0+xx,y=y0+yy,H=height[i],hm=(dx,dy)=>{const n=(yy+dy)*w+xx+dx;return xx+dx<0||xx+dx>=w||yy+dy<0||yy+dy>=h||!mask[n*4+3]?H:height[n];};
   const bump=o.bump??.8,nx=normal[0]-(hm(1,0)-hm(-1,0))*.5*bump,ny=normal[1]-(hm(0,1)-hm(0,-1))*.5*bump,nz=normal[2],len=Math.hypot(nx,ny,nz),N=[nx/len,ny/len,nz/len];
   const ndl=N[0]*L[0]+N[1]*L[1]+N[2]*L[2],d=clamp((ndl+.08)/1.08),sid=this.styleSid,banded=[1,4,7].includes(sid);
   let diff=d*.55+d*d*(3-2*d)*.45;
   if(banded){diff=lerp(.03,.32,smooth(-.24,-.18,ndl));diff=lerp(diff,1,smooth(.18,.24,ndl));if(sid===7)diff=lerp(diff,1.18,smooth(.72,.76,ndl));}
   const term=banded?0:(1-smooth(0,.32,ndl))*(ndl>0?.6:0),ao=occ[i],shadow=o.shadowField?clamp(o.shadowField(x,y),.05,1):1;
   const hx=L[0],hy=L[1],hz=L[2]+1,hl=Math.hypot(hx,hy,hz),highlight=Math.max(0,(N[0]*hx+N[1]*hy+N[2]*hz)/hl)**(mat==='water'?65:32)*spec[i]*smooth(-.05,.1,ndl);
   const lum=diff*ao*shadow*illum,point=[0,0,0],pointSpec=[0,0,0];
   for(const e of this.emitters){
    const dx=e.x-x,dy=e.y-y,dist=Math.hypot(dx,dy),fall=(1-smooth(0,e.r,dist))**(e.falloff??2),den=Math.hypot(dx,dy,e.z||55),dot=Math.max(.08,(N[0]*dx+N[1]*dy+N[2]*(e.z||55))/den);
    const visibility=(e.visibility?clamp(e.visibility(x,y)):1)*(o.pointVisibility?clamp(o.pointVisibility(e,x,y)):1),power=fall*dot*e.power*visibility;
    for(let k=0;k<3;k++)point[k]+=e.color[k]/255*power;
    if(e.specular){
     const hx=dx/den,hy=dy/den,hz=(e.z||55)/den+1,hl=Math.hypot(hx,hy,hz),sp=Math.max(0,(N[0]*hx+N[1]*hy+N[2]*hz)/hl)**28*spec[i]*fall*e.specular*visibility;
     for(let k=0;k<3;k++)pointSpec[k]+=e.color[k]*sp;
    }
   }
   // Back-plane fill is opt-in per illustrated surface. Existing portrait
   // lighting retains the same defaults; cavities can keep their low floor.
   const lightTint=[1.04,1.01*(1-term*.48),.93*(1-term*.66)],ambient=o.ambient||[.065,.10,.14],emColor=rgb(o.glow||'#6bff9e');
   const grain=1+(hash(x,y,seed)-.5)*.025;
   for(let k=0;k<3;k++){
    const ambK=sid===6?3.0:sid===2?1.6:1,fill=sid===2||sid===6?.16*Math.pow(Math.max(N[2],0),1.5):0;
    const sp=banded?(highlight>=.4?spec[i]*.8:0):highlight;
    const a=colors[i*3+k],value=a*(ambient[k]*ao*ambK+fill+lum*lightTint[k]+point[k])+sp*125*shadow*illum+em[i]*emColor[k]+pointSpec[k];
    out.data[j+k]=clamp(value*grain,0,255);albedo.data[j+k]=a;shape.data[j+k]=clamp(((o.ambient?ambient[k]*ao:.07)+lum+point[k])*(k===2?175:183),0,255);
   }
   out.data[j+3]=albedo.data[j+3]=shape.data[j+3]=alpha;
  }
  tc.setTransform(1,0,0,1,0,0);tc.putImageData(out,0,0);
  // Surface-space pigment marks take their colour from the already coupled
  // material/light result. Their direction follows cloth or rock strata; dark
  // masses stay quiet. This is not a stock bitmap texture or a finished asset.
  const br=rng(seed+this.layers*73);tc.save();tc.globalCompositeOperation='source-atop';
  for(let k=0;k<w*h/([1,4,7].includes(this.styleSid)?140:36);k++){
   const xx=Math.floor(br()*w),yy=Math.floor(br()*h),i=(yy*w+xx)*4;if(out.data[i+3]<200)continue;
   const bright=(out.data[i]+out.data[i+1]+out.data[i+2])/765;if(br()>bright*1.1)continue;
   const a=o.flow?o.flow(x0+xx,y0+yy):mat==='cloth'?1.45:mat==='water'?.1:.15+(br()-.5)*.75;
   const len=(mat==='cloth'?8:6)+br()*10,wide=1.5+br()*3.8,tint=(br()-.5)*12;
   tc.save();tc.translate(xx,yy);tc.rotate(a);tc.globalAlpha=.14+br()*.2;tc.fillStyle=css([out.data[i]+tint,out.data[i+1]+tint,out.data[i+2]+tint]);tc.beginPath();tc.moveTo(-len*.5,-wide*.25);tc.lineTo(len*.3,-wide*.5);tc.lineTo(len*.5,wide*.3);tc.lineTo(-len*.4,wide*.5);tc.fill();tc.restore();
  }tc.restore();
  this.c.drawImage(tile,x0,y0);tc.putImageData(albedo,0,0);this.mc.drawImage(tile,x0,y0);tc.putImageData(shape,0,0);this.fc.drawImage(tile,x0,y0);
 }
 fill(d,color,alpha=1){for(const c of[this.c,this.mc,this.fc]){c.save();c.globalAlpha=alpha;c.fillStyle=typeof color==='string'?color:css(color);c.fill(path(d));c.restore();}}
 line(d,color,width=1,alpha=1){for(const c of[this.c,this.mc,this.fc]){c.save();c.globalAlpha=alpha;c.lineWidth=width;c.lineCap='round';c.lineJoin='round';c.strokeStyle=typeof color==='string'?color:css(color);c.stroke(path(d));c.restore();}}
 shadow(d,amount=.5,blur=0){for(const c of[this.c,this.fc]){c.save();c.fillStyle=`rgba(2,7,17,${amount})`;c.filter=blur?`blur(${blur}px)`:'none';c.fill(path(d));c.restore();}}
 glow(x,y,r,color,alpha=.4){const c=this.c,g=c.createRadialGradient(x,y,1,x,y,r);g.addColorStop(0,css(color));g.addColorStop(.18,css(mix(color,'#122536',.5)));g.addColorStop(1,'#00000000');c.save();c.globalCompositeOperation='screen';c.globalAlpha=alpha;c.fillStyle=g;c.fillRect(x-r,y-r,r*2,r*2);c.restore();}
 stroke(d,color,width=2,alpha=.5){for(let i=0;i<3;i++){this.c.save();this.c.translate((this.r()-.5)*width*.4,(this.r()-.5)*width*.4);this.c.globalAlpha=alpha*.4;this.c.strokeStyle=css(color);this.c.lineWidth=width*(.45+this.r()*.55);this.c.lineCap='round';this.c.stroke(path(d));this.c.restore();}}
 fade(start=870){for(const c of[this.c,this.mc,this.fc]){c.save();c.globalCompositeOperation='destination-in';const g=c.createLinearGradient(0,start,0,960);g.addColorStop(0,'#fff');g.addColorStop(1,'#fff0');c.fillStyle=g;c.fillRect(0,0,960,960);c.restore();}}
 reframe(scale,dx,dy){for(const c of[this.c,this.mc,this.fc]){const copy=canvas();copy.getContext('2d').drawImage(c.canvas,0,0);c.clearRect(0,0,SIZE,SIZE);c.drawImage(copy,dx,dy,SIZE*scale,SIZE*scale);}}
 output(){return{albedo:this.canvas,normals:canvas(),material:this.material,form:this.form,count:this.layers};}
}
