shader_type canvas_item;

// Slow breathe between pulse_min and pulse_max brightness.
uniform float pulse_speed : hint_range(0.2, 5.0) = 1.4;
uniform float pulse_min : hint_range(0.0, 1.0) = 1.2;
uniform float pulse_max : hint_range(1.0, 3.0) = 3.0;

// Fast per-pixel shimmer layered on top of the pulse.
uniform float shimmer_speed : hint_range(0.0, 20.0) = 12.0;
uniform float shimmer_strength : hint_range(0.0, 0.5) = 0.32;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = mix(pulse_min, pulse_max, sin(TIME * pulse_speed) * 0.5 + 0.5);
	float shimmer = sin(TIME * shimmer_speed + UV.x * 17.3 + UV.y * 13.7) * shimmer_strength;
	COLOR = tex * COLOR * max(pulse + shimmer, 0.0);
}
