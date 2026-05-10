shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.15;
uniform float dither_scale : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform float luma_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float smoke_strength : hint_range(0.0, 1.0) = 0.5;
uniform float smoke_speed : hint_range(0.0, 2.0) = 0.3;
uniform float smoke_scale : hint_range(1.0, 10.0) = 4.0;
uniform float smoke_height : hint_range(0.0, 0.5) = 0.12;
uniform float turbulence_strength : hint_range(0.0, 2.0) = 0.6;
uniform float turbulence_speed : hint_range(0.0, 4.0) = 1.2;
uniform float turbulence_scale : hint_range(1.0, 20.0) = 6.0;
uniform float blur_radius : hint_range(0.0, 0.02) = 0.006;
uniform vec4 smoke_color : source_color = vec4(0.75, 0.9, 1.0, 1.0);

float bayer4x4(vec2 pos) {
	int x = int(mod(pos.x, 4.0));
	int y = int(mod(pos.y, 4.0));
	int index = x + y * 4;
	float matrix[16] = float[](
		 0.0,  8.0,  2.0, 10.0,
		12.0,  4.0, 14.0,  6.0,
		 3.0, 11.0,  1.0,  9.0,
		15.0,  7.0, 13.0,  5.0
	);
	return matrix[index] / 16.0;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
	float b = dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.1;
		amplitude *= 0.5;
	}
	return value;
}

float fbm_turb(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += amplitude * noise(p);
		p *= 3.0;
		amplitude *= 0.45;
	}
	return value;
}

float compute_smoke(vec2 uv, float t, float t_turb) {
	// Source accumulation
	float source = 0.0;
	float nearest_source_y = 0.0;
	int steps = 16;
	for (int i = 0; i < steps; i++) {
    float frac = float(i) / float(steps);
    // Wave the column sideways as it rises — breaks the straight edge
    float wave = sin(frac * TAU * 2.0 + TIME * 2.0) * 0.02 * frac;
    vec2 s_uv = uv + vec2(wave, frac * smoke_height);
    float s_luma = luma(texture(screen_texture, s_uv).rgb);
    float contribution = smoothstep(luma_threshold, luma_threshold + 0.1, s_luma);
    contribution *= (1.0 - frac);
    if (contribution > source) {
        source = contribution;
        nearest_source_y = frac;
    }
}

	float rise_t = clamp(nearest_source_y, 0.0, 1.0);

	// Slow warp
	vec2 warp_uv = uv * smoke_scale * 0.6 + vec2(t * 0.15, t * 0.08);
	vec2 warp = vec2(fbm(warp_uv), fbm(warp_uv + vec2(3.7, 1.4)));

	// Turbulence
	vec2 turb_uv = uv * turbulence_scale + vec2(t_turb * 0.3, -t_turb * 0.2);
	vec2 turb_uv2 = uv * turbulence_scale + vec2(5.2, 1.3) - vec2(t_turb * 0.25, t_turb * 0.15);
	vec2 turbulence = vec2(
		fbm_turb(turb_uv) - 0.5,
		fbm_turb(turb_uv2) - 0.5
	);

	float turb_weight = mix(0.1, 1.0, rise_t) * turbulence_strength;

	vec2 smoke_uv = uv * smoke_scale
		+ warp * mix(0.3, 1.2, rise_t)
		+ turbulence * turb_weight;
	smoke_uv.y -= t;

	float shape = fbm(smoke_uv);
	float thresh = mix(0.48, 0.62, rise_t);
	float wisps = smoothstep(thresh + 0.12, thresh, shape);
	float fade = pow(1.0 - rise_t, 1.8);

	return wisps * fade * source;
}

void fragment() {
	float t = TIME * smoke_speed;
	float t_turb = TIME * turbulence_speed;
	vec4 color = texture(screen_texture, SCREEN_UV);

	// Blur the smoke by averaging samples in a cross pattern around this pixel
	float r = blur_radius;
	float s = compute_smoke(SCREEN_UV, t, t_turb);
	s += compute_smoke(SCREEN_UV + vec2( r,  0.0), t, t_turb);
	s += compute_smoke(SCREEN_UV + vec2(-r,  0.0), t, t_turb);
	s += compute_smoke(SCREEN_UV + vec2( 0.0,  r), t, t_turb);
	s += compute_smoke(SCREEN_UV + vec2( 0.0, -r), t, t_turb);
	s += compute_smoke(SCREEN_UV + vec2( r,  r), t, t_turb);
	s += compute_smoke(SCREEN_UV + vec2(-r,  r), t, t_turb);
	s += compute_smoke(SCREEN_UV + vec2( r, -r), t, t_turb);
	s += compute_smoke(SCREEN_UV + vec2(-r, -r), t, t_turb);
	s /= 9.0;

	float smoke = clamp(s * smoke_strength, 0.0, 1.0);
	color.rgb = mix(color.rgb, smoke_color.rgb, smoke);

	// Dither
	vec2 screen_pos = floor(FRAGCOORD.xy / dither_scale);
	float dither_threshold = bayer4x4(screen_pos);
	float dark_weight = pow(1.0 - luma(color.rgb), 2.0);
	color.rgb += (dither_threshold - 0.5) * dither_strength * dark_weight;

	// Vignette
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float vignette = 1.0 - dot(centered, centered) * vignette_strength;
	color.rgb *= vignette;

	COLOR = color;
}