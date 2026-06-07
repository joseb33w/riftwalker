extends Node
class_name Assets

# Central asset helpers: model loading, the shared KayKit Rig_Medium animation library
# (cached once, with a dot-bone remapped variant so the adventurer clips drive the kaykit
# skeleton enemy meshes), clip-name resolution, material styling, and collider derivation.

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

const HERO_GLB := {
	"Knight": "res://models/kk_Knight.glb",
	"Barbarian": "res://models/kk_Barbarian.glb",
	"Rogue": "res://models/kk_Rogue.glb",
	"Mage": "res://models/kk_Mage.glb",
}

static var _scene_cache: Dictionary = {}
static var _kaykit_lib_underscore: AnimationLibrary = null
static var _kaykit_lib_dot: AnimationLibrary = null

static func load_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]

static func instance(path: String) -> Node3D:
	var ps := load_scene(path)
	if ps == null:
		return null
	return ps.instantiate()

# ---- shared KayKit animation library (Rig_Medium, 132 clips) ----

static func _ensure_kaykit_libs() -> void:
	if _kaykit_lib_underscore != null:
		return
	var src: Node = load("res://models/kk_Knight.glb").instantiate()
	var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
	_kaykit_lib_underscore = ap.get_animation_library(ap.get_animation_library_list()[0])
	# build the dot-bone variant for skeleton meshes (handslot_r -> handslot.r etc.)
	var dot := AnimationLibrary.new()
	for clip in _kaykit_lib_underscore.get_animation_list():
		var a: Animation = _kaykit_lib_underscore.get_animation(clip).duplicate(true)
		for t in range(a.get_track_count()):
			var p := a.track_get_path(t)
			var names := str(p).get_slice(":", 0)
			var sub := p.get_concatenated_subnames()
			if sub != "":
				var ns := _dot_bone(sub)
				if ns != sub:
					a.track_set_path(t, NodePath(names + ":" + ns))
		dot.add_animation(clip, a)
	_kaykit_lib_dot = dot
	src.free()

static func _dot_bone(s: String) -> String:
	if s.ends_with("_r"):
		return s.substr(0, s.length() - 2) + ".r"
	if s.ends_with("_l"):
		return s.substr(0, s.length() - 2) + ".l"
	return s

# Returns the right library for a skeleton based on its actual bone naming convention.
static func kaykit_library_for(skel: Skeleton3D) -> AnimationLibrary:
	_ensure_kaykit_libs()
	if skel != null and skel.find_bone("handslot.r") >= 0:
		return _kaykit_lib_dot
	return _kaykit_lib_underscore

# Instance a kaykit skeleton enemy mesh and graft a working AnimationPlayer onto it.
static func make_kaykit_skeleton(path: String) -> Dictionary:
	var model: Node3D = instance(path)
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var lib := kaykit_library_for(skel)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	model.add_child(ap)
	ap.add_animation_library("", lib)
	return {"model": model, "anim": ap, "skeleton": skel}

# ---- clip resolution ----

static func find_anim_player(root: Node) -> AnimationPlayer:
	return root.find_child("AnimationPlayer", true, false)

static func resolve_clip(ap: AnimationPlayer, candidates: Array) -> String:
	if ap == null:
		return ""
	for c in candidates:
		if ap.has_animation(c):
			return c
	# fuzzy: case-insensitive substring match against the candidates' keywords
	var list := ap.get_animation_list()
	for c in candidates:
		var key := String(c).to_lower()
		for name in list:
			if String(name).to_lower().find(key) >= 0:
				return name
	return ""

# ---- material styling ----

static func _iter_meshes(root: Node) -> Array:
	var out: Array = []
	if root is MeshInstance3D:
		out.append(root)
	for m in root.find_children("*", "MeshInstance3D", true, false):
		out.append(m)
	return out

static func _base_mat(mi: MeshInstance3D, s: int) -> StandardMaterial3D:
	var existing: Material = mi.get_active_material(s)
	if existing is StandardMaterial3D:
		return (existing as StandardMaterial3D).duplicate()
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.8, 0.8, 0.8)
	return sm

# opts keys (all optional): toon(bool), outline(bool), outline_width(float),
# outline_color(Color), tint(Color), tint_amount(float 0..1), emission(Color),
# emission_energy(float), metallic(float), roughness(float), nearest(bool), rim(bool)
static func style_model(root: Node3D, opts: Dictionary) -> void:
	var outline: bool = opts.get("outline", false)
	for mi: MeshInstance3D in _iter_meshes(root):
		var count: int = max(1, mi.mesh.get_surface_count()) if mi.mesh != null else 1
		for s in range(count):
			var mat := _base_mat(mi, s)
			if opts.get("toon", false):
				mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
			if opts.has("tint"):
				var amt: float = opts.get("tint_amount", 1.0)
				mat.albedo_color = mat.albedo_color.lerp(opts["tint"], amt)
			if opts.has("emission"):
				mat.emission_enabled = true
				mat.emission = opts["emission"]
				mat.emission_energy_multiplier = opts.get("emission_energy", 1.5)
			if opts.has("metallic"):
				mat.metallic = opts["metallic"]
			if opts.has("roughness"):
				mat.roughness = opts["roughness"]
			if opts.get("nearest", false):
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if outline:
				var sh := ShaderMaterial.new()
				sh.shader = OUTLINE_SHADER
				sh.set_shader_parameter("outline", opts.get("outline_width", 0.025))
				sh.set_shader_parameter("col", opts.get("outline_color", Color(0.04, 0.03, 0.05)))
				mat.next_pass = sh
			mi.set_surface_override_material(s, mat)

static func tint_meshes(root: Node3D, color: Color, amount: float = 1.0) -> void:
	style_model(root, {"tint": color, "tint_amount": amount})

# ---- colliders ----

static func merged_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var a := m.get_aabb()
		# transform child AABB into n-local space
		var xf := n.global_transform.affine_inverse() * m.global_transform
		a = xf * a
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out

# Add a snug static box collider derived from the model's scaled mesh AABB.
static func add_static_box(model: Node3D, shrink: float = 0.82, height_scale: float = 1.0) -> StaticBody3D:
	var aabb := merged_aabb(model)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var sz := aabb.size
	box.size = Vector3(max(0.2, sz.x * shrink), max(0.4, sz.y * height_scale), max(0.2, sz.z * shrink))
	col.shape = box
	body.add_child(col)
	model.add_child(body)
	col.position = aabb.get_center()
	col.position.y = aabb.position.y + box.size.y * 0.5
	return body
