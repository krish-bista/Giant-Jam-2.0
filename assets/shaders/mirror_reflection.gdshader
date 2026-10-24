shader_type canvas_item;
// A character's reflection in the mirror floor: faint, tinted, and cut off at the platform's
// edge (a world-space circle) so it never hangs over the void.
render_mode unshaded;

uniform vec2 center = vec2(0.0);
uniform float radius = 380.0;
uniform vec4 tint : source_color = vec4(0.7, 0.92, 1.0, 1.0);
uniform float alpha = 0.34;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (distance(world_pos, center) > radius - 6.0) {
		discard;
	}
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 col = mix(c.rgb, tint.rgb * (0.3 + l), 0.45);
	COLOR = vec4(col, c.a * alpha);
}
