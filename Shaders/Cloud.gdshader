shader_type canvas_item;

/* --- il tuo wobble --- */
uniform float wave_strength_y = 1.0;
uniform float wave_strength_x = 0.5;
uniform float wave_speed      = 2.0;
uniform float pixel_snap      = 1.0;

/* --- velo di trasparenza --- */
uniform float seed = 0.0;                                // per-istanza (0..1)
uniform float veil_random_min : hint_range(0.0,1.0) = 0.85; // alpha media minima per nuvola
uniform float veil_noise_strength : hint_range(0.0,1.0) = 0.12; // 0 = off, 0.1..0.2 leggero
uniform float veil_noise_scale = 4.0;                    // scala del “granello”
uniform float veil_noise_speed = 0.0;                    // 0 = statico, >0 = fruscio lento

/* hash semplice per “noise” */
float hash12(vec2 p){
    p = fract(p*vec2(123.34, 456.21));
    p += dot(p, p+45.32);
    return fract(p.x*p.y);
}

void fragment() {
    // --- offset "respiro" ---
    float offset_y = sin(UV.x * 10.0 + TIME * wave_speed) * wave_strength_y;
    float offset_x = cos(UV.y * 6.0  + TIME * wave_speed * 0.8) * wave_strength_x;

    offset_y = round(offset_y / pixel_snap) * pixel_snap * TEXTURE_PIXEL_SIZE.y;
    offset_x = round(offset_x / pixel_snap) * pixel_snap * TEXTURE_PIXEL_SIZE.x;
    vec2 pixel_offset = vec2(offset_x, offset_y);

    // campiona la nuvola
    vec4 col = texture(TEXTURE, UV + pixel_offset);

    // --- velo costante per-istanza (random ma stabile per nuvola) ---
    float r = fract(sin(seed * 78.233 + 1.0) * 43758.5453);
    float veil_const = mix(veil_random_min, 1.0, r);  // es. 0.85..1.0

    // --- noise morbido per-pixel (facoltativo) ---
    float n = hash12(UV * veil_noise_scale + vec2(TIME * veil_noise_speed, 0.0));
    float veil_noise = mix(1.0 - veil_noise_strength, 1.0, n);

    // applica il velo all’alpha
    col.a *= veil_const * veil_noise;

    COLOR = col;
}
