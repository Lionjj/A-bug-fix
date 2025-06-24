shader_type canvas_item;

uniform float glow_strength = 0.3;
uniform float pulse_speed = 2.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = sin(TIME * pulse_speed) * glow_strength;
	COLOR = tex + vec4(pulse, pulse, pulse, 0.0);
}
