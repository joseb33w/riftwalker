extends Control
class_name Hud

var player: Player
var camera_rig: CameraRig

var _joy_id := -2
var _joy_origin := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _look_id := -2
var _safe := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

var _hp := 1.0
var _objective := ""
var _count := ""
var _banner := ""
var _banner_a := 0.0
var _compass_dir := Vector2.ZERO   # screen-space toward portal, zero = hidden
var _hurt_flash := 0.0

var _btn_attack := Rect2()
var _btn_dodge := Rect2()
const JOY_R := 96.0
const KNOB_R := 46.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_read_safe()
	# Lay everything out against the LIVE (expanded) viewport so the joystick,
	# ATK/DASH buttons and the HP/objective HUD are always fully on-screen at any
	# orientation. Re-fit on resize/rotate AND after the first web frames (the
	# canvas size is not final on frame 0).
	get_viewport().size_changed.connect(_on_resize)
	_layout()
	set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_layout()

func _on_resize() -> void:
	_read_safe()
	_layout()

# Live expanded viewport size — never the stale 1280x720 base.
func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size

func bind(p: Player, cam: CameraRig) -> void:
	player = p
	camera_rig = cam
	if p != null:
		p.health_changed.connect(func(hp: int, mx: int) -> void:
			_hp = float(hp) / float(max(1, mx)))

func set_objective(text: String) -> void:
	_objective = text

func set_count(text: String) -> void:
	_count = text

func show_banner(text: String) -> void:
	_banner = text
	_banner_a = 1.0

func set_compass(dir: Vector2) -> void:
	_compass_dir = dir

func flash_hurt() -> void:
	_hurt_flash = 1.0

func _layout() -> void:
	var s := _vp()
	size = s
	position = Vector2.ZERO
	var m: float = 36.0 + float(_safe["right"])
	var bm: float = 44.0 + float(_safe["bottom"])
	var atk := 150.0
	var ddg := 112.0
	_btn_attack = Rect2(Vector2(s.x - m - atk, s.y - bm - atk), Vector2(atk, atk))
	# dodge sits up-left of attack, inside the screen
	_btn_dodge = Rect2(Vector2(s.x - m - atk - ddg - 22.0, s.y - bm - ddg + 8.0), Vector2(ddg, ddg))

func _read_safe() -> void:
	if not OS.has_feature("web"):
		return
	var js := """(() => { const d=document.createElement('div');
	  d.style.cssText='position:fixed;top:env(safe-area-inset-top);bottom:env(safe-area-inset-bottom);left:env(safe-area-inset-left);right:env(safe-area-inset-right)';
	  document.body.appendChild(d); const r=getComputedStyle(d);
	  const o={top:parseFloat(r.top)||0,bottom:parseFloat(r.bottom)||0,left:parseFloat(r.left)||0,right:parseFloat(r.right)||0};
	  d.remove(); return JSON.stringify(o);})()"""
	var raw: String = str(JavaScriptBridge.eval(js, true))
	if raw != "":
		var d: Variant = JSON.parse_string(raw)
		if d is Dictionary:
			_safe = d

func _process(dt: float) -> void:
	if player != null and is_instance_valid(player):
		var iv := _joy_vec
		player.move_input = iv
		player.set_run(iv.length() > 0.72)
	if _banner_a > 0.0:
		_banner_a = maxf(0.0, _banner_a - dt * 0.45)
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - dt * 1.6)
	queue_redraw()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _joy_id:
			_update_joy(d.position)
		elif d.index == _look_id and camera_rig != null:
			camera_rig.apply_look(d.relative)

func _on_press(idx: int, pos: Vector2) -> void:
	if player == null or player.is_dead():
		return
	if _btn_attack.has_point(pos):
		player.do_attack(); return
	if _btn_dodge.has_point(pos):
		player.do_dodge(); return
	if pos.x < _vp().x * 0.5 and _joy_id == -2:
		_joy_id = idx
		_joy_origin = pos
		_joy_vec = Vector2.ZERO
	elif _look_id == -2:
		_look_id = idx

func _on_release(idx: int) -> void:
	if idx == _joy_id:
		_joy_id = -2
		_joy_vec = Vector2.ZERO
	elif idx == _look_id:
		_look_id = -2

func _update_joy(pos: Vector2) -> void:
	var d := pos - _joy_origin
	if d.length() > JOY_R:
		d = d.normalized() * JOY_R
		_joy_origin = pos - d
	_joy_vec = Vector2(d.x / JOY_R, -d.y / JOY_R)

func _draw() -> void:
	var s := _vp()
	# hurt vignette
	if _hurt_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.7, 0.05, 0.05, 0.32 * _hurt_flash))
	# joystick
	if _joy_id != -2:
		draw_circle(_joy_origin, JOY_R, Color(1, 1, 1, 0.10))
		draw_arc(_joy_origin, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
		var knob := _joy_origin + Vector2(_joy_vec.x, -_joy_vec.y) * JOY_R
		draw_circle(knob, KNOB_R, Color(1, 1, 1, 0.28))
		draw_circle(knob, KNOB_R, Color(1, 1, 1, 0.85))
	else:
		var hint := Vector2(float(_safe["left"]) + 140.0, s.y - float(_safe["bottom"]) - 140.0)
		draw_arc(hint, JOY_R, 0, TAU, 40, Color(1, 1, 1, 0.16), 3.0, true)
	# attack button
	var ac := _btn_attack.get_center()
	draw_circle(ac, _btn_attack.size.x * 0.5, Color(0.95, 0.35, 0.25, 0.30))
	draw_arc(ac, _btn_attack.size.x * 0.5, 0, TAU, 48, Color(1, 0.7, 0.55, 0.85), 4.0, true)
	_label(ac, "ATK", 30, Color(1, 1, 1, 0.95))
	# dodge button
	var dc := _btn_dodge.get_center()
	draw_circle(dc, _btn_dodge.size.x * 0.5, Color(0.3, 0.6, 0.95, 0.26))
	draw_arc(dc, _btn_dodge.size.x * 0.5, 0, TAU, 40, Color(0.7, 0.85, 1.0, 0.8), 3.0, true)
	_label(dc, "DASH", 22, Color(1, 1, 1, 0.92))
	# health bar
	var hx: float = float(_safe["left"]) + 24.0
	var hy: float = float(_safe["top"]) + 24.0
	var hw := 340.0
	draw_rect(Rect2(hx - 3, hy - 3, hw + 6, 32), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(hx, hy, hw, 26), Color(0.18, 0.04, 0.05, 0.9))
	var col := Color(0.35, 0.85, 0.4).lerp(Color(0.9, 0.3, 0.25), 1.0 - _hp)
	draw_rect(Rect2(hx, hy, hw * _hp, 26), col)
	_text_left(Vector2(hx + 8, hy + 20), "HP", 18, Color(1, 1, 1, 0.9))
	# objective + count (centred, below the top safe-area)
	var oy: float = float(_safe["top"]) + 34.0
	if _objective != "":
		_text_center(Vector2(s.x * 0.5, oy), _objective, 26, Color(1, 0.95, 0.8, 0.95))
	if _count != "":
		_text_center(Vector2(s.x * 0.5, oy + 32.0), _count, 22, Color(1, 1, 1, 0.8))
	# compass arrow toward portal
	if _compass_dir.length() > 0.1:
		var cc := Vector2(s.x * 0.5, oy + 78.0)
		var dir := _compass_dir.normalized()
		var tip := cc + dir * 26
		var a := dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([tip, cc - dir * 10 + a * 14, cc - dir * 10 - a * 14]), Color(0.5, 0.9, 1.0, 0.9))
	# banner
	if _banner_a > 0.01:
		var fade: float = clampf(_banner_a * 1.4, 0.0, 1.0)
		_text_center(Vector2(s.x * 0.5, s.y * 0.32), _banner, 64, Color(1, 0.96, 0.85, fade))

func _font() -> Font:
	return ThemeDB.fallback_font

func _label(center: Vector2, txt: String, sz: int, col: Color) -> void:
	var f := _font()
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string(f, center - Vector2(w * 0.5, -sz * 0.34), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _text_center(center: Vector2, txt: String, sz: int, col: Color) -> void:
	var f := _font()
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string(f, center - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _text_left(pos: Vector2, txt: String, sz: int, col: Color) -> void:
	draw_string(_font(), pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
