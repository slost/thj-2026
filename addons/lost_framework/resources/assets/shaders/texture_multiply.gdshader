shader_type canvas_item;

render_mode blend_mul;

uniform vec4 color_white : source_color = vec4(1.0);
uniform vec4 color_black : source_color = vec4(0.0);
uniform float recolor_strength : hint_range(0.0, 1.0) = 1.0;

// UV control
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform float uv_scale : hint_range(0.1, 5.0) = 1.0;

// Distortion
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.05;
uniform float distortion_speed : hint_range(0.0, 5.0) = 1.0;

void fragment() {
    vec2 uv = UV;

    // ----------------------
    // 1. Scale & offset (tileable)
    uv = uv * uv_scale + uv_offset;

    // ----------------------
    // 2. Distortion
    // ใช้ sine wave ตาม UV และ TIME เพื่อบิดเบี้ยว
    uv.x += sin(uv.y * 10.0 + TIME * distortion_speed) * distortion_strength;
    uv.y += cos(uv.x * 10.0 + TIME * distortion_speed) * distortion_strength;

    // ----------------------
    // 3. Tileable
    uv = fract(uv);

    // ----------------------
    // 4. Sample texture
    vec4 tex = texture(TEXTURE, uv);

    // ----------------------
    // 5. Recolor
    float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 recolor = mix(color_black.rgb, color_white.rgb, lum);
    tex.rgb = mix(tex.rgb, recolor, recolor_strength);

    // ----------------------
    // 6. Output with multiply blend
    COLOR = tex;
}
