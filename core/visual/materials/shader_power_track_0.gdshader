shader_type spatial;
render_mode unshaded, blend_add; // unlit для чистого свечения, blend_add для голографического наложения

uniform vec4 contour_color : source_color = vec4(0.0, 0.8, 1.0, 1.0); // Базовый цвет контура
uniform float scroll_speed = 0.2; // Скорость (зависит от напряжения)
uniform float stripe_density = 4.0; // Количество "пусковых" полос на метр

uniform float alpha = 0.9; // Количество "пусковых" полос на метр

void fragment() {
    // Делаем UV-скроллинг по оси Y (или X, зависит от развертки твоего меша рельса)
    float moving_uv = UV.x + (TIME * scroll_speed);
    
    // Создаем полосатый паттерн с помощью функции fract
    float pattern = fract(moving_uv * stripe_density);
    
    // Делаем края полос резкими с помощью step
    float stripes = step(0.3, pattern);
    
    // Добавляем легкое базовое свечение, чтобы рельс было видно даже между полосами
    vec3 final_color = contour_color.rgb * (0.3 + (stripes * 0.7));
    
    ALBEDO = final_color;
    EMISSION = final_color * 2.0; // Умножаем для эффекта неонового свечения
    ALPHA = alpha; // Легкая полупрозрачность
}