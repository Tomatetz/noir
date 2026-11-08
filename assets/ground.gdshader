shader_type canvas_item;

varying vec2 ground_pos;

void vertex() {
	ground_pos = VERTEX;
}

vec2 cell_seed(vec2 cell) {
	return fract(sin(vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
	vec2 region = ground_pos / 440.0;
	float basin = smoothstep(-0.45, 0.66, sin(region.x + sin(region.y * 0.7)) * cos(region.y - region.x * 0.38));
	vec2 p = ground_pos / mix(25.0, 59.0, basin);
	p += sin(p.yx * 2.8) * 0.14;
	vec2 cell = floor(p);
	float nearest = 10.0;
	float second = 10.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = cell + vec2(float(x), float(y));
			vec2 offset = neighbor + 0.18 + cell_seed(neighbor) * 0.64 - p;
			float d = dot(offset, offset);
			second = min(second, max(nearest, d));
			nearest = min(nearest, d);
		}
	}
	float crack = 1.0 - smoothstep(0.008, 0.059, second - nearest);
	float patches = sin(p.x * 0.27 + sin(p.y * 0.24)) * sin(p.y * 0.21 - p.x * 0.12);
	float grain = cell_seed(floor(ground_pos / 2.0)).x;
	vec3 soil = mix(vec3(0.12, 0.125, 0.12), vec3(0.24, 0.207, 0.169), basin * 0.76 + (patches * 0.5 + 0.5) * 0.24);
	COLOR = vec4(soil * (0.91 + grain * 0.18) * (1.0 - crack * mix(0.09, 0.46, basin)), 1.0);
}
