extends Node3D
## The player's interceptor.
##
## Godot convention: -Z is forward. The ship's meshes are built in code so the
## project has no binary model files to lose, and the whole thing stays readable
## and editable.

const MOUSE_SENS := 0.0022
const MAX_YAW := 2.6
const MAX_PITCH := 2.4
const BASE_SPEED := 46.0
const THROTTLE_SPEED := 108.0
const BOOST_MULT := 1.75
const ARENA_RADIUS := 900.0

var active := false
var throttle := 0.65
var boost := 100.0
var boosting := false
var speed := 0.0

var particles: Node = null

var _model: Node3D
var _pending_yaw := 0.0
var _pending_pitch := 0.0
var _bank := 0.0
var _time := 0.0


func _ready() -> void:
	_build_model()


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)

	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.79, 0.83, 0.89)
	hull.metallic = 0.95
	hull.roughness = 0.26

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.11, 0.14, 0.20)
	dark.metallic = 0.88
	dark.roughness = 0.42

	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.07, 0.04, 0.02)
	accent.emission_enabled = true
	accent.emission = Color(1.0, 0.54, 0.17)
	accent.emission_energy_multiplier = 3.0

	var canopy := StandardMaterial3D.new()
	canopy.albedo_color = Color(0.02, 0.06, 0.09)
	canopy.metallic = 0.6
	canopy.roughness = 0.18
	canopy.emission_enabled = true
	canopy.emission = Color(0.16, 0.85, 1.0)
	canopy.emission_energy_multiplier = 1.8

	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.56, 0.95, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.56, 0.95, 1.0)
	glow.emission_energy_multiplier = 6.0
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED

	# fuselage
	var body := CylinderMesh.new()
	body.top_radius = 0.52
	body.bottom_radius = 0.92
	body.height = 4.8
	body.radial_segments = 14
	_add_mesh(_model, body, hull, Vector3.ZERO, Vector3(90, 0, 0))

	# nose cone
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.52
	nose.height = 1.9
	nose.radial_segments = 14
	_add_mesh(_model, nose, hull, Vector3(0, 0, -3.32), Vector3(-90, 0, 0))

	# dorsal spine
	var spine := BoxMesh.new()
	spine.size = Vector3(0.34, 0.5, 3.4)
	_add_mesh(_model, spine, dark, Vector3(0, 0.62, 0.5), Vector3.ZERO)

	# canopy
	var cock := SphereMesh.new()
	cock.radius = 0.56
	cock.height = 1.12
	cock.radial_segments = 18
	cock.rings = 12
	var cock_mi := _add_mesh(_model, cock, canopy, Vector3(0, 0.44, -1.0), Vector3.ZERO)
	cock_mi.scale = Vector3(0.92, 0.66, 1.55)

	# main wing
	var wing := BoxMesh.new()
	wing.size = Vector3(5.4, 0.15, 1.45)
	_add_mesh(_model, wing, hull, Vector3(0, -0.06, 0.75), Vector3.ZERO)

	for s in [-1.0, 1.0]:
		var tip := BoxMesh.new()
		tip.size = Vector3(1.5, 0.12, 1.1)
		_add_mesh(_model, tip, dark, Vector3(s * 3.0, 0.1, 0.35), Vector3(0, s * -0.22, s * 0.28))

		var stripe := BoxMesh.new()
		stripe.size = Vector3(1.9, 0.06, 0.16)
		_add_mesh(_model, stripe, accent, Vector3(s * 1.7, 0.05, 0.28), Vector3.ZERO)

		var nacelle := CylinderMesh.new()
		nacelle.top_radius = 0.34
		nacelle.bottom_radius = 0.42
		nacelle.height = 1.5
		nacelle.radial_segments = 12
		_add_mesh(_model, nacelle, dark, Vector3(s * 1.5, -0.1, 1.7), Vector3(90, 0, 0))

		var eng := SphereMesh.new()
		eng.radius = 0.42
		eng.height = 0.84
		eng.radial_segments = 12
		eng.rings = 10
		var eng_mi := _add_mesh(_model, eng, glow, Vector3(s * 1.5, -0.1, 2.5), Vector3.ZERO)
		eng_mi.scale = Vector3(1.0, 1.0, 2.2)

		var gun := CylinderMesh.new()
		gun.top_radius = 0.09
		gun.bottom_radius = 0.09
		gun.height = 2.0
		gun.radial_segments = 8
		_add_mesh(_model, gun, dark, Vector3(s * 2.1, -0.02, -1.2), Vector3(90, 0, 0))


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func forward() -> Vector3:
	return -global_transform.basis.z.normalized()


func right() -> Vector3:
	return global_transform.basis.x.normalized()


## Both gun muzzles, in world space, with the ship's forward direction.
func muzzles() -> Array:
	var f := forward()
	var r := right()
	var o := global_position
	return [
		[o + f * 3.4 + r * 2.1, f],
		[o + f * 3.4 - r * 2.1, f],
	]


func reset(pos: Vector3 = Vector3.ZERO) -> void:
	# Assign through a local Transform3D: global_transform is a value type, so
	# writing to one of its members in place does not stick.
	var t := Transform3D(Basis.IDENTITY, pos)
	global_transform = t
	throttle = 0.65
	boost = 100.0
	boosting = false
	speed = 0.0
	_pending_yaw = 0.0
	_pending_pitch = 0.0
	_bank = 0.0
	if _model:
		_model.rotation = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pending_yaw += event.relative.x
		_pending_pitch += event.relative.y


func tick(delta: float) -> void:
	_time += delta

	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0

	if Input.is_key_pressed(KEY_LEFT):
		yaw += 1.5
	if Input.is_key_pressed(KEY_RIGHT):
		yaw -= 1.5
	if Input.is_key_pressed(KEY_UP):
		pitch += 1.3
	if Input.is_key_pressed(KEY_DOWN):
		pitch -= 1.3
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		roll += 2.2
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_D):
		roll -= 2.2

	yaw += clampf(-_pending_yaw * MOUSE_SENS * 12.0, -MAX_YAW, MAX_YAW)
	pitch += clampf(-_pending_pitch * MOUSE_SENS * 12.0, -MAX_PITCH, MAX_PITCH)
	_pending_yaw = 0.0
	_pending_pitch = 0.0

	yaw = clampf(yaw, -MAX_YAW, MAX_YAW)
	pitch = clampf(pitch, -MAX_PITCH, MAX_PITCH)

	var q := global_transform.basis.get_rotation_quaternion()
	q = q * Quaternion(Vector3.UP, yaw * delta)
	q = q * Quaternion(Vector3.RIGHT, pitch * delta)
	q = q * Quaternion(Vector3.BACK, roll * delta)

	var t := global_transform
	t.basis = Basis(q.normalized())
	global_transform = t

	_bank = lerpf(_bank, clampf(yaw * 0.22, -0.55, 0.55), 1.0 - exp(-6.0 * delta))
	_model.rotation.z = _bank

	if Input.is_key_pressed(KEY_W):
		throttle = minf(1.0, throttle + delta * 0.8)
	if Input.is_key_pressed(KEY_S):
		throttle = maxf(0.05, throttle - delta * 0.8)

	var want_boost := Input.is_key_pressed(KEY_SHIFT) and boost > 2.0
	boosting = want_boost
	if want_boost:
		boost = maxf(0.0, boost - delta * 34.0)
	else:
		boost = minf(100.0, boost + delta * 13.0)

	speed = BASE_SPEED + throttle * THROTTLE_SPEED
	if boosting:
		speed *= BOOST_MULT

	var f := forward()
	global_position += f * speed * delta

	var dist := global_position.length()
	if dist > ARENA_RADIUS:
		global_position *= ARENA_RADIUS / dist

	_emit_exhaust(delta, f)


func _emit_exhaust(delta: float, f: Vector3) -> void:
	if particles == null:
		return
	var r := right()
	var size_mul := 1.6 if boosting else 1.0
	for s in [-1.0, 1.0]:
		var origin := global_position - f * 2.6 + r * (s * 1.5)
		var jitter := Vector3(randf_range(-0.9, 0.9), randf_range(-0.9, 0.9), randf_range(-0.9, 0.9))
		var vel := -f * randf_range(10.0, 40.0) + Vector3(
			randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)
		)
		particles.emit(
			origin + jitter,
			vel,
			randf_range(0.16, 0.32),
			Color(0.35, 0.85, 1.0),
			randf_range(1.6, 2.8) * size_mul,
			3.0
		)
