class_name OverworldScenery
extends RefCounted
## Builds the open world's static scenery once at load: one ground plane
## whose colors blend from region to region (world_floor shader), the town's
## paved square ringed by lantern posts and houses, each region's trees and
## houses, the dungeon gates, and the wall around the world's edge.
## Props keep clear of camp sites and gates, since nothing collides with them.

const WORLD_FLOOR := preload("res://shaders/world_floor.gdshader")
const TILE_FLOOR := preload("res://shaders/zone_floor.gdshader")
## Ground reaches this far past the edge wall, under the fog.
const OUTSIDE_GROUND := 60.0
const WALL_THICKNESS := 1.2
const LANTERN_POST_HEIGHT := 2.6
const LANTERN_POST_SPACING := 8.0
const PROP_TRIES := 40


static func build(parent: Node3D, map: WorldMap) -> Node3D:
	var root := Node3D.new()
	root.name = "Overworld"
	parent.add_child(root)
	var config := map.config
	_build_ground(root, config)
	_build_plaza(root, map)
	Arena.add_walls(root, config.half_extent(), WALL_THICKNESS, config.edge_wall_height,
			config.edge_wall_color, config.edge_wall_trim_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = config.world_seed + 17
	var blocked := PackedVector2Array(map.overworld_sites.centers)
	for d in config.dungeons.size():
		blocked.append(map.gate_position(d))
		var dungeon := config.dungeons[d]
		var title := "%s   Lv %d" % [dungeon.display_name, dungeon.level]
		GateProp.build(root, map.gate_position(d), title, dungeon.gate_color)
		GateProp.build(root, map.town_gate_position(d), title, dungeon.gate_color)
	for region in config.regions.size():
		_build_region_props(root, map, region, rng, blocked)
	return root


## Per-region floor colors as three tiny textures, one texel per region.
static func _build_ground(root: Node3D, config: WorldConfig) -> void:
	var n := config.grid_size
	var base := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var alt := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var worn := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for k in config.regions.size():
		var theme := config.regions[k].theme
		@warning_ignore("integer_division")
		var row := k / n
		base.set_pixel(k % n, row, theme.floor_color)
		alt.set_pixel(k % n, row, theme.floor_alt_color)
		worn.set_pixel(k % n, row, theme.grout_color)
	var material := ShaderMaterial.new()
	material.shader = WORLD_FLOOR
	material.set_shader_parameter("region_base", ImageTexture.create_from_image(base))
	material.set_shader_parameter("region_alt", ImageTexture.create_from_image(alt))
	material.set_shader_parameter("region_worn", ImageTexture.create_from_image(worn))
	material.set_shader_parameter("grid_size", n)
	material.set_shader_parameter("region_size", config.region_size)
	material.set_shader_parameter("blend", config.region_blend)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (config.half_extent() + OUTSIDE_GROUND) * 2.0
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)


## The town's flagstone square, a hair above the ground, with lantern posts
## along its edge.
static func _build_plaza(root: Node3D, map: WorldMap) -> void:
	var config := map.config
	var town := map.town_spawn()
	var theme := config.regions[config.town_region()].theme
	var material := ShaderMaterial.new()
	material.shader = TILE_FLOOR
	material.set_shader_parameter("pattern", int(ZoneTheme.FloorPattern.FLAGSTONES))
	material.set_shader_parameter("base_color", config.plaza_color)
	material.set_shader_parameter("alt_color", config.plaza_color.darkened(0.12))
	material.set_shader_parameter("grout_color", config.plaza_grout_color)
	material.set_shader_parameter("tile_size", 2.5)
	material.set_shader_parameter("grout_width", 0.06)
	material.set_shader_parameter("noise_amount", 0.2)
	material.set_shader_parameter("roughness_value", 0.85)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * config.plaza_size
	var plaza := MeshInstance3D.new()
	plaza.name = "Plaza"
	plaza.mesh = plane
	plaza.material_override = material
	plaza.position = Vector3(town.x, 0.02, town.y)
	plaza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(plaza)
	var posts: Array[Transform3D] = []
	var lanterns: Array[Transform3D] = []
	var half := config.plaza_size * 0.5
	var per_side := maxi(1, floori(config.plaza_size / LANTERN_POST_SPACING))
	for k in per_side + 1:
		var along := -half + k * config.plaza_size / per_side
		for spot: Vector2 in [Vector2(along, -half), Vector2(along, half), Vector2(-half, along),
				Vector2(half, along)]:
			var at := town + spot
			posts.append(Transform3D(Basis.from_scale(Vector3(0.12, LANTERN_POST_HEIGHT, 0.12)),
					Vector3(at.x, LANTERN_POST_HEIGHT * 0.5, at.y)))
			lanterns.append(Transform3D(Basis.from_scale(Vector3(0.3, 0.45, 0.3)),
					Vector3(at.x, LANTERN_POST_HEIGHT + 0.2, at.y)))
	var lit := ArenaProps.lit_material()
	ArenaProps.add_batch(root, "LanternPosts", ArenaProps.cylinder(1.0, 1.0, 6, lit), posts,
			theme.pillar_color, true)
	ArenaProps.add_batch(root, "Lanterns", ArenaProps.cylinder(0.8, 1.0, 8,
			ArenaProps.glow_material()), lanterns, theme.lantern_color, false)


## Trees and houses scattered in a region, clear of camps, gates, the plaza
## and the world edge. Town houses face the square.
static func _build_region_props(root: Node3D, map: WorldMap, region: int,
		rng: RandomNumberGenerator, blocked: PackedVector2Array) -> void:
	var config := map.config
	var def := config.regions[region]
	var theme := def.theme
	if theme == null:
		return
	var holder := Node3D.new()
	holder.name = "Region%d" % region
	root.add_child(holder)
	var center := map.region_center(region)
	var town := map.town_spawn()
	var taken: Array[Vector2] = []
	var houses: Array[Vector2] = []
	for n in theme.house_count:
		var at := _prop_spot(map, center, town, rng, blocked, taken, def.is_town)
		if not is_nan(at.x):
			houses.append(at)
	var trees: Array[Vector2] = []
	for n in theme.tree_count:
		var at := _prop_spot(map, center, town, rng, blocked, taken, false)
		if not is_nan(at.x):
			trees.append(at)
	var lit := ArenaProps.lit_material()
	ArenaProps.add_houses(holder, theme, houses, town if def.is_town else center, rng, lit)
	ArenaProps.add_trees(holder, theme, trees, rng, lit)


## A free spot in the region, or NAN. near_plaza keeps it to a ring around
## the town square (for town houses).
static func _prop_spot(map: WorldMap, center: Vector2, town: Vector2,
		rng: RandomNumberGenerator, blocked: PackedVector2Array, taken: Array[Vector2],
		near_plaza: bool) -> Vector2:
	var config := map.config
	var half := config.region_size * 0.5 - 4.0
	var edge := config.half_extent() - 6.0
	var plaza_keep := config.plaza_size * 0.5 + 6.0
	for attempt in PROP_TRIES:
		var at := center + Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		if near_plaza:
			at = town + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(plaza_keep + 4.0,
					plaza_keep + 22.0)
		if absf(at.x) > edge or absf(at.y) > edge:
			continue
		if absf(at.x - town.x) < plaza_keep and absf(at.y - town.y) < plaza_keep:
			continue
		if WorldMap.too_close(at, blocked, config.prop_clearance):
			continue
		var crowded := false
		for other in taken:
			if other.distance_squared_to(at) < config.prop_spacing * config.prop_spacing:
				crowded = true
				break
		if crowded:
			continue
		taken.append(at)
		return at
	return Vector2(NAN, NAN)
