shader_type canvas_item;

uniform float speed = 1.5;
uniform float density = 20.0;
uniform float brightness = 0.07;

void fragment() {
	vec2 pos = floor(UV * density);
	float fall = mod(pos.x + TIME * speed, density);
	float bit = step(fall, 1.0) * brightness;

	COLOR = texture(TEXTURE, UV);
	COLOR.rgb += vec3(0.0, bit, 0.0); // verde Matrix
}
