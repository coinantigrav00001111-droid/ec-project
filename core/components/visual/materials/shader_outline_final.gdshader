shader_type spatial;
// blend_add делает свечение стабильнее поверх других слоев
// depth_test_always убираем, чтобы не светить сквозь горы, 
// но оставляем стандартный тест для стабильности.
render_mode unshaded, cull_front, blend_add;

uniform vec4 glow_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 1.0) = 0.02;
uniform float glow_intensity : hint_range(0.0, 20.0) = 2.0;
uniform float appearance_progress : hint_range(0.0, 1.0) = 0.0;

void vertex() {
    vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    float dist = abs(view_pos.z);
    float final_width = outline_width * appearance_progress * dist * 0.05;

    vec3 n = NORMAL;
    
    // Если нормаль смотрит вниз (Y < 0), убираем вертикальную составляющую
    if (n.y < 0.0) {
        n.y = 0.0;
        n = normalize(n); // Пересчитываем, чтобы она толкала только вбок
    }

    // Применяем раздутие только по исправленной нормали
    VERTEX += n * final_width;
    
    // Микро-лифт, чтобы нижняя грань не мерцала (Z-fighting) с полом
    // 0.001 достаточно, чтобы глаз не видел плоскость, но видеокарта видела контур
    VERTEX.y += 0.001; 
}

//void vertex() {
    //// Используем дистанцию более стабильно через позицию камеры
    //float dist = length(MODELVIEW_MATRIX[3].xyz); 
    //
    //// Ограничиваем минимальную дистанцию, чтобы контур не исчезал в упор
    //float safe_dist = max(dist, 1.0);
    //
    //float final_width = outline_width * appearance_progress * safe_dist * 0.05;
    //VERTEX += NORMAL * final_width;
//}

void fragment() {
    // В режиме blend_add мы используем чистый цвет. 
    // Умножаем на ALPHA для плавности появления.

    ALBEDO = glow_color.rgb * glow_intensity * appearance_progress;
}
