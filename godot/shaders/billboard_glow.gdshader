shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Camera-facing quads. Used for the star field and the pooled particle system.
// Per-instance colour (with alpha) comes from MultiMesh.use_colors, and the
// per-instance scale lives in the transform's basis.

varying vec4 v_col;

void vertex() {
	mat4 world = mat4(
		vec4(normalize(INV_VIEW_MATRIX[0].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[1].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz), 0.0),
		vec4(MODEL_MATRIX[3].xyz, 1.0)
	);

	float sx = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	float sy = max(length(MODEL_MATRIX[1].xyz), 0.0001);
	world = world * mat4(
		vec4(sx, 0.0, 0.0, 0.0),
		vec4(0.0, sy, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);

	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_col = COLOR;
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv);
	if (d > 0.5) {
		discard;
	}
	float a = smoothstep(0.5, 0.0, d);
	ALBEDO = v_col.rgb;
	ALPHA = a * v_col.a;
}
