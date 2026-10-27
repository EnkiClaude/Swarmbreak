extends TestSuite


func _loot() -> LootConfig:
	return load("res://data/rpg/loot.tres") as LootConfig


func test_rolls_respect_rarity_and_slot() -> void:
	var config := _loot()
	var generator := ItemGenerator.new(config, 42)
	var seen_rarities := {}
	for n in 300:
		var item := generator.roll(1)
		seen_rarities[item.rarity] = true
		var allowed := 0
		for affix in config.affixes:
			if affix.slots.has(item.slot):
				allowed += 1
		check_eq(item.stats.size(), mini(config.rarity_affixes[item.rarity], allowed),
				"affix count for rarity %d" % item.rarity)
		var unique := {}
		for k in item.stats.size():
			unique[item.stats[k]] = true
			var ok := false
			for affix in config.affixes:
				if affix.stat == item.stats[k] and affix.slots.has(item.slot):
					ok = true
			if not ok:
				failures.append("stat %d not allowed on slot %d" % [item.stats[k], item.slot])
		check_eq(unique.size(), item.stats.size(), "no duplicate stats on one item")
		check(item.item_name != "", "item has a name")
	check_eq(seen_rarities.size(), 3, "all rarities drop over 300 rolls")


func test_values_grow_with_zone_level() -> void:
	var config := _loot()
	var low := 0.0
	var high := 0.0
	var a := ItemGenerator.new(config, 7)
	var b := ItemGenerator.new(config, 7)
	for n in 200:
		var x := a.roll(1)
		var y := b.roll(6)
		for k in x.values.size():
			low += x.values[k]
		for k in y.values.size():
			high += y.values[k]
	check(high > low * 1.5, "zone 6 items roll higher (%.1f vs %.1f)" % [high, low])


func test_inventory_equips_stores_and_swaps() -> void:
	var inventory := Inventory.new(1)
	var first := ItemData.new()
	first.slot = AffixDef.Slot.CHARM
	var second := ItemData.new()
	second.slot = AffixDef.Slot.CHARM
	var third := ItemData.new()
	third.slot = AffixDef.Slot.CHARM
	check(inventory.add(first), "first equips")
	check(inventory.equipped[AffixDef.Slot.CHARM] == first, "into its slot")
	check(inventory.add(second), "second goes to the backpack")
	check(not inventory.add(third), "backpack full")
	inventory.equip(0)
	check(inventory.equipped[AffixDef.Slot.CHARM] == second, "swapped in")
	check(inventory.backpack[0] == first, "old one in the backpack")
	inventory.discard(0)
	check(inventory.backpack.is_empty(), "discarded")


func test_can_accept_matches_add() -> void:
	var inventory := Inventory.new(1)
	var a := ItemData.new()
	a.slot = AffixDef.Slot.ARMOR
	var b := ItemData.new()
	b.slot = AffixDef.Slot.ARMOR
	var c := ItemData.new()
	c.slot = AffixDef.Slot.ARMOR
	var d := ItemData.new()
	d.slot = AffixDef.Slot.CHARM
	check(inventory.can_accept(a) and inventory.add(a), "empty slot")
	check(inventory.can_accept(b) and inventory.add(b), "backpack has room")
	check(not inventory.can_accept(c), "slot taken and backpack full")
	check(inventory.can_accept(d), "a different empty slot still fits")


func _rolled(slot: int, rarity: int, upgrade: int = 0) -> ItemData:
	var item := ItemData.new()
	item.slot = slot
	item.rarity = rarity
	item.upgrade_level = upgrade
	item.upgrade_bonus = 0.1
	return item


func test_salvage_all_takes_one_rarity_from_the_backpack_only() -> void:
	var config := _loot()
	var inventory := Inventory.new(8)
	var worn := _rolled(AffixDef.Slot.WEAPON, 0)
	inventory.add(worn)  # equipped
	inventory.add(_rolled(AffixDef.Slot.WEAPON, 0))
	inventory.add(_rolled(AffixDef.Slot.WEAPON, 0, 2))
	inventory.add(_rolled(AffixDef.Slot.WEAPON, 1))
	inventory.add(_rolled(AffixDef.Slot.WEAPON, 2))
	var preview: Array = inventory.salvage_all_preview(0, config.salvage_stones)
	check_eq(preview[0], 2, "two commons in the backpack")
	var gained := inventory.salvage_all(0, config.salvage_stones)
	check_eq(gained, preview[1], "preview matches the result")
	check_eq(gained, config.salvage_stones[0] * 2 + 2, "refine levels add stones")
	check_eq(inventory.backpack.size(), 2, "magic and rare stay")
	check(inventory.equipped[AffixDef.Slot.WEAPON] == worn, "equipped common untouched")


func test_backpack_sorts_by_slot_then_best_first() -> void:
	var inventory := Inventory.new(8)
	inventory.add(_rolled(AffixDef.Slot.WEAPON, 0))
	inventory.add(_rolled(AffixDef.Slot.CHARM, 0))
	inventory.add(_rolled(AffixDef.Slot.ARMOR, 0))
	inventory.add(_rolled(AffixDef.Slot.ARMOR, 0, 3))
	inventory.add(_rolled(AffixDef.Slot.WEAPON, 2))
	inventory.add(_rolled(AffixDef.Slot.WEAPON, 1))
	inventory.sort_backpack()
	var order := []
	for item in inventory.backpack:
		order.append([item.slot, item.rarity, item.upgrade_level])
	check_eq(order, [[0, 2, 0], [0, 1, 0], [2, 0, 3]], "weapons best first, then armor")


func test_compare_marks_better_worse_gained_and_lost() -> void:
	var current := _rolled(AffixDef.Slot.WEAPON, 1)
	current.stats = PackedInt32Array([PlayerStat.Id.BOLT_DAMAGE, PlayerStat.Id.NOVA_DAMAGE])
	current.values = PackedFloat32Array([0.1, 0.2])
	var candidate := _rolled(AffixDef.Slot.WEAPON, 1)
	candidate.stats = PackedInt32Array([PlayerStat.Id.BOLT_DAMAGE, PlayerStat.Id.FIRE_RATE])
	candidate.values = PackedFloat32Array([0.15, 0.05])
	var rows := ItemCompare.compare(candidate, current)
	check_eq(rows.size(), 3, "bolt, fire rate, and the lost nova damage")
	check_eq(rows[0]["change"], ItemCompare.Change.BETTER, "more bolt damage")
	check_near(rows[0]["delta"], 0.05, 0.0001, "by 5%")
	check_eq(rows[1]["change"], ItemCompare.Change.GAINED, "fire rate is new")
	check_eq(rows[2]["change"], ItemCompare.Change.LOST, "nova damage would be lost")
	check_eq(PlayerStat.describe_delta(PlayerStat.Id.NOVA_DAMAGE, -0.2), "-20%", "signed delta")
	var into_empty := ItemCompare.compare(candidate, null)
	check_eq(into_empty[0]["change"], ItemCompare.Change.GAINED, "empty slot: all gains")
