extends Control
class_name StartScreen

signal begin(class_id: String, tint: Color)

var class_idx := 0
var tint_idx := 0
var _holder: Node3D
var _hero: Node3D
var _class_label: Label
var _tint_label: Label
var _swatches: Array[Panel] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_preview()
	_build_ui()
	_rebuild_hero()

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08)
	add_child(bg)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.10, 0.08, 0.16))
	grad.set_color(1, Color(0.03, 0.03, 0.06))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.35)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 64; gt.height = 64
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tr)

func _build_preview() -> void:
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_preset(Control.PRESET_CENTER)
	cont.custom_minimum_size = Vector2(520, 520)
	cont.position = Vector2(-260, -300)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cont)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.size = Vector2i(520, 520)
	cont.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, 3.5)
	cam.rotation.x = deg_to_rad(-8)
	cam.fov = 40.0
	root.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-35), deg_to_rad(35), 0)
	key.light_energy = 1.6
	key.light_color = Color(1.0, 0.95, 0.85)
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-10), deg_to_rad(200), 0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.6, 0.7, 1.0)
	root.add_child(rim)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_color = Color(0.5, 0.52, 0.6)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = env
	root.add_child(we)
	# soft disc under the hero
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1; cyl.bottom_radius = 1.1; cyl.height = 0.05
	disc.mesh = cyl
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.15, 0.15, 0.22)
	disc.material_override = dm
	disc.position.y = 0.0
	root.add_child(disc)
	_holder = Node3D.new()
	root.add_child(_holder)

func _build_ui() -> void:
	var title := Label.new()
	title.text = "RIFTWALKER"
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 36
	add_child(title)
	var sub := Label.new()
	sub.text = "Forge your hero, then walk the rifts"
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.75, 0.78, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.position.y = 128
	add_child(sub)

	# bottom control stack
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 18)
	panel.position = Vector2(0, -300)
	panel.custom_minimum_size = Vector2(0, 280)
	add_child(panel)

	# class selector
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 24)
	panel.add_child(crow)
	crow.add_child(_arrow("<", _prev_class))
	_class_label = Label.new()
	_class_label.add_theme_font_size_override("font_size", 40)
	_class_label.add_theme_color_override("font_color", Color.WHITE)
	_class_label.custom_minimum_size = Vector2(260, 0)
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crow.add_child(_class_label)
	crow.add_child(_arrow(">", _next_class))

	# tint swatches
	var trow := HBoxContainer.new()
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	trow.add_theme_constant_override("separation", 16)
	panel.add_child(trow)
	for i in range(WorldDefs.TINTS.size()):
		var sw := Panel.new()
		sw.custom_minimum_size = Vector2(56, 56)
		var sb := StyleBoxFlat.new()
		sb.bg_color = WorldDefs.TINTS[i]["color"]
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(3)
		sb.border_color = Color(1, 1, 1, 0.0)
		sw.add_theme_stylebox_override("panel", sb)
		sw.gui_input.connect(_swatch_input.bind(i))
		trow.add_child(sw)
		_swatches.append(sw)

	_tint_label = Label.new()
	_tint_label.add_theme_font_size_override("font_size", 22)
	_tint_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	_tint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.add_child(_tint_label)

	# begin button
	var begin_btn := Button.new()
	begin_btn.text = "BEGIN JOURNEY"
	begin_btn.add_theme_font_size_override("font_size", 34)
	begin_btn.custom_minimum_size = Vector2(420, 78)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.85, 0.5, 0.2)
	bsb.set_corner_radius_all(14)
	begin_btn.add_theme_stylebox_override("normal", bsb)
	var bhover := bsb.duplicate()
	bhover.bg_color = Color(0.95, 0.6, 0.28)
	begin_btn.add_theme_stylebox_override("hover", bhover)
	begin_btn.add_theme_stylebox_override("pressed", bhover)
	var bbox := HBoxContainer.new()
	bbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bbox.add_child(begin_btn)
	panel.add_child(bbox)
	begin_btn.pressed.connect(_on_begin)

	var hint := Label.new()
	hint.text = "Move: left joystick   Look: drag right side   ATK / DASH buttons"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.add_child(hint)

	_update_labels()

func _arrow(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 44)
	b.custom_minimum_size = Vector2(80, 80)
	b.pressed.connect(cb)
	return b

func _swatch_input(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		tint_idx = i
		_apply_tint_to_hero()
		_update_labels()
	elif e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
		tint_idx = i
		_apply_tint_to_hero()
		_update_labels()

func _prev_class() -> void:
	class_idx = (class_idx - 1 + WorldDefs.HERO_CLASSES.size()) % WorldDefs.HERO_CLASSES.size()
	_rebuild_hero(); _update_labels()

func _next_class() -> void:
	class_idx = (class_idx + 1) % WorldDefs.HERO_CLASSES.size()
	_rebuild_hero(); _update_labels()

func _update_labels() -> void:
	_class_label.text = WorldDefs.HERO_CLASSES[class_idx]
	_tint_label.text = "Colour:  " + WorldDefs.TINTS[tint_idx]["name"]
	for i in range(_swatches.size()):
		var sb := _swatches[i].get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.border_color = Color(1, 1, 1, 1) if i == tint_idx else Color(1, 1, 1, 0)

func _current_tint() -> Color:
	return WorldDefs.TINTS[tint_idx]["color"]

func _rebuild_hero() -> void:
	if _holder == null:
		return
	if _hero != null and is_instance_valid(_hero):
		_hero.queue_free()
	var path: String = Assets.HERO_GLB[WorldDefs.HERO_CLASSES[class_idx]]
	_hero = Assets.instance(path)
	if _hero == null:
		return
	_holder.add_child(_hero)
	Assets.style_model(_hero, {"toon": true, "outline": true, "outline_width": 0.022})
	_apply_tint_to_hero()
	var ap := Assets.find_anim_player(_hero)
	if ap != null:
		var idle := Assets.resolve_clip(ap, ["Idle_A", "Idle_B", "Idle"])
		if idle != "":
			ap.play(idle)

func _apply_tint_to_hero() -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	var tint := _current_tint()
	for mi: MeshInstance3D in _hero.find_children("*", "MeshInstance3D", true, false):
		var n := mi.name.to_lower()
		if n.find("body") >= 0 or n.find("cape") >= 0 or n.find("cloak") >= 0 or n.find("robe") >= 0 or n.find("arm") >= 0:
			for s in range(max(1, mi.get_surface_override_material_count())):
				var m := mi.get_surface_override_material(s)
				if m is StandardMaterial3D:
					(m as StandardMaterial3D).albedo_color = (m as StandardMaterial3D).albedo_color.lerp(tint, 0.55)

func _process(dt: float) -> void:
	if _holder:
		_holder.rotation.y += dt * 0.6

func _on_begin() -> void:
	begin.emit(WorldDefs.HERO_CLASSES[class_idx], _current_tint())
