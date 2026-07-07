shader_type spatial;
// Убираем cull_front, разрешаем рисовать обе стороны
render_mode unshaded, cull_disabled, blend_add; 

uniform vec4 glow_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 1.0) = 0.02;
uniform float glow_intensity : hint_range(0.0, 20.0) = 2.0;
uniform float appearance_progress : hint_range(0.0, 1.0) = 0.0;

void vertex() {
    float dist = abs((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z);
    float final_width = outline_width * appearance_progress * dist * 0.05;
    
    // Раздуваем как обычно
    VERTEX += NORMAL * final_width;
}

void fragment() {
    // 1. Убираем горизонтальные крышки, как и раньше
    if (abs(NORMAL.y) > 0.5) { discard; }

    // 2. Магия для передней стенки:
    // Если полигон смотрит на нас (FRONT_FACING), мы делаем его 
    // видимым только на самых краях (как эффект Френеля)
    float opac = 1.0;
    if (FRONT_FACING) {
        // Создаем тонкую маску по краям для передней панели
        opac = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    }

    ALBEDO = glow_color.rgb * glow_intensity * appearance_progress;
    ALPHA = appearance_progress * opac;
}
