class_name ArenaProps
extends RefCounted
## Builds a zone's static props from its ZoneTheme, one MultiMeshInstance3D
## per mesh kind: pillars with bases and capitals along the inside of the
## walls, glowing lanterns on some of them, and houses with stacked roofs and
## trees outside the walls. Props are scenery only: enemies and the player
## never collide with them, which is why none stand inside the arena.

const PILLAR_SEGMENTS := 12
const LANTERN_SEGMENTS := 8
const CANOPY_SEGMENTS := 8
## Houses and trees keep this far apart, and this far outside the walls.
const OUTSIDE_SPACING := 9.0
const OUTSIDE_GAP := 5.0
const PLACEMENT_TRIES := 30


static func build(parent: Node3D, theme: ZoneTheme, half_extent: float, wall_thickness: float,
		rng: RandomNumberGenerator) -> void:
	var lit := _lit_material()
	var glow := _glow_material()
	if theme.pillar_spacing > 0.0:
		_build_pillars(parent, theme, half_extent, lit, glow)
	var taken: Array[Vector2] = []
	if theme.house_count > 0:
		_build_houses(parent, theme, half_extent + wall_thickness, rng, lit, taken)
	if theme.tree_count > 0:
		_build_trees(parent, theme, half_extent + wall_thickness, rng, lit, taken)


## Ground positions where pillars stand, just inside the walls.
static func pillar_spots(half_extent: float, spacing: float, radius: float) -> PackedVector2Array:
	var spots := PackedVector2Array()
	var inset := half_extent - radius - 0.2
	var per_side := maxi(1, floori(half_extent * 2.0 / spacing))
	var step := half_extent * 2.0 / per_side
	for k in per_side:
		var along := -half_extent + step * (k + 0.5)
		spots.append(Vector2(along, -inset))
		spots.append(Vector2(along, inset))
		spots.append(Vector2(-inset, along))
		spots.append(Vector2(inset, along))
	return spots


static func _build_pillars(parent: Node3D, theme: ZoneTheme, half_extent: float,
		lit: Material, glow: Material) -> void:
	var r := theme.pillar_radius
	var height := theme.pillar_height
	var spots := pillar_spots(half_extent, theme.pillar_spacing, r)
	var shafts: Array[Transform3D] = []
	var trims: Array[Transform3D] = []
	var lanterns: Array[Transform3D] = []
	for k in spots.size():
		var p := spots[k]
		shafts.append(Transform3D(Basis.from_scale(Vector3(r, height, r)),
				Vector3(p.x, height * 0.5, p.y)))
		trims.append(Transform3D(Basis.from_scale(Vector3(r * 2.6, 0.5, r * 2.6)),
				Vector3(p.x, 0.25, p.y)))
		trims.append(Transform3D(Basis.from_scale(Vector3(r * 2.9, 0.45, r * 2.9)),
				Vector3(p.x, height - 0.22, p.y)))
		if theme.lantern_every > 0 and k % theme.lantern_every == 0:
			# Hang it on the side facing the middle of the arena.
			var inward := -p.normalized() if p != Vector2.ZERO else Vector2.ZERO
			var at := p + inward * (r + 0.45)
			lanterns.append(Transform3D(Basis.from_scale(Vector3(0.38, 0.7, 0.38)),
					Vector3(at.x, height * 0.55, at.y)))
	_add_batch(parent, "Pillars", _cylinder(1.0, 1.0, PILLAR_SEGMENTS, lit), shafts,
			theme.pillar_color, true)
	_add_batch(parent, "PillarTrims", _box(lit), trims, theme.pillar_trim_color, true)
	if not lanterns.is_empty():
		_add_batch(parent, "Lanterns", _cylinder(0.8, 1.0, LANTERN_SEGMENTS, glow), lanterns,
				theme.lantern_color, false)


static func _build_houses(parent: Node3D, theme: ZoneTheme, inner: float,
		rng: RandomNumberGenerator, lit: Material, taken: Array[Vector2]) -> void:
	var bodies: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	for n in theme.house_count:
		var at := _outside_spot(inner, theme.outside_reach, rng, taken)
		if is_nan(at.x):
			continue
		var w := rng.randf_range(6.0, 10.0)
		var d := rng.randf_range(5.0, 8.0)
		var tall := rng.randf_range(3.0, 4.2)
		var yaw := atan2(at.x, at.y)  # face the arena
		var turn := Basis(Vector3.UP, yaw)
		var origin := Vector3(at.x, 0.0, at.y)
		bodies.append(Transform3D(turn * Basis.from_scale(Vector3(w, tall, d)),
				origin + Vector3(0.0, tall * 0.5, 0.0)))
		roofs.append(_roof(turn, origin + Vector3(0.0, tall, 0.0), w * 1.35, d * 1.4, tall * 0.55))
		if rng.randf() < 0.5:
			# A second, smaller story with its own roof.
			var upper := tall * 0.7
			var base_y := tall + tall * 0.35
			bodies.append(Transform3D(turn * Basis.from_scale(Vector3(w * 0.55, upper, d * 0.55)),
					origin + Vector3(0.0, base_y + upper * 0.5, 0.0)))
			roofs.append(_roof(turn, origin + Vector3(0.0, base_y + upper, 0.0), w * 0.85, d * 0.9,
					upper * 0.6))
	_add_batch(parent, "Houses", _box(lit), bodies, theme.house_color, true)
	_add_batch(parent, "Roofs", _cylinder(0.0, 1.0, 4, lit), roofs, theme.roof_color, true)


## A four-sided pyramid roof of the given footprint, sitting on base.
static func _roof(turn: Basis, base: Vector3, width: float, depth: float, height: float) -> Transform3D:
	# The 4-segment cylinder's corners lie on its radius; turning it 45 degrees
	# lines its edges up with the house, each edge sqrt(2) wide per unit radius.
	var square := Basis(Vector3.UP, PI * 0.25)
	var scale_xz := Vector3(width / sqrt(2.0), height, depth / sqrt(2.0))
	return Transform3D(turn * Basis.from_scale(scale_xz) * square,
			base + Vector3(0.0, height * 0.5, 0.0))


static func _build_trees(parent: Node3D, theme: ZoneTheme, inner: float,
		rng: RandomNumberGenerator, lit: Material, taken: Array[Vector2]) -> void:
	var trunks: Array[Transform3D] = []
	var canopies: Array[Transform3D] = []
	var bare := theme.leaf_color.a <= 0.0
	for n in theme.tree_count:
		var at := _outside_spot(inner, theme.outside_reach, rng, taken)
		if is_nan(at.x):
			continue
		var tall := rng.randf_range(3.5, 6.5)
		var r := rng.randf_range(0.22, 0.4)
		var origin := Vector3(at.x, 0.0, at.y)
		trunks.append(Transform3D(Basis.from_scale(Vector3(r, tall, r)),
				origin + Vector3(0.0, tall * 0.5, 0.0)))
		if bare:
			for b in 3:
				var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT,
						rng.randf_range(0.5, 0.9))
				var length := tall * rng.randf_range(0.35, 0.55)
				var start := origin + Vector3(0.0, tall * rng.randf_range(0.55, 0.9), 0.0)
				trunks.append(Transform3D(tilt * Basis.from_scale(Vector3(r * 0.45, length, r * 0.45)),
						start + tilt.y * length * 0.5))
		else:
			var spread := rng.randf_range(2.0, 3.2)
			canopies.append(Transform3D(Basis.from_scale(Vector3(spread, spread * 0.75, spread)),
					origin + Vector3(0.0, tall + spread * 0.3, 0.0)))
	_add_batch(parent, "Trunks", _cylinder(0.7, 1.0, 6, lit), trunks, theme.trunk_color, true)
	if not canopies.is_empty():
		_add_batch(parent, "Canopies", _sphere(lit), canopies, theme.leaf_color, true)


## A random spot in the ring outside the walls, at least OUTSIDE_SPACING from
## every taken spot (which it joins), or NAN when none was found.
static func _outside_spot(inner: float, reach: float, rng: RandomNumberGenerator,
		taken: Array[Vector2]) -> Vector2:
	var near := inner + OUTSIDE_GAP
	var far := inner + maxf(reach - OUTSIDE_GAP, OUTSIDE_GAP + 1.0)
	for attempt in PLACEMENT_TRIES:
		var at := Vector2(rng.randf_range(-far, far), rng.randf_range(-far, far))
		if maxf(absf(at.x), absf(at.y)) < near:
			continue
		var clear := true
		for other in taken:
			if other.distance_squared_to(at) < OUTSIDE_SPACING * OUTSIDE_SPACING:
				clear = false
				break
		if clear:
			taken.append(at)
			return at
	return Vector2(NAN, NAN)


static func _add_batch(parent: Node3D, batch_name: String, mesh: Mesh,
		transforms: Array[Transform3D], color: Color, shadows: bool) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, color)
	var instance := MultiMeshInstance3D.new()
	instance.name = batch_name
	instance.multimesh = multimesh
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


static func _lit_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.75
	return material


## Unshaded and drawn brighter than its color, so the glow picks it up.
static func _glow_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.albedo_color = Color(1.6, 1.6, 1.6)
	return material


## Unit-height cylinder centered on its origin.
static func _cylinder(top: float, bottom: float, segments: int, material: Material) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = 1
	mesh.material = material
	return mesh


static func _box(material: Material) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = material
	return mesh


static func _sphere(material: Material) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = CANOPY_SEGMENTS
	mesh.rings = 4
	mesh.material = material
	return mesh
