shader_type canvas_item;
// Mirror shield: a moving specular streak, sparkles, a "ready" rim glow and a deflect flash.

uniform float shine_speed = 0.6;
uniform float ready = 0.0;      // 1 while the perfect-block window is open
uniform float flash = 0.0;      // 1 right after a perfect deflect
uniform vec4 rim_color : source_color = vec4(0.5, 1.0, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float glass = step(0.55, c.b) * step(c.r, c.b + 0.05);
	float band = fract(TIME * shine_speed);
	float d = abs((UV.x + UV.y) * 0.5 - band * 1.6 + 0.3);
	float streak = smoothstep(0.12, 0.0, d) * glass;
	vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
	float sparkle = step(0.985, hash(cell + floor(TIME * 6.0))) * glass;
	c.rgb += vec3(streak * 0.9 + sparkle);
	// rim glow on the frame while the perfect window is open
	float frame = 1.0 - glass;
	c.rgb = mix(c.rgb, rim_color.rgb * 1.8, ready * frame * 0.7 * c.a);
	c.rgb = mix(c.rgb, vec3(2.4), flash * c.a);
	COLOR = c * COLOR;
}
