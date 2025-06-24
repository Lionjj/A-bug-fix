shader_type canvas_item;

uniform float glitch_intensity = 3.0; // in pixel
uniform float glitch_speed = 10.0;    // velocità del glitch

void fragment() {
    vec2 uv = UV;

    // Blocchi verticali
    float line = floor(UV.y * 64.0);           // più = più righe
    float time_mod = mod(floor(TIME * glitch_speed), 8.0);

    // solo ogni tot righe
    if (mod(line + time_mod, 8.0) == 0.0) {
        uv.x += glitch_intensity * TEXTURE_PIXEL_SIZE.x;
    }

    COLOR = texture(TEXTURE, uv);
}
