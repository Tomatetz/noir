shader_type canvas_item;
render_mode unshaded;
uniform bool selected = false;
uniform bool preview = false;

void fragment() {
	vec4 body = texture(TEXTURE, UV);
	vec2 step_uv = vec2(length(dFdx(UV)), length(dFdy(UV))) * 2.0;
	float rim = 0.0;
	if (selected) {
		for (int i = 0; i < 8; i++) {
			float angle = float(i) * 0.785398;
			rim = max(rim, texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * step_uv).a);
		}
	}
	vec3 mint = vec3(0.45, 1.0, 0.84);
	float opacity = body.a * (preview ? 0.66 : 1.0);
	float edge = max(rim - body.a, 0.0);
	COLOR = vec4(mix(mint, mix(body.rgb, mint, preview ? 0.16 : 0.0), body.a), max(opacity, edge * 0.92));
}
