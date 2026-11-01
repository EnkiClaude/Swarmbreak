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
		for child in parent.get_children():
			var mm := (child as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var at := mm.get_instance_transform(i).origin
				var inside := maxf(absf(at.x), absf(at.z)) < 64.0
				if str(child.name) in ["Houses", "Roofs", "Trunks", "Canopies"]:
					check(not inside, "%s %s stands outside the walls" % [theme.display_name,
							child.name])
		parent.free()
