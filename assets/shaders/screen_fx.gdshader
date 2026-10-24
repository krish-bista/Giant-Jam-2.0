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
// Time rift: beyond the world's boundary everything reverts into a see-through mirror that
// reflects the world back in. Computed in world space so it stays put while the camera moves.
uniform float edge_on = 0.0;
uniform int edge_mode = 0;                       // 0 = rectangle, 1 = circle
uniform vec4 edge_rect = vec4(0.0);              // world: x0, y0, x1, y1
uniform vec3 edge_circle = vec3(0.0);            // world: cx, cy, r
uniform float edge_outer = 100000.0;             // world px from the circle center where it stops
uniform float edge_warn = 0.0;                   // 0..1: seam turns red
uniform vec2 world_origin = vec2(0.0);           // world position of the screen's top-left
uniform vec2 world_span = vec2(1280.0, 720.0);   // world size covered by the screen

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Glass cracks: the edges of a Voronoi pattern (1 on a crack line).
float crack_lines(vec2 w) {
	vec2 g = w / 120.0;
	vec2 i = floor(g);
	vec2 f = fract(g);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 p = o + hash2(i + o) - f;
			float d = dot(p, p);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return 1.0 - smoothstep(0.0, 0.05, sqrt(d2) - sqrt(d1));
}

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
	if (edge_on > 0.0) {
		vec2 w = world_origin + SCREEN_UV * world_span;
		float d;
		vec2 rw = w;
		float outer_fade = 1.0;
		if (edge_mode == 0) {
			vec2 lo = edge_rect.xy;
			vec2 hi = edge_rect.zw;
			vec2 o = max(lo - w, w - hi);
			d = length(max(o, vec2(0.0))) + min(max(o.x, o.y), 0.0);
			if (w.x < lo.x) { rw.x = 2.0 * lo.x - w.x; }
			if (w.x > hi.x) { rw.x = 2.0 * hi.x - w.x; }
			if (w.y < lo.y) { rw.y = 2.0 * lo.y - w.y; }
			if (w.y > hi.y) { rw.y = 2.0 * hi.y - w.y; }
		} else {
			vec2 dv = w - edge_circle.xy;
			float dist = length(dv);
			d = dist - edge_circle.z;
			rw = edge_circle.xy + dv / max(dist, 0.001) * (edge_circle.z - d);
			outer_fade = 1.0 - smoothstep(edge_outer - 30.0, edge_outer, dist);
		}
		float cl = crack_lines(w);
		vec3 seam_col = mix(vec3(0.55, 0.95, 1.0), vec3(1.0, 0.4, 0.45), edge_warn);
		if (d > 0.0) {
			vec2 ruv = clamp((rw - world_origin) / world_span, vec2(0.002), vec2(0.998));
			vec3 refl = texture(screen_tex, ruv).rgb;
			float depth = smoothstep(0.0, 260.0, d);
			vec3 m = mix(col, refl, 0.5 + 0.3 * depth);                    // see-through mirror
			m = mix(m, vec3(1.0) - m, 0.15 + 0.3 * depth);                   // reverting
			float lum = dot(m, vec3(0.3, 0.59, 0.11));
			m = mix(m, vec3(0.72, 0.9, 1.0) * (0.35 + 0.75 * lum), 0.45);    // silver-cyan glass
			float shine = pow(max(0.0, sin((w.x + w.y) * 0.006 - TIME * 1.4)), 28.0);
			m += vec3(0.5, 0.8, 0.9) * shine * 0.35;
			m = mix(m, vec3(0.9, 1.0, 1.0), cl * smoothstep(10.0, 120.0, d) * 0.55);
			col = mix(col, m, edge_on * smoothstep(0.0, 8.0, d) * outer_fade);
		}
		// the glowing seam where time breaks, and a crack front creeping just inside it
		float seam = smoothstep(4.0, 0.0, abs(d)) + 0.3 * smoothstep(20.0, 0.0, abs(d));
		float front = cl * smoothstep(-70.0, 0.0, d) * step(d, 0.0) * 0.45;
		col += seam_col * (seam * (0.85 + 0.25 * sin(TIME * 6.0)) + front) * edge_on * outer_fade;
	}
	COLOR = vec4(col * tint.rgb, 1.0);
}
