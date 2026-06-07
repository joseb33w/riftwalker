extends Node3D
class_name World

signal portal_reached
signal player_dead

var index := 0
var hero_class := "Knight"
var hero_tint := Color(0.8, 0.18, 0.2)

var player: Player
var camera_rig: CameraRig
var hud: Hud
var portal: Portal
var spawn_pos := Vector3(0, 0.2, 0)
var arena_half := 24.0
var enemies_left := 0
var enemies_total := 0
var _campfire_light: OmniLight3D
var _t := 0.0
var _cleared := false

func build(idx: int, cls: String, tint: Color) -> void:
	index = idx
	hero_class = cls
	hero_tint = tint
	match idx:
		0: _build_greenmoor()
		1: _build_helios()
		2: _build_foundry()
		_: _build_lastlight()
	_spawn_player()
	_make_camera()
	_make_hud()
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy:
			(e as Enemy).set_player(player)
	if portal:
		portal.set_active(enemies_total == 0)
	_update_objective()
	hud.show_banner(WorldDefs.WORLD_TITLES[idx])

# ---------- shared construction ----------

func _make_environment(p: Dictionary) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	env.sky = sky
	if p.get("sky_kind", "") == "hdr":
		var sh := ShaderMaterial.new()
		sh.shader = preload("res://shaders/hdri_sky.gdshader")
		var tex: Texture2D = load(p["sky_path"])
		sh.set_shader_parameter("panorama", tex)
		sh.set_shader_parameter("exposure", p.get("sky_exposure", 1.0))
		sh.set_shader_parameter("tint", p.get("sky_tint", Vector3(1, 1, 1)))
		sky.sky_material = sh
	else:
		var pm := PanoramaSkyMaterial.new()
		pm.panorama = load(p["sky_path"])
		pm.energy_multiplier = p.get("sky_energy", 1.0)
		sky.sky_material = pm
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = p.get("ambient_sky", 1.0)
	env.ambient_light_color = p.get("ambient_color", Color(0.5, 0.5, 0.5))
	env.ambient_light_energy = p.get("ambient_energy", 1.0)
	env.tonemap_mode = p.get("tonemap", Environment.TONE_MAPPER_AGX)
	env.tonemap_white = 6.0
	env.background_energy_multiplier = p.get("bg_energy", 1.0)
	if p.has("fog_color"):
		env.fog_enabled = true
		env.fog_light_color = p["fog_color"]
		env.fog_density = p.get("fog_density", 0.01)
		env.fog_sky_affect = p.get("fog_sky", 0.4)
		if p.has("fog_aerial"):
			env.fog_aerial_perspective = p["fog_aerial"]
	we.environment = env
	add_child(we)
	return we

func _make_sun(euler_deg: Vector3, color: Color, energy: float, shadows: bool = true) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z))
	sun.light_color = color
	sun.light_energy = energy
	sun.shadow_enabled = shadows
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	return sun

func _make_ground(tex_name: String, tile: float, tint: Color, size: float, psx: bool = false, rough: float = 0.95, metallic: float = 0.0) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	mesh.mesh = pm
	var mat := ShaderMaterial.new()
	if psx:
		mat.shader = preload("res://shaders/psx_ground.gdshader")
		mat.set_shader_parameter("albedo_tex", load("res://textures/%s.png" % tex_name))
		mat.set_shader_parameter("tile", tile)
		mat.set_shader_parameter("tint", tint)
	else:
		mat.shader = preload("res://shaders/ground.gdshader")
		mat.set_shader_parameter("albedo_tex", load("res://textures/%s.png" % tex_name))
		mat.set_shader_parameter("tile", tile)
		mat.set_shader_parameter("tint", tint)
		mat.set_shader_parameter("rough", rough)
		mat.set_shader_parameter("metallic_v", metallic)
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0, size)
	col.shape = box
	col.position.y = -0.5
	body.add_child(col)
	body.collision_layer = 1

func _arena_walls(half: float) -> void:
	arena_half = half
	var h := 8.0
	var th := 1.0
	var spots := [
		Vector3(0, h * 0.5, half), Vector3(0, h * 0.5, -half),
		Vector3(half, h * 0.5, 0), Vector3(-half, h * 0.5, 0),
	]
	var sizes := [
		Vector3(half * 2 + th, h, th), Vector3(half * 2 + th, h, th),
		Vector3(th, h, half * 2 + th), Vector3(th, h, half * 2 + th),
	]
	for i in range(spots.size()):
		var b := StaticBody3D.new()
		var c := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sizes[i]
		c.shape = bs
		b.add_child(c)
		b.position = spots[i]
		b.collision_layer = 1
		add_child(b)

func _place(path: String, pos: Vector3, rot_y: float = 0.0, scale: float = 1.0, opts: Dictionary = {}) -> Node3D:
	var m := Assets.instance(path)
	if m == null:
		return null
	add_child(m)
	m.position = pos
	m.rotation.y = rot_y
	m.scale = Vector3(scale, scale, scale)
	if opts.has("style"):
		Assets.style_model(m, opts["style"])
	if opts.get("collide", false):
		Assets.add_static_box(m, opts.get("shrink", 0.8), opts.get("height_scale", 1.0))
	return m

func _scatter(paths: Array, count: int, rmin: float, rmax: float, smin: float, smax: float, collide: bool = false, y: float = 0.0) -> void:
	for i in range(count):
		var ang := randf() * TAU
		var rad := randf_range(rmin, rmax)
		var pos := Vector3(cos(ang) * rad, y, sin(ang) * rad)
		if pos.distance_to(spawn_pos) < 4.0:
			continue
		var path: String = paths[randi() % paths.size()]
		_place(path, pos, randf() * TAU, randf_range(smin, smax), {"collide": collide, "shrink": 0.7})

func _spawn_player() -> void:
	player = Player.new()
	player.add_to_group("player")
	add_child(player)
	player.setup(hero_class, hero_tint)
	player.position = spawn_pos
	player.collision_layer = 2
	player.collision_mask = 1
	player.died.connect(_on_player_dead)

func _make_camera() -> void:
	camera_rig = CameraRig.new()
	camera_rig.target = player
	camera_rig.yaw = PI
	add_child(camera_rig)
	player.camera_rig = camera_rig

func _make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.bind(player, camera_rig)
	player.health_changed.connect(func(hp: int, mx: int) -> void:
		if hp < player.max_hp and hp > 0:
			hud.flash_hurt())

func _spawn_enemy(cfg: Dictionary, pos: Vector3) -> Enemy:
	var e := Enemy.new()
	add_child(e)
	e.setup(cfg)
	e.position = pos
	e.set_player(player)
	e.died.connect(_on_enemy_died)
	enemies_total += 1
	enemies_left += 1
	return e

func _spawn_enemy_ring(cfg: Dictionary, count: int, rmin: float, rmax: float, jitter_scale := 0.12) -> void:
	for i in range(count):
		var ang := (TAU * float(i) / float(count)) + randf_range(-0.4, 0.4)
		var rad := randf_range(rmin, rmax)
		var pos := spawn_pos + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		var c := cfg.duplicate(true)
		c["scale"] = cfg.get("scale", 1.0) * randf_range(1.0 - jitter_scale, 1.0 + jitter_scale)
		_spawn_enemy(c, pos)

func _make_portal(pos: Vector3, color: Color) -> void:
	portal = Portal.new()
	add_child(portal)
	portal.position = pos
	portal.set_color(color)
	portal.entered.connect(func() -> void: portal_reached.emit())

func _add_point_light(pos: Vector3, color: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	add_child(l)
	return l

func _add_campfire(pos: Vector3) -> void:
	_place("res://models/ms_campfire.glb", pos, 0, 1.0, {"collide": true, "shrink": 0.5})
	_campfire_light = _add_point_light(pos + Vector3(0, 1.0, 0), Color(1.0, 0.6, 0.25), 4.0, 12.0)
	var p := CPUParticles3D.new()
	add_child(p)
	p.position = pos + Vector3(0, 0.5, 0)
	p.amount = 22
	p.lifetime = 1.4
	p.direction = Vector3(0, 1, 0)
	p.spread = 14.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 1.0, 0)
	var em := SphereMesh.new()
	em.radius = 0.05; em.height = 0.1; em.radial_segments = 4; em.rings = 2
	var emat := StandardMaterial3D.new()
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.emission_enabled = true
	emat.emission = Color(1.0, 0.55, 0.2)
	emat.albedo_color = Color(1.0, 0.6, 0.25)
	em.material = emat
	p.mesh = em
	p.emitting = true

# Edge box prop (emissive accent strips, fences, low walls) built from a mesh, not a glb.
func _accent_box(pos: Vector3, sz: Vector3, color: Color, emissive := true, energy := 2.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	add_child(mi)
	mi.position = pos

# ---------- world 0: Greenmoor (medieval golden hour) ----------

func _build_greenmoor() -> void:
	spawn_pos = Vector3(0, 0.2, 0)
	_make_environment({
		"sky_kind": "hdr",
		"sky_path": "res://skies/w1_golden.hdr",
		"sky_exposure": 1.1,
		"sky_tint": Vector3(1.05, 0.96, 0.85),
		"ambient_color": Color(1.0, 0.85, 0.65),
		"ambient_energy": 0.9,
		"ambient_sky": 0.7,
		"tonemap": Environment.TONE_MAPPER_AGX,
		"fog_color": Color(0.95, 0.74, 0.45),
		"fog_density": 0.010,
		"fog_sky": 0.2,
		"fog_aerial": 0.3,
		"bg_energy": 1.0,
	})
	_make_sun(Vector3(-22, 47, 0), Color(1.0, 0.82, 0.55), 1.7, true)
	_add_point_light(Vector3(0, 4, 0), Color(1.0, 0.8, 0.5), 0.6, 30.0)
	_make_ground("grass", 16.0, Color(0.78, 0.82, 0.5), 90.0, false, 0.95)
	_arena_walls(26.0)
	# landmark buildings around the rim
	var blo := {"collide": true, "shrink": 0.78, "style": {"toon": true, "outline": true, "outline_width": 0.03}}
	_place("res://models/building_blacksmith_blue.glb", Vector3(-15, 0, -12), 0.7, 2.2, blo)
	_place("res://models/building_tower_B_blue.glb", Vector3(16, 0, -14), -0.5, 2.4, blo)
	_place("res://models/building_market_blue.glb", Vector3(14, 0, 12), 2.4, 2.2, blo)
	_place("res://models/building_well_blue.glb", Vector3(-12, 0, 13), 0.0, 2.2, blo)
	# nature scatter
	var trees := ["res://models/tree_blocks.glb", "res://models/tree_blocks_dark.glb", "res://models/tree_blocks_fall.glb", "res://models/tree_cone.glb", "res://models/tree_cone_dark.glb"]
	for i in range(16):
		var ang := randf() * TAU
		var rad := randf_range(10.0, 25.0)
		_place(trees[randi() % trees.size()], Vector3(cos(ang) * rad, 0, sin(ang) * rad), randf() * TAU, randf_range(3.2, 5.4), {"collide": true, "shrink": 0.22})
	var rocks := ["res://models/rock_largeA.glb", "res://models/rock_largeC.glb", "res://models/stone_largeB.glb"]
	for i in range(8):
		var ang := randf() * TAU
		var rad := randf_range(8.0, 23.0)
		_place(rocks[randi() % rocks.size()], Vector3(cos(ang) * rad, 0, sin(ang) * rad), randf() * TAU, randf_range(2.0, 3.6), {"collide": true, "shrink": 0.5})
	var foliage := ["res://models/plant_bushLarge.glb", "res://models/plant_bushDetailed.glb", "res://models/grass_large.glb"]
	for i in range(22):
		var ang := randf() * TAU
		var rad := randf_range(5.0, 24.0)
		_place(foliage[randi() % foliage.size()], Vector3(cos(ang) * rad, 0, sin(ang) * rad), randf() * TAU, randf_range(1.6, 3.0))
	# enemies: roaming kaykit skeletons (mixed types)
	var skel_paths := ["res://models/skeleton_warrior.glb", "res://models/skeleton_minion.glb", "res://models/skeleton_rogue.glb"]
	var sk_style := {"outline": true, "outline_width": 0.02}
	for i in range(6):
		var ang := TAU * float(i) / 6.0 + randf_range(-0.3, 0.3)
		var rad := randf_range(9.0, 16.0)
		var pos := spawn_pos + Vector3(cos(ang) * rad, 0, sin(ang) * rad)
		_spawn_enemy({
			"kind": "kaykit_skeleton",
			"path": skel_paths[i % skel_paths.size()],
			"hp": 50 + (i % 3) * 14,
			"speed": randf_range(2.2, 3.0),
			"damage": 9,
			"attack_range": 2.1,
			"scale": randf_range(0.95, 1.12),
			"style": sk_style,
		}, pos)
	_make_portal(Vector3(0, 0, -22), Color(0.55, 0.8, 1.0))

# ---------- world 1: Helios Station (sci-fi) ----------

func _build_helios() -> void:
	spawn_pos = Vector3(0, 0.2, 6)
	_make_environment({
		"sky_kind": "ldr",
		"sky_path": "res://skies/w2_planet.png",
		"sky_energy": 1.0,
		"ambient_color": Color(0.4, 0.5, 0.7),
		"ambient_energy": 0.7,
		"ambient_sky": 0.5,
		"tonemap": Environment.TONE_MAPPER_FILMIC,
		"fog_color": Color(0.3, 0.4, 0.6),
		"fog_density": 0.012,
		"fog_sky": 0.0,
		"bg_energy": 1.0,
	})
	_make_sun(Vector3(-40, 30, 0), Color(0.7, 0.8, 1.0), 1.1, true)
	_make_ground("metal_panel", 10.0, Color(0.55, 0.6, 0.7), 80.0, false, 0.5, 0.45)
	_arena_walls(24.0)
	# modular station bays
	var so := {"collide": true, "shrink": 0.82}
	_place("res://models/cargodepot_A.glb", Vector3(-13, 0, -10), 0.3, 3.0, so)
	_place("res://models/basemodule_A.glb", Vector3(14, 0, -8), -0.6, 3.0, so)
	_place("res://models/containers_B.glb", Vector3(12, 0, 11), 1.6, 2.6, so)
	_place("res://models/containers_D.glb", Vector3(-12, 0, 12), 2.4, 2.6, so)
	_place("res://models/cargo_A.glb", Vector3(-4, 0, -14), 0.0, 2.6, so)
	_place("res://models/lander_base.glb", Vector3(7, 0, 14), 0.8, 2.6, so)
	# emissive accent strips on the floor
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		_accent_box(Vector3(cos(ang) * 20.0, 0.05, sin(ang) * 20.0), Vector3(2.4, 0.1, 0.4), Color(0.2, 0.9, 1.0), true, 3.0)
	_add_point_light(Vector3(-8, 4, -6), Color(0.3, 0.8, 1.0), 2.4, 16.0)
	_add_point_light(Vector3(9, 4, 8), Color(0.6, 0.4, 1.0), 2.2, 16.0)
	_add_point_light(Vector3(0, 5, 0), Color(0.4, 0.7, 1.0), 1.2, 26.0)
	# alien monsters / robots
	_spawn_enemy_ring({
		"kind": "self_rig", "path": "res://models/q_monster_slime.glb",
		"hp": 60, "speed": 2.4, "damage": 10, "attack_range": 2.0, "scale": 1.3,
		"tint": Color(0.3, 1.0, 0.7), "tint_amount": 0.5,
		"style": {"emission": Color(0.2, 0.8, 0.6), "emission_energy": 0.9},
	}, 3, 8.0, 13.0)
	_spawn_enemy_ring({
		"kind": "self_rig", "path": "res://models/q_enemy_spider.glb",
		"hp": 44, "speed": 3.2, "damage": 8, "attack_range": 1.9, "scale": 1.5,
		"tint": Color(0.5, 0.4, 1.0), "tint_amount": 0.5,
		"style": {"emission": Color(0.5, 0.3, 1.0), "emission_energy": 0.8},
	}, 2, 10.0, 15.0)
	_spawn_enemy_ring({
		"kind": "self_rig", "path": "res://models/q_enemy_wasp.glb",
		"hp": 32, "speed": 3.4, "damage": 7, "attack_range": 2.0, "scale": 1.6, "fly": true, "fly_height": 2.2,
		"tint": Color(1.0, 0.6, 0.2), "tint_amount": 0.4,
		"style": {"emission": Color(1.0, 0.5, 0.1), "emission_energy": 1.0},
	}, 2, 9.0, 14.0)
	_make_portal(Vector3(0, 0, -20), Color(0.7, 0.5, 1.0))

# ---------- world 2: The Foundry (PSX industrial) ----------

func _build_foundry() -> void:
	spawn_pos = Vector3(0, 0.2, 8)
	get_viewport().scaling_3d_scale = 0.55
	_make_environment({
		"sky_kind": "ldr",
		"sky_path": "res://skies/w3_cloudy.png",
		"sky_energy": 0.5,
		"ambient_color": Color(0.4, 0.42, 0.4),
		"ambient_energy": 0.5,
		"ambient_sky": 0.3,
		"tonemap": Environment.TONE_MAPPER_FILMIC,
		"fog_color": Color(0.42, 0.46, 0.42),
		"fog_density": 0.045,
		"fog_sky": 0.9,
	})
	_make_sun(Vector3(-35, 60, 0), Color(0.7, 0.72, 0.68), 0.6, true)
	_make_ground("stone_floor", 9.0, Color(0.5, 0.5, 0.48), 80.0, true)
	_arena_walls(22.0)
	# the prebuilt PSX industrial environment as central scenery
	var env_glb := _place("res://models/industrialhorror_ps_like.glb", Vector3(0, 0, -6), 0.0, 3.0, {"style": {"nearest": true}})
	if env_glb:
		Assets.add_static_box(env_glb, 0.9, 1.0)
	# a few scattered barrels for cover
	for i in range(7):
		var ang := randf() * TAU
		var rad := randf_range(7.0, 16.0)
		_place(["res://models/Barrel_A.glb", "res://models/Barrel_C.glb", "res://models/Box_B.glb"][i % 3], Vector3(cos(ang) * rad, 0, sin(ang) * rad), randf() * TAU, randf_range(1.6, 2.2), {"collide": true, "shrink": 0.7, "style": {"nearest": true}})
	_add_point_light(Vector3(0, 3, -4), Color(1.0, 0.7, 0.4), 1.6, 14.0)
	# vermin in the rust
	_spawn_enemy_ring({
		"kind": "self_rig", "path": "res://models/q_enemy_rat.glb",
		"hp": 38, "speed": 3.4, "damage": 8, "attack_range": 1.8, "scale": 1.7,
		"tint": Color(0.45, 0.42, 0.4), "tint_amount": 0.4,
		"style": {"nearest": true},
	}, 4, 8.0, 14.0)
	_spawn_enemy_ring({
		"kind": "self_rig", "path": "res://models/q_enemy_spider.glb",
		"hp": 46, "speed": 2.9, "damage": 9, "attack_range": 1.9, "scale": 1.6,
		"tint": Color(0.3, 0.32, 0.3), "tint_amount": 0.55,
		"style": {"nearest": true},
	}, 3, 9.0, 15.0)
	_make_portal(Vector3(0, 0, 18), Color(0.9, 0.55, 0.3))

# ---------- world 3: Last Light (survival night) ----------

func _build_lastlight() -> void:
	spawn_pos = Vector3(0, 0.2, 6)
	_make_environment({
		"sky_kind": "hdr",
		"sky_path": "res://skies/w4_night.exr",
		"sky_exposure": 1.0,
		"sky_tint": Vector3(0.8, 0.85, 1.1),
		"ambient_color": Color(0.25, 0.3, 0.45),
		"ambient_energy": 0.5,
		"ambient_sky": 0.5,
		"tonemap": Environment.TONE_MAPPER_AGX,
		"fog_color": Color(0.12, 0.14, 0.22),
		"fog_density": 0.02,
		"fog_sky": 0.1,
	})
	_make_sun(Vector3(-50, 200, 0), Color(0.55, 0.62, 0.85), 0.4, true)
	_make_ground("dirt_ground", 13.0, Color(0.5, 0.46, 0.4), 80.0, false, 0.98)
	_arena_walls(22.0)
	_add_campfire(Vector3(0, 0, 0))
	# outpost clutter
	var oo := {"collide": true, "shrink": 0.72}
	_place("res://models/ms_cabinet_basic.glb", Vector3(-5, 0, -4), 0.4, 1.6, oo)
	_place("res://models/ms_control_box.glb", Vector3(5, 0, -3), -0.5, 1.6, oo)
	_place("res://models/ms_cable_reel.glb", Vector3(6, 0, 4), 0.0, 1.6, oo)
	_place("res://models/ms_brick_pile.glb", Vector3(-6, 0, 5), 0.0, 1.6, oo)
	for i in range(8):
		var ang := randf() * TAU
		var rad := randf_range(4.0, 12.0)
		_place(["res://models/Barrel_A.glb", "res://models/Barrel_C.glb", "res://models/Box_B.glb", "res://models/Crate.glb"][i % 4], Vector3(cos(ang) * rad, 0, sin(ang) * rad), randf() * TAU, randf_range(1.5, 2.0), {"collide": true, "shrink": 0.7})
	# night creatures
	_spawn_enemy_ring({
		"kind": "self_rig", "path": "res://models/q_monster_bat.glb",
		"hp": 30, "speed": 3.6, "damage": 8, "attack_range": 2.0, "scale": 1.6, "fly": true, "fly_height": 2.4,
		"tint": Color(0.4, 0.3, 0.45), "tint_amount": 0.5,
	}, 3, 9.0, 15.0)
	_spawn_enemy_ring({
		"kind": "self_rig", "path": "res://models/q_monster_skeleton.glb",
		"hp": 58, "speed": 2.5, "damage": 11, "attack_range": 2.1, "scale": 1.5,
		"tint": Color(0.7, 0.72, 0.7), "tint_amount": 0.3,
	}, 3, 8.0, 13.0)
	_spawn_enemy_ring({
		"kind": "self_rig", "path": "res://models/q_enemy_rat.glb",
		"hp": 34, "speed": 3.2, "damage": 7, "attack_range": 1.8, "scale": 1.6,
		"tint": Color(0.35, 0.32, 0.3), "tint_amount": 0.4,
	}, 2, 7.0, 12.0)
	_make_portal(Vector3(0, 0, -20), Color(0.6, 0.95, 0.8))

# ---------- runtime ----------

func _on_enemy_died(_e) -> void:
	enemies_left = max(0, enemies_left - 1)
	_update_objective()
	if enemies_left == 0 and not _cleared:
		_cleared = true
		if portal:
			portal.set_active(true)
		hud.show_banner("RIFT OPEN")

func _update_objective() -> void:
	if hud == null:
		return
	if enemies_left > 0:
		hud.set_objective("Clear the area")
		hud.set_count("Enemies remaining: %d / %d" % [enemies_left, enemies_total])
	else:
		hud.set_objective("Enter the rift")
		hud.set_count("")

func _on_player_dead() -> void:
	player_dead.emit()

func _process(dt: float) -> void:
	_t += dt
	if _campfire_light:
		_campfire_light.light_energy = 3.4 + sin(_t * 11.0) * 0.5 + sin(_t * 23.0) * 0.3
	if hud and portal and portal.active and player and is_instance_valid(player) and camera_rig:
		var cam := camera_rig.get_camera()
		if cam:
			var local := cam.global_transform.affine_inverse() * portal.global_position
			hud.set_compass(Vector2(local.x, local.z))
	elif hud:
		hud.set_compass(Vector2.ZERO)

func teardown() -> void:
	get_viewport().scaling_3d_scale = 1.0
