extends CharacterBody3D
class_name Enemy

signal died(enemy)

enum St { CHASE, ATTACK, HIT, DEAD }

var hp := 60
var max_hp := 60
var speed := 2.6
var damage := 10
var attack_range := 2.0
var aggro_range := 26.0
var is_flyer := false
var fly_height := 1.8

var state: int = St.CHASE
var _attack_cd := 0.0
var _hit_t := 0.0
var _hit_done := false
var player: Node3D
var model: Node3D
var anim: AnimationPlayer
var clip := {}
var face_yaw := 0.0

const GRAVITY := 22.0
const TURN := 9.0

func setup(cfg: Dictionary) -> void:
	add_to_group("enemy")
	var path: String = cfg["path"]
	var kind: String = cfg.get("kind", "self_rig")
	if kind == "kaykit_skeleton":
		var d := Assets.make_kaykit_skeleton(path)
		model = d["model"]
		anim = d["anim"]
		clip = {
			"idle": Assets.resolve_clip(anim, ["Skeletons_Idle", "Idle_A"]),
			"walk": Assets.resolve_clip(anim, ["Skeletons_Walking", "Walking_A"]),
			"attack": Assets.resolve_clip(anim, ["Melee_Unarmed_Attack_Punch_A", "Melee_1H_Attack_Chop", "Skeletons_Taunt"]),
			"hit": Assets.resolve_clip(anim, ["Hit_A", "Hit_B"]),
			"death": Assets.resolve_clip(anim, ["Skeletons_Death", "Death_A"]),
		}
	else:
		model = Assets.instance(path)
		anim = Assets.find_anim_player(model)
		clip = {
			"idle": Assets.resolve_clip(anim, ["idle", "hover", "flying", "fly", "walk"]),
			"walk": Assets.resolve_clip(anim, ["run", "running", "walk", "flying", "fly", "move"]),
			"attack": Assets.resolve_clip(anim, ["attack", "bite", "hit"]),
			"hit": Assets.resolve_clip(anim, ["hit", "death"]),
			"death": Assets.resolve_clip(anim, ["death", "die"]),
		}
	add_child(model)
	if anim != null:
		anim.playback_default_blend_time = 0.12
	var sc: float = cfg.get("scale", 1.0)
	model.scale = Vector3(sc, sc, sc)
	if cfg.has("style"):
		Assets.style_model(model, cfg["style"])
	if cfg.has("tint"):
		Assets.tint_meshes(model, cfg["tint"], cfg.get("tint_amount", 0.6))
	hp = cfg.get("hp", 60); max_hp = hp
	speed = cfg.get("speed", 2.6)
	damage = cfg.get("damage", 10)
	attack_range = cfg.get("attack_range", 2.0)
	is_flyer = cfg.get("fly", false)
	fly_height = cfg.get("fly_height", 1.8)
	# collider
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * sc
	cap.height = max(1.0, 1.6 * sc)
	col.shape = cap
	col.position.y = cap.height * 0.5
	add_child(col)
	collision_layer = 4
	collision_mask = 1
	_play("idle")
	# random anim phase so a crowd doesn't move in lockstep
	if anim != null and anim.current_animation != "":
		anim.seek(randf() * 0.8, true)

func set_player(p: Node3D) -> void:
	player = p

func _physics_process(dt: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - dt)
	if state == St.DEAD:
		return
	if not is_flyer:
		if not is_on_floor():
			velocity.y -= GRAVITY * dt
		else:
			velocity.y = -1.0
	if player == null or not is_instance_valid(player):
		move_and_slide()
		return

	var to: Vector3 = player.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	var dist := flat.length()

	match state:
		St.HIT:
			_hit_t -= dt
			velocity.x = move_toward(velocity.x, 0, 30 * dt)
			velocity.z = move_toward(velocity.z, 0, 30 * dt)
			if is_flyer: velocity.y = move_toward(velocity.y, 0, 30 * dt)
			move_and_slide()
			if _hit_t <= 0.0:
				state = St.CHASE
			return
		St.ATTACK:
			velocity.x = move_toward(velocity.x, 0, 20 * dt)
			velocity.z = move_toward(velocity.z, 0, 20 * dt)
			if is_flyer: velocity.y = move_toward(velocity.y, 0, 20 * dt)
			_face(flat, dt)
			move_and_slide()
			return

	# CHASE
	if dist <= attack_range and _attack_cd <= 0.0:
		_begin_attack()
		return
	if dist < aggro_range:
		var dir := flat.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if is_flyer:
			var want_y: float = player.global_position.y + fly_height
			velocity.y = clampf((want_y - global_position.y) * 3.0, -speed, speed)
		_face(flat, dt)
		_play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, 10 * dt)
		velocity.z = move_toward(velocity.z, 0, 10 * dt)
		_play("idle")
	move_and_slide()

func _face(flat: Vector3, dt: float) -> void:
	if flat.length() < 0.05 or model == null:
		return
	face_yaw = lerp_angle(face_yaw, atan2(flat.x, flat.z), clampf(TURN * dt, 0, 1))
	model.rotation.y = face_yaw

func _begin_attack() -> void:
	state = St.ATTACK
	_attack_cd = 1.5
	_hit_done = false
	_play("attack")
	get_tree().create_timer(0.4).timeout.connect(_attack_hit, CONNECT_ONE_SHOT)
	get_tree().create_timer(0.95).timeout.connect(_attack_end, CONNECT_ONE_SHOT)

func _attack_hit() -> void:
	if state != St.ATTACK or _hit_done:
		return
	_hit_done = true
	if player == null or not is_instance_valid(player) or player.is_dead():
		return
	var to: Vector3 = player.global_position - global_position
	if Vector3(to.x, 0, to.z).length() <= attack_range + 0.8:
		player.take_damage(damage, to)

func _attack_end() -> void:
	if state == St.ATTACK:
		state = St.CHASE

func take_damage(amount: int, from_dir: Vector3) -> void:
	if state == St.DEAD:
		return
	hp = max(0, hp - amount)
	FX.hit_flash(model, Color(1, 1, 1), 2.8)
	FX.spark_burst(get_parent(), global_position + Vector3(0, 1.1, 0), Color(1.0, 0.5, 0.35), 14)
	FX.damage_popup(get_parent(), global_position, amount)
	velocity += from_dir.normalized() * 5.0
	if not is_flyer:
		velocity.y = 2.0
	if hp <= 0:
		_die()
	else:
		state = St.HIT
		_hit_t = 0.22
		_play("hit")

func _die() -> void:
	state = St.DEAD
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	_play("death")
	Audio.sfx("enemy_death")
	FX.spark_burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(1.0, 0.7, 0.3), 22, 1.3)
	died.emit(self)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(self, "position:y", position.y - 1.6, 0.7)
	tw.tween_callback(queue_free)

func is_dead() -> bool:
	return state == St.DEAD

func _play(key: String) -> void:
	var c: String = clip.get(key, "")
	if c == "" or anim == null:
		return
	if anim.current_animation == c:
		return
	anim.play(c)
