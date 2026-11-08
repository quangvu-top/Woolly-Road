// Stylised lawn: soft two-tone checker (low contrast), large and small value-noise blotches, gentle radial
// darkening so the board in the middle reads first. Works in the Compatibility renderer.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 light_col : source_color = vec3(0.49, 0.80, 0.31);
uniform vec3 dark_col : source_color = vec3(0.43, 0.74, 0.27);
uniform float tile = 2.0;
uniform vec2 centre = vec2(0.0, 2.0);
uniform float vignette_radius = 16.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 t = floor(p / tile);
	float checker = mod(t.x + t.y, 2.0);
	// soften the tile edges a little
	vec2 f = abs(fract(p / tile) - 0.5);
	float edge = smoothstep(0.5, 0.47, max(f.x, f.y));
	vec3 col = mix(light_col, dark_col, checker * edge + (1.0 - edge) * 0.5);
	float n = noise(p * 0.35) * 0.55 + noise(p * 1.7) * 0.3 + noise(p * 6.0) * 0.15;
	col *= 0.9 + n * 0.18;
	float d = length(p - centre) / vignette_radius;
	col *= 1.0 - smoothstep(0.55, 1.25, d) * 0.22;
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
