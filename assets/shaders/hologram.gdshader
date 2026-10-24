shader_type canvas_item;
// Hologram: you, made of light. Keeps the sprite's shading (the visor stays dark so the face reads),
// tints it cyan, lights up the outer outline, adds a faint halo, soft scanlines, flicker and the
// odd glitch line. Self-lit (unshaded) so dark worlds don't dim it. Used for the reflection ally.
render_mode unshaded;

uniform vec4 holo_color : source_color = vec4(0.45, 0.95, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.8, 1.0, 1.0, 1.0);
uniform float tint_strength = 0.75;
uniform float alpha = 0.86;
uniform float halo = 0.3;
uniform float flash = 0.0;

varying vec4 tint_in;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	// keep the node's modulate (COLOR in fragment() already includes the texture)
	tint_in = COLOR;
}

void fragment() {
	vec2 uv = UV;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float row = floor(UV.y / px.y);
	// occasional glitch: a row slides sideways for a moment
	float g = step(0.985, hash(row + floor(TIME * 12.0)));
	uv.x += g * px.x * 2.0;
	vec4 c = texture(TEXTURE, uv);
	float a1 = texture(TEXTURE, uv + vec2(px.x, 0.0)).a;
	float a2 = texture(TEXTURE, uv - vec2(px.x, 0.0)).a;
	float a3 = texture(TEXTURE, uv + vec2(0.0, px.y)).a;
	float a4 = texture(TEXTURE, uv - vec2(0.0, px.y)).a;
	float scan = mod(row + floor(TIME * 6.0), 2.0) < 1.0 ? 1.0 : 0.86;
	float flicker = 0.94 + 0.06 * sin(TIME * 41.0) * sin(TIME * 17.0);
	vec3 col;
	float a;
	if (c.a < 0.1) {
		// faint glow just outside the figure
		float near = max(max(a1, a2), max(a3, a4));
		col = holo_color.rgb;
		a = near * halo * flicker;
	} else {
		float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		col = mix(c.rgb, holo_color.rgb * (0.08 + l * 1.35), tint_strength);
		// only the OUTER outline lights up; inner dark lines (the visor) stay dark
		float outer = 1.0 - step(0.5, min(min(a1, a2), min(a3, a4)));
		col = mix(col, edge_color.rgb, outer * step(l, 0.15));
		col *= scan * flicker;
		col = mix(col, vec3(1.0), flash);
		a = c.a * alpha * (g > 0.5 ? 0.6 : 1.0);
	}
	COLOR = vec4(col, a) * tint_in;
}
