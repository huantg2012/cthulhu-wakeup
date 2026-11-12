shader_type canvas_item;
render_mode unshaded;
#include "res://src/presentation/production/painted/peripheral_fields.gdshaderinc"
void fragment() {
 vec4 fog = foreground_mist(UV*vec2(1280.0,720.0));
 COLOR = vec4(fog.rgb, fog.a * wash_strength);
}
