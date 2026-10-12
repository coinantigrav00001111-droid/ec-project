shader_type spatial;
render_mode unshaded; 

uniform vec3 normal_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 slip_color : source_color = vec3(1.0, 0.0, 0.0);
uniform float slip_blend : hint_range(0.0, 1.0) = 0.0;
uniform float spoke_count = 6.0; 

// Переменная для передачи 3D-координат из вершинного шейдера во фрагментный
varying vec3 local_pos;

void vertex() {
	// Получаем чистые локальные координаты колеса от его центра
	local_pos = VERTEX;
}

void fragment() {
	// Колесо крутится по оси X, значит смотрим на него сбоку - это плоскость YZ.
	// Вычисляем угол на основе реальных физических габаритов меша
	float angle = atan(local_pos.y, local_pos.z);
	
	// Генерируем лучи (спицы)
	float sp = step(0.0, sin(angle * spoke_count));
	
	// Смешиваем цвета
	vec3 current_spoke_color = mix(normal_color, slip_color, slip_blend);
	
	// Фон делаем полупрозрачным серым (или можешь использовать ALPHA = sp если нужен прозрачный фон)
	vec3 final_color = mix(vec3(0.1), current_spoke_color, sp);
	
	ALBEDO = final_color;
}
