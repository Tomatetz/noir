shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 p = UV - vec2(0.5);
	vec2 tile = abs(fract(UV * vec2(7.0, 8.0)) - 0.5);
	float seam = smoothstep(0.48, 0.50, max(tile.x, tile.y));
	float grit = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	float lamp = exp(-dot(p * vec2(2.1, 1.55), p * vec2(2.1, 1.55)) * 3.0);
	vec3 concrete = mix(vec3(0.063, 0.071, 0.074), vec3(0.24, 0.213, 0.173), lamp);
	COLOR = vec4(concrete * (0.85 + grit * 0.30) * (1.0 - seam * 0.27), 1.0);
}
