extends Control
class_name StartScreen

signal begin(class_id: String, tint: Color)

# The rotating 3D hero preview is rendered in the MAIN viewport (via `stage`, a
# Node3D placed in the main world by Game) rather than a SubViewport — a
# transparent own-world SubViewport hangs the GL-Compatibility/WebGL2 renderer
# on the first frame, which froze the game on the very first tap.

var class_idx := 0
var tint_idx := 0
var stage: Node3D
var _holder: Node3D
var _hero: Node3D
var _class_label: Label
var _tint_label: Label
var _swatches: Array[Panel] = []

func _ready() -> void:
	# A Control parented to a CanvasLayer does NOT auto-fill the viewport, so size
	# it to the LIVE (expanded) visible rect and keep it in sync on resize/rotate.
	# All UI lives inside Containers (never absolute offsets) so it can never
	# overlap or fall off-screen at any aspect ratio.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize_self()
	get_viewport().size_changed.connect(_resize_self)
	_build_stage()
	_build_vignette()
	_build_ui()
	_rebuild_hero()
	# the web canvas size is NOT final on the first frame — re-fit after two frames
	await get_tree().process_frame
	await get_tree().process_frame
	_resize_self()

func _resize_self() -> void:
	size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO

# ---------- 3D preview (main viewport) ----------

func _build_stage() -> void:
	if stage == null:
		return
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.7, 6.7)
	cam.rotation.x = deg_to_rad(-9)
	cam.fov = 30.0
	stage.add_child(cam)
	cam.current = true
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-35), deg_to_rad(40), 0)
	key.light_energy = 1.7
	key.light_color = Color(1.0, 0.95, 0.85)
	key.shadow_enabled = true
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-12), deg_to_rad(205), 0)
	rim.light_energy = 1.0
	rim.light_color = Color(0.55, 0.7, 1.0)
	stage.add_child(rim)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.09, 0.08, 0.17)
	psm.sky_horizon_color = Color(0.24, 0.16, 0.30)
	psm.ground_horizon_color = Color(0.10, 0.09, 0.15)
	psm.ground_bottom_color = Color(0.03, 0.03, 0.06)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.8
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.14, 0.26)
	env.fog_density = 0.014
	env.fog_sky_affect = 0.0
	we.environment = env
	stage.add_child(we)
	# soft disc under the hero
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.05; cyl.bottom_radius = 1.05; cyl.height = 0.06
	disc.mesh = cyl
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.12, 0.12, 0.18)
	dm.roughness = 0.65
	disc.material_override = dm
	stage.add_child(disc)
	_holder = Node3D.new()
	stage.add_child(_holder)

func _build_vignette() -> void:
	var top := _vgrad(Color(0.02, 0.02, 0.05, 0.92), Color(0.02, 0.02, 0.05, 0.0))
	top.anchor_left = 0.0; top.anchor_right = 1.0
	top.anchor_top = 0.0; top.anchor_bottom = 0.34
	top.offset_left = 0; top.offset_right = 0; top.offset_top = 0; top.offset_bottom = 0
	add_child(top)
	var bot := _vgrad(Color(0.02, 0.02, 0.05, 0.0), Color(0.01, 0.01, 0.04, 0.98))
	bot.anchor_left = 0.0; bot.anchor_right = 1.0
	bot.anchor_top = 0.52; bot.anchor_bottom = 1.0
	bot.offset_left = 0; bot.offset_right = 0; bot.offset_top = 0; bot.offset_bottom = 0
	add_child(bot)

func _vgrad(c_top: Color, c_bot: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, c_top)
	g.set_color(1, c_bot)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8; gt.height = 64
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

# ---------- UI ----------

func _build_ui() -> void:
	# Full-rect Margin -> VBox: title block pinned top, controls pinned bottom, an
	# expanding spacer between (the rotating hero shows through). Containers mean
	# nothing overlaps or clips at portrait OR landscape.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	# --- top: title + subtitle ---
	var title := Label.new()
	title.text = "RIFTWALKER"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Forge your hero, then walk the rifts"
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(0.75, 0.78, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub)

	# --- expanding gap (hero preview is visible through it) ---
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 20)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	# --- class selector ---
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 26)
	col.add_child(crow)
	crow.add_child(_arrow("<", _prev_class))
	_class_label = Label.new()
	_class_label.add_theme_font_size_override("font_size", 46)
	_class_label.add_theme_color_override("font_color", Color.WHITE)
	_class_label.custom_minimum_size = Vector2(300, 0)
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crow.add_child(_class_label)
	crow.add_child(_arrow(">", _next_class))

	# --- tint swatches ---
	var trow := HBoxContainer.new()
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	trow.add_theme_constant_override("separation", 16)
	col.add_child(trow)
	for i in range(WorldDefs.TINTS.size()):
		var sw := Panel.new()
		sw.custom_minimum_size = Vector2(72, 72)
		var sb := StyleBoxFlat.new()
		sb.bg_color = WorldDefs.TINTS[i]["color"]
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(4)
		sb.border_color = Color(1, 1, 1, 0.0)
		sw.add_theme_stylebox_override("panel", sb)
		sw.gui_input.connect(_swatch_input.bind(i))
		trow.add_child(sw)
		_swatches.append(sw)

	_tint_label = Label.new()
	_tint_label.add_theme_font_size_override("font_size", 26)
	_tint_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	_tint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_tint_label)

	# --- begin button ---
	var begin_btn := Button.new()
	begin_btn.text = "BEGIN JOURNEY"
	begin_btn.add_theme_font_size_override("font_size", 38)
	begin_btn.custom_minimum_size = Vector2(480, 92)
	begin_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.85, 0.5, 0.2)
	bsb.set_corner_radius_all(18)
	bsb.content_margin_left = 32; bsb.content_margin_right = 32
	begin_btn.add_theme_stylebox_override("normal", bsb)
	var bhover := bsb.duplicate()
	(bhover as StyleBoxFlat).bg_color = Color(0.95, 0.6, 0.28)
	begin_btn.add_theme_stylebox_override("hover", bhover)
	begin_btn.add_theme_stylebox_override("pressed", bhover)
	var bbox := HBoxContainer.new()
	bbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bbox.add_child(begin_btn)
	col.add_child(bbox)
	begin_btn.pressed.connect(_on_begin)

	var hint := Label.new()
	hint.text = "Joystick to move   -   drag to look   -   ATK / DASH buttons"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint)

	_update_labels()

func _arrow(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 44)
	b.custom_minimum_size = Vector2(92, 92)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.22, 0.9)
	sb.set_corner_radius_all(16)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate(); (hb as StyleBoxFlat).bg_color = Color(0.26, 0.24, 0.34, 0.95)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	b.pressed.connect(cb)
	return b

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		match (e as InputEventKey).keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_on_begin()
			KEY_LEFT, KEY_A:
				_prev_class()
			KEY_RIGHT, KEY_D:
				_next_class()

func _swatch_input(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		tint_idx = i
		Audio.sfx("ui")
		_apply_tint_to_hero()
		_update_labels()
	elif e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
		tint_idx = i
		Audio.sfx("ui")
		_apply_tint_to_hero()
		_update_labels()

func _prev_class() -> void:
	class_idx = (class_idx - 1 + WorldDefs.HERO_CLASSES.size()) % WorldDefs.HERO_CLASSES.size()
	Audio.sfx("ui")
	_rebuild_hero(); _update_labels()

func _next_class() -> void:
	class_idx = (class_idx + 1) % WorldDefs.HERO_CLASSES.size()
	Audio.sfx("ui")
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
	Assets.recolor_body(_hero, _current_tint())

func _process(dt: float) -> void:
	if _holder != null and is_instance_valid(_holder):
		_holder.rotation.y += dt * 0.6

func _on_begin() -> void:
	Audio.sfx("begin")
	begin.emit(WorldDefs.HERO_CLASSES[class_idx], _current_tint())
