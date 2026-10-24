shader_type sky;

void sky() {
	float elevation = max(EYEDIR.y, 0.0);
	vec3 horizon = vec3(0.065, 0.052, 0.055);
	vec3 zenith = vec3(0.025, 0.023, 0.03);
	float clouds = sin(EYEDIR.x * 16.0 + EYEDIR.z * 11.0) * sin(EYEDIR.z * 24.0 - EYEDIR.y * 17.0);
	vec3 color = mix(horizon, zenith, smoothstep(0.1, 0.8, elevation));
	color += clouds * 0.009 * smoothstep(0.15, 0.45, elevation);
	// Below the horizon is the same haze used by the floor and panel bases.
	COLOR = mix(color, vec3(0.161, 0.105, 0.098), smoothstep(0.0, 0.18, -EYEDIR.y));
}
