//🟡 Вариант для подсветки!
shader_type spatial;
render_mode blend_add, unshaded, cull_back;

uniform bool use_fresnel = true;
uniform vec4 glow_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 10.0) = 1.0;
uniform float fresnel_power : hint_range(0.1, 20.0) = 5.0;
uniform float appearance_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float mask = 1.0;
	
	if (use_fresnel) {
		// Используем нормализованный вектор взгляда и нормаль
		float fresnel = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		
		// Чтобы убрать "пересвет" на дальних гранях, возводим в степень 
		// и жестко ограничиваем края через smoothstep
		mask = pow(fresnel, fresnel_power);
		mask = smoothstep(0.2, 0.8, mask);
	}
	
	float final_alpha = mask * glow_intensity * appearance_progress;
	
	ALBEDO = glow_color.rgb;
	ALPHA = final_alpha;
}
