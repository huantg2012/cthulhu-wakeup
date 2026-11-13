shader_type canvas_item;
render_mode unshaded;
uniform int palette = 0;
uniform vec2 image_extent = vec2(240.0);
void fragment() {
 vec4 pigment=texture(TEXTURE,UV);
 float edge=min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
 float feather=palette==0 ? .04 : 1.0/max(1.0,min(image_extent.x,image_extent.y));
 COLOR=vec4(pigment.rgb,pigment.a*smoothstep(0.0,feather,edge));
}
