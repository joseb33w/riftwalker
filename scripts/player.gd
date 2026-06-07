extends CharacterBody3D
class_name Player

signal health_changed(hp: int, max_hp: int)
signal died

enum St { IDLE, MOVE, ATTACK, DODGE, HIT, DEAD }

const WALK_SPEED := 3.6
const RUN_SPEED := 7.0
const ACCEL := 14.0
const GRAVITY := 22.0
const DODGE_SPEED := 11.0
const TURN_LERP := 14.0

var camera_rig: CameraRig
var move_input := Vector2.ZERO
var run_held := false

var state: int = St.IDLE
var max_hp := 100
var hp := 100
var base_damage := 34
var attack_range := 2.7
var attack_arc := 0.25      # dot threshold for the front cone
var _attack_cd := 0.0
var _hurt_cd := 0.0
var _dodge_t := 0.0
var _dodge_dir := Vector3.ZERO
var _hit_done := false

var model: Node3D
var anim: AnimationPlayer
var face_yaw := 0.0

var clip := {}

func setup(class_id: String, tint: Color) -> void:
	var path: String = Assets.HERO_GLB.get(class_id, Assets.HERO_GLB["Knight"])
	model = Assets.instance(path)
	add_child(model)
	# cel protagonist: toon shading + ink outline + accent tint on body/cape
	Assets.style_model(model, {"toon": true, "outline": true, "outline_width": 0.022})
	_apply_tint(tint)
	anim = Assets.find_anim_player(model)
	anim.playback_default_blend_time = 0.14
	clip = {
		"idle": Assets.resolve_clip(anim, ["Idle_A", "Idle_B", "Idle"]),
		"walk": Assets.resolve_clip(anim, ["Walking_A", "Walking_B", "Walking_C", "Walk"]),
		"run": Assets.resolve_clip(anim, ["Running_A", "Running_B", "Run"]),
		"attack": Assets.resolve_clip(anim, _attack_candidates(class_id)),
		"hit": Assets.resolve_clip(anim, ["Hit_A", "Hit_B", "Hit"]),
		"death": Assets.resolve_clip(anim, ["Death_A", "Death_B", "Death"]),
		"dodge": Assets.resolve_clip(anim, ["Dodge_Forward", "Dodge_Roll", "Roll"]),
	}
	match class_id:
		"Barbarian":
			max_hp = 120; base_damage = 40; attack_range = 2.9
		"Rogue":
			max_hp = 84; base_damage = 26; attack_range = 2.5
		"Mage":
			max_hp = 80; base_damage = 38; attack_range = 2.8
		_:
			max_hp = 100; base_damage = 34
	hp = max_hp
	# collider
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	_play("idle")

func _attack_candidates(class_id: String) -> Array:
	match class_id:
		"Barbarian":
			return ["Melee_2H_Attack_Chop", "Melee_2H_Attack_Slice", "Melee_1H_Attack_Chop", "Chop"]
		"Rogue":
			return ["Melee_Dualwield_Attack_Slice", "Melee_1H_Attack_Stab", "Melee_1H_Attack_Slice_Horizontal"]
		"Mage":
			return ["Melee_1H_Attack_Slice_Diagonal", "Ranged_Magic_Shoot", "Melee_1H_Attack_Chop"]
		_:
			return ["Melee_1H_Attack_Chop", "Melee_1H_Attack_Slice_Diagonal", "Chop"]

func _apply_tint(tint: Color) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var n := mi.name.to_lower()
		if n.find("body") >= 0 or n.find("cape") >= 0 or n.find("cloak") >= 0 or n.find("robe") >= 0 or n.find("arm") >= 0:
			for s in range(max(1, mi.get_surface_override_material_count())):
				var m := mi.get_surface_override_material(s)
				if m is StandardMaterial3D:
					m.albedo_color = m.albedo_color.lerp(tint, 0.55)

func reset_for_world() -> void:
	hp = max_hp
	state = St.IDLE
	velocity = Vector3.ZERO
	_play("idle")
	health_changed.emit(hp, max_hp)

func _physics_process(dt: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - dt)
	_hurt_cd = maxf(0.0, _hurt_cd - dt)
	if not is_on_floor():
		velocity.y -= GRAVITY * dt
	else:
		velocity.y = -1.0

	match state:
		St.DEAD:
			velocity.x = 0; velocity.z = 0
			move_and_slide()
			return
		St.DODGE:
			_dodge_t -= dt
			velocity.x = _dodge_dir.x * DODGE_SPEED
			velocity.z = _dodge_dir.z * DODGE_SPEED
			move_and_slide()
			if _dodge_t <= 0.0:
				state = St.IDLE
			return
		St.ATTACK:
			velocity.x = move_toward(velocity.x, 0, ACCEL * dt)
			velocity.z = move_toward(velocity.z, 0, ACCEL * dt)
			move_and_slide()
			_update_face(dt)
			return
		St.HIT:
			velocity.x = move_toward(velocity.x, 0, ACCEL * dt)
			velocity.z = move_toward(velocity.z, 0, ACCEL * dt)
			move_and_slide()
			return

	# IDLE / MOVE
	var dir := _wish_dir()
	var speed := (RUN_SPEED if run_held else WALK_SPEED)
	if dir.length() > 0.05:
		velocity.x = move_toward(velocity.x, dir.x * speed, ACCEL * dt)
		velocity.z = move_toward(velocity.z, dir.z * speed, ACCEL * dt)
		face_yaw = lerp_angle(face_yaw, atan2(dir.x, dir.z), clampf(TURN_LERP * dt, 0, 1))
		state = St.MOVE
	else:
		velocity.x = move_toward(velocity.x, 0, ACCEL * 1.5 * dt)
		velocity.z = move_toward(velocity.z, 0, ACCEL * 1.5 * dt)
		state = St.IDLE
	if model:
		model.rotation.y = face_yaw
	move_and_slide()
	_anim_locomotion()

func _wish_dir() -> Vector3:
	var iv := move_input
	if Input.is_action_pressed("move_left"): iv.x -= 1.0
	if Input.is_action_pressed("move_right"): iv.x += 1.0
	if Input.is_action_pressed("move_up"): iv.y += 1.0
	if Input.is_action_pressed("move_down"): iv.y -= 1.0
	iv.x = clampf(iv.x, -1, 1); iv.y = clampf(iv.y, -1, 1)
	if iv.length() < 0.05 or camera_rig == null:
		return Vector3.ZERO
	var b := camera_rig.global_transform.basis
	var fwd := -b.z; fwd.y = 0; fwd = fwd.normalized()
	var right := b.x; right.y = 0; right = right.normalized()
	var d := (fwd * iv.y + right * iv.x)
	return d.normalized() if d.length() > 1.0 else d

func _update_face(dt: float) -> void:
	if model:
		model.rotation.y = lerp_angle(model.rotation.y, face_yaw, clampf(TURN_LERP * dt, 0, 1))

func set_run(v: bool) -> void:
	run_held = v

func do_dodge() -> void:
	if state in [St.DEAD, St.DODGE, St.ATTACK, St.HIT]:
		return
	var dir := _wish_dir()
	if dir.length() < 0.1:
		dir = Vector3(sin(face_yaw), 0, cos(face_yaw))
	_dodge_dir = dir.normalized()
	face_yaw = atan2(_dodge_dir.x, _dodge_dir.z)
	if model: model.rotation.y = face_yaw
	_dodge_t = 0.42
	state = St.DODGE
	_play("dodge", "run")

func do_attack() -> void:
	if state in [St.DEAD, St.ATTACK, St.HIT, St.DODGE]:
		return
	if _attack_cd > 0.0:
		return
	_attack_cd = 0.55
	# aim-snap toward nearest enemy in reach so a stationary tap never whiffs
	var tgt := _nearest_enemy(attack_range * 1.8)
	if tgt != null:
		var to: Vector3 = (tgt as Node3D).global_position - global_position
		face_yaw = atan2(to.x, to.z)
		if model: model.rotation.y = face_yaw
	state = St.ATTACK
	_hit_done = false
	_play("attack")
	get_tree().create_timer(0.22).timeout.connect(_do_hit, CONNECT_ONE_SHOT)
	get_tree().create_timer(0.5).timeout.connect(_end_attack, CONNECT_ONE_SHOT)

func _end_attack() -> void:
	if state == St.ATTACK:
		state = St.IDLE

func _do_hit() -> void:
	if state != St.ATTACK or _hit_done:
		return
	_hit_done = true
	var face := Vector3(sin(face_yaw), 0, cos(face_yaw))
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		var dist := to.length()
		if dist > attack_range:
			continue
		if face.dot(to.normalized()) < attack_arc:
			continue
		hit_any = true
		e.take_damage(base_damage, (e.global_position - global_position).normalized())
	# JUICE FLOOR — always fire visible feedback on the swing
	var fxpos := global_position + face * 1.4 + Vector3(0, 1.0, 0)
	FX.spark_burst(get_parent(), fxpos, Color(1.0, 0.9, 0.5) if hit_any else Color(0.8, 0.85, 1.0), 18 if hit_any else 8)
	if hit_any:
		FX.ring_impact(get_parent(), fxpos, Color(1.0, 0.85, 0.45))
		if camera_rig: camera_rig.add_shake(0.35)
	else:
		if camera_rig: camera_rig.add_shake(0.12)

func _nearest_enemy(radius: float) -> Node:
	var best: Node = null
	var bd := radius
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead():
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < bd:
			bd = d; best = e
	return best

func take_damage(amount: int, from_dir: Vector3) -> void:
	if state == St.DEAD or _hurt_cd > 0.0:
		return
	hp = max(0, hp - amount)
	health_changed.emit(hp, max_hp)
	_hurt_cd = 0.45
	FX.hit_flash(model, Color(1, 0.4, 0.4), 2.2)
	if camera_rig: camera_rig.add_shake(0.5)
	velocity += from_dir.normalized() * 4.0
	if hp <= 0:
		_die()
	else:
		state = St.HIT
		_play("hit")
		get_tree().create_timer(0.32).timeout.connect(_end_hit, CONNECT_ONE_SHOT)

func _end_hit() -> void:
	if state == St.HIT:
		state = St.IDLE

func _die() -> void:
	state = St.DEAD
	_play("death")
	died.emit()

func is_dead() -> bool:
	return state == St.DEAD

func _anim_locomotion() -> void:
	if state == St.MOVE:
		var sp := Vector2(velocity.x, velocity.z).length()
		if run_held and sp > WALK_SPEED + 0.5:
			_play("run")
		else:
			_play("walk")
	elif state == St.IDLE:
		_play("idle")

func _play(key: String, fallback: String = "") -> void:
	var clip_name: String = clip.get(key, "")
	if clip_name == "" and fallback != "":
		clip_name = clip.get(fallback, "")
	if clip_name == "" or anim == null:
		return
	if anim.current_animation == clip_name:
		return
	anim.play(clip_name)
