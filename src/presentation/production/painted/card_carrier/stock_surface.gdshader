shader_type canvas_item;
render_mode unshaded;

// One continuous print substrate. The original illustration never uses this
// material: only the paper is coloured here.
uniform vec4 reading_colour : source_color = vec4(0.63, 0.51, 0.36, 1.0);
uniform vec4 ink_colour : source_color = vec4(0.15, 0.12, 0.13, 1.0);
uniform vec4 edge_colour : source_color = vec4(0.62, 0.48, 0.32, 1.0);

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise21(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
    vec4 paper = texture(TEXTURE, UV);
    float fibre = dot(paper.rgb, vec3(0.299, 0.587, 0.114));
    float cloud = noise21(UV * vec2(5.0, 7.0));
    float grain = noise21(UV * vec2(170.0, 240.0));
    float onset = 0.52 + (cloud - 0.5) * 0.11
        + 0.035 * sin(UV.x * 7.0 + 1.4);
    float reading = smoothstep(onset, onset + 0.22, UV.y);
    vec3 pigment = mix(ink_colour.rgb, reading_colour.rgb, reading);
    // An absorbed impression remains at the foot and outer edge, leaving
    // the centre-left reading space lighter. It is not a separate panel.
    float foot = smoothstep(0.83, 1.02, UV.y + 0.06 * cloud);
    float side = 1.0 - smoothstep(0.012, 0.095, min(UV.x, 1.0 - UV.x));
    pigment = mix(pigment, ink_colour.rgb, foot * (0.16 + UV.x * 0.15));
    pigment = mix(pigment, ink_colour.rgb, side * 0.48);
    float rim = 1.0 - smoothstep(0.010, 0.026, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
    pigment = mix(pigment, edge_colour.rgb, rim * (0.28 + cloud * 0.24));
    float sweep = smoothstep(0.30, 0.92, UV.x) * smoothstep(0.75, 1.07, UV.y + cloud * 0.07);
    pigment = mix(pigment, ink_colour.rgb, sweep * 0.16);
    pigment *= 1.0 + (fibre - 0.82) * 0.75 + (cloud - 0.5) * 0.12;
    pigment += vec3((grain - 0.5) * 0.026);
    COLOR = vec4(pigment, paper.a);
}
