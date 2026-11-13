shader_type canvas_item;
render_mode unshaded;

// Printed carrier only. Generated art, backdrop and organic motion are excluded.
uniform int palette = 0;
uniform int role = 0;
uniform vec4 original_tint : source_color = vec4(1.0);
uniform vec4 category : source_color = vec4(0.54,0.28,0.24,1.0);
uniform bool on_card = false;
uniform bool paper_text = false;
uniform bool spine = false;
uniform float reading_start = 0.625;
uniform float reading_end = 0.985;
uniform vec2 extent = vec2(260.0,390.0);
uniform float stack_depth = 0.0;
uniform float hover_light = 1.0;
uniform float stock_seed = 0.0;
varying vec2 stock_pos;
varying float vertex_alpha;

void vertex() {
 stock_pos = VERTEX / max(extent,vec2(1.0));
 vertex_alpha = COLOR.a;
}
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
vec3 printed_stock(vec3 source) {
 vec2 p=stock_pos;
 float v=dot(source,vec3(.2126,.7152,.0722));
 float broken=noise(vec2(p.x*32.0,p.y*5.0));
 float drag=noise(vec2(p.x*5.0+p.y*2.1,p.y*87.0));
 vec3 colour=category.rgb;
 vec3 deep=colour*vec3(.52,.48,.57)+vec3(.018,.014,.022);
 vec3 pigment=colour*(.84+(drag-.5)*.07);
 // Two flat ink passes with a dry registration edge, no rounded bevel shine.
 float stroke_end=.15+(broken-.5)*.045+p.y*.04;
 float shoulder=1.0-smoothstep(stroke_end,stroke_end+.008,p.x);
 float head=1.0-smoothstep(.085+(broken-.5)*.009,.090+(broken-.5)*.009,p.y);
 vec3 ink=mix(deep,pigment,max(shoulder*.56,head*.55));
 float start=reading_start+(broken-.5)*1.8/extent.y;
 float face=smoothstep(start-.5/extent.y,start+.5/extent.y,p.y)*(1.0-smoothstep(reading_end-.003,reading_end+.003,p.y));
 vec3 paper=vec3(.863,.847,.800);
 // Paper is light, ink carries chroma. Grain is fibre-scale, never cloudy.
 float fibre=hash21(floor(p*extent));
 paper*=1.0+(fibre-.5)*.018+clamp((.203-v)*.55,-.023,.012);
 paper*=1.0-.095*min(stack_depth,2.6);
 ink=mix(ink,paper,face);
 // Only two tiny exposed fibres; the separate image mount supplies thickness.
 float exposed_edge=smoothstep(2.8,3.4,p.x*extent.x)*(1.0-smoothstep(4.7,5.2,p.x*extent.x));
 float exposure=(smoothstep(.12,.13,p.y)*(1.0-smoothstep(.18,.19,p.y))
              +smoothstep(.49,.50,p.y)*(1.0-smoothstep(.54,.55,p.y)));
 ink=mix(ink,paper,exposed_edge*exposure*(1.0-face)*.36);
 if (spine) {
  float exposed=.35+.24*smoothstep(.15,.70,p.y);
  ink=mix(deep,pigment,exposed);
  ink*=.93+.08*noise(vec2(p.x*3.0,p.y*24.0));
 }
 // Paper fibres upper-left, concentrated ink lower-right, contact shadows.
 vec2 d=min(p,vec2(1.0)-p)*extent;
 float rim=1.0-smoothstep(1.5,3.5,min(d.x,d.y));
 float upper=max(1.0-smoothstep(.01,.04,p.x),1.0-smoothstep(.008,.03,p.y));
 vec3 cut=mix(deep*.37,mix(colour*.72,vec3(.85,.81,.69),.37),upper);
 if (!spine) ink=mix(ink,cut,rim*.91);
 // Preserve source silhouettes, black shadow and short selection cuts.
 ink=mix(ink,vec3(.87,.79,.58),smoothstep(.65,.91,v));
 return ink*smoothstep(.015,.09,v)*mix(1.0,hover_light,.42);
}
float paper_mask(vec2 point) {
 // Mostly stable cut stock; a handful of shallow nicks replace saw-tooth wear.
 vec2 edge=min(point,extent-point);
 float corner=min(min(point.x+point.y,extent.x-point.x+point.y),
                  min(point.x+extent.y-point.y,extent.x-point.x+extent.y-point.y));
 float seed=fract(sin(stock_seed*17.31+2.4)*43758.5453);
 float left_nick=(1.0-smoothstep(1.5,3.5,abs(point.y-extent.y*(.23+.21*seed))))*.8;
 float right_nick=(1.0-smoothstep(1.0,3.0,abs(point.y-extent.y*(.67+.13*seed))))*.8;
 float top_nick=(1.0-smoothstep(1.2,3.0,abs(point.x-extent.x*(.57+.20*seed))))*.7;
 float bottom_nick=(1.0-smoothstep(1.0,2.8,abs(point.x-extent.x*(.23+.20*seed))))*.7;
 float distance_to_cut=min(min(point.x-left_nick,extent.x-point.x-right_nick),
                           min(point.y-top_nick,extent.y-point.y-bottom_nick));
 return smoothstep(1.0,1.7,distance_to_cut)*smoothstep(4.0,4.8,corner);
}
void fragment() {
 vec4 c=COLOR;
 if (palette!=0) {
  if (role==1) {
   // Only the 260×390 stock, never the seal, focus strokes or shadow polygons.
   bool is_stock=abs(TEXTURE_PIXEL_SIZE.x-1.0/260.0)<.000001
              && abs(TEXTURE_PIXEL_SIZE.y-1.0/390.0)<.000001;
   vec3 source=c.rgb/max(original_tint.rgb,vec3(.001));
   if (is_stock && texture(TEXTURE,UV).a<.001) source=vec3(.203);
   // Old stock highlights describe hundreds of torn flecks. The new cut has
   // its own paper edge; do not translate those flecks into metallic foil.
   if (is_stock) source=clamp(source,vec3(.14),vec3(.30));
   c.rgb=printed_stock(source);
   if (is_stock && !spine) c.a=vertex_alpha*paper_mask(stock_pos*extent);
  }
  else if (role==0 && on_card) {
   float v=dot(c.rgb,vec3(.2126,.7152,.0722));
   if (v>.60) {
    bool semantic=c.r>c.g*1.10 || c.b>c.g*1.10;
    if (paper_text) c.rgb=semantic ? c.rgb*.34 : vec3(.12,.105,.13)*(1.0+(1.0-smoothstep(.70,.84,v))*.35);
    else if (!semantic) c.rgb=vec3(.94,.90,.75)*mix(.94,1.0,smoothstep(.60,.84,v));
   }
  } else if (role==3) {
   float v=dot(c.rgb,vec3(.2126,.7152,.0722));
   vec3 dark=category.rgb*.17+vec3(.01,.015,.02);
   c.rgb=mix(dark,vec3(.78,.74,.58),smoothstep(.16,.38,v));
  }
 }
 COLOR=c;
}
