extends TestSuite


func _types() -> Array[EnemyType]:
	return (load("res://data/swarm.tres") as SwarmConfig).enemy_types


## Vertex heights of a built mesh, and its rig (UV) values.
func _arrays(mesh: ArrayMesh) -> Array:
	return mesh.surface_get_arrays(0)


func test_every_enemy_type_builds_a_rigged_model_of_its_height() -> void:
	var models := {}
	for t in _types():
		var mesh := CharacterModels.enemy(t)
		var arrays := _arrays(mesh)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		check(vertices.size() > 100, "%s has a real model (%d vertices)" % [t.display_name,
				vertices.size()])
		check_eq(uvs.size(), vertices.size(), "%s: every vertex carries its rig" % t.display_name)
		check_eq(colors.size(), vertices.size(), "%s: every vertex has a color" % t.display_name)
		var low := INF
		var high := -INF
		var limbs := {}
		for k in vertices.size():
			low = minf(low, vertices[k].y)
			high = maxf(high, vertices[k].y)
			limbs[int(uvs[k].x)] = true
		check(low > -0.1 and low < 0.25, "%s stands on the ground (lowest %.2f)" % [t.display_name,
				low])
		check(high > t.body_height * 0.8 and high < t.body_height * 1.25,
				"%s is about its body height (%.2f vs %.2f)" % [t.display_name, high, t.body_height])
		var animated := limbs.has(ModelBuilder.Limb.LEFT_ARM) or limbs.has(ModelBuilder.Limb.FLOAT)
		check(animated, "%s has limbs that move" % t.display_name)
		models[t.model] = true
	check(models.size() >= 6, "six different models (%d)" % models.size())


func test_hero_has_legs_arms_and_a_staff_in_the_right_hand() -> void:
	var mesh := CharacterModels.hero(1.8, Color.BLUE, Color.GOLD, Color.CYAN)
	var arrays := _arrays(mesh)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var limbs := {}
	var right_arm_high := -INF
	for k in vertices.size():
		var limb := int(uvs[k].x)
		limbs[limb] = true
		if limb == ModelBuilder.Limb.RIGHT_ARM:
			right_arm_high = maxf(right_arm_high, vertices[k].y)
			check(vertices[k].x > 0.0, "the right arm is on the right (+X)")
	for limb in [ModelBuilder.Limb.LEFT_LEG, ModelBuilder.Limb.RIGHT_LEG,
			ModelBuilder.Limb.LEFT_ARM, ModelBuilder.Limb.RIGHT_ARM]:
		check(limbs.has(limb), "hero has limb %d" % limb)
	check(right_arm_high > 1.5, "the staff rises above the shoulder (%.2f)" % right_arm_high)


func test_regions_field_their_own_monsters() -> void:
	var config := load("res://data/world/world.tres") as WorldConfig
	var map := WorldMap.new(config)
	var count := _types().size()
	var light := {}
	for s in map.overworld_sites.size():
		var region := config.regions[map.region_at(map.overworld_sites.centers[s])]
		check_eq(map.overworld_sites.light_type[s], region.enemy_type, "site uses its region's type")
		check(map.overworld_sites.heavy_type[s] < count, "heavy type exists")
		light[region.enemy_type] = true
	check(light.size() >= 3, "at least three kinds of monster across the regions (%d)" % light.size())
	for d in config.dungeons.size():
		var sites := map.dungeon_sites[d]
		for s in sites.size():
			check_eq(sites.light_type[s], config.dungeons[d].enemy_type, "dungeon type")
