shader_type canvas_item;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_texture : source_color, repeat_enable;
uniform float glitch_strength = 0.03;

void fragment() {
	vec2 glitch_offset = vec2(sin(UV.y * 200.0) * glitch_strength, 0.0);
	vec4 noise = texture(noise_texture, UV + glitch_offset);

	if (noise.r < dissolve_amount) {
		discard;
	}

	COLOR = texture(TEXTURE, UV + glitch_offset);
}
