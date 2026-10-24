shader_type canvas_item;
// A round mirror lying on the ground: dark silver glass with a soft sky gradient, rings and
// rune ticks, a slowly turning shine, a bright rim, and cracks that creep in from the edge.
// Draw it on a square texture: UV (0,0)-(1,1) spans the circle.
render_mode unshaded;

uniform vec4 tint : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.6, 0.95, 1.0, 1.0);
uniform float alpha = 0.95;
uniform float crack = 0.0;        // 0..1 how far the cracks have spread inward
uniform float open = 1.0;         // 0..1 the mirror opening up (portal pool)

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float cells(vec2 g) {
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
	return 1.0 - smoothstep(0.0, 0.04, sqrt(d2) - sqrt(d1));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > open) {
		discard;
	}
	float rn = r / max(open, 0.001);
	float ang = atan(p.y, p.x);
	// glass: brighter in the middle, deep blue toward the edge, a faint reflected sky
	vec3 col = mix(vec3(0.07, 0.09, 0.17), tint.rgb * 0.62, 0.3 + 0.45 * (1.0 - rn));
	col += vec3(0.08, 0.1, 0.16) * (0.5 + 0.5 * sin(p.y * 3.0 + TIME * 0.4));
	vec2 sg = floor(UV * 180.0);
	float star = step(0.997, hash2(sg).x) * (0.5 + 0.5 * sin(TIME * 3.0 + hash2(sg).y * 20.0));
	col += vec3(0.8, 0.9, 1.0) * star * 0.6;
	// rings and rune ticks
	float rings = smoothstep(0.006, 0.0, abs(rn - 0.34)) + smoothstep(0.006, 0.0, abs(rn - 0.67)) * 0.8;
	float ticks = step(0.86, rn) * step(rn, 0.92) * step(0.6, sin(ang * 36.0 - TIME * 0.8));
	col += rim_color.rgb * (rings * 0.35 + ticks * 0.35);
	// a slow shine sweeping round, and diagonal glints
	float sweep = pow(max(0.0, cos(ang - TIME * 0.5)), 16.0) * (0.25 + 0.6 * rn);
	float glint = pow(max(0.0, sin((p.x - p.y) * 3.0 - TIME * 0.9)), 40.0);
	col += vec3(0.75, 0.9, 1.0) * (sweep * 0.3 + glint * 0.18);
	// cracks creeping in from the rim
	float reach = 1.0 - crack * 0.75;
	float cr = cells(p * 4.0) * smoothstep(reach - 0.08, reach + 0.04, rn) * step(0.001, crack);
	col = mix(col, vec3(0.9, 1.0, 1.0), cr * 0.75);
	// bright rim
	float rim = smoothstep(0.035, 0.0, abs(rn - 0.975));
	col += rim_color.rgb * rim * 0.9;
	COLOR = vec4(col, alpha);
}
