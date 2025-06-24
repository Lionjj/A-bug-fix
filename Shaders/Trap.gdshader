shader_type canvas_item;

uniform float strength = 0.02;     // sfalsamento orizzontale
uniform float frequency = 100.0;   // righe glitchate
uniform float speed = 4.0;         // velocità glitch
uniform float danger_flash_speed = 5.0; // velocità lampeggio rosso

void fragment() {
    vec2 uv = UV;

    // calcolo righe glitchate
    float glitch = step(0.7, fract(sin(uv.y * frequency + TIME * speed) * 43758.5453));

    // immagine base
    vec4 base = texture(TEXTURE, uv);

    // immagine duplicata e sfalsata
    vec4 dup = texture(TEXTURE, uv + vec2(strength, 0.0));

    // unione base + duplicato su righe glitchate
    vec4 final_color = mix(base, dup, glitch);

    // aggiunta lampeggio rosso intermittente globale (pericolo visivo)
    float flash = sin(TIME * danger_flash_speed) * 0.5 + 0.5;
    final_color.rgb = mix(final_color.rgb, vec3(1.0, 0.0, 0.0), flash * 0.2); // leggero rosso pulsante

    COLOR = final_color;
}
