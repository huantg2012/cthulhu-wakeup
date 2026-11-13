shader_type canvas_item;
render_mode unshaded;

// The cut of the same card, behind its printed face. All distances are local
// pixels, so a larger card gains only a little thickness, never a broad frame.
uniform vec2 face_size = vec2(148.0, 198.0);
uniform float padding = 4.0;
uniform float thickness = 1.8;
uniform vec4 core_colour : source_color = vec4(0.48, 0.40, 0.28, 1.0);

float silhouette(sampler2D source, vec2 pixel) {
    vec2 at = pixel / face_size;
    float inside = step(0.0, at.x) * step(0.0, at.y)
        * step(at.x, 1.0) * step(at.y, 1.0);
    return texture(source, clamp(at, vec2(0.0), vec2(1.0))).a * inside;
}

void fragment() {
    vec2 pixel = UV * (face_size + vec2(padding * 2.0)) - vec2(padding);
    vec2 cut = vec2(0.35, 1.0) * thickness;
    float face = silhouette(TEXTURE, pixel);
    float near_cut = silhouette(TEXTURE, pixel - cut * 0.32);
    float middle_cut = silhouette(TEXTURE, pixel - cut * 0.66);
    float far_cut = silhouette(TEXTURE, pixel - cut);
    float body = max(max(face, near_cut), max(middle_cut, far_cut));
    // The opaque face covers the body. Only its narrow lower/right cut shows.
    // A quiet compressed-fibre seam keeps it matte instead of a shiny bevel.
    float heel = max(0.0, far_cut - middle_cut);
    float lip = max(0.0, near_cut - face);
    float fibre = sin(pixel.y * 4.2 + sin(pixel.x * 0.61)) * 0.025;
    vec3 pigment = core_colour.rgb * (1.0 + fibre - heel * 0.27 + lip * 0.12);
    COLOR = vec4(pigment, body * core_colour.a);
}
