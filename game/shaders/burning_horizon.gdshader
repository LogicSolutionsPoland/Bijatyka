shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never;

// First detail boundary: translucent so enemies beyond 20 m remain readable.
// One shared material; no textures, lights or particle systems.
float hash(float p) { return fract(sin(p * 127.1) * 43758.5453); }

void fragment() {
	float x = UV.x;
	float y = 1.0 - UV.y;
	vec3 haze = vec3(0.161, 0.105, 0.098);
	vec3 sky = vec3(0.065, 0.052, 0.055);
	float edge = smoothstep(0.0, 0.06, x) * smoothstep(0.0, 0.06, 1.0 - x);
	float cell = floor(x * 29.0);
	float height = 0.24 + hash(cell) * 0.43;
	float building = (1.0 - step(height, y)) * step(0.08, fract(x * 29.0));
	float ruin = step(0.16, hash(cell + floor(y * 22.0) * 37.0));
	building *= ruin;
	float flame_wave = sin(x * 210.0 + TIME * 2.0) * 0.025 + sin(x * 383.0 - TIME * 3.0) * 0.018;
	float fire_height = 0.18 + hash(floor(x * 64.0)) * 0.20 + flame_wave;
	float flame = (1.0 - smoothstep(fire_height - 0.08, fire_height, y)) * smoothstep(0.06, 0.16, y);
	float smoke = sin(x * 47.0 + y * 12.0 + sin(y * 17.0 - TIME * 0.18)) * 0.5 + 0.5;
	vec3 color = mix(haze, sky, smoothstep(0.45, 1.0, y));
	color += vec3(0.24, 0.045, 0.006) * smoke * (1.0 - smoothstep(0.4, 0.85, y)) * edge;
	color = mix(color, vec3(0.035, 0.028, 0.03), building * edge);
	float windows = step(0.65, fract(x * 145.0)) * step(0.72, fract(y * 25.0)) * building;
	color += vec3(0.65, 0.12, 0.008) * windows * edge;
	color = mix(color, vec3(1.0, 0.22 + flame_wave, 0.015), flame * edge * 0.8);
	// Fade the panel borders into the existing world haze.
	color = mix(haze, color, smoothstep(0.0, 0.18, y));
	color = mix(color, sky, smoothstep(0.8, 1.0, y));
	ALBEDO = color;
	float vertical_fade = smoothstep(0.0, 0.12, y) * (1.0 - smoothstep(0.65, 1.0, y));
	ALPHA = clamp(0.16 + building * 0.22 + flame * 0.20 + smoke * 0.06, 0.0, 0.60) * edge * vertical_fade;
}
