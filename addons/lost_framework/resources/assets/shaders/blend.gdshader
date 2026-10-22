shader_type canvas_item;

// ใช้โหมด multiply แบบเดียวกับ CanvasItemMaterial
render_mode blend_mul;

uniform vec4 color_white : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_black : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float recolor_strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // ใช้ texture ของ Sprite ตัวเอง
    vec4 tex = texture(TEXTURE, UV);

    // คำนวณความสว่าง
    float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

    // ผสมสีดำกับขาวตามค่าความสว่าง
    vec3 recolor = mix(color_black.rgb, color_white.rgb, lum);

    // ผสมระหว่างสีเดิมกับสี recolor
    tex.rgb = mix(tex.rgb, recolor, recolor_strength);

    // blend_mul จะคูณกับ background ให้อัตโนมัติ
    COLOR = tex;
}
