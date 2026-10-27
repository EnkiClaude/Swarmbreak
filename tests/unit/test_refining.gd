extends TestSuite


func _loot() -> LootConfig:
	return load("res://data/rpg/loot.tres") as LootConfig


func _item(level: int = 0) -> ItemData:
	var item := ItemData.new()
	item.slot = AffixDef.Slot.WEAPON
	item.stats = PackedInt32Array([PlayerStat.Id.BOLT_DAMAGE])
	item.values = PackedFloat32Array([0.1])
	item.upgrade_bonus = 0.1
	item.upgrade_level = level
	return item


func test_refine_levels_scale_stats() -> void:
	var item := _item(3)
	check_near(item.value_of(PlayerStat.Id.BOLT_DAMAGE), 0.13, 0.0001, "+3 is 1.3x")
	check_eq(item.display_name(), "+3 " + item.item_name, "name shows the level")


func test_never_breaks_and_never_below_zero() -> void:
	var config := _loot()
	var refinery := Refinery.new(config, 123)
	var inventory := Inventory.new(4)
	var item := _item()
	inventory.add(item)
	inventory.stones = 100000
	var seen_down := false
	var seen_up := false
	for n in 400:
		var before := item.upgrade_level
		var result := refinery.attempt(item, inventory)
		match result:
			Refinery.Result.SUCCESS:
				seen_up = true
				check_eq(item.upgrade_level, before + 1, "success adds one")
			Refinery.Result.DOWNGRADED:
				seen_down = true
				check_eq(item.upgrade_level, before - 1, "failure drops exactly one")
			Refinery.Result.FAILED:
				check_eq(before, 0, "plain failure only happens at +0")
			Refinery.Result.MAXED:
				check_eq(before, config.upgrade_max, "maxed only at the cap")
		check(item.upgrade_level >= 0 and item.upgrade_level <= config.upgrade_max,
				"level stays in range (%d)" % item.upgrade_level)
	check(seen_up and seen_down, "both outcomes happen over many tries")
	check(inventory.equipped[item.slot] == item, "the item is never destroyed")


func test_costs_stones_and_needs_enough() -> void:
	var config := _loot()
	var refinery := Refinery.new(config, 5)
	var inventory := Inventory.new(4)
	var item := _item(2)
	inventory.stones = refinery.cost_for(item) - 1
	check_eq(refinery.attempt(item, inventory), Refinery.Result.NOT_ENOUGH_STONES, "too poor")
	check_eq(item.upgrade_level, 2, "unchanged")
	inventory.stones = refinery.cost_for(item)
	refinery.attempt(item, inventory)
	check_eq(inventory.stones, 0, "cost paid")


func test_chances_fall_and_pity_builds() -> void:
	var config := _loot()
	var refinery := Refinery.new(config, 9)
	var low := _item(0)
	var high := _item(8)
	check(refinery.chance_for(low) > refinery.chance_for(high), "higher levels are riskier")
	var base := refinery.chance_for(high)
	high.fail_streak = 3
	check_near(refinery.chance_for(high), base + 3 * config.upgrade_pity_per_fail, 0.0001,
			"each failure adds pity")


func test_salvage_gives_stones_by_rarity() -> void:
	var config := _loot()
	var inventory := Inventory.new(4)
	inventory.add(_item())
	var rare := _item(2)
	rare.rarity = 2
	inventory.add(rare)
	var gained := inventory.salvage(0, config.salvage_stones)
	check_eq(gained, config.salvage_stones[2] + 2, "rare plus its refine levels")
	check_eq(inventory.stones, gained, "stones added")
	check(inventory.backpack.is_empty(), "item gone")
