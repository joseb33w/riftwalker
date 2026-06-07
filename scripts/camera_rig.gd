extends Node3D
class_name CameraRig

# SpringArm3D third-person follow camera with drag-look and additive shake.

var target: Node3D
var yaw: float = 0.0
var pitch: float = -0.32
var distance: float = 6.2
var pivot_height: float = 1.5
var follow_speed: float = 9.0

var _arm: SpringArm3D
var _cam: Camera3D
var _shake: float = 0.0
var _shake_seed: float = 0.0

const PITCH_MIN := -1.15
const PITCH_MAX := 0.45

func _ready() -> void:
	_arm = SpringArm3D.new()
	_arm.spring_length = distance
	_arm.margin = 0.4
	_arm.collision_mask = 1
	add_child(_arm)
	_cam = Camera3D.new()
	_cam.fov = 66.0
	_cam.current = true
	_arm.add_child(_cam)
	_shake_seed = randf() * 100.0
	if target != null:
		global_position = target.global_position + Vector3(0, pivot_height, 0)
		if target is CollisionObject3D:
			_arm.add_excluded_object((target as CollisionObject3D).get_rid())

func apply_look(delta: Vector2, sensitivity: float = 0.0055) -> void:
	yaw -= delta.x * sensitivity
	pitch = clampf(pitch - delta.y * sensitivity, PITCH_MIN, PITCH_MAX)

func add_shake(amount: float) -> void:
	_shake = minf(1.2, _shake + amount)

func get_camera() -> Camera3D:
	return _cam

func _process(dt: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var want := target.global_position + Vector3(0, pivot_height, 0)
	global_position = global_position.lerp(want, clampf(follow_speed * dt, 0.0, 1.0))
	var base := Basis.from_euler(Vector3(pitch, yaw, 0))
	if _shake > 0.001:
		_shake = maxf(0.0, _shake - dt * 2.2)
		var t := Time.get_ticks_msec() * 0.05
		var sx := sin(t * 1.7 + _shake_seed) * _shake * 0.06
		var sy := cos(t * 2.3 + _shake_seed) * _shake * 0.06
		base = base * Basis.from_euler(Vector3(sy, sx, 0))
	global_transform.basis = base
