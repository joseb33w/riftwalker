extends Node
class_name Game

var hero_class := "Knight"
var hero_tint := Color(0.8, 0.18, 0.2)
var world_index := 0
var current_world: World
var ui_layer: CanvasLayer
var fade: ColorRect
var run_start_ms := 0
var best_ms := 0

func _ready() -> void:
	randomize()
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(fade)
	best_ms = _load_best()
	var dw := _debug_world()
	if dw >= 0:
		hero_tint = WorldDefs.TINTS[0]["color"]
		run_start_ms = Time.get_ticks_msec()
		_goto_world(dw)
		_fade_to(0.0, 0.6)
		return
	_show_title()
	_fade_to(0.0, 0.6)

# Optional deep-link for testing: open index.html#w=2 to jump straight to a world.
func _debug_world() -> int:
	if not OS.has_feature("web"):
		return -1
	var h: String = str(JavaScriptBridge.eval("window.location.hash", true))
	var idx := h.find("w=")
	if idx < 0:
		return -1
	var n := h.substr(idx + 2).to_int()
	if n >= 0 and n < WorldDefs.WORLD_COUNT:
		return n
	return -1

# ---------- title ----------

func _show_title() -> void:
	var c := Control.new()
	c.name = "TitleGate"
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gradient_bg(c)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(box)
	var t := Label.new()
	t.text = "RIFTWALKER"
	t.add_theme_font_size_override("font_size", 92)
	t.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var tap := Label.new()
	tap.text = "TAP TO BEGIN"
	tap.add_theme_font_size_override("font_size", 38)
	tap.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0))
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tap)
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func() -> void:
		c.queue_free()
		_show_start())
	c.add_child(btn)
	ui_layer.add_child(c)
	var tw := create_tween().set_loops()
	tw.tween_property(tap, "modulate:a", 0.3, 0.7)
	tw.tween_property(tap, "modulate:a", 1.0, 0.7)

# ---------- start / customization ----------

func _show_start() -> void:
	var ss := StartScreen.new()
	ss.name = "StartScreen"
	ui_layer.add_child(ss)
	ss.begin.connect(func(cls: String, tint: Color) -> void:
		hero_class = cls
		hero_tint = tint
		ss.queue_free()
		_start_journey())

func _start_journey() -> void:
	world_index = 0
	run_start_ms = Time.get_ticks_msec()
	_goto_world(0)

# ---------- world flow ----------

func _goto_world(i: int) -> void:
	world_index = i
	_fade_to(1.0, 0.45)
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		_swap_world(i)
		_fade_to(0.0, 0.55), CONNECT_ONE_SHOT)

func _swap_world(i: int) -> void:
	if current_world != null and is_instance_valid(current_world):
		current_world.teardown()
		current_world.queue_free()
	current_world = World.new()
	add_child(current_world)
	current_world.build(i, hero_class, hero_tint)
	current_world.portal_reached.connect(_on_portal)
	current_world.player_dead.connect(_on_player_dead)

func _on_portal() -> void:
	var nxt := world_index + 1
	if nxt >= WorldDefs.WORLD_COUNT:
		_victory()
	else:
		_goto_world(nxt)

func _on_player_dead() -> void:
	var over := _overlay("YOU FELL", "The rift reclaims you...", "RETRY AREA", Color(0.7, 0.2, 0.2))
	over.get_meta("action").pressed.connect(func() -> void:
		over.queue_free()
		_goto_world(world_index))

func _victory() -> void:
	var elapsed := Time.get_ticks_msec() - run_start_ms
	if best_ms == 0 or elapsed < best_ms:
		best_ms = elapsed
		_save_best(best_ms)
	var sub := "Clear time: %s     Best: %s" % [_fmt(elapsed), _fmt(best_ms)]
	var over := _overlay("RIFTS CLOSED", sub, "PLAY AGAIN", Color(0.2, 0.5, 0.35))
	over.get_meta("action").pressed.connect(func() -> void:
		over.queue_free()
		if current_world != null and is_instance_valid(current_world):
			current_world.teardown()
			current_world.queue_free()
			current_world = null
		_show_start())

# ---------- ui helpers ----------

func _overlay(title: String, subtitle: String, btn_text: String, accent: Color) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.66)
	c.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	c.add_child(box)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 78)
	t.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s := Label.new()
	s.text = subtitle
	s.add_theme_font_size_override("font_size", 28)
	s.add_theme_color_override("font_color", Color(0.85, 0.88, 0.96))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	var btn := Button.new()
	btn.text = btn_text
	btn.add_theme_font_size_override("font_size", 32)
	btn.custom_minimum_size = Vector2(360, 72)
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.set_corner_radius_all(14)
	btn.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate(); (hb as StyleBoxFlat).bg_color = accent.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hb)
	btn.add_theme_stylebox_override("pressed", hb)
	var bbox := HBoxContainer.new()
	bbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bbox.add_child(btn)
	box.add_child(bbox)
	c.set_meta("action", btn)
	ui_layer.add_child(c)
	return c

func _gradient_bg(parent: Control) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.10, 0.08, 0.16))
	grad.set_color(1, Color(0.02, 0.02, 0.05))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.4)
	gt.fill_to = Vector2(0.5, 1.0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	parent.add_child(tr)

func _fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, dur)

func _fmt(ms: int) -> String:
	var s := int(ms / 1000.0)
	return "%d:%02d" % [s / 60, s % 60]

func _load_best() -> int:
	if not OS.has_feature("web"):
		return 0
	var v: Variant = JavaScriptBridge.eval("window.localStorage.getItem('riftwalker_best') || '0'", true)
	return int(str(v))

func _save_best(ms: int) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.localStorage.setItem('riftwalker_best','%d')" % ms, true)
