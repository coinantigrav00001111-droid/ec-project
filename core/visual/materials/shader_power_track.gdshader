shader_type spatial;
render_mode unshaded; 

uniform vec4 contour_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float scroll_speed = 0.0;
uniform float stripe_density = 4.0;

uniform bool is_solid = false; // Глобальная заливка (true = весь рельс плотный)
uniform float transparent_alpha = 0.8; // Прозрачность промежутков
uniform bool solid_stripes = true; // НОВЫЙ ПАРАМЕТР: Непрозрачные бегущие полосы

void fragment() {
    // Вычисляем бегущую полосу
    float moving_uv = UV.x + (TIME * scroll_speed);
    float pattern = fract(moving_uv * stripe_density);
    float stripes = step(0.5, pattern);
    
    // Формируем цвет
    vec3 final_color = contour_color.rgb * (0.3 + (stripes * 0.7));
    
    ALBEDO = final_color;
    EMISSION = final_color * 1.5;
    
    // Логика прозрачности
    if (is_solid) {
        // Режим 1: Весь материал (и полосы, и фон) на 100% непрозрачный
        ALPHA = 1.0; 
    } else {
        // Режим 2: Полупрозрачный фон, но полосы можно сделать плотными
        if (solid_stripes && stripes > 0.0) {
            ALPHA = 1.0; // Пиксель попал на полосу тока — делаем его плотным
        } else {
            ALPHA = transparent_alpha; // Промежуток — оставляем полупрозрачным
        }
    }
}