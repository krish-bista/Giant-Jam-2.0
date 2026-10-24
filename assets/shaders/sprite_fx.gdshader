shader_type canvas_item;
// Hit flash, telegraph tint and dissolve-on-death for any sprite.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_edge : source_color = vec4(1.0, 0.6, 1.0, 1.0);
uniform float emission = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, flash_color.rgb, flash * c.a);
	c.rgb *= emission;
	if (dissolve > 0.0) {
		vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
		float n = hash(cell);
		if (n < dissolve) {
			c.a = 0.0;
		} else if (n < dissolve + 0.12) {
			c.rgb = dissolve_edge.rgb * 2.0;
		}
	}
	COLOR = c * COLOR;
}
