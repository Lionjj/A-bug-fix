shader_type canvas_item;

uniform float wave_strength_y = 1.0;   // spostamento verticale massimo in pixel
uniform float wave_strength_x = 0.5;   // leggero respiro orizzontale
uniform float wave_speed = 2.0;        // velocità oscillazione
uniform float pixel_snap = 1.0;        // dimensione del pixel base

void fragment() {
    // Calcola offset a onde (come respiro)
    float offset_y = sin(UV.x * 10.0 + TIME * wave_speed) * wave_strength_y;
    float offset_x = cos(UV.y * 6.0 + TIME * wave_speed * 0.8) * wave_strength_x;

    // Snappa agli step di pixel
    offset_y = round(offset_y / pixel_snap) * pixel_snap * TEXTURE_PIXEL_SIZE.y;
    offset_x = round(offset_x / pixel_snap) * pixel_snap * TEXTURE_PIXEL_SIZE.x;

    vec2 pixel_offset = vec2(offset_x, offset_y);

    COLOR = texture(TEXTURE, UV + pixel_offset);
}
