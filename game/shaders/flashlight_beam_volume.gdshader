shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Crossed, camera-independent sheets form a depth-tested 3D flashlight shaft.
// Alpha tint keeps the shaft readable over both the warm rooftop sky and
// the ground-floor blackout. Opaque world geometry still occludes each sheet.
uniform float beam_range = 30.0;
uniform float beam_tangent = 0.46630766;
uniform vec3 beam_color : source_color = vec3(0.61, 0.80, 1.0);
uniform float beam_opacity = 0.10;
uniform float core_opacity = 0.08;

varying float axial_distance;
varying float across_fraction;

void vertex() {
	// QuadMesh starts as a 2 x beam_range rectangle in XY. Widen each
	// cross-section with distance from the cone tip to create a 3D wedge.
	float distance_from_tip = beam_range * 0.5 - VERTEX.y;
	float radius = max(0.32, distance_from_tip * beam_tangent);
	VERTEX.x *= radius;
	axial_distance = distance_from_tip;
	across_fraction = abs(VERTEX.x) / radius;
}

void fragment() {
	float start_fade = smoothstep(0.2, 2.4, axial_distance);
	float end_fade = 1.0 - smoothstep(beam_range * 0.78, beam_range, axial_distance);
	float side_fade = 1.0 - smoothstep(0.58, 1.0, across_fraction);
	float core_fade = 1.0 - smoothstep(0.0, 0.42, across_fraction);
	float shaft = (beam_opacity * side_fade + core_opacity * core_fade)
		* start_fade * end_fade;
	ALBEDO = beam_color;
	ALPHA = clamp(shaft, 0.0, 0.85);
}
