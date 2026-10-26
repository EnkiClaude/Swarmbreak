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
