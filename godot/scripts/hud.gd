extends CanvasLayer
## HUD: score, wave, hull, shields, throttle, boost, banners.
##
## Built in code so the scene files stay tiny and there are no font assets to
## ship. All labels use the default theme font.

var _score: Label
var _wave: Label
var _contacts: Label
var _hull: ProgressBar
var _shield: ProgressBar
var _throttle: ProgressBar
var _boost: ProgressBar
var _banner: Label
var _flash: ColorRect

var _banner_time := 0.0
var _flash_amount := 0.0


func _ready() -> void:
	layer = 2

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# damage vignette sits under everything else
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1.0, 0.12, 0.24, 0.0)
	root.add_child(_flash)

	var tl := VBoxContainer.new()
	tl.position = Vector2(28, 22)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)

	tl.add_child(_small_label("SCORE"))
	_score = _big_label("0")
	tl.add_child(_score)
	_wave = _mid_label("WAVE 1")
	tl.add_child(_wave)

	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-260, 22)
	tr.custom_minimum_size = Vector2(230, 0)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)

	tr.add_child(_small_label("HULL"))
	_hull = _bar(Color(1.0, 0.42, 0.42))
	tr.add_child(_hull)

	tr.add_child(_small_label("SHIELDS"))
	_shield = _bar(Color(0.31, 0.82, 1.0))
	tr.add_child(_shield)

	_contacts = _small_label("0 CONTACTS")
	tr.add_child(_contacts)

	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(28, -96)
	bl.custom_minimum_size = Vector2(200, 0)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bl)

	bl.add_child(_small_label("THROTTLE"))
	_throttle = _bar(Color(0.56, 0.60, 1.0))
	bl.add_child(_throttle)

	bl.add_child(_small_label("BOOST"))
	_boost = _bar(Color(1.0, 0.70, 0.28))
	bl.add_child(_boost)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-300, 190)
	_banner.custom_minimum_size = Vector2(600, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	_banner.modulate.a = 0.0
	root.add_child(_banner)


func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.30, 0.42, 0.55))
	return l


func _mid_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.50, 0.85, 1.0))
	return l


func _big_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(0.87, 0.96, 1.0))
	return l


func _bar(fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(220, 10)
	b.show_percentage = false
	b.max_value = 100.0
	b.value = 100.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.16, 0.24, 0.85)
	bg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)

	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("fill", fg)

	return b


func set_values(score: int, wave: int, hull: float, shield: float, throttle: float, boost: float, contacts: int) -> void:
	_score.text = str(score)
	_wave.text = "WAVE %d" % wave
	_contacts.text = "%d CONTACT%s" % [contacts, "" if contacts == 1 else "S"]
	_hull.value = hull
	_shield.value = shield
	_throttle.value = throttle * 100.0
	_boost.value = boost


func show_banner(text: String, duration: float = 2.0) -> void:
	_banner.text = text
	_banner_time = duration
	_banner.modulate.a = 1.0


func flash(amount: float) -> void:
	_flash_amount = minf(1.0, _flash_amount + amount)


func tick(delta: float) -> void:
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time, 0.0, 1.0)

	if _flash_amount > 0.0:
		_flash_amount = maxf(0.0, _flash_amount - delta * 1.9)
		_flash.color.a = _flash_amount * 0.5
