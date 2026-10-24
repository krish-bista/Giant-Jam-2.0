shader_type canvas_item;
// Reversal transition: the whole screen flips like a card turned in a mirror.
// progress 0 = normal, 0.5 = edge-on (a bright seam), 1 = fully mirrored.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float progress = 0.0;
uniform vec4 seam_color : source_color = vec4(0.7, 0.95, 1.0, 1.0);

void fragment() {
	float s = cos(progress * PI);
	float a = max(abs(s), 0.0015);
	vec2 uv = SCREEN_UV;
	float x = 0.5 + (uv.x - 0.5) / (s >= 0.0 ? a : -a);
	vec3 col = vec3(0.02, 0.03, 0.06);
	if (x >= 0.0 && x <= 1.0) {
		float off = 0.012 * (1.0 - abs(s));
		col.r = texture(screen_tex, vec2(clamp(x + off, 0.0, 1.0), uv.y)).r;
		col.g = texture(screen_tex, vec2(x, uv.y)).g;
		col.b = texture(screen_tex, vec2(clamp(x - off, 0.0, 1.0), uv.y)).b;
		// darker on the turned-away side, like the back of a mirror
		col *= 0.55 + 0.45 * abs(s);
		if (s < 0.0) {
			col = mix(col, col * vec3(0.85, 0.9, 1.15), 0.5);
		}
	}
	float edge = abs(abs(uv.x - 0.5) - 0.5 * abs(s));
	col += seam_color.rgb * exp(-edge * 90.0) * (1.4 - abs(s));
	col += seam_color.rgb * (1.0 - abs(s)) * 0.35;
	COLOR = vec4(col, 1.0);
}
