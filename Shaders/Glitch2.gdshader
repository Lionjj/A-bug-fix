shader_type canvas_item;

uniform float glitch_strength = 0.02;
uniform float glitch_speed = 10.0;

void fragment() {
    vec2 uv = UV;

    // Glitch orizzontale casuale
    float glitch = step(0.8, fract(sin(dot(UV.xy * TIME, vec2(12.9898,78.233))) * 43758.5453));
    uv.x += glitch * glitch_strength * sin(TIME * glitch_speed * UV.y * 10.0);

    // Glitch di colore (canale rosso leggermente separato)
    vec4 tex = texture(TEXTURE, uv);
    vec4 tex_r = texture(TEXTURE, uv + vec2(glitch_strength * 0.5, 0.0));

    COLOR = vec4(tex_r.r, tex.g, tex.b, tex.a);
}
