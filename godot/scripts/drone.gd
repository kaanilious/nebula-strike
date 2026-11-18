extends Node3D
## Enemy drone. Built in code, steered by a simple seek / strafe behaviour.

signal wants_fire(pos: Vector3, dir: Vector3)

var hp := 5.0
var max_hp := 5.0
var radius := 5.2
var speed := 100.0
var is_boss := false
var score_value := 120
var vel := Vector3.ZERO
var alive := true

var _core_mat: StandardMaterial3D
var _body: Node3D
var _fire_cd := 2.0
var _flash := 0.0
var _wobble := 0.0


func _ready() -> void:
	_build()


func _build() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.17, 0.19, 0.24)
	shell.metallic = 0.9
	shell.roughness = 0.34

	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.08, 0.0, 0.03)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color(1.0, 0.18, 0.42)
	_core_mat.emission_energy_multiplier = 4.0

	# faceted hull: a 4-sided sphere is an octahedron
	var hull := SphereMesh.new()
	hull.radius = 1.5
	hull.height = 3.0
	hull.radial_segments = 4
	hull.rings = 2
	var hull_mi := _add(hull, shell, Vector3.ZERO)
	hull_mi.scale = Vector3(1.25, 0.78, 1.85)

	var core := SphereMesh.new()
	core.radius = 0.4
	core.height = 0.8
	core.radial_segments = 12
	core.rings = 10
	_add(core, _core_mat, Vector3(0, 0, -1.0))

	var wing_l := BoxMesh.new()
	wing_l.size = Vector3(2.7, 0.12, 0.75)
	var wl := _add(wing_l, shell, Vector3(1.55, 0, 0.15))
	wl.rotation_degrees.z = 0.24

	var wing_r := BoxMesh.new()
	wing_r.size = Vector3(2.7, 0.12, 0.75)
	var wr := _add(wing_r, shell, Vector3(-1.55, 0, 0.15))
	wr.rotation_degrees.z = -0.24

	var fin := BoxMesh.new()
	fin.size = Vector3(0.12, 1.15, 0.7)
	_add(fin, shell, Vector3(0, 0.7, 0.5))


func _add(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_body.add_child(mi)
	return mi


func setup(boss: bool, wave: int) -> void:
	is_boss = boss
	if boss:
		scale = Vector3.ONE * 4.2
		hp = 34.0
		radius = 17.0
		speed = 54.0
		score_value = 1500
		if _core_mat:
			_core_mat.emission = Color(1.0, 0.70, 0.0)
	else:
		hp = 5.0 + wave * 1.6
		radius = 5.2
		speed = randf_range(88.0, 122.0)
		score_value = 120
	max_hp = hp
	_fire_cd = randf_range(1.0, 3.0)
	_wobble = randf_range(0.0, TAU)


func take_damage(amount: float) -> bool:
	hp -= amount
	_flash = 0.09
	return hp <= 0.0


func tick(delta: float, target: Vector3) -> void:
	if not alive:
		return

	_wobble += delta * 1.7

	var to_target := target - global_position
	var dist := to_target.length()
	if dist < 0.001:
		dist = 0.001
	to_target /= dist

	var desired := to_target * speed
	if dist < (90.0 if is_boss else 42.0):
		desired *= -0.7
	elif dist < 160.0:
		# strafe around the player
		desired += Vector3(-to_target.z, 0.0, to_target.x) * speed * 0.85
	desired.y += sin(_wobble) * (8.0 if is_boss else 22.0)

	vel = vel.lerp(desired, 1.0 - exp(-1.4 * delta))
	global_position += vel * delta

	if vel.length_squared() > 0.001:
		var up := Vector3.UP
		if absf(vel.normalized().dot(up)) > 0.99:
			up = Vector3.RIGHT
		look_at(global_position + vel, up)

	if _flash > 0.0:
		_flash -= delta
		_core_mat.emission_energy_multiplier = 12.0
	else:
		_core_mat.emission_energy_multiplier = 4.0

	_fire_cd -= delta
	if _fire_cd <= 0.0 and dist < 340.0:
		_fire_cd = randf_range(0.9, 1.5) if is_boss else randf_range(1.4, 3.2)
		var dir := (target - global_position).normalized()
		if is_boss:
			for k in [-1.0, 0.0, 1.0]:
				wants_fire.emit(global_position, dir.rotated(Vector3.UP, k * 0.12))
		else:
			wants_fire.emit(global_position, dir)
