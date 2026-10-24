shader_type canvas_item;
// Gentle wind sway for trees and plants. The bottom stays planted.

uniform float strength = 2.0;
uniform float speed = 1.4;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float bend = (1.0 - UV.y);
	VERTEX.x += sin(TIME * speed + world.x * 0.013 + world.y * 0.007) * strength * bend * bend;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, vec3(1.0), flash * c.a);
	COLOR = c * COLOR;
}
