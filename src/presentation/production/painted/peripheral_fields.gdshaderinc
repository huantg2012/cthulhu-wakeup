// Shared air, pigment and tissue fields for the three depth layers.
uniform sampler2D pigment_noise : repeat_enable, filter_linear;
uniform float elapsed = 0.0;
uniform float wash_strength = 1.0;
uniform float tissue_strength = 1.0;
uniform vec4 protected_rects[8];
uniform int protected_count = 0;

float cycle_angle() { return elapsed * TAU / 24.0; }

float cloud_field(vec2 p, float phase) {
 float angle = cycle_angle();
 vec2 drift = vec2(sin(angle + phase), cos(angle + phase)) * 0.04;
 vec2 warp = vec2(texture(pigment_noise, p * 0.0009 + drift + phase).r,
                  texture(pigment_noise, p * 0.0009 - drift + phase + 0.37).r) - 0.5;
 float broad = texture(pigment_noise, p * 0.0011 + warp * 0.06 + drift).r;
 float detail = texture(pigment_noise, p * vec2(0.0028, 0.0037) - drift * 0.7 + phase).r;
 return broad * 0.78 + detail * 0.22;
}

float edge_distance(vec2 p) {
 return min(min(p.x, 1280.0-p.x), min(p.y, 720.0-p.y));
}

float quiet_box(vec2 p, vec2 lower, vec2 upper) {
 vec2 outside = max(lower-p, p-upper);
 return 1.0-smoothstep(0.0, 22.0, max(outside.x, outside.y));
}

float reading_mask(vec2 p) {
 float quiet = 0.0;
 for (int i = 0; i < 8; i++) {
  if (i >= protected_count) { break; }
  vec4 rect = protected_rects[i];
  quiet = max(quiet, quiet_box(p, rect.xy, rect.zw));
 }
 return 1.0-quiet*0.92;
}

vec4 paint_over(vec4 base, vec4 paint) {
 float alpha = paint.a + base.a*(1.0-paint.a);
 return vec4((paint.rgb*paint.a + base.rgb*base.a*(1.0-paint.a))/max(alpha,0.001),alpha);
}

// q is a coordinate on the carrier surface, never an independently moving sprite.
vec4 tissue_eye(vec2 q, float seed, float opening) {
 float r = length(q);
 if (r > 1.5) { return vec4(0.0); }
 float theta = atan(q.y,q.x);
 float pigment = texture(pigment_noise,q*0.24+seed).r;
 float contour = 1.0+sin(theta*3.0+seed)*0.10+sin(theta*5.0-seed)*0.05;
 float shell = 1.0-smoothstep(contour*0.77,contour*1.20,r);
 float iris = smoothstep(0.20,0.45,r)*(1.0-smoothstep(0.74,1.10,r));
 float fibres = 0.5+0.5*sin(theta*31.0+r*11.0+pigment*8.0);
 vec2 pupil_q = q-vec2(0.10,0.07);
 float split_core = (0.25+0.09*cos(atan(pupil_q.y,pupil_q.x)*3.0+seed))*opening;
 float pupil = 1.0-smoothstep(split_core-0.025,split_core+0.045,length(pupil_q));
 float secondary = 1.0-smoothstep(0.05,0.12,length(q-vec2(-0.35,0.22)));
 vec3 tissue = mix(vec3(0.052,0.083,0.075),vec3(0.34,0.39,0.25),iris*(0.26+pigment*0.42+fibres*0.15));
 tissue = mix(tissue,vec3(0.007,0.016,0.015),max(pupil,secondary));
 return vec4(tissue,shell*0.90);
}

vec4 foreground_mist(vec2 p) {
 float edge = edge_distance(p);
 if (edge > 145.0) { return vec4(0.0); }
 float density = cloud_field(p+vec2(81.0,19.0),2.4);
 float covering = smoothstep(0.34,0.69,density);
 float spread = 1.0-smoothstep(28.0,132.0,edge);
 vec3 tint = mix(vec3(0.025,0.043,0.046),vec3(0.14,0.20,0.18),density*0.65);
 return vec4(tint,covering*spread*0.64*reading_mask(p));
}
