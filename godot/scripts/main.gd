extends Node3D
## Nebula Strike 3D - main game loop and orchestrator.
##
## Owns the world, the camera, the wave director, the laser pool and all the
## gameplay state. Every other script is a specialist: ship.gd flies, drone.gd
## seeks, asteroids.gd scatters, particles.gd draws, hud.gd displays.

const DroneScene := preload("res://scenes/Drone.tscn")
const LaserScript := preload("res://scripts/laser.gd")
const AsteroidsScript := preload("res://scripts/asteroids.gd")
const ParticlesScript := preload("res://scripts/particles.gd")
const HudScript := preload("res://scripts/hud.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const NebulaSky := preload("res://shaders/nebula_sky.gdshader")
const GlowShader := preload("res://shaders/billboard_glow.gdshader")

const LASER_POOL := 90
const BEST_PATH := "user://nebula_strike_3d.cfg"

enum State { MENU, PLAYING, PAUSED, OVER }

# --- state ---
var state: int = State.MENU
var score := 0
var best := 0
var wave := 1
var hull := 100.0
var shield := 100.0
var time := 0.0
var last_hit := -10.0
var shake := 0.0

var _wave_queue := 0
var _wave_spawn_timer := 0.0
var _wave_delay := 0.0
var _boss_pending := false
var _fire_timer := 0.0

# --- nodes ---
# Deliberately untyped: each is a scene node carrying its own script, so their
# methods (tick, show_banner, place_all...) are resolved at runtime.
var world: Node3D
var ship
var enemies_root: Node3D
var lasers_root: Node3D
var effects_root: Node3D
var asteroids
var particles
var hud
var sfx

var camera: Camera3D
var environment: Environment

var _lasers: Array = []
var _enemies: Array = []
var _cam_target := Vector3.ZERO

# --- UI ---
var _overlay: Control
var _overlay_title: Label
var _overlay_text: Label
var _overlay_button: Button
var _lock_hint: Label


func _ready() -> void:
	randomize()

	world = $World
	ship = $World/Ship
	enemies_root = $World/Enemies
	lasers_root = $World/Lasers
	effects_root = $World/Effects

	_build_environment()
	_build_camera()
	_build_world()
	_build_lasers()
	_build_hud()
	_build_overlay()

	sfx = SfxScript.new(self)

	_load_best()
	_reset_world()
	state = State.MENU
	_show_menu()


# =====================================================================
# setup
# =====================================================================

func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = NebulaSky
	sky.sky_material = sky_mat
	environment.sky = sky

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.0

	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.12
	environment.tonemap_white = 6.0

	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 0.85
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	environment.fog_enabled = true
	environment.fog_light_color = Color(0.02, 0.03, 0.07)
	environment.fog_density = 0.0005

	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.05
	environment.adjustment_saturation = 1.1

	var we := WorldEnvironment.new()
	we.environment = environment
	world.add_child(we)

	# key light: the distant star
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.81, 0.88, 1.0)
	key.light_energy = 2.4
	key.rotation_degrees = Vector3(-32, 128, 0)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 320.0
	world.add_child(key)

	# rim light: warm bounce from the nebula
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(1.0, 0.48, 0.30)
	rim.light_energy = 1.0
	rim.rotation_degrees = Vector3(24, -46, 0)
	world.add_child(rim)

	# distant planet with an atmospheric rim
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 760.0
	sphere.height = 1520.0
	sphere.radial_segments = 44
	sphere.rings = 30
	planet.mesh = sphere
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.14, 0.20, 0.37)
	pmat.roughness = 0.95
	pmat.metallic = 0.0
	pmat.emission_enabled = true
	pmat.emission = Color(0.03, 0.05, 0.12)
	planet.material_override = pmat
	planet.position = Vector3(1500, -560, -2500)
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(planet)

	var halo := MeshInstance3D.new()
	var halo_sphere := SphereMesh.new()
	halo_sphere.radius = 806.0
	halo_sphere.height = 1612.0
	halo_sphere.radial_segments = 44
	halo_sphere.rings = 30
	halo.mesh = halo_sphere
	var hmat := StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.albedo_color = Color(0.31, 0.66, 1.0, 0.20)
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hmat.cull_mode = BaseMaterial3D.CULL_FRONT
	hmat.disable_receive_shadows = true
	halo.material_override = hmat
	halo.position = planet.position
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(halo)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.4
	camera.far = 9000.0
	camera.position = Vector3(0, 9, 26)
	world.add_child(camera)
	camera.make_current()
	_cam_target = Vector3.ZERO


func _build_world() -> void:
	particles = ParticlesScript.new()
	particles.name = "Particles"
	effects_root.add_child(particles)

	asteroids = AsteroidsScript.new()
	asteroids.name = "Asteroids"
	effects_root.add_child(asteroids)

	ship.particles = particles
	ship.active = false

	_build_stars()


func _build_stars() -> void:
	var count := 2600
	var positions := PackedVector3Array()
	var colors := PackedColorArray()
	positions.resize(count)
	colors.resize(count)

	for i in count:
		var r := randf_range(1400.0, 3200.0)
		var u := randf_range(-1.0, 1.0)
		var th := randf_range(0.0, TAU)
		var s := sqrt(1.0 - u * u)
		positions[i] = Vector3(cos(th) * s, u, sin(th) * s) * r

		var t := randf()
		var base: Color
		if t < 0.62:
			base = Color(0.92, 0.96, 1.0)
		elif t < 0.86:
			base = Color(0.72, 0.84, 1.0)
		else:
			base = Color(1.0, 0.86, 0.74)
		var b := randf_range(0.45, 1.0)
		colors[i] = Color(base.r * b, base.g * b, base.b * b, 1.0)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	mm.mesh = quad
	mm.instance_count = count

	for i in count:
		var basis := Basis.IDENTITY.scaled(Vector3(2.4, 2.4, 2.4))
		mm.set_instance_transform(i, Transform3D(basis, positions[i]))
		mm.set_instance_color(i, colors[i])

	var mat := ShaderMaterial.new()
	mat.shader = GlowShader

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "StarField"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.top_level = true
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mmi)


func _build_lasers() -> void:
	for i in LASER_POOL:
		var l := LaserScript.new()
		l.name = "Laser%d" % i
		lasers_root.add_child(l)
		_lasers.append(l)


func _build_hud() -> void:
	hud = HudScript.new()
	hud.name = "HUD"
	add_child(hud)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.015, 0.035, 0.92)
	_overlay.add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-340, -170)
	box.custom_minimum_size = Vector2(680, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_overlay.add_child(box)

	_overlay_title = Label.new()
	_overlay_title.text = "NEBULA STRIKE 3D"
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 52)
	_overlay_title.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	box.add_child(_overlay_title)

	_overlay_text = Label.new()
	_overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_text.add_theme_font_size_override("font_size", 17)
	_overlay_text.add_theme_color_override("font_color", Color(0.64, 0.75, 0.85))
	box.add_child(_overlay_text)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(btn_row)

	_overlay_button = Button.new()
	_overlay_button.text = "LAUNCH"
	_overlay_button.custom_minimum_size = Vector2(240, 54)
	_overlay_button.add_theme_font_size_override("font_size", 20)
	_overlay_button.pressed.connect(_on_overlay_button)
	btn_row.add_child(_overlay_button)

	_lock_hint = Label.new()
	_lock_hint.text = "CLICK TO CAPTURE MOUSE"
	_lock_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lock_hint.position = Vector2(-160, -140)
	_lock_hint.custom_minimum_size = Vector2(320, 0)
	_lock_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_hint.add_theme_font_size_override("font_size", 14)
	_lock_hint.add_theme_color_override("font_color", Color(0.55, 0.68, 0.80))
	_lock_hint.modulate.a = 0.0
	layer.add_child(_lock_hint)


# =====================================================================
# flow
# =====================================================================

func _show_menu() -> void:
	_overlay_title.text = "NEBULA STRIKE 3D"
	_overlay_text.text = (
		"You are the last interceptor in the Helios belt.\n"
		+ "Break the drone waves, and put down the dreadnought that arrives every fifth wave.\n\n"
		+ "Mouse steers  ·  W/S throttle  ·  Shift boost  ·  Q/E roll\n"
		+ "Guns fire automatically  ·  P pause  ·  M mute  ·  F1 fullscreen"
	)
	_overlay_button.text = "LAUNCH"
	_overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_overlay_button() -> void:
	match state:
		State.PAUSED:
			_resume()
		_:
			_start()


func _start() -> void:
	score = 0
	hull = 100.0
	shield = 100.0
	time = 0.0
	last_hit = -10.0
	shake = 0.0
	_fire_timer = 0.0
	_wave_delay = 0.0
	_boss_pending = false
	_wave_queue = 0

	_reset_world()
	ship.active = true
	ship.reset(Vector3.ZERO)
	state = State.PLAYING
	_overlay.visible = false
	_begin_wave(1)

	if DisplayServer.get_name() != "headless" and not _is_touch():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pause() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	ship.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_overlay_title.text = "PAUSED"
	_overlay_text.text = "Score %d   ·   Wave %d" % [score, wave]
	_overlay_button.text = "RESUME"
	_overlay.visible = true


func _resume() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	ship.active = true
	_overlay.visible = false
	if not _is_touch():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _game_over() -> void:
	state = State.OVER
	ship.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	shake = 26.0
	sfx.play("over")
	_save_best()

	_overlay_title.text = "SHIP DESTROYED"
	_overlay_text.text = "Score %d   ·   Best %d   ·   Wave %d" % [score, best, wave]
	_overlay_button.text = "REDEPLOY"
	_overlay.visible = true


func _begin_wave(n: int) -> void:
	wave = n
	_wave_queue = mini(3 + n, 9)
	_wave_spawn_timer = 0.4
	_boss_pending = (n % 5 == 0)
	_wave_delay = 0.0
	hud.show_banner("WAVE %d%s" % [n, "  //  DREADNOUGHT" if _boss_pending else ""])
	sfx.play("wave")


func _reset_world() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()

	for l in _lasers:
		l.deactivate()

	if particles:
		particles.clear()
	if asteroids:
		asteroids.place_all(Vector3.ZERO)
	if ship:
		ship.reset(Vector3.ZERO)


# =====================================================================
# input
# =====================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P, KEY_ESCAPE:
				if state == State.PLAYING:
					_pause()
				elif state == State.PAUSED:
					_resume()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if state == State.MENU or state == State.OVER:
					_start()
				elif state == State.PAUSED:
					_resume()
			KEY_M:
				var muted: bool = sfx.toggle()
				hud.show_banner("SOUND OFF" if muted else "SOUND ON", 1.0)
			KEY_F1:
				var mode := DisplayServer.window_get_mode()
				if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	if event is InputEventMouseButton and event.pressed:
		if state == State.PLAYING and not _is_touch():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _is_touch() -> bool:
	return DisplayServer.is_touchscreen_available()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING:
		_pause()


# =====================================================================
# main loop
# =====================================================================

func _process(delta: float) -> void:
	time += delta

	match state:
		State.PLAYING:
			_tick_playing(delta)
		State.MENU:
			_tick_menu(delta)

	particles.tick(delta)
	_update_camera(delta)
	hud.tick(delta)

	_lock_hint.modulate.a = 1.0 if (state == State.PLAYING and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _is_touch()) else 0.0


func _tick_playing(delta: float) -> void:
	ship.tick(delta)
	_tick_waves(delta)
	_tick_lasers(delta)
	_tick_enemies(delta)
	_tick_asteroids(delta)

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = 0.135
		for m in ship.muzzles():
			_fire_laser(m[0], m[1], true, 1.0, 1.5)
		sfx.play("laser")

	if time - last_hit > 4.0:
		shield = minf(100.0, shield + delta * 16.0)

	shake = maxf(0.0, shake - 55.0 * delta)

	hud.set_values(
		score, wave, hull, shield, ship.throttle, ship.boost,
		_enemies.size() + maxi(0, _wave_queue)
	)


func _tick_menu(delta: float) -> void:
	# slow drift so the title screen is alive
	ship.rotate_y(delta * 0.12)
	asteroids.tick(delta, ship.global_position)


func _update_camera(delta: float) -> void:
	var basis := ship.global_transform.basis
	var fwd := -basis.z.normalized()

	var want := ship.global_position + basis * Vector3(0, 7.2, 19.0)
	camera.global_position = camera.global_position.lerp(want, 1.0 - exp(-9.0 * delta))

	var look := ship.global_position + fwd * 55.0
	_cam_target = _cam_target.lerp(look, 1.0 - exp(-11.0 * delta))
	camera.look_at(_cam_target, Vector3.UP)

	var fov_target := 70.0
	if state == State.PLAYING:
		fov_target += 9.0 if ship.boosting else 0.0
		fov_target += minf(6.0, maxf(0.0, ship.throttle - 0.6) * 14.0)
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-3.5 * delta))

	if shake > 0.05:
		camera.global_position += Vector3(
			randf_range(-1, 1) * shake * 0.22,
			randf_range(-1, 1) * shake * 0.22,
			0.0
		)
		camera.rotate_object_local(Vector3.FORWARD, randf_range(-1, 1) * shake * 0.0022)


# =====================================================================
# waves, enemies, lasers
# =====================================================================

func _tick_waves(delta: float) -> void:
	if _wave_delay > 0.0:
		_wave_delay -= delta
		if _wave_delay <= 0.0:
			_begin_wave(wave + 1)
		return

	if _boss_pending and _wave_queue <= 0 and _enemies.is_empty():
		_boss_pending = false
		_spawn_enemy(true)
		hud.show_banner("DREADNOUGHT INBOUND")
		return

	if _wave_queue > 0:
		_wave_spawn_timer -= delta
		if _wave_spawn_timer <= 0.0 and _enemies.size() < 9:
			_wave_spawn_timer = randf_range(0.5, 1.3)
			_wave_queue -= 1
			_spawn_enemy(false)
	elif not _boss_pending and _enemies.is_empty():
		_wave_delay = 2.6


func _spawn_enemy(boss: bool) -> void:
	var e := DroneScene.instantiate()
	enemies_root.add_child(e)
	e.setup(boss, wave)

	var dir := Vector3(randf_range(-1, 1), randf_range(-0.35, 1), randf_range(-1, 1))
	if dir.length_squared() < 0.01:
		dir = Vector3(0, 0.3, 1)
	dir = dir.normalized()

	e.global_position = ship.global_position + dir * randf_range(220.0, 380.0)
	e.vel = -dir * randf_range(30.0, 70.0)
	e.wants_fire.connect(_on_enemy_fire)
	_enemies.append(e)


func _on_enemy_fire(pos: Vector3, dir: Vector3) -> void:
	_fire_laser(pos, dir, false, 1.0, 3.2)
	sfx.play("enemy")


func _tick_enemies(delta: float) -> void:
	var i := _enemies.size() - 1
	while i >= 0:
		var e = _enemies[i]
		if not is_instance_valid(e) or not e.alive:
			_enemies.remove_at(i)
			i -= 1
			continue

		e.tick(delta, ship.global_position)

		var d: float = e.global_position.distance_to(ship.global_position)
		if d < e.radius + 4.0:
			_damage_player(34.0 if e.is_boss else 16.0, true)
			particles.burst(e.global_position, 18, 90.0, Color(1.0, 0.5, 0.6), 3.0, 0.7)
			_kill_enemy(e, true)
		i -= 1


func _kill_enemy(e, silent: bool) -> void:
	var idx := _enemies.find(e)
	if idx >= 0:
		_enemies.remove_at(idx)

	score += e.score_value
	var big: bool = e.is_boss
	particles.burst(e.global_position, 90 if big else 30, 160.0 if big else 95.0,
		Color(1.0, 0.55, 0.25), 7.0 if big else 3.4, 1.3 if big else 0.8)
	particles.burst(e.global_position, 40 if big else 14, 110.0 if big else 60.0,
		Color(0.5, 0.85, 1.0), 6.0 if big else 2.6, 0.9)
	if big:
		shake = minf(30.0, shake + 22.0)

	if not silent:
		sfx.play("bigboom" if big else "boom")

	e.queue_free()


func _tick_asteroids(delta: float) -> void:
	var hits: Array = asteroids.tick(delta, ship.global_position)
	for rock in hits:
		var away: Vector3 = (rock["pos"] as Vector3) - ship.global_position
		var d := away.length()
		if d < 0.001:
			d = 0.001
		var n := away / d
		var radius: float = rock["radius"]
		ship.global_position += n * -(radius + 5.0 - d) + n * 6.0
		particles.burst(rock["pos"], 14, 70.0, Color(0.9, 0.9, 1.0), 2.4, 0.6)
		_damage_player(18.0 + radius, true)

		rock["hp"] = int(rock["hp"]) - 1
		if int(rock["hp"]) <= 0:
			_destroy_rock(rock)


func _destroy_rock(rock: Dictionary) -> void:
	var pos: Vector3 = rock["pos"]
	var radius: float = rock["radius"]
	particles.burst(pos, int(6 + radius * 2.0), 40.0 + radius * 5.0, Color(0.75, 0.78, 0.85), 2.2 + radius * 0.22, 0.85)
	particles.burst(pos, int(3 + radius), 30.0 + radius * 4.0, Color(1.0, 0.7, 0.4), 2.0 + radius * 0.16, 0.6)
	score += int(8 + radius * 2.2)
	sfx.play("boom" if radius > 9.0 else "hit")
	asteroids.destroy_rock(rock)


func _fire_laser(pos: Vector3, dir: Vector3, from_player: bool, dmg: float, lifetime: float) -> void:
	for l in _lasers:
		if not l.visible:
			l.activate(pos, dir, from_player, dmg, lifetime)
			return


func _tick_lasers(delta: float) -> void:
	for l in _lasers:
		if not l.visible:
			continue
		if not l.tick(delta):
			continue

		if l.from_player:
			if _laser_hits_rock(l) or _laser_hits_enemy(l):
				l.deactivate()
		else:
			if l.global_position.distance_to(ship.global_position) < 12.0:
				l.deactivate()
				particles.burst(l.global_position, 8, 55.0, Color(1.0, 0.4, 0.6), 2.0, 0.4)
				_damage_player(9.0, false)


func _laser_hits_rock(l) -> bool:
	for rock in asteroids.rocks:
		if not rock["alive"]:
			continue
		var rr: float = float(rock["radius"]) + 1.2
		if l.global_position.distance_squared_to(rock["pos"]) < rr * rr:
			rock["hp"] = int(rock["hp"]) - 1
			if int(rock["hp"]) <= 0:
				_destroy_rock(rock)
			else:
				particles.burst(l.global_position, 4, 45.0, Color(0.9, 0.95, 1.0), 1.6, 0.3)
				sfx.play("hit")
			return true
	return false


func _laser_hits_enemy(l) -> bool:
	for e in _enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var rr: float = e.radius + 1.4
		if l.global_position.distance_squared_to(e.global_position) < rr * rr:
			var dead: bool = e.take_damage(l.damage)
			if dead:
				_kill_enemy(e, false)
			else:
				particles.burst(l.global_position, 3, 40.0, Color(1.0, 0.6, 0.8), 1.5, 0.25)
				sfx.play("hit")
			return true
	return false


# =====================================================================
# damage, score, save
# =====================================================================

func _damage_player(amount: float, big: bool) -> void:
	if state != State.PLAYING:
		return

	if shield > 0.0:
		shield = maxf(0.0, shield - amount * 1.35)
		amount *= 0.3

	hull = maxf(0.0, hull - amount)
	last_hit = time
	shake = minf(24.0, shake + (16.0 if big else 7.0))
	hud.flash(0.85 if big else 0.42)
	sfx.play("hurt")

	if hull <= 0.0:
		_game_over()


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(BEST_PATH) == OK:
		best = int(cfg.get_value("score", "best", 0))


func _save_best() -> void:
	if score <= best:
		return
	best = score
	var cfg := ConfigFile.new()
	cfg.load(BEST_PATH)
	cfg.set_value("score", "best", best)
	cfg.save(BEST_PATH)
