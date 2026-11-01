extends TestSuite


func _table() -> AttributeTable:
	return load("res://data/rpg/attributes.tres") as AttributeTable


func _progress() -> PlayerProgress:
	return PlayerProgress.new(load("res://data/rpg/progression.tres") as ProgressionConfig,
			load("res://data/rpg/skills.tres") as SkillTree, _table())


func test_five_attributes_feed_real_stats() -> void:
	var table := _table()
	check_eq(table.attributes.size(), 5, "five attributes")
	for def in table.attributes:
		check(not def.stats.is_empty(), "%s raises something" % def.display_name)
		check_eq(def.per_point.size(), def.stats.size(), "%s has a value per stat" % def.short_name)


func test_levels_grant_attribute_points() -> void:
	var progress := _progress()
	var per_level := _table().points_per_level
	check_eq(progress.attribute_points, _table().starting_points, "starting points")
	progress.add_xp(progress.xp_to_next() + 0.01)
	check_eq(progress.attribute_points, _table().starting_points + per_level, "a level's worth")
	check_eq(progress.earned_attribute_points(), progress.attribute_points, "earned matches")


func test_raising_spends_points_and_changes_stats() -> void:
	var progress := _progress()
	progress.attribute_points = 7
	var stats := PlayerStats.new(progress, load("res://data/rpg/skills.tres") as SkillTree,
			Inventory.new(16), load("res://data/rpg/progression.tres") as ProgressionConfig)
	var def := _table().attributes[0]
	var stat: int = def.stats[0]
	var before := stats.value(stat)
	check_eq(progress.raise_attribute(0, 5), 5, "spent five")
	check_eq(progress.raise_attribute(0, 5), 2, "only two left to spend")
	check_eq(progress.raise_attribute(0, 1), 0, "none left")
	check_eq(progress.attributes[0], 7, "seven points in it")
	stats.recompute()
	check_near(stats.value(stat), before + def.per_point[0] * 7, 0.0001, "the stat grew")
	progress.reset()
	check_eq(progress.attributes[0], 0, "New Game clears attributes")


func test_saves_keep_attributes_and_old_saves_get_their_points() -> void:
	var progress := _progress()
	progress.level = 4
	progress.attribute_points = 3
	progress.attributes[2] = 12
	var data := SaveCodec.encode(progress, Inventory.new(16), 1)
	var copy := _progress()
	SaveCodec.decode(data, copy, Inventory.new(16), null, 50, 10)
	check_eq(copy.attributes[2], 12, "points in INT kept")
	check_eq(copy.attribute_points, 3, "unspent points kept")
	var old := data.duplicate(true)
	(old["progress"] as Dictionary).erase("attributes")
	(old["progress"] as Dictionary).erase("attribute_points")
	var legacy := _progress()
	SaveCodec.decode(old, legacy, Inventory.new(16), null, 50, 10)
	check_eq(legacy.attribute_points, legacy.earned_attribute_points(),
			"an old level 4 save gets level 4's points to spend")
