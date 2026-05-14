shader_type canvas_item;

uniform float outline_width : hint_range(0.5, 8.0) = 1.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.95, 0.9, 1.0);

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;

	// Maximum alpha from 8 neighbours. stays in 0..1 range
	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2( ps.x,  0.0 )).a);
	n = max(n, texture(TEXTURE, UV + vec2(-ps.x,  0.0 )).a);
	n = max(n, texture(TEXTURE, UV + vec2( 0.0,   ps.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2( 0.0,  -ps.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2( ps.x,  ps.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-ps.x,  ps.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2( ps.x, -ps.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a);

	// Outline alpha: strong near the sprite edge, zero inside or far outside.
	// (1 - color.a) ensures the outline fades where the sprite itself is opaque.
	float outline_alpha = n * (1.0 - color.a);

	vec4 outline = vec4(outline_color.rgb, outline_color.a * outline_alpha);
	COLOR = mix(outline, color, color.a);
}
