shader_type canvas_item;
render_mode unshaded;
#include "res://src/presentation/production/painted/peripheral_fields.gdshaderinc"
varying vec2 stage_point;
varying float strand_id;
void vertex() {
 stage_point = VERTEX;
 strand_id = COLOR.r*5.0;
}
void fragment() {
 float seed = floor(strand_id+0.5);
 float along = UV.x;
 float across = UV.y;
 float pigment = texture(pigment_noise,vec2(along*1.8,across*0.25)+seed).r;
 float dry = texture(pigment_noise,vec2(along*1.5,across*0.21)+seed).g;
 float light = exp(-pow((across-0.30)/0.21,2.0));
 float crease = exp(-pow((across-0.72)/0.08,2.0));
 vec3 ink = mix(vec3(0.017,0.032,0.031),vec3(0.15,0.21,0.17),light*(0.33+pigment*0.42));
 ink *= 1.0-crease*0.20;
 ink += (dry-0.5)*0.018;
 float edge = smoothstep(0.0,0.11,across)*(1.0-smoothstep(0.89,1.0,across));
 float fade = 1.0-smoothstep(0.80,1.0,along);
 vec4 surface = vec4(ink,edge*fade*0.86);
 // Only three curls carry eyes. Their UV centres deform with the fixed strip.
 if (seed<0.5 || abs(seed-3.0)<0.5 || abs(seed-4.0)<0.5) {
  float centre = seed>3.5 ? 0.57 : 0.44;
  vec2 q = (UV-vec2(centre,0.48))/vec2(0.075,0.33);
  vec4 eye = tissue_eye(q,seed+0.7,0.84+0.09*sin(cycle_angle()+seed));
  eye.a *= edge*fade;
  surface = paint_over(surface,eye);
 }
 COLOR = vec4(surface.rgb,surface.a*tissue_strength*reading_mask(stage_point));
}
