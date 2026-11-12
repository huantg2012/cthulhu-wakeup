shader_type canvas_item;
render_mode unshaded;
#include "res://docs/art/visual-generation/ui-study/peripheral_fields.gdshaderinc"
void fragment() {
 COLOR = foreground_mist(UV*vec2(1280.0,720.0));
}
