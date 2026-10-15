shader_type canvas_item;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform vec4 outline_color : source_color = vec4(1.0, 0.62, 0.1, 1.0);
uniform float width_px = 2.5;

const int DIRS = 16;
const int MAX_RINGS = 8;

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(mask_tex, 0));
	float inside = texture(mask_tex, UV).a;
	float edge = 0.0;

	for (int r = 1; r <= MAX_RINGS; r++) {
		float fr = float(r);
		if (fr > width_px + 1.0) break;
		float w = clamp(width_px + 0.5 - fr, 0.0, 1.0); // мягкий внешний край
		for (int d = 0; d < DIRS; d++) {
			float a = TAU * float(d) / float(DIRS);
			float m = texture(mask_tex, UV + vec2(cos(a), sin(a)) * fr * px).a;
			edge = max(edge, m * w);
		}
	}
	// рисуем только снаружи силуэта
	COLOR = vec4(outline_color.rgb, outline_color.a * edge * (1.0 - inside));
}
