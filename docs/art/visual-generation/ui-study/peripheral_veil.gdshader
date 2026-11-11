shader_type canvas_item;
render_mode unshaded;

uniform sampler2D pigment_noise : repeat_enable, filter_linear;
uniform float elapsed = 0.0;

// Each side has its own tide. Movement displaces pigment fields, not the game image.
vec4 edge_paint(vec2 point, float phase) {
 if (point.y > 115.0) {
  return vec4(0.0);
 }
 float time = elapsed * 0.22;
 float along = point.x;
 float depth = point.y;
 vec2 flow = vec2(along * 0.0018 + sin(time * 0.31 + phase) * 0.025,
                  depth * 0.006 + time * 0.018 + phase);
 float broad = texture(pigment_noise, flow).r;
 float folds = texture(pigment_noise, flow * vec2(2.7, 1.3) + vec2(time * 0.012, 0.0)).r;
 float breath = sin(along * 0.009 + time + phase) * 5.0
              + sin(along * 0.021 - time * 0.73 + phase) * 3.0;
 float boundary = 13.0 + broad * 30.0 + breath;
 float distance_to_fold = depth - boundary;
 float body = 1.0 - smoothstep(-9.0, 11.0, distance_to_fold);
 float mist = exp(-pow((distance_to_fold - 9.0) / 25.0, 2.0));
 float ridge = exp(-pow((distance_to_fold + 3.0 + folds * 9.0) / 7.0, 2.0));
 float brush = texture(pigment_noise, vec2(along * 0.012, depth * 0.042)).g;
 float breaks = smoothstep(0.26, 0.73, folds);
 vec3 dark = vec3(0.016, 0.030, 0.033);
 vec3 color = mix(dark, vec3(0.16, 0.23, 0.20), ridge * breaks * 0.52);
 color += (brush - 0.5) * 0.016 * (body + ridge);
 float alpha = body * 0.76 + mist * (0.10 + breaks * 0.13);
 return vec4(color, clamp(alpha, 0.0, 0.90));
}

float quiet_box(vec2 p, vec2 lower, vec2 upper) {
 vec2 outside = max(lower - p, p - upper);
 return 1.0 - smoothstep(0.0, 20.0, max(outside.x, outside.y));
}

void fragment() {
 vec2 p = UV * vec2(1280.0, 720.0);
 vec4 top = edge_paint(vec2(p.x, p.y), 0.4);
 vec4 bottom = edge_paint(vec2(1280.0-p.x, 720.0-p.y), 2.8);
 vec4 left = edge_paint(vec2(p.y, p.x), 5.9);
 vec4 right = edge_paint(vec2(720.0-p.y, 1280.0-p.x), 9.2);
 float sum = top.a + bottom.a + left.a + right.a;
 vec3 ink = (top.rgb*top.a + bottom.rgb*bottom.a + left.rgb*left.a + right.rgb*right.a) / max(sum, 0.001);
 float opacity = 1.0 - (1.0-top.a)*(1.0-bottom.a)*(1.0-left.a)*(1.0-right.a);
 float quiet = max(quiet_box(p, vec2(30.0, 25.0), vec2(320.0, 112.0)),
                   quiet_box(p, vec2(1020.0, 24.0), vec2(1250.0, 110.0)));
 quiet = max(quiet, quiet_box(p, vec2(30.0, 638.0), vec2(425.0, 687.0)));
 quiet = max(quiet, quiet_box(p, vec2(1050.0, 638.0), vec2(1250.0, 687.0)));
 COLOR = vec4(ink, opacity * (1.0-quiet*0.9));
}
