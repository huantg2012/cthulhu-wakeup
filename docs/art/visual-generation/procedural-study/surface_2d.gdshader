shader_type canvas_item;
// Shape-specific 2D albedo and relief normals. The original common include is
// used unchanged: gnoise3/fbm3/voronoi3 and style_shade use the world light.
// This is not the planet's sphere geometry or an identical planet material.
uniform sampler2D normal_tex : filter_linear, repeat_disable;
uniform float seed_offset = 0.0;
uniform int archetype = 0;
uniform vec3 palette_c1 : source_color;
uniform vec3 palette_c3 : source_color;
uniform vec3 palette_c4 : source_color;
#include "res://shaders/common.gdshaderinc"

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec4 encoded = texture(normal_tex, UV);
    if (encoded.a < 0.08) { COLOR = base; }
    else {
        vec2 xy = encoded.rg * 2.0 - 1.0;
        vec3 N = normalize(vec3(xy, sqrt(max(0.06, 1.0 - dot(xy, xy)))));
        float kind = encoded.b;
        vec3 q = vec3(UV * 7.0, seed_offset);
        float h = fbm3(q * 1.8, 4) + 0.12 * ridged3(q * 3.0, 3);
        float feature = 0.0;
        if (archetype == 1) { feature = pow(1.0-abs(gnoise3(q*4.0)), 6.0); }
        if (archetype == 2) { feature = pow(1.0-abs(gnoise3(q*3.0)), 14.0); }
        if (archetype == 3) { h = ridged3(q*1.7, 4)-0.45+0.3*fbm3(q*.8, 3); }
        if (archetype == 5) { h = mix(h, floor(h*7.0)/7.0, .7); }
        if (archetype == 7) { h += sin(dot(q,vec3(14.0,3.0,9.0))+fbm3(q*3.0,3)*6.0)*.08; }
        if (archetype == 8) { vec3 warp = vec3(fbm3(q,3),fbm3(q+vec3(5.2),3),fbm3(q+vec3(9.2),3)); h = fbm3(q+3.0*warp,4); }
        if (archetype == 9) { h += sin(q.y*18.0+fbm3(q*3.0,3)*8.0)*.1; }
        vec4 cells = voronoi3(q * 1.35);
        float seam = smoothstep(0.0, 0.06, cells.y - cells.x);
        if (archetype == 3) { feature = (1.0-smoothstep(.05,.32,cells.x))*step(.35,cells.z); }
        if (archetype == 4 || archetype == 6 || archetype == 9) { feature = 1.0-seam; }
        if (archetype == 10) { float d = cells.x/(.25+.4*cells.z); h += (d<1.0 ? (d*d-1.0)*.35 : 0.0) + exp(-pow((d-1.0)/.18,2.0))*.14; }
        float rock = smoothstep(0.18, 0.28, kind) * (1.0 - smoothstep(0.48, 0.58, kind));
        float cloth = 1.0 - smoothstep(0.17, 0.27, kind);
        float metallic = smoothstep(0.72, 0.82, kind);
        float texture_height = h * (0.13 + rock * 0.14 + cloth * 0.035) + rock * cells.z * 0.025;
        vec3 bump = vec3(-dFdx(texture_height), dFdy(texture_height), 0.0);
        N = normalize(N + bump * 5.0);
        vec3 alb = base.rgb;
        vec3 stone = mix(alb * 0.8, palette_c3, clamp(cells.z * 0.6 + h * 0.8, 0.0, 1.0));
        float patches = smoothstep(0.1, 0.3, fbm3(q * 4.0 + vec3(5.0), 3));
        stone = mix(stone, mix(palette_c1, palette_c4 * 0.35, 0.4), patches * 0.7);
        stone *= mix(0.35, 1.0, seam);
        alb = mix(alb, stone, rock * 0.52);
        float fibres = fbm3(vec3(UV.x * 4.0, UV.y * 19.0, seed_offset), 3);
        alb *= 0.90 + clamp(h + 0.5, 0.0, 1.0) * 0.20 + fibres * cloth * 0.08;
        vec3 L = normalize(g_light_dir);
        vec3 V = vec3(0.0, 0.0, 1.0);
        vec3 lit = style_shade(alb, N, L, V, g_light_col, mix(0.12, 0.65, metallic), 28.0);
        lit += rim_term(N, V) * 0.65;
        if (archetype == 2 || archetype == 3 || archetype == 4 || archetype == 6 || archetype == 9) {
            lit += palette_c4 * feature * rock * .20;
        }
        COLOR = vec4(mix(base.rgb, lit, smoothstep(0.08, 0.45, encoded.a)), base.a);
    }
}
