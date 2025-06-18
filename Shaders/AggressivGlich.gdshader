shader_type canvas_item;
render_mode unshaded;

uniform float glitch_speed = 20.0;
uniform float glitch_intensity = 0.07;
uniform float rgb_shift = 0.006;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment(){
    vec2 uv = UV;
    float time = TIME * glitch_speed;

    // Glitch a blocchi orizzontali
    float block = floor(uv.y * 40.0);
    float glitch_offset = (rand(vec2(block, time)) - 0.5) * glitch_intensity;

    // Scorrimento orizzontale casuale di blocchi
    if (rand(vec2(time, block)) > 0.6){
        uv.x += glitch_offset;
    }

    // Separazione RGB leggera
    vec4 col_r = texture(TEXTURE, uv + vec2(-rgb_shift, 0.0));
    vec4 col_g = texture(TEXTURE, uv);
    vec4 col_b = texture(TEXTURE, uv + vec2(rgb_shift, 0.0));

    vec4 final_color = vec4(col_r.r, col_g.g, col_b.b, 1.0);

    // Disturbo flash casuale
    if (rand(vec2(time * 3.0, uv.y * 100.0)) > 0.96){
        final_color.rgb = vec3(1.0, 0.2, 0.7); // flash rosa glitch
    }

    COLOR = final_color;
}
