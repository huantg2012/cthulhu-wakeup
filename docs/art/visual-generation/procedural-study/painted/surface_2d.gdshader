shader_type canvas_item;
// Painted pigment + continuous 2D cloth/terrain slope fields, not a 3D model.
// All shape and material organisation precedes this shader. No global stone overlay.
uniform sampler2D normal_tex : filter_linear, repeat_disable;
uniform float seed_offset;
uniform int archetype;
uniform vec3 palette_c1 : source_color;
uniform vec3 palette_c3 : source_color;
uniform vec3 palette_c4 : source_color;
#include "res://shaders/common.gdshaderinc"
void fragment() {
    vec4 src = texture(TEXTURE, UV);
    vec4 field = texture(normal_tex, UV);
    vec2 n = field.rg * 2.0 - 1.0;
    vec3 N = normalize(vec3(n, sqrt(max(.04,1.0-dot(n,n)))));
    float mat = field.b;
    float wet = step(.62, mat) * (1.0-step(.78,mat));
    float metal = step(.78,mat)*(1.0-step(.94,mat));
    vec3 col = style_shade(src.rgb, N, normalize(g_light_dir), vec3(0,0,1), g_light_col, .045+wet*.55+metal*.7, 38.0);
    // Very restrained cool fill preserves the source's lit/unlit relation.
    col += src.rgb * .07 + rim_term(N,vec3(0,0,1))*.18;
    if (mat > .94) { col = src.rgb*1.65; }
    if (mat < .025) { col = src.rgb; }
    COLOR = vec4(col,src.a);
}
