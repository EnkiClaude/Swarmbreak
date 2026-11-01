extends TestSuite


func _progress() -> PlayerProgress:
	return PlayerProgress.new(load("res://data/rpg/progression.tres") as ProgressionConfig,
			load("res://data/rpg/skills.tres") as SkillTree,
			load("res://data/rpg/attributes.tres") as AttributeTable)


func _agility(table: AttributeTable) -> int:
	for a in table.attributes.size():
		if table.attributes[a].stats.has(PlayerStat.Id.EVASION):
			return a
	return -1


## Hits evaded out of n, with that many points in Agility.
func _evaded(points: int, n: int) -> int:
	var progress := _progress()
	progress.attribute_points = points
	progress.raise_attribute(_agility(progress.attribute_table), points)
	var stats := PlayerStats.new(progress, load("res://data/rpg/skills.tres") as SkillTree,
			Inventory.new(4), load("res://data/rpg/progression.tres") as ProgressionConfig)
	var vitals := PlayerVitals.new(load("res://data/player.tres") as PlayerConfig, stats)
	vitals.seed_rolls(5)
	var count := [0]
	vitals.evaded.connect(func() -> void: count[0] += 1)
	for k in n:
		vitals.health = vitals.max_health
		vitals.take_damage(1.0, 0.0)
	return count[0]


func test_agility_feeds_evasion() -> void:
	check(_agility(load("res://data/rpg/attributes.tres") as AttributeTable) >= 0,
			"an attribute raises evasion")
	check_eq(_evaded(0, 400), 0, "no agility, no evasion")
	var some := _evaded(50, 1000)
	check(some > 120 and some < 280, "50 points evade about a fifth (%d / 1000)" % some)
	var lots := _evaded(400, 1000)
	var cap := PlayerStat.CAPS[PlayerStat.Id.EVASION]
	check(lots > 1000 * (cap - 0.05) and lots < 1000 * (cap + 0.05),
			"maxed evasion dodges most hits, up to the cap (%d / 1000)" % lots)


func _loot() -> LootSystem:
	var config := load("res://data/rpg/loot.tres") as LootConfig
	var loot := LootSystem.new()
	loot.setup(config, Inventory.new(30), ItemGenerator.new(config, 9))
	return loot


func test_drops_are_mostly_geon_and_rarely_items() -> void:
	var loot := _loot()
	var config := load("res://data/rpg/loot.tres") as LootConfig
	var items := 0
	var drops := 0
	for n in 400:
		loot.clear()
		items += loot.drop_rewards(Vector2.ZERO, 5, 1)
		drops += 5
	var rate := float(items) / drops
	check(absf(rate - config.item_drop_chance) < 0.025,
			"items drop at about %.2f (got %.3f)" % [config.item_drop_chance, rate])
	loot.free()


func test_geon_piles_grow_with_level_and_are_picked_up() -> void:
	var loot := _loot()
	var low := 0
	var high := 0
	for n in 200:
		low += loot.geon_pile(1)
		high += loot.geon_pile(8)
	check(high > low * 2, "level 8 piles are much bigger (%d vs %d)" % [high, low])
	loot.place_geon(25, Vector2(0.5, 0.0))
	check_eq(loot.ground_geon(), 25, "a pile lies on the ground")
	var picked := [0]
	loot.picked_up_geon.connect(func(amount: int) -> void: picked[0] += amount)
	loot.tick(0.016, Vector2.ZERO)
	check_eq(picked[0], 25, "touching it picks it up")
	check_eq(loot.ground_count(), 0, "nothing left on the ground")
	loot.free()
