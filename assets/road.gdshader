shader_type canvas_item;

varying vec2 road_pos;
uniform vec2 road_origin;
uniform vec2 road_forward = vec2(1.0, 0.0);

void vertex() {
	road_pos = VERTEX;
}

void fragment() {
	vec2 relative = road_pos - road_origin;
	float along = dot(relative, road_forward);
	float across = dot(relative, vec2(-road_forward.y, road_forward.x)) / 42.0;
	float edge = abs(across);
	float grit = fract(sin(dot(floor(road_pos), vec2(12.9898, 78.233))) * 43758.5453);
	float shoulder = smoothstep(0.72, 0.85, edge);
	float lane = (1.0 - smoothstep(0.017, 0.048, edge)) * step(0.52, fract(along / 48.0));
	float rim = (1.0 - smoothstep(0.018, 0.055, abs(edge - 0.74)));
	vec3 asphalt = mix(vec3(0.083, 0.103, 0.118), vec3(0.29, 0.255, 0.204), shoulder);
	asphalt *= 0.78 + grit * 0.38 + 0.12 * sin(road_pos.x * 0.034 + sin(road_pos.y * 0.04));
	asphalt += vec3(0.15, 0.13, 0.10) * (lane * 0.66 + rim * 0.38) * smoothstep(0.16, 0.60, grit);
	float crack_path = fract((along + sin(across * 5.5) * 7.0 + sin(across * 17.0) * 2.0) / 173.0);
	float crack = (1.0 - smoothstep(0.002, 0.013, abs(crack_path - 0.5))) * smoothstep(0.15, 0.50, sin(along * 0.029 + across * 1.55));
	asphalt *= 1.0 - crack * 0.59;
	COLOR = vec4(asphalt, 1.0 - smoothstep(0.86, 1.0, edge));
}
