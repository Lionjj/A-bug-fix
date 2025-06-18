shader_type canvas_item;
render_mode unshaded;

uniform float glitch_strength = 0.03;
uniform float glitch_speed = 10.0;
uniform float slice_height = 0.05;

float rand(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

void fragment() {
    vec2 new_uv = UV;
    float y_slice = floor(new_uv.y / slice_height);
    float time_offset = floor(TIME * glitch_speed);
    float offset = rand(y_slice + time_offset) * glitch_strength;

    if (rand(y_slice + time_offset * 1.3) > 0.5) {
        new_uv.x += offset;
    }

    COLOR = texture(TEXTURE, new_uv);
}
