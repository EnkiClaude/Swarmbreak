extends TestSuite


const THEME_DIR := "res://data/zones/themes/"


func _themes() -> Array[ZoneTheme]:
	var themes: Array[ZoneTheme] = []
	for file in DirAccess.get_files_at(THEME_DIR):
		if file.ends_with(".tres"):
			themes.append(load(THEME_DIR + file) as ZoneTheme)
	return themes


func test_every_theme_loads_with_its_own_name() -> void:
	var names := {}
	var themes := _themes()
	check(themes.size() >= 5, "%d themes" % themes.size())
	for theme in themes:
		check(theme != null, "every theme loads")
		names[theme.display_name] = true
	check_eq(names.size(), themes.size(), "every theme has its own name")


func test_pillars_stand_inside_the_walls() -> void:
	var spots := ArenaProps.pillar_spots(64.0, 8.0, 0.6)
	check_eq(spots.size(), 16 * 4, "16 per side")
	for p in spots:
		check(maxf(absf(p.x), absf(p.y)) < 64.0 - 0.6, "inside the arena (%s)" % p)
		check(maxf(absf(p.x), absf(p.y)) > 62.0, "against a wall (%s)" % p)


func test_every_theme_builds() -> void:
	for theme in _themes():
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
