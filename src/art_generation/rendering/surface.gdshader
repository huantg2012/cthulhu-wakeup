shader_type canvas_item;
render_mode unshaded;
uniform vec2 tile_origin;
uniform vec2 tile_size;
uniform int pass_index = 0; // 0 lit, 1 pigment, 2 form
uniform int mat_id = 0;
uniform int field_id = 0;
uniform int style_sid = 0;
uniform float seed = 1339.0;
uniform vec3 base_col;
uniform vec3 shade_col;
uniform vec3 accent_col;
uniform vec3 glow_col;
uniform vec3 world_c0;
uniform vec3 world_c1;
uniform vec3 world_c2;
uniform vec3 world_c4;
uniform vec3 world_star;
uniform vec3 world_nebula;
uniform float world_seed;
uniform int environment_kind = 0;
uniform vec3 normal = vec3(0.0,0.0,1.0);
uniform vec3 light_dir = vec3(-.7,-.26,.665);
uniform vec3 ambient = vec3(.065,.10,.14);
uniform float bump = .8;
uniform float exposure = 1.0;
uniform float scale = 32.0;
uniform float salt = .08;
uniform float emission_amount = 0.0;
uniform vec2 center = vec2(0.0);
uniform bool ambient_custom = false;
uniform bool corrupt_enabled = false;
uniform int light_count = 0;
uniform vec4 light_position_radius[16];
uniform vec4 light_color_power[16];
uniform vec3 light_falloff_spec_visibility[16];
uniform int layer_id = 0;

float sm(float a,float b,float x){float t=clamp((x-a)/(b-a),0.0,1.0);return t*t*(3.0-2.0*t);}
float hs(float x,float y,float s){uint h=uint(int(x))*374761393u ^ uint(int(y))*668265263u ^ uint(int(s))*1274126177u; h=(h^(h>>13u))*1274126177u;return float(h^(h>>16u))/4294967295.0;}
float vn(float x,float y,float s){float ix=floor(x),iy=floor(y);vec2 f=fract(vec2(x,y));f=f*f*(3.0-2.0*f);return mix(mix(hs(ix,iy,s),hs(ix+1.0,iy,s),f.x),mix(hs(ix,iy+1.0,s),hs(ix+1.0,iy+1.0,s),f.x),f.y);}
float fbm(float x,float y,float s){return vn(x,y,s)*.57+vn(x*2.03+1.7,y*2.03+9.2,s)*.28+vn(x*4.13+4.1,y*4.13+7.1,s)*.15;}
vec3 cell(float x,float y,float s){float ix=floor(x),iy=floor(y),a=9.0,b=9.0,id=0.0;for(int j=-1;j<=1;j++){for(int i=-1;i<=1;i++){float xx=ix+float(i),yy=iy+float(j),dx=xx+.15+.7*hs(xx,yy,s)-x,dy=yy+.15+.7*hs(xx,yy,s+81.0)-y,d=dx*dx+dy*dy;if(d<a){b=a;a=d;id=hs(xx,yy,s+7.0);}else if(d<b){b=d;}}}return vec3(sqrt(a),sqrt(b)-sqrt(a),id);}
float fold_curve(vec2 p,vec2 a,vec2 b,vec2 c,vec2 d,float w,float amp){
 vec2 lo=min(min(a,b),min(c,d))-vec2(w*3.0),hi=max(max(a,b),max(c,d))+vec2(w*3.0);
 if(any(lessThan(p,lo))||any(greaterThan(p,hi)))return 0.0;
 float best=1e20,side=0.0,at=0.0;vec2 prev=a;
 for(int k=1;k<=26;k++){float t=float(k)/26.0,u=1.0-t;vec2 next=u*u*u*a+3.0*u*u*t*b+3.0*u*t*t*c+t*t*t*d;vec2 v=next-prev;float f=clamp(dot(p-prev,v)/max(dot(v,v),.00001),0.0,1.0);vec2 e=p-prev-v*f;float ds=dot(e,e);if(ds<best){best=ds;at=(float(k-1)+f)/26.0;side=sign(dot(e,vec2(-v.y,v.x)))*sqrt(ds);}prev=next;}
 float z=side/w;return amp*pow(max(sin(3.14159265*at),0.0),.85)*(exp(-z*z*.65)-.34*exp(-pow(z+1.35,2.0)*1.7));
}
#ifndef NATIVE_FIELDS
float field_height(float x,float y,float b){return 0.0;}
float field_u(float x,float y,float b){return x;}
float field_v(float x,float y,float b){return y;}
float field_wet(float x,float y,float b){return 0.0;}
float field_ao(float x,float y,float b){return 1.0;}
float field_corrupt(float x,float y,float b){return 0.0;}
float field_shadowField(float x,float y,float b){return 1.0;}
vec2 inverse_design(vec2 p){return p;}
float light_visibility(int i,float x,float y){return 1.0;}
#endif
// GENERATED_FIELDS

void fragment(){
 vec2 screen_point=tile_origin+UV*tile_size;
 vec2 p=inverse_design(screen_point);
 float x=p.x,y=p.y;
 float u=field_u(x,y,0.0),v=field_v(x,y,0.0);
 float broad=fbm(u*.012,v*.014,seed),mid=fbm(u*.045,v*.049,seed+2.0);
 float wet=clamp(field_wet(x,y,broad),0.0,1.0);
 float H=field_height(x,y,broad),S=.04,emitted=0.0,A=clamp(field_ao(x,y,broad),.03,1.0);
 vec3 col=base_col;
 if(field_id>0){
  col=mix(shade_col,base_col,.26+broad*.48);H+=(mid-.5)*3.0;S=.06;float warped=u+(broad-.5)*32.0;
  if(field_id==1){float ridge=pow(1.0-abs(vn(warped*.028,v*.019,seed)*2.0-1.0),6.0),fine=pow(1.0-abs(vn(u*.075,v*.058,seed+3.0)*2.0-1.0),8.0);col=mix(col,accent_col,ridge*.43);col=mix(col,shade_col,fine*.38);H+=ridge*7.0-fine*2.0;S=.25;emitted=fine*.025;}
  else if(field_id==2){vec3 vo=cell(warped/52.0,v/45.0,seed);float lobe=1.0-sm(.05,.72,vo.x),vein=pow(1.0-abs(mid*2.0-1.0),17.0);col=mix(col,accent_col,lobe*.18);col=mix(col,shade_col,vein*.55);H+=lobe*6.0+vein*1.8;S=.17;emitted=vein*.025;}
  else if(field_id==3){float colony=sm(.48,.72,broad),ice=sm(.72,.87,vn(u*.007,v*.009,seed+92.0));vec3 vo=cell(u/31.0,v/25.0,seed);float spores=(1.0-sm(.03,.20,vo.x))*colony*(1.0-ice);col=mix(col,world_c2,colony*.3);col=mix(col,mix(vec3(102,114,87)/255.0,base_col,.35),sm(.58,.78,broad)*.46);col=mix(col,accent_col,ice*.26);H+=spores*2.0+abs(mid-.5)*5.0;emitted=spores*.20;S=ice*.14;}
  else if(field_id==4){vec3 a=cell(warped/59.0,v/51.0,seed),b=cell(warped/23.0,v/19.0,seed+6.0);float crack=1.0-sm(.008,.065,a.y)+(1.0-sm(.005,.04,b.y))*.3;col=mix(shade_col,base_col,.16+broad*.48);H+=a.z*2.2-crack*3.0;col=mix(col,accent_col,sm(.54,.74,broad)*.2);emitted=crack*.14;S=.065;}
  else if(field_id==5){float terr=floor(broad*8.0)/8.0,cr=pow(1.0-abs(vn(warped*.027,v*.032,seed)*2.0-1.0),26.0),snow=sm(.38,.65,broad);col=mix(col,accent_col,snow*.42);col=mix(col,shade_col,cr*.29);H=field_height(x,y,broad)+terr*6.0+(mid-.5)*1.5-cr*2.2;S=.02+snow*.025;}
  else if(field_id==6){vec3 vo=cell(u/54.0,v/43.0,seed);float facing=normal.z/length(normal),hue=vo.z*.6+facing*.9+v*.0006+mid*.35+.09;vec3 iri=(.5+.5*cos(6.2831853*(vec3(hue)+vec3(0,.33,.67))))*175.0/255.0;float edge=1.0-sm(.008,.055,vo.y);col=mix(mix(shade_col,iri,.60),base_col,.25);col=mix(col,shade_col,edge*.35);H+=vo.z*3.0-edge*1.3;S=.19;emitted=.025+edge*.08;}
  else if(field_id==7){float dune=.5+.5*sin(v*.057+u*.022+broad*7.0);col=mix(col,accent_col,dune*.16);H+=dune*3.0;S=.03;}
  else if(field_id==8||field_id==15){float a=fbm(u*.009+3.0,v*.012+.36,seed),b=fbm(u*.011+a*3.0,v*.009-a*2.0,seed+53.0),f=fbm(u*.017+b*3.5,v*.014+a*2.5,seed);col=mix(shade_col,base_col,f);col=mix(col,accent_col,sm(.52,.75,f));H=field_height(x,y,broad)+f*3.0;emitted=(.1+sm(.55,.8,f)*.55)*(field_id==15?.46:1.0);S=.02;}
  else if(field_id==9){vec3 vo=cell(u/78.0,v/61.0,seed);float crack=1.0-sm(.007,.045,vo.y),stri=.5+.5*sin(v*.14+broad*8.0+u*.035);col=mix(col,accent_col,stri*.24);col=mix(col,shade_col,crack*.4);H+=stri*2.8-crack*1.6;emitted=crack*.08;S=.12;}
  else if(field_id==10){float relief=0.0;for(int i=0;i<2;i++){float sc=i==0?76.0:33.0,amp=i==0?1.0:.4,off=i==0?0.0:7.0;vec3 vo=cell(u/sc,v/(sc*.7),seed+off);float d=vo.x/(.28+vo.z*.34);relief+=(min(0.0,d*d-1.0)*4.0+exp(-pow((d-1.0)/.18,2.0))*2.6)*amp;}H=field_height(x,y,broad)+relief;col=mix(shade_col,base_col,clamp(.65+broad*.25+relief*.09,0.0,1.0));col=mix(col,accent_col,sm(.5,2.0,relief)*.55);S=.035;}
  else if(field_id==11){float fibre=vn(u*.14,v*.018,seed),pores=pow(1.0-mid,7.0);col=mix(col,accent_col,.2+fibre*.22);col=mix(col,shade_col,pores*.7);H+=fibre*.8-pores*1.4;S=.06;}
  else if(field_id==12){float grain=vn(u*.16,v*.015,seed);col=mix(shade_col,base_col,.42+grain*.5);H+=grain*.8;S=.04;}
  else if(field_id==13){float strand=vn(u*.23,v*.02,seed),flow=.5+.5*sin(u*.055+v*.023+mid*2.0);col=mix(col,accent_col,flow*.24);H+=strand*.4+flow*2.0;S=.18;}
  else if(field_id==14){float flow=.5+.5*sin(u*.022+v*.041+broad*9.0);col=mix(world_c1,world_c4,flow*.7);col=mix(col,world_star,pow(flow,8.0)*.52);H+=flow;S=.1;emitted=.3+flow*.5;}
 }else if(environment_kind>0 && (mat_id==2||mat_id==3||mat_id==4)){
  float deposit=0.0;
  if(environment_kind<=2){bool cold=environment_kind==1;deposit=sm(cold?.56:.52,.82,fbm(u*.025,v*.011,seed+83.0+world_seed*13.0));float worn=sm(.49,.78,mid),grain=fbm(u*.21,v*.08,seed+8.0);col=mix(shade_col,base_col,.55+broad*.45);col=mix(col,accent_col,worn*.13);col=mix(col,cold?vec3(182,194,205)/255.0:vec3(57,48,46)/255.0,deposit*(cold?.25:.34));H+=(grain-.5)*.8+(mid-.5)*1.5;S=mat_id==2?.13:.035;
  }else{float n=fbm(u*.018,v*.022,seed+world_seed*7.0);deposit=sm(.55,.81,n);col=mix(shade_col,base_col,.53+broad*.47);H+=(mid-.5)*1.2;S=mat_id==2?.14:.035;
   if(environment_kind==3){col=mix(col,accent_col,deposit*.28);H+=deposit*.8;}
   else if(environment_kind==4){float fibre=fbm(u*.21,v*.023,seed+3.0);H+=(fibre-.5)*.9;col=mix(col,accent_col,sm(.63,.84,fibre)*.17);}
   else if(environment_kind==5){col=mix(col,mix(world_nebula,world_c4,n),.08+mid*.12);S=.12;}
   else if(environment_kind==6){col=mix(col,world_nebula,deposit*.28);S+=deposit*.06;}
   else if(environment_kind==7){col=mix(col,world_c0,deposit*.36);}
   else if(environment_kind==8){float streak=fbm((u+v*.4)*.06,v*.013,seed);col=mix(col,accent_col,sm(.58,.83,streak)*.22);H+=(streak-.5)*.65;}
   else{col=mix(col,environment_kind==9?accent_col:world_c1,deposit*.23);}
  }
 }else if(mat_id==1){float strands=vn(u*.25,v*.025,seed+4.0),wave=vn(u*.08+v*.009,v*.012,seed+2.0);col=mix(shade_col,base_col,.4+wave*.6);col=mix(col,accent_col,sm(.68,.84,strands)*.12);H+=(strands-.5)*.55;S=.06;}
 else if(mat_id==2||mat_id==3){float worn=sm(.48,.78,mid),grain=vn(u*.32,v*.34,seed+7.0);col=mix(shade_col,base_col,.57+broad*.43);col=mix(col,accent_col,worn*(mat_id==2?.23:.12));H+=(grain-.5)*.42+(mid-.5)*.7;S=mat_id==2?.16:.07;}
 else if(mat_id==4){float fibre=vn(u*.17,v*.037,seed+4.0),dye=sm(.28,.73,broad),sal=sm(.59,.78,mid)*clamp(salt,0.0,1.0);col=mix(mix(shade_col,base_col,.48+dye*.52),accent_col,sal);H+=(fibre-.5)*1.15+(mid-.5)*1.8;float weave=(vn(u*.9,v*.12,seed)-.5)*.025;col*=.97+weave+mid*.06;S=.035;}
 else if(mat_id==5||mat_id==6){float wx=u+(fbm(u*.013,v*.014,seed+9.0)-.5)*24.0,wy=v+(fbm(u*.017,v*.018,seed+18.0)-.5)*20.0;vec3 vo=cell(wx/scale,wy/(scale*.7),seed);float seam=1.0-sm(.015,.085,vo.y),strata=sin((v+u*.13+(broad-.5)*36.0)*.13),mineral=clamp((broad-.3)*1.5+vo.z*.25,0.0,1.0),sal=sm(.6,.8,mid)*(1.0-wet);col=mix(shade_col,base_col,.27+mineral*.73);col=mix(col,accent_col,sal*.64);col*=1.0-seam*.09;H+=(mid-.5)*7.0+(vo.z-.5)*.65*sm(0.0,.16,vo.y)-seam*.38+strata*.9;S=.05+wet*.4;col=mix(col,vec3(19,61,62)/255.0,wet*.58);emitted=emission_amount*seam*sm(.80,.95,vo.z)*sm(.56,.72,broad);
 if(mat_id==6){float rowY=v-u*.31+(broad-.5)*3.0,row=floor(rowY/19.0),bx=(u+mod(row,2.0)*17.0+(mid-.5)*2.0)/37.0,fx=fract(bx),fy=rowY/19.0-row,joint=1.0-sm(.012,.07,min(min(fx,1.0-fx),min(fy,1.0-fy)));col=mix(col,accent_col,hs(floor(bx),row,seed)*.17);col*=1.0-joint*.14;H-=joint*.32;}}
 else if(mat_id==7){vec2 d=vec2(u,v)-center;float rad=length(d),angle=atan(d.y,d.x),spiral=sin(angle*3.0+log(rad+8.0)*10.0+(mid-.5)*2.2),current=(.5+.5*spiral)*sm(6.0,27.0,rad)*(1.0-sm(85.0,220.0,rad));col=mix(shade_col,base_col,clamp(.15+current*.55+mid*.2,0.0,1.0));col=mix(col,vec3(2,14,22)/255.0,1.0-sm(5.0,25.0,rad));H+=(mid-.5)*2.0+spiral*.6;S=.65;emitted=current*(emission_amount==0.0?.08:emission_amount);}
 else if(mat_id==8){float patina=sm(.38,.69,broad);col=mix(base_col,shade_col,patina*.8);col=mix(col,accent_col,sm(.7,.83,mid)*.7);H+=(mid-.5)*1.3;S=.38;}
 else if(mat_id==9){col=mix(base_col,shade_col,(1.0-broad)*.25);H+=(mid-.5)*.35;S=.13;}
 else{col=base_col*(.92+mid*.16);H+=(mid-.5)*.5;}
 if(corrupt_enabled){float mask=clamp(field_corrupt(x,y,broad),0.0,1.0)*sm(.27,.65,broad),vein=pow(1.0-abs(mid*2.0-1.0),12.0);col=mix(col,vec3(44,24,61)/255.0,mask*.72);H+=mask*vein*.7;emitted+=mask*vein*.26;}
 vec3 N=normalize(normal-vec3(dFdx(H)*bump,dFdy(H)*bump,0.0));
 float ndl=dot(N,light_dir),d=clamp((ndl+.08)/1.08,0.0,1.0),diff=d*.55+d*d*(3.0-2.0*d)*.45;
 bool banded=style_sid==1||style_sid==4||style_sid==7;
 if(banded){diff=mix(.03,.32,sm(-.24,-.18,ndl));diff=mix(diff,1.0,sm(.18,.24,ndl));if(style_sid==7){diff=mix(diff,1.18,sm(.72,.76,ndl));}}
 float term=banded?0.0:(1.0-sm(0.0,.32,ndl))*(ndl>0.0?.6:0.0),shadow=clamp(field_shadowField(x,y,broad),.05,1.0);
 float highlight=pow(max(0.0,dot(N,normalize(light_dir+vec3(0,0,1)))),mat_id==7?65.0:32.0)*S*sm(-.05,.1,ndl);
 float lum=diff*A*shadow*exposure;
 vec3 point=vec3(0.0),point_spec=vec3(0.0);
 for(int i=0;i<16;i++){if(i>=light_count)break;vec4 ep=light_position_radius[i];vec3 delta=vec3(ep.xy-screen_point,ep.z);float dist=length(delta.xy),fall=pow(1.0-sm(0.0,ep.w,dist),light_falloff_spec_visibility[i].x),facing=max(.08,dot(N,normalize(delta))),vis=light_falloff_spec_visibility[i].z*light_visibility(i,screen_point.x,screen_point.y);point+=light_color_power[i].rgb*(fall*facing*light_color_power[i].a*vis);float sp=pow(max(0.0,dot(N,normalize(normalize(delta)+vec3(0,0,1)))),28.0)*S*fall*light_falloff_spec_visibility[i].y*vis;point_spec+=light_color_power[i].rgb*sp;}
 vec3 tint=vec3(1.04,1.01*(1.0-term*.48),.93*(1.0-term*.66));
 float ambK=style_sid==6?3.0:style_sid==2?1.6:1.0,fill=style_sid==2||style_sid==6?.16*pow(max(N.z,0.0),1.5):0.0,sp=banded?(highlight>=.4?S*.8:0.0):highlight;
 vec3 value=col*(ambient*A*ambK+vec3(fill)+lum*tint+point)+vec3(sp*125.0/255.0*shadow*exposure)+emitted*glow_col+point_spec;
 value*=1.0+(hs(screen_point.x,screen_point.y,seed)-.5)*.025;
 // Pigment marks are coupled to the illuminated surface and quiet in shadows.
 vec2 mark=floor(screen_point/vec2(mat_id==4?4.0:8.0,mat_id==4?13.0:5.0));float mark_seed=seed+float(layer_id)*73.0;
 float br=hs(mark.x,mark.y,mark_seed),bright=(value.r+value.g+value.b)/3.0;
 float brush=(br<bright*.45?1.0:0.0)*(hs(mark.x,mark.y,mark_seed+1.0)-.5)*.024;
 if(pass_index==1)value=col;
 else if(pass_index==2)value=(ambient_custom?ambient*A:vec3(.07))+vec3(lum)+point;
 if(pass_index==2)value*=vec3(183,183,175)/255.0;
 else if(pass_index==0)value+=vec3(brush);
 COLOR=vec4(clamp(value,vec3(0),vec3(1)),texture(TEXTURE,UV).a);
}
