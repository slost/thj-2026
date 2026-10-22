shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 10.0, 1.0) = 4.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 grid_uv = round(SCREEN_UV * (1.0 / pixel_size) * SCREEN_PIXEL_SIZE) / ((1.0 / pixel_size) * SCREEN_PIXEL_SIZE);
    vec2 grid_uv_fixed = grid_uv * (1.0 / SCREEN_PIXEL_SIZE) * pixel_size;
    grid_uv = floor(SCREEN_UV * grid_uv_fixed) / grid_uv_fixed;
    
    // Alternative simpler version:
    vec2 size = vec2(textureSize(TEXTURE, 0)) / pixel_size;
    vec2 uv = floor(SCREEN_UV * size) / size;
    
    COLOR = texture(SCREEN_TEXTURE, SCREEN_UV); // Placeholder
    // Correct application:
    COLOR = texture(SCREEN_TEXTURE, uv);
}
