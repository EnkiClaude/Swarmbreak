extends TestSuite


func test_zone_levels_cycle_through_themes() -> void:
	var config := load("res://data/zones/zone.tres") as ZoneConfig
	var count := config.themes.size()
	check(count >= 2, "several themes (%d)" % count)
	check(config.theme_for(1) == config.themes[0], "level 1 uses the first theme")
	check(config.theme_for(2) == config.themes[1], "level 2 uses the second")
	check(config.theme_for(count + 1) == config.themes[0], "then it wraps around")
	var names := {}
	for theme in config.themes:
		check(theme != null, "every theme loads")
		names[theme.display_name] = true
	check_eq(names.size(), count, "every theme has its own name")


func test_no_themes_means_no_theme() -> void:
	check(ZoneConfig.new().theme_for(3) == null, "null without themes")


func test_pillars_stand_inside_the_walls() -> void:
	var spots := ArenaProps.pillar_spots(64.0, 8.0, 0.6)
	check_eq(spots.size(), 16 * 4, "16 per side")
	for p in spots:
		check(maxf(absf(p.x), absf(p.y)) < 64.0 - 0.6, "inside the arena (%s)" % p)
		check(maxf(absf(p.x), absf(p.y)) > 62.0, "against a wall (%s)" % p)


func test_every_theme_builds() -> void:
	var config := load("res://data/zones/zone.tres") as ZoneConfig
	for theme in config.themes:
		var parent := Node3D.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		ArenaProps.build(parent, theme, 64.0, 0.8, rng)
		var instances := 0
		for child in parent.get_children():
			instances += (child as MultiMeshInstance3D).multimesh.instance_count
		var expects_props := theme.pillar_spacing > 0.0 or theme.house_count > 0 \
				or theme.tree_count > 0
		check(instances > 0 or not expects_props, "%s has props" % theme.display_name)
		parent.free()


## Instance transforms can't be read back under the headless dummy renderer,
## so this checks the placement function houses and trees use.
func test_outside_props_stand_outside_the_walls_and_apart() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var taken: Array[Vector2] = []
	for n in 40:
		var at := ArenaProps.outside_spot(64.8, 45.0, rng, taken)
		if is_nan(at.x):
			continue
		check(maxf(absf(at.x), absf(at.y)) >= 64.8 + ArenaProps.OUTSIDE_GAP, "outside (%s)" % at)
	check(taken.size() > 20, "most spots found (%d)" % taken.size())
	for i in taken.size():
		for j in range(i + 1, taken.size()):
			check(taken[i].distance_to(taken[j]) >= ArenaProps.OUTSIDE_SPACING, "kept apart")
