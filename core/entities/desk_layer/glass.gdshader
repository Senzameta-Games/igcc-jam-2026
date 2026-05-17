shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear;

uniform float magnification : hint_range(1.0, 4.0) = 1.15;
uniform float glass_mix : hint_range(0.0, 1.0) = 0.45;
uniform float edge_distortion : hint_range(0.0, 0.05) = 0.015;
uniform float edge_falloff : hint_range(0.0, 0.5) = 0.2;
uniform float brightness : hint_range(1.0, 3.0) = 1.0;

// Sprite center in viewport pixels, stable regardless of scene-tree position.
varying flat vec2 center_viewport_pos;

void vertex() {
	// Derive the texture center in local space from the current vertex.
	// VERTEX - (UV - 0.5) / TEXTURE_PIXEL_SIZE cancels to the sprite's offset
	// for every vertex, so the result is position-invariant across the quad.
	vec2 center_local = VERTEX - (UV - vec2(0.5)) / TEXTURE_PIXEL_SIZE;

	// CANVAS_MATRIX transforms world → viewport pixels, including the camera.
	// This keeps center_viewport_pos anchored to the glass regardless of where
	// the DeskLayer has slid on screen.
	center_viewport_pos = (CANVAS_MATRIX * MODEL_MATRIX * vec4(center_local, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;

	// Convert both the center and the current fragment to the same screen UV space.
	vec2 center_uv = center_viewport_pos / viewport_size;
	vec2 from_center = SCREEN_UV - center_uv;

	// Magnification: pull the sample toward the center by 1/magnification.
	float magnify_value = (magnification - 1.0) / magnification;
	vec2 global_mapped_uv = SCREEN_UV - from_center * magnify_value;

	// Edge distortion — strongest at the rim, fades toward the center.
	float edge_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float distort_factor = 1.0 - smoothstep(0.0, edge_falloff, edge_dist);
	global_mapped_uv += vec2(
		sin(UV.y * PI * 3.0),
		sin(UV.x * PI * 3.0)
	) * edge_distortion * distort_factor;

	vec4 screen_color = texture(SCREEN_TEXTURE, global_mapped_uv);
	vec4 glass_color = texture(TEXTURE, UV);

	COLOR = screen_color;
	COLOR.rgb = mix(COLOR.rgb, glass_color.rgb, glass_mix * glass_color.a);
	COLOR.rgb *= brightness;
}
