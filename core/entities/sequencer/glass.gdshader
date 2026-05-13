shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear;

uniform bool is_object_centered = true;
uniform float magnification : hint_range(1.0, 4.0) = 1.15;
uniform float glass_mix : hint_range(0.0, 1.0) = 0.45;
uniform float edge_distortion : hint_range(0.0, 0.05) = 0.015;
uniform float edge_falloff : hint_range(0.0, 0.5) = 0.2;

varying flat vec2 center_pos;

void vertex() {
	if (is_object_centered) {
		center_pos = vec2(0.0, 0.0);
	} else {
		center_pos = (1.0 / TEXTURE_PIXEL_SIZE) / 2.0;
	}
	center_pos = (MODEL_MATRIX * vec4(center_pos, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 screen_resolution = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 uv_distance = vec2(0.5) - UV;
	vec2 pixel_distance;
	pixel_distance.x = center_pos.x - FRAGCOORD.x;
	pixel_distance.y = center_pos.y - (screen_resolution.y - FRAGCOORD.y);
	vec2 obj_size = pixel_distance / uv_distance;
	vec2 ratio = obj_size / screen_resolution;

	float magnify_value = (magnification - 1.0) / magnification;

	vec2 local_mapped_uv = mix(UV, vec2(0.5), magnify_value);
	vec2 difference = local_mapped_uv - UV;

	vec2 global_mapped_uv;
	global_mapped_uv.x = SCREEN_UV.x + difference.x * ratio.x;
	global_mapped_uv.y = SCREEN_UV.y - difference.y * ratio.y;

	// Liquid glass edge distortion — strongest at edges, fades toward center
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
}
