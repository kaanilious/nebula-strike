extends MultiMeshInstance3D
## The asteroid belt: one MultiMesh per rock shape, each rock a transformed
## instance. Moving a rock is one set_instance_transform, not a node.

const SHAPES := 3
const PER_SHAPE := 34

var rocks: Array = []          # flat list of rock dictionaries
var _groups: Array = []        # [{ multimesh, items: Array[int] }]


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var tints := [Color(0.42, 0.44, 0.47), Color(0.45, 0.44, 0.37), Color(0.37, 0.41, 0.45)]

	for s in SHAPES:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tints[s]
		mat.metallic = 0.14
		mat.roughness = 0.94

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false
		mm.mesh = _make_rock_mesh(s * 2.7 + 1.1)
		mm.instance_count = PER_SHAPE
		mm.visible_instance_count = PER_SHAPE

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.top_level = true
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)

		var indices: Array = []
		for i in PER_SHAPE:
			rocks.append({
				"pos": Vector3.ZERO,
				"basis": Basis.IDENTITY,
				"axis": Vector3.UP,
				"spin": 0.2,
				"drift": Vector3.ZERO,
				"radius": 4.0,
				"hp": 1,
				"alive": true,
				"respawn": 0.0,
				"shape": s,
				"slot": i,
			})
			indices.append(rocks.size() - 1)

		_groups.append({"multimesh": mm, "items": indices})

	place_all(Vector3.ZERO)


func _make_rock_mesh(seed_value: float) -> ArrayMesh:
	# Start from a sphere's triangles, push every vertex in or out by a noise
	# field so the rock is lumpy, then let SurfaceTool rebuild flat-ish normals.
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 7

	var arr: Array = sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	if indices.size() > 0:
		for idx in indices:
			st.add_vertex(_deform(verts[idx], seed_value))
	else:
		for v in verts:
			st.add_vertex(_deform(v, seed_value))

	st.generate_normals()
	return st.commit()


func _deform(v: Vector3, seed_value: float) -> Vector3:
	var n := 0.80 \
		+ 0.20 * sin(v.x * 3.1 + seed_value) * cos(v.y * 2.7 - seed_value * 1.3) * sin(v.z * 3.6 + seed_value * 0.7) \
		+ 0.10 * sin(v.x * 7.3 + v.y * 5.1 + v.z * 6.7 + seed_value * 2.1)
	return v * clampf(n, 0.55, 1.35)


func place_rock(rock: Dictionary, near: Vector3) -> void:
	var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	dir = dir.normalized()

	rock["pos"] = near + dir * randf_range(260.0, 640.0)
	rock["radius"] = randf_range(3.2, 13.5)
	rock["hp"] = 3 if rock["radius"] > 9.0 else (2 if rock["radius"] > 5.5 else 1)
	rock["alive"] = true
	rock["respawn"] = 0.0
	rock["drift"] = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	rock["axis"] = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	rock["spin"] = randf_range(0.06, 0.42)
	rock["basis"] = Basis(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), randf_range(0.0, TAU))


func place_all(near: Vector3) -> void:
	for r in rocks:
		place_rock(r, near)
	_write_all()


func tick(delta: float, ship_pos: Vector3) -> Array:
	## Returns rocks the ship collided with this frame.
	var hits: Array = []

	for rock in rocks:
		if not rock["alive"]:
			rock["respawn"] -= delta
			if rock["respawn"] <= 0.0:
				place_rock(rock, ship_pos)
				_write(rock)
			continue

		var pos: Vector3 = rock["pos"] + rock["drift"] * delta
		rock["pos"] = pos
		var axis: Vector3 = rock["axis"]
		rock["basis"] = Basis(axis, rock["spin"] * delta) * (rock["basis"] as Basis)

		var away := pos - ship_pos
		var d := away.length()

		if d > 950.0:
			place_rock(rock, ship_pos)
			_write(rock)
			continue

		if d < float(rock["radius"]) + 3.2:
			hits.append(rock)

		_write(rock)

	return hits


func _write(rock: Dictionary) -> void:
	var g: Dictionary = _groups[rock["shape"]]
	var mm: MultiMesh = g["multimesh"]
	var r: float = rock["radius"]
	var b: Basis = (rock["basis"] as Basis).scaled(Vector3(r, r, r))
	mm.set_instance_transform(rock["slot"], Transform3D(b, rock["pos"]))


func _write_all() -> void:
	for rock in rocks:
		_write(rock)


func destroy_rock(rock: Dictionary) -> void:
	rock["alive"] = false
	rock["respawn"] = randf_range(4.0, 9.0)
	var g: Dictionary = _groups[rock["shape"]]
	var mm: MultiMesh = g["multimesh"]
	# Park it far below the arena rather than scaling to zero: a zero-scale
	# basis produces NaN normals in the shader.
	mm.set_instance_transform(
		rock["slot"],
		Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3(0, -100000, 0))
	)
