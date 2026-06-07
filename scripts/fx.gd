extends Node
class_name FX

# Combat juice: spark bursts, hit-flash, floating damage. Camera shake lives on CameraRig.

static func spark_burst(world: Node3D, pos: Vector3, color: Color = Color(1, 0.85, 0.4), amount: int = 16, scale: float = 1.0) -> void:
	if world == null or not world.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	world.add_child(p)
	p.global_position = pos
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 75.0
	p.initial_velocity_min = 2.5 * scale
	p.initial_velocity_max = 6.0 * scale
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.06 * scale
	p.scale_amount_max = 0.16 * scale
	p.mesh = _spark_mesh(color)
	p.emitting = true
	_autofree(world, p, 0.9)

static func _spark_mesh(color: Color) -> Mesh:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 5
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.material = mat
	return m

static func ring_impact(world: Node3D, pos: Vector3, color: Color = Color(1, 0.9, 0.5)) -> void:
	if world == null or not world.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	torus.material = mat
	mi.mesh = torus
	world.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.6, 0)
	mi.rotation.x = PI / 2.0
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(3.2, 3.2, 3.2), 0.28)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(mi.queue_free)

static func hit_flash(model: Node3D, color: Color = Color(1, 1, 1), energy: float = 2.6, dur: float = 0.14) -> void:
	if model == null or not model.is_inside_tree():
		return
	var mats: Array[StandardMaterial3D] = []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in range(max(1, mi.get_surface_override_material_count())):
			var mt := mi.get_surface_override_material(s)
			if mt is StandardMaterial3D:
				mats.append(mt)
	if mats.is_empty():
		return
	for mt in mats:
		if not mt.has_meta("flash_base_en"):
			mt.set_meta("flash_base_en", mt.emission_enabled)
			mt.set_meta("flash_base_col", mt.emission)
			mt.set_meta("flash_base_eg", mt.emission_energy_multiplier)
		mt.emission_enabled = true
		mt.emission = color
		mt.emission_energy_multiplier = energy
	var tw := model.create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(func() -> void:
		for mt in mats:
			mt.emission_enabled = mt.get_meta("flash_base_en", false)
			mt.emission = mt.get_meta("flash_base_col", Color.BLACK)
			mt.emission_energy_multiplier = mt.get_meta("flash_base_eg", 1.0)
	)

static func damage_popup(world: Node3D, pos: Vector3, amount: int, color: Color = Color(1, 0.95, 0.6)) -> void:
	if world == null or not world.is_inside_tree():
		return
	var lbl := Label3D.new()
	lbl.text = str(amount)
	lbl.font_size = 64
	lbl.outline_size = 18
	lbl.modulate = color
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = false
	lbl.pixel_size = 0.006
	world.add_child(lbl)
	lbl.global_position = pos + Vector3(randf_range(-0.3, 0.3), 1.4, 0)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 1.0, 0.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.15)
	tw.chain().tween_callback(lbl.queue_free)

static func _autofree(world: Node, node: Node, t: float) -> void:
	var tw := world.create_tween()
	tw.tween_interval(t)
	tw.tween_callback(node.queue_free)
