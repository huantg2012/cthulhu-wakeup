shader_type canvas_item;
render_mode unshaded;
// A continuous matte window rim. Only the inward edge is worn; the text
// carrier stays opaque, so moving fog never crosses resource/navigation text.
uniform vec4 ink : source_color;
uniform vec4 pigment : source_color;
uniform vec4 edge_ink : source_color;
uniform vec2 extent = vec2(1280.0, 80.0);
uniform bool lower = false;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 vec2 p=UV*extent;
 float depth=lower ? p.y : extent.y-p.y;
 float wear=1.2+noise(vec2(p.x*.027,2.0))*1.4;
 float d=depth-wear;
 float wash=noise(p*vec2(.006,.024));
 float brush=noise(p*vec2(.045,.24));
 vec3 color=mix(ink.rgb,pigment.rgb,.17+wash*.32+brush*.08);
 // Rolled dark lip and a narrow, broken catch of light, not a box outline.
 color*=1.0-.30*exp(-max(d,0.0)/2.4);
 float lip=exp(-pow((d-2.5)/1.05,2.0));
 color=mix(color,edge_ink.rgb,lip*(.22+.20*noise(vec2(p.x*.08,9.0))));
 color+= (hash(floor(FRAGCOORD.xy))-.5)*.008;
 COLOR=vec4(color,smoothstep(-.8,.8,d));
}
