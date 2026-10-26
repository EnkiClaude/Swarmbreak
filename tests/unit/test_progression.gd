extends TestSuite


func _tree() -> SkillTree:
	return load("res://data/rpg/skills.tres") as SkillTree


func _progression() -> ProgressionConfig:
	return load("res://data/rpg/progression.tres") as ProgressionConfig


func _skill_index(tree: SkillTree, stat: int) -> int:
	for k in tree.skills.size():
		if tree.skills[k].stat == stat:
			return k
	return -1


func test_xp_levels_up_and_grants_points() -> void:
	var progress := PlayerProgress.new(_progression(), _tree())
	var first := progress.xp_to_next()
	check(first > 0.0, "xp needed for level 2")
	progress.add_xp(first * 0.5)
	check_eq(progress.level, 1, "half way is still level 1")
	progress.add_xp(first * 0.5 + 0.01)
	check_eq(progress.level, 2, "level 2")
	check_eq(progress.skill_points, 1, "one skill point")
	check(progress.xp_to_next() > first, "each level needs more")
	progress.add_xp(100000.0)
	check(progress.level > 5, "big xp gains several levels at once (%d)" % progress.level)


func test_skill_ranks_cap_and_cost_points() -> void:
	var tree := _tree()
	var progress := PlayerProgress.new(_progression(), tree)
	check(not progress.rank_up(0), "no points, no rank")
	progress.skill_points = 99
	for n in tree.skills[0].max_rank + 2:
		progress.rank_up(0)
	check_eq(progress.ranks[0], tree.skills[0].max_rank, "rank capped at max")
	check_eq(progress.skill_points, 99 - tree.skills[0].max_rank, "one point per rank")


func test_stats_combine_level_skills_and_items() -> void:
	var tree := _tree()
	var progression := _progression()
	var progress := PlayerProgress.new(progression, tree)
	var inventory := Inventory.new(4)
	var stats := PlayerStats.new(progress, tree, inventory, progression)
	var nova_skill := _skill_index(tree, PlayerStat.Id.NOVA_DAMAGE)
	progress.skill_points = 2
	progress.rank_up(nova_skill)
	progress.rank_up(nova_skill)
	var item := ItemData.new()
	item.slot = AffixDef.Slot.WEAPON
	item.stats = PackedInt32Array([PlayerStat.Id.NOVA_DAMAGE])
	item.values = PackedFloat32Array([0.1])
	inventory.add(item)
	progress.level = 3
	stats.recompute()
	check_near(stats.value(PlayerStat.Id.NOVA_DAMAGE), tree.skills[nova_skill].per_rank * 2 + 0.1,
			0.0001, "skills plus item")
	check_near(stats.value(PlayerStat.Id.MAX_HEALTH), progression.health_per_level * 2, 0.0001,
			"health from levels")


func test_vitals_follow_stats_and_armor() -> void:
	var tree := _tree()
	var progression := _progression()
	var progress := PlayerProgress.new(progression, tree)
	var inventory := Inventory.new(4)
	var stats := PlayerStats.new(progress, tree, inventory, progression)
	var config := load("res://data/player.tres") as PlayerConfig
	var vitals := PlayerVitals.new(config, stats)
	var armor := ItemData.new()
	armor.slot = AffixDef.Slot.ARMOR
	armor.stats = PackedInt32Array([PlayerStat.Id.MAX_HEALTH, PlayerStat.Id.ARMOR])
	armor.values = PackedFloat32Array([25.0, 0.5])
	inventory.add(armor)
	stats.recompute()
	vitals.refresh_maxima()
	check_near(vitals.max_health, config.max_health + 25.0, 0.001, "max health from item")
	vitals.reset()
	var taken := vitals.take_damage(10.0, 0.0)
	check_near(taken, 5.0, 0.001, "50% damage reduction")
