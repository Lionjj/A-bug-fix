shader_type canvas_item;

uniform float glitch_strength = 5.0;
uniform float glitch_speed = 2.0;
uniform float pixel_size = 2.0;
uniform vec2 screen_size = vec2(640.0, 360.0); // da aggiornare via script per coerenza con il viewport

void fragment() {
    vec2 uv = UV;

    // calcolo glitch casuale
    float glitch = step(0.9, fract(sin(uv.y * 100.0 + TIME * glitch_speed) * 43758.5453));

    // spostamento orizzontale basato su glitch
    float offset = glitch * glitch_strength / screen_size.x;

    uv.x += offset;

    // effetto blocco pixel (quantizzazione UV)
    uv = floor(uv * pixel_size) / pixel_size;

    // campionamento texture
    COLOR = texture(TEXTURE, uv);

    // glitch intermittente (rosso flash)
    float flicker = fract(sin(dot(UV * 50.0, vec2(12.9898,78.233))) * 43758.5453 + TIME);
    if (flicker < 0.03) {
        COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.0, 0.0), 0.6);
    }
}
