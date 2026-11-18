extends Node3D
## One laser bolt. Pooled by Main; activate() re-uses it.

static var _mesh: BoxMesh = null
static var _mat_player: StandardMaterial3D = null
static var _mat_enemy: StandardMaterial3D = null

const SPEED_PLAYER := 620.0
const SPEED_ENEMY := 320.0

var dir := Vector3.FORWARD
var speed := SPEED_PLAYER
var life := 0.0
var damage := 1.0
var from_player := true
var radius := 1.6


func _ready() -> void:
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(0.18, 0.18, 3.6)

		_mat_player = _make_mat(Color(0.62, 0.95, 1.0))
		_mat_enemy = _make_mat(Color(1.0, 0.31, 0.55))

	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _mat_player
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Bolt"
	add_child(mi)

	visible = false


static func _make_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 4.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


func activate(pos: Vector3, direction: Vector3, player: bool, dmg: float, lifetime: float) -> void:
	global_position = pos
	dir = direction.normalized()
	from_player = player
	speed = SPEED_PLAYER if player else SPEED_ENEMY
	damage = dmg
	life = lifetime
	visible = true

	var mi: MeshInstance3D = get_node("Bolt")
	mi.material_override = _mat_player if player else _mat_enemy

	# orient the box's local -Z along the travel direction
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	look_at(global_position + dir, up)


func tick(delta: float) -> bool:
	life -= delta
	if life <= 0.0:
		visible = false
		return false
	global_position += dir * speed * delta
	return true


func deactivate() -> void:
	visible = false
	life = 0.0
