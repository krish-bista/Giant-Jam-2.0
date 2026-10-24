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
	COLOR = vec4(col * tint.rgb, 1.0);
}
