import {fbm,noise,cell,smooth,clamp,mix} from './engine.js';

// Planar, material-specific translations of s_* in planet_body.gdshaderinc.
// They share structural causes across pigment, relief, reflectance and light;
// they are not the original spherical algorithms. Time/view are frozen at 3 s.
export function worldField(kind,w){
 return ({u,v,broad,mid,seed,base,shade,accent,wet,normal=[0,0,1]})=>{
  let color=mix(shade,base,.26+broad*.48),height=(mid-.5)*3,spec=.06,emission=0;
  const warped=u+(broad-.5)*32;
  if(kind==='ridge'){
   const ridge=Math.pow(1-Math.abs(noise(warped*.028,v*.019,seed)*2-1),6),fine=Math.pow(1-Math.abs(noise(u*.075,v*.058,seed+3)*2-1),8);
   color=mix(color,accent,ridge*.43);color=mix(color,shade,fine*.38);height+=ridge*7-fine*2;spec=.25;emission=fine*.025;
  }else if(kind==='flesh'){
   const vo=cell(warped/52,v/45,seed),lobe=1-smooth(.05,.72,vo[0]),vein=Math.pow(1-Math.abs(mid*2-1),17);
   color=mix(color,accent,lobe*.18);color=mix(color,shade,vein*.55);height+=lobe*6+vein*1.8;spec=.17;emission=vein*.025;
  }else if(kind==='fungus'){
   const colony=smooth(.48,.72,broad),ice=smooth(.72,.87,noise(u*.007,v*.009,seed+92)),vo=cell(u/31,v/25,seed);
   const spores=(1-smooth(.03,.20,vo[0]))*colony*(1-ice);
   color=mix(color,w.c2,colony*.3);color=mix(color,mix('#667257',base,.35),smooth(.58,.78,broad)*.46);color=mix(color,accent,ice*.26);height+=spores*2+Math.abs(mid-.5)*5;emission=spores*.20;spec=ice*.14;
  }else if(kind==='basalt'){
   const a=cell(warped/59,v/51,seed),b=cell(warped/23,v/19,seed+6),crack=(1-smooth(.008,.065,a[1]))+(1-smooth(.005,.04,b[1]))*.3;
   color=mix(shade,base,.16+broad*.48);height+=a[2]*2.2-crack*3;color=mix(color,accent,smooth(.54,.74,broad)*.2);emission=crack*.14;spec=.065;
  }else if(kind==='frost'){
   const terr=Math.floor(broad*8)/8,cr=Math.pow(1-Math.abs(noise(warped*.027,v*.032,seed)*2-1),26),snow=smooth(.38,.65,broad);
   color=mix(color,accent,snow*.42);color=mix(color,shade,cr*.29);height=terr*6+(mid-.5)*1.5-cr*2.2;spec=.02+snow*.025;
  }else if(kind==='prism'){
   const vo=cell(u/54,v/43,seed),facing=normal[2]/Math.hypot(...normal),hue=vo[2]*.6+facing*.9+v*.0006+mid*.35+.09;
   const iri=[0,.33,.67].map(c=>(.5+.5*Math.cos(Math.PI*2*(hue+c)))*175),edge=1-smooth(.008,.055,vo[1]);
   color=mix(mix(shade,iri,.60),base,.25);color=mix(color,shade,edge*.35);height+=vo[2]*3-edge*1.3;spec=.19;emission=.025+edge*.08;
  }else if(kind==='sand'){
   const dune=.5+.5*Math.sin(v*.057+u*.022+broad*7);color=mix(color,accent,dune*.16);height+=dune*3;spec=.03;
  }else if(kind==='flux'){
   const a=fbm(u*.009+3,v*.012+.36,seed),b=fbm(u*.011+a*3,v*.009-a*2,seed+53),f=fbm(u*.017+b*3.5,v*.014+a*2.5,seed);
   color=mix(shade,base,f);color=mix(color,accent,smooth(.52,.75,f));height=f*3;emission=.1+smooth(.55,.8,f)*.55;spec=.02;
  }else if(kind==='shell'){
   const vo=cell(u/78,v/61,seed),crack=1-smooth(.007,.045,vo[1]),stri=.5+.5*Math.sin(v*.14+broad*8+u*.035);
   color=mix(color,accent,stri*.24);color=mix(color,shade,crack*.4);height+=stri*2.8-crack*1.6;emission=crack*.08;spec=.12;
  }else if(kind==='bone'){
   height=0;
   for(const [sc,amp,off]of[[76,1,0],[33,.4,7]]){const vo=cell(u/sc,v/(sc*.7),seed+off),d=vo[0]/(.28+vo[2]*.34);height+=(Math.min(0,d*d-1)*4+Math.exp(-(((d-1)/.18)**2))*2.6)*amp;}
   color=mix(shade,base,clamp(.65+broad*.25+height*.09));color=mix(color,accent,smooth(.5,2,height)*.55);spec=.035;
  }else if(kind==='ivory'){
   const fibre=noise(u*.14,v*.018,seed),pores=Math.pow(1-mid,7);
   color=mix(color,accent,.2+fibre*.22);color=mix(color,shade,pores*.7);height+=fibre*.8-pores*1.4;spec=.06;
  }else if(kind==='wood'){
   const grain=noise(u*.16,v*.015,seed);color=mix(shade,base,.42+grain*.5);height+=grain*.8;spec=.04;
  }else if(kind==='silk'){
   const strand=noise(u*.23,v*.02,seed),flow=.5+.5*Math.sin(u*.055+v*.023+mid*2);color=mix(color,accent,flow*.24);height+=strand*.4+flow*2;spec=.18;
  }else if(kind==='lava'){
   const flow=.5+.5*Math.sin(u*.022+v*.041+broad*9);color=mix(w.c1,w.c4,flow*.7);color=mix(color,w.star,Math.pow(flow,8)*.52);height+=flow;spec=.1;emission=.3+flow*.5;
  }
  return{color,height,spec,emission};
 };
}
