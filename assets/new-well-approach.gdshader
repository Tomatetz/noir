shader_type canvas_item;

varying vec2 site;

void vertex() {
	site = VERTEX;
}

float grain(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 low = (site - vec2(482.0, -300.0)) / vec2(203.0, 125.0);
	float shore = length(low) + sin(low.x * 9.0 + low.y * 5.0) * 0.055;
	float basin = 1.0 - smoothstep(0.69, 1.12, shore);
	float sediment = sin(shore * 36.0 + low.x * 2.0) * 0.5 + 0.5;
	vec3 silt = mix(vec3(0.048, 0.078, 0.087), vec3(0.15, 0.17, 0.16), sediment * smoothstep(0.28, 0.95, shore));

	vec2 pad = abs(site - vec2(410.0, -111.0));
	float edge = max(max(pad.x - 119.0, pad.y - 68.0), (pad.x + pad.y - 169.0) * 0.707);
	float slab = 1.0 - smoothstep(-1.0, 5.0, edge);
	float ramp = (1.0 - smoothstep(24.0, 34.0, abs(site.x - 410.0))) *
		smoothstep(-50.0, -42.0, site.y) * (1.0 - smoothstep(-17.0, -8.0, site.y));
	vec2 joint = abs(fract((site - vec2(410.0, -111.0)) / vec2(60.0, 44.0) + 0.5) - 0.5);
	float seams = smoothstep(0.467, 0.50, max(joint.x, joint.y)) * slab;
	vec3 concrete = vec3(0.33, 0.34, 0.31) * (1.0 - seams * 0.35);
	concrete *= 0.88 + grain(site / vec2(60.0, 44.0)) * 0.19;
	float border = (1.0 - smoothstep(1.0, 3.5, abs(edge + 8.0))) * step(0.22, grain(site / 3.0));
	float stripes = step(0.5, fract((site.x + site.y) / 14.0));
	float hazard = step(94.0, pad.x) * (1.0 - step(107.0, pad.x)) * (1.0 - step(48.0, pad.y)) * stripes;
	concrete = mix(concrete, vec3(0.57, 0.43, 0.19), max(border * 0.69, hazard * 0.76));

	float surface = max(slab, ramp);
	float road_fade = smoothstep(245.0, 315.0, site.x) * (1.0 - smoothstep(610.0, 705.0, site.x));
	float road_edge = abs(site.y);
	float road = (1.0 - smoothstep(17.0, 24.0, road_edge)) * road_fade;
	float shoulder = (1.0 - smoothstep(0.8, 2.4, abs(road_edge - 16.0))) * road_fade;
	float center_dash = (1.0 - smoothstep(0.5, 1.3, road_edge)) * step(0.60, fract(site.x / 26.0));
	vec3 asphalt = mix(vec3(0.095, 0.112, 0.116), vec3(0.36, 0.35, 0.28), max(shoulder * 0.55, center_dash * 0.65));
	vec3 color = mix(silt, asphalt, road);
	color = mix(color, concrete, surface) * (0.93 + grain(site) * 0.14);
	COLOR = vec4(color, max(max(basin * 0.96, road), surface));
}
