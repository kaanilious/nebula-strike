extends MultiMeshInstance3D
## Pooled particle system.
##
## One MultiMesh, one draw call. Particles are plain structs in an Array; dead
## ones are swapped with the last live one, exactly like the web build, so the
## pool never fragments.

const MAX_PARTICLES := 1600
const QUAD_SHADER := preload("res://shaders/billboard_glow.gdshader")

var _data: Array = []
var _count := 0


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)

	var mat := ShaderMaterial.new()
	mat.shader = QUAD_SHADER

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = MAX_PARTICLES
	mm.visible_instance_count = 0
	multimesh = mm

	material_override = mat

	for i in MAX_PARTICLES:
		_data.append({
			"pos": Vector3.ZERO,
			"vel": Vector3.ZERO,
			"life": 0.0,
			"max_life": 1.0,
			"col": Color.WHITE,
			"size": 1.0,
			"drag": 1.6,
		})


func emit(pos: Vector3, vel: Vector3, life: float, col: Color, size: float, drag: float = 1.6) -> void:
	if _count >= MAX_PARTICLES:
		return
	var p: Dictionary = _data[_count]
	p["pos"] = pos
	p["vel"] = vel
	p["life"] = life
	p["max_life"] = life
	p["col"] = col
	p["size"] = size
	p["drag"] = drag
	_count += 1


## Radial spray of particles from one point.
func burst(pos: Vector3, count: int, speed: float, col: Color, size: float, life: float) -> void:
	for i in count:
		var dir := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		)
		if dir.length_squared() < 0.0001:
			dir = Vector3.UP
		dir = dir.normalized() * speed * randf_range(0.25, 1.0)
		var tint := randf_range(0.75, 1.0)
		emit(
			pos + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)),
			dir,
			life * randf_range(0.6, 1.3),
			Color(col.r * tint, col.g * tint, col.b * tint, 1.0),
			size * randf_range(0.6, 1.5)
		)


func clear() -> void:
	_count = 0
	multimesh.visible_instance_count = 0


func tick(delta: float) -> void:
	var i := _count - 1
	while i >= 0:
		var p: Dictionary = _data[i]
		var life: float = float(p["life"]) - delta
		if life <= 0.0:
			# swap-remove with the last live particle
			var last := _count - 1
			if i != last:
				var tmp: Dictionary = _data[i]
				_data[i] = _data[last]
				_data[last] = tmp
			_count -= 1
			i -= 1
			continue

		p["life"] = life
		var drag: float = exp(-float(p["drag"]) * delta)
		var vel: Vector3 = p["vel"] * drag
		p["vel"] = vel
		p["pos"] = p["pos"] + vel * delta
		i -= 1

	var mm := multimesh
	for n in _count:
		var p: Dictionary = _data[n]
		var size: float = float(p["size"])
		var basis := Basis.IDENTITY.scaled(Vector3(size, size, size))
		mm.set_instance_transform(n, Transform3D(basis, p["pos"]))

		var col: Color = p["col"]
		var fade: float = clampf(float(p["life"]) / maxf(0.0001, float(p["max_life"])), 0.0, 1.0)
		col.a = fade
		mm.set_instance_color(n, col)

	mm.visible_instance_count = _count
