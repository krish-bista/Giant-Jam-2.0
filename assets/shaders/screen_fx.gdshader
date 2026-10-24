shader_type canvas_item;
// Full-screen effects: deflect shockwave, chromatic aberration, vignette, VR scanlines.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 wave_center = vec2(0.5);
uniform float wave_radius = 0.0;
uniform float wave_strength = 0.0;
uniform float chroma = 0.0;
uniform float vignette = 0.35;
uniform float scanlines = 0.0;
uniform float desaturate = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float invert = 0.0;
// Hypno Reverse "Mirror Domain": a circle where the world shows its inverted soul.
uniform vec2 dom_center = vec2(0.5);
uniform float dom_radius = 0.0;   // in screen heights
uniform float dom_on = 0.0;
uniform float dom_crack = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	if (wave_strength > 0.0) {
		vec2 dv = (uv - wave_center) * aspect;
		float dist = length(dv);
		float ring = smoothstep(wave_radius - 0.06, wave_radius, dist) * (1.0 - smoothstep(wave_radius, wave_radius + 0.06, dist));
		uv -= normalize(dv + 0.0001) / aspect * ring * wave_strength;
	}
	vec3 col;
	if (chroma > 0.0) {
		vec2 off = (uv - 0.5) * chroma;
		col.r = texture(screen_tex, uv + off).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - off).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	float l = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(l), desaturate);
	if (scanlines > 0.0) {
		col *= 1.0 - scanlines * 0.5 * (0.5 + 0.5 * sin(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y * 1.6 + TIME * 4.0));
	}
	vec2 v = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	col *= 1.0 - vignette * smoothstep(0.25, 0.75, length(v));
	col = mix(col, vec3(1.0) - col, invert);
	if (dom_on > 0.0 && dom_radius > 0.0) {
		vec2 dv = (SCREEN_UV - dom_center) * aspect;
		float r = length(dv) / dom_radius;
		if (r <= 1.0) {
			float ang = atan(dv.y, dv.x);
			vec3 inv = vec3(1.0) - col;
			vec3 m = mix(inv, vec3(0.7, 0.95, 1.0) * (0.45 + 0.55 * dot(inv, vec3(0.333))), 0.35);
			float rim = smoothstep(0.035, 0.0, abs(r - 0.965));
			float inner = smoothstep(0.02, 0.0, abs(r - 0.72)) * 0.6;
			float ticks = step(0.8, r) * step(r, 0.93) * step(0.55, sin(ang * 28.0 + TIME * 3.0));
			float spokes = smoothstep(0.015, 0.0, abs(sin(ang * 6.0 - TIME * 2.0))) * step(0.72, r) * step(r, 0.8);
			float sweep = pow(max(0.0, sin(ang - TIME * 12.0)), 24.0) * smoothstep(1.0, 0.2, r);
			m += vec3(0.55, 0.95, 1.0) * (rim * 0.9 + inner + ticks * 0.5 + spokes * 0.6) + vec3(0.6) * sweep;
			float k = abs(sin(ang * 7.0 + floor(ang * 3.0) * 1.7));
			m = mix(m, vec3(1.0), smoothstep(0.035, 0.0, k * r) * dom_crack);
			col = mix(col, m, dom_on * (1.0 - dom_crack * 0.9));
		}
	}
	COLOR = vec4(col * tint.rgb, 1.0);
}
