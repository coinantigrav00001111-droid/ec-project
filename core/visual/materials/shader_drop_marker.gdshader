shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, depth_draw_never;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 col : source_color = vec4(1.0);
uniform vec3 half_size = vec3(2.7, 0.6, 7.0);   // половина объема проекции
uniform vec2 body_half = vec2(1.7, 6.0);        // половина самой формы (x - ширина, y - длина)
uniform float corner = 0.9; 			//отвечает за скругление
uniform float rim = 0.09;				//за толщину линии
uniform float snap : hint_range(0.0, 1.0) = 0.0;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	// мировая позиция поверхности под этим пикселем
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 v = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	v.xyz /= v.w;
	vec3 wp = (INV_VIEW_MATRIX * vec4(v.xyz, 1.0)).xyz;
	vec3 lp = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;

	if (any(greaterThan(abs(lp), half_size))) discard;

	vec2 p = lp.xz;                       // p.y < 0 - нос вагона
	float d = sd_round_box(p, body_half - vec2(corner), corner);
	float aa = max(fwidth(d), 0.01);

	// рамка + бегущая по ней волна
	float ring = 1.0 - smoothstep(rim * 0.5 - aa, rim * 0.5 + aa, abs(d + rim * 0.5));
	float sweep = pow(0.5 + 0.5 * sin(p.y * 0.6 - TIME * 3.0), 3.0); // 0.6 -  длина бегущей волны,  TIME * 3.0 - скорость
	float rim_a = ring * (0.6 + 0.4 * sweep);

	// мягкая заливка: гуще у края
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float fill = inside * (0.10 + 0.16 * snap) * (0.35 + 0.65 * exp(min(d, 0.0) * 1.8));

	// ореол снаружи
	float outer = exp(-max(d, 0.0) * 3.5) * (1.0 - inside) * 0.35;

	// шеврон на носу Если шеврон не нужен, убери chev * 0.8 из итоговой суммы.
	float k = 0.9;
	float cy = -body_half.y + 2.2;
	float cd = abs(p.y - cy - abs(p.x) * k) / sqrt(1.0 + k * k);
	float chev = (1.0 - smoothstep(rim * 0.5 - aa, rim * 0.5 + aa, cd)) * step(abs(p.x), body_half.x * 0.6);

	float a = clamp(fill + outer + rim_a + chev * 0.8, 0.0, 1.0);
	ALBEDO = col.rgb * (1.0 + 0.4 * rim_a);
	ALPHA = a * col.a;
}
