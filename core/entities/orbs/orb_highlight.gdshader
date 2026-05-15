shader_type canvas_item;

uniform float pulse_speed : hint_range(0.1, 5.0) = 1.2;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float t = sin(TIME * pulse_speed) * 0.5 + 0.5;
	COLOR = vec4(col.rgb + col.a * t * pulse_strength, col.a);
}
