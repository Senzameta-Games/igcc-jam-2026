shader_type canvas_item;

// Width of the glow in texture-space pixels. Scale up if sprite scale < 1.
uniform float outline_width: hint_range(0.0, 30.0) = 8.0;
// Color of the animated outline/glow.
uniform vec4 outline_color: source_color = vec4(0.8, 0.8, 0.78, 1.0);
// Wave distortion amplitude in texture-space pixels.
uniform float wave_amplitude: hint_range(0.0, 12.0) = 2.0;
// Number of sine-wave cycles around the full circumference.
uniform float wave_frequency: hint_range(1.0, 20.0) = 6.0;
// How fast the wave travels around the outline.
uniform float wave_speed: hint_range(0.0, 12.0) = 2.0;
// Controls how sharply the glow fades toward its outer edge. Higher = tighter.
uniform float glow_falloff: hint_range(0.3, 6.0) = 0.6;
// How fast the orb pulses in brightness while hovered.
uniform float pulse_speed: hint_range(0.0, 20.0) = 4.0;
// How much the brightness swings each pulse (±fraction).
uniform float pulse_amount: hint_range(0.0, 0.5) = 0.08;
// How fast dust motes rise. Actual speed varies per mote.
uniform float dust_rise_speed: hint_range(0.0, 2.0) = 0.3;
// Radius of each dust mote in UV space. Tune alongside sprite scale.
uniform float dust_size: hint_range(0.0, 0.15) = 0.1;
// How rough/broken the outline edge looks. 0 = smooth, 1 = full brush stroke.
uniform float brush_roughness: hint_range(0.0, 1.0) = 0.65;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

// Smoothly interpolated 1-D value noise.
float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), u);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a > 0.01) {
		// Inside the sprite — pass through with a subtle brightness pulse.
		float pulse = 1.0 + pulse_amount * sin(TIME * pulse_speed);
		COLOR = vec4(tex.rgb * pulse, tex.a);
	} else {
		// Outside the sprite — sample outward in a ring to detect the boundary.
		// The ring radius oscillates as a sine wave to produce the wavy outline.
		const int STEPS = 24;
		float max_hit = 0.0;
		for (int i = 0; i < STEPS; i++) {
			float angle = float(i) * (TAU / float(STEPS));
			float wave = wave_amplitude * sin(angle * wave_frequency + TIME * wave_speed);
			// Layered value noise roughens the edge like a brush stroke.
			float rough = vnoise(angle * 7.0  + TIME * 1.4) * 0.65
			            + vnoise(angle * 17.0 + TIME * 2.5) * 0.35;
			float noise_px = brush_roughness * outline_width * (rough - 0.5) * 2.0;
			float dist_px = max(outline_width + wave + noise_px, 0.5);
			vec2 offset = vec2(cos(angle), sin(angle)) * dist_px * TEXTURE_PIXEL_SIZE;
			max_hit = max(max_hit, texture(TEXTURE, UV + offset).a);
		}

		vec4 result = vec4(0.0);
		if (max_hit > 0.01) {
			// Angular opacity variation — simulates bristles pressing unevenly.
			float px_angle = atan(UV.y - 0.5, UV.x - 0.5) / TAU + 0.5;
			float bristle  = vnoise(px_angle * 14.0 + TIME * 0.6);
			float opacity  = mix(1.0, 0.15 + 0.85 * bristle, brush_roughness);
			float glow = pow(max_hit, glow_falloff) * opacity;
			result = vec4(outline_color.rgb, glow * outline_color.a);
		}

		// Magic dust: motes that sample the orb's own colors and rise upward.
		const int DUST_COUNT = 7;
		for (int p = 0; p < DUST_COUNT; p++) {
			float seed = float(p) * 53.71;

			// Fixed spawn UV in the upper half of the orb body.
			float sx = 0.5 + (hash(seed) - 0.5) * 0.5;
			float sy = 0.2 + hash(seed + 1.0) * 0.35;

			vec3 dust_rgb   = vec3(1.0);
			float dust_base = 0.2 + hash(seed + 6.0) * 0.5; // random alpha [0.2, 0.7]

			float speed = dust_rise_speed * (0.6 + hash(seed + 2.0) * 0.8);
			float phase = hash(seed + 3.0);
			float drift = (hash(seed + 4.0) - 0.5) * 0.08;
			float sz    = dust_size * (0.5 + hash(seed + 5.0));

			// t in [0,1] drives one full rise cycle.
			float t     = fract(phase + TIME * speed);
			vec2 ppos   = vec2(sx + drift * t, sy - t * 0.55);

			float d     = length(UV - ppos);
			float shape = 1.0 - smoothstep(0.0, sz, d);
			// Fade in quickly at birth, fade out gently toward death.
			float life  = smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.55, 1.0, t));
			float a     = shape * shape * life * dust_base;

			// Porter-Duff over: composite each mote onto the running result.
			result.rgb = a * dust_rgb + (1.0 - a) * result.rgb;
			result.a   = a + (1.0 - a) * result.a;
		}

		if (result.a > 0.001) {
			COLOR = result;
		} else {
			discard;
		}
	}
}
