shader_type canvas_item;
render_mode unshaded;
#include "res://docs/art/visual-generation/ui-study/peripheral_fields.gdshaderinc"

float membrane_boundary(float along,float phase) {
 float angle = cycle_angle();
 float lobe = texture(pigment_noise,vec2(along*0.0018+sin(angle+phase)*0.025,phase+cos(angle+phase)*0.018)).r;
 return 16.0+lobe*30.0+sin(along*0.009+angle+phase)*6.0+sin(along*0.021-angle*2.0+phase)*1.8;
}

vec4 membrane(vec2 point,float phase,float eye_at) {
 if (point.y>100.0) { return vec4(0.0); }
 float boundary = membrane_boundary(point.x,phase);
 float fold = point.y-boundary;
 float skin = 1.0-smoothstep(-8.0,7.0,fold);
 float ridge = exp(-pow((fold+6.0)/6.5,2.0));
 float drag = texture(pigment_noise,point*vec2(0.005,0.022)+phase).r;
 float grain = texture(pigment_noise,point*vec2(0.009,0.028)+phase).g;
 vec3 color = mix(vec3(0.012,0.025,0.025),vec3(0.14,0.20,0.16),ridge*(0.22+drag*0.40));
 color += (grain-0.5)*0.009*skin;
 vec4 result = vec4(color,skin*0.88);
 if (eye_at>=0.0) {
  // The eye rides the exact boundary that supports its surrounding skin.
  float centre_boundary = membrane_boundary(eye_at,phase);
  float slope = (membrane_boundary(eye_at+1.0,phase)-membrane_boundary(eye_at-1.0,phase))*0.5;
  vec2 delta = point-vec2(eye_at,centre_boundary*0.50);
  vec2 q = vec2(delta.x,delta.y-delta.x*slope*0.50)/vec2(18.0,max(7.0,centre_boundary*0.32));
  vec4 eye = tissue_eye(q,phase,0.82+0.10*sin(cycle_angle()+phase));
  eye.a *= skin;
  result = paint_over(result,eye);
 }
 return result;
}

void fragment() {
 vec2 p = UV*vec2(1280.0,720.0);
 float edge = edge_distance(p);
 vec4 paint = vec4(0.0);
 if (edge<155.0) {
  float density = cloud_field(p,0.4);
  float body = smoothstep(0.10,0.90,density);
  float depth = 30.0+density*50.0;
  float haze = 1.0-smoothstep(depth*0.35,depth+65.0,edge);
  vec3 ink = mix(vec3(0.014,0.025,0.031),vec3(0.15,0.22,0.21),body*0.78);
  paint = vec4(ink,haze*(0.33+body*0.48));
  paint = paint_over(paint,membrane(vec2(p.x,p.y),0.4,855.0));
  paint = paint_over(paint,membrane(vec2(1280.0-p.x,720.0-p.y),2.8,-1.0));
  paint = paint_over(paint,membrane(vec2(p.y,p.x),5.9,-1.0));
  paint = paint_over(paint,membrane(vec2(720.0-p.y,1280.0-p.x),9.2,438.0));
 }
 COLOR = vec4(paint.rgb,paint.a*reading_mask(p));
}
