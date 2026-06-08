extends Area3D
class_name Portal

signal entered

var active := false
var color := Color(0.5, 0.8, 1.0)
var _ring: MeshInstance3D
var _disc: MeshInstance3D
var _light: OmniLight3D
var _parts: CPUParticles3D
var _disc_mat: StandardMaterial3D
var _t := 0.0
var _fired := false

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.4
	cyl.height = 3.2
	col.shape = cyl
	col.position.y = 1.6
	add_child(col)
	monitoring = true
	# The player CharacterBody3D lives on collision_layer 2 (see World._spawn_player).
	# An Area3D only reports a body whose layer is in the Area's mask, so this MUST
	# include bit 2 or walking into the rift silently does nothing.
	collision_mask = 2

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 1.85
	torus.rings = 24
	torus.ring_segments = 16
	_ring.mesh = torus
	_ring.position.y = 2.0
	add_child(_ring)

	_disc = MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(3.0, 3.6)
	pl.orientation = PlaneMesh.FACE_Z
	_disc.mesh = pl
	_disc.position.y = 2.0
	add_child(_disc)
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_disc.material_override = _disc_mat

	_light = OmniLight3D.new()
	_light.omni_range = 9.0
	_light.light_energy = 2.0
	_light.position.y = 2.0
	add_child(_light)

	_parts = CPUParticles3D.new()
	_parts.amount = 28
	_parts.lifetime = 1.6
	_parts.position.y = 0.2
	_parts.direction = Vector3(0, 1, 0)
	_parts.spread = 18.0
	_parts.initial_velocity_min = 1.2
	_parts.initial_velocity_max = 2.4
	_parts.gravity = Vector3.ZERO
	_parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_parts.emission_ring_radius = 1.5
	_parts.emission_ring_inner_radius = 0.4
	_parts.emission_ring_height = 0.1
	_parts.emission_ring_axis = Vector3(0, 1, 0)
	var pm := SphereMesh.new()
	pm.radius = 0.07; pm.height = 0.14; pm.radial_segments = 5; pm.rings = 3
	_parts.mesh = pm
	add_child(_parts)

	set_color(color)
	body_entered.connect(_on_body)
	set_active(false)

func set_color(c: Color) -> void:
	color = c
	var rm := StandardMaterial3D.new()
	rm.albedo_color = c
	rm.emission_enabled = true
	rm.emission = c
	rm.emission_energy_multiplier = 3.0
	_ring.material_override = rm
	_disc_mat.albedo_color = Color(c.r, c.g, c.b, 0.55)
	_disc_mat.emission_enabled = true
	_disc_mat.emission = c
	_light.light_color = c

func set_active(v: bool) -> void:
	var was := active
	active = v
	_parts.emitting = v
	_light.visible = v
	_disc.visible = v
	if not v:
		var rm := _ring.material_override as StandardMaterial3D
		if rm:
			rm.emission_energy_multiplier = 0.4
			rm.albedo_color = color.darkened(0.5)
	else:
		set_color(color)
		if not was:
			Audio.sfx("portal_open")

func _process(dt: float) -> void:
	_t += dt
	if _ring:
		_ring.rotation.z = _t * 1.2
	if active and _disc_mat:
		var p := 0.45 + 0.2 * sin(_t * 3.0)
		_disc_mat.albedo_color.a = p
		_light.light_energy = 1.6 + 0.8 * sin(_t * 3.0)

# Poll overlaps too (not just the body_entered edge): this catches the player
# already standing on the rift at the moment it opens, where no fresh enter event
# would ever fire.
func _physics_process(_dt: float) -> void:
	if not active or _fired:
		return
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			_trigger()
			return

func _on_body(body: Node) -> void:
	if active and not _fired and body.is_in_group("player"):
		_trigger()

func _trigger() -> void:
	_fired = true
	entered.emit()
