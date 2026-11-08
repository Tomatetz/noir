shader_type canvas_item;

uniform float seed = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float crown = 0.0;
	for (int i = 0; i < 7; i++) {
		float a = float(i) * 2.39996 + seed;
		vec2 center = vec2(cos(a), sin(a)) * (0.22 + float(i) * 0.038);
		float d = length(p - center);
		crown = max(crown, 1.0 - smoothstep(0.26, 0.43, d));
	}
	float leaf = fract(sin(dot(floor(p * 27.0), vec2(127.1, 311.7)) + seed) * 43758.5453);
	float alpha = smoothstep(0.09, 0.63, crown + (leaf - 0.5) * 0.22);
	vec3 color = mix(vec3(0.07, 0.083, 0.062), vec3(0.26, 0.29, 0.16), crown * (0.36 + leaf * 0.64));
	COLOR = vec4(color, alpha);
}
