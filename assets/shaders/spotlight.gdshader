shader_type canvas_item;
// Tutorial dim layer with a rounded see-through window (reference: Parking Loop tutorial).
uniform vec2 rect_size = vec2(886.0, 1920.0);   // size of the dim layer in canvas pixels
uniform vec4 hole = vec4(0.0, 0.0, 0.0, 0.0);   // window x, y, w, h in the same pixels (w = 0: no window)
uniform float radius = 36.0;
uniform vec4 dim : source_color = vec4(0.0, 0.02, 0.08, 0.74);

void fragment() {
	vec2 p = UV * rect_size;
	float a = 1.0;
	if (hole.z > 0.0) {
		vec2 c = hole.xy + hole.zw * 0.5;
		float r = min(radius, min(hole.z, hole.w) * 0.5);
		vec2 q = abs(p - c) - (hole.zw * 0.5 - vec2(r));
		float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
		a = smoothstep(-3.0, 3.0, d);
		// a thin bright rim round the window
		float rim = 1.0 - smoothstep(0.0, 7.0, abs(d - 4.0));
		COLOR = mix(vec4(dim.rgb, dim.a * a), vec4(1.0, 1.0, 1.0, 0.85), rim * 0.8);
	} else {
		COLOR = dim;
	}
}
