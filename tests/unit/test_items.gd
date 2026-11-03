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
		var kind := config.item_kinds[item.kind]
		check_eq(item.slot, int(kind.slot), "slot comes from the kind")
		check_eq(item.two_handed, kind.two_handed, "hands come from the kind")
		var implicit := 1 if kind.has_implicit else 0
		if implicit == 1:
			check_eq(item.stats[0], int(kind.implicit_stat), "implicit comes first")
		var allowed := 0
		for affix in config.affixes:
			if affix.slots.has(item.slot) and not (implicit == 1 and affix.stat == kind.implicit_stat):
				allowed += 1
		check_eq(item.stats.size(), implicit + mini(config.rarity_affixes[item.rarity], allowed),
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
	# Epic and legendary are rare enough to miss in 300 (test_sets_talismans).
	check(seen_rarities.has(0) and seen_rarities.has(1) and seen_rarities.has(2),
			"common, magic and rare all drop over 300 rolls")
	check(not seen_rarities.has(5), "set rarity never rolls")


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
	first.slot = AffixDef.Slot.AMULET
	var second := ItemData.new()
	second.slot = AffixDef.Slot.AMULET
	var third := ItemData.new()
	third.slot = AffixDef.Slot.AMULET
	check(inventory.add(first), "first equips")
	check(inventory.equipped[AffixDef.Slot.AMULET] == first, "into its slot")
	check(inventory.add(second), "second goes to the backpack")
	check(not inventory.add(third), "backpack full")
	inventory.equip(0)
	check(inventory.equipped[AffixDef.Slot.AMULET] == second, "swapped in")
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
	d.slot = AffixDef.Slot.AMULET
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
	inventory.add(_rolled(AffixDef.Slot.AMULET, 0))
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


func _made(slot: int, two_handed: bool = false, rarity: int = 0) -> ItemData:
	var item := ItemData.new()
	item.slot = slot
	item.two_handed = two_handed
	item.rarity = rarity
	item.item_name = "Test"
	return item


func test_rings_fill_both_ring_positions() -> void:
	var inventory := Inventory.new(4)
	var a := _made(AffixDef.Slot.RING)
	var b := _made(AffixDef.Slot.RING)
	var c := _made(AffixDef.Slot.RING)
	inventory.add(a)
	inventory.add(b)
	inventory.add(c)
	check(inventory.equipped[Inventory.Equip.RING_1] == a, "first ring on the left")
	check(inventory.equipped[Inventory.Equip.RING_2] == b, "second ring on the right")
	check(inventory.backpack.has(c), "third waits in the backpack")
	check(inventory.equip_item(c, Inventory.Equip.RING_2), "swap the right ring")
	check(inventory.equipped[Inventory.Equip.RING_2] == c and inventory.backpack.has(b),
			"the right ring went to the backpack")
	check(not inventory.equip_item(b, Inventory.Equip.MAIN_HAND), "a ring isn't a weapon")


func test_two_handed_weapons_and_off_hands_exclude_each_other() -> void:
	var inventory := Inventory.new(4)
	var wand := _made(AffixDef.Slot.WEAPON)
	var tome := _made(AffixDef.Slot.OFF_HAND)
	var staff := _made(AffixDef.Slot.WEAPON, true)
	inventory.add(wand)
	inventory.add(tome)
	check(inventory.equipped[Inventory.Equip.OFF_HAND] == tome, "one hand + off hand together")
	inventory.add(staff)
	check(inventory.backpack.has(staff), "a staff never auto-equips over an off hand")
	check(inventory.equip_item(staff), "equipping the staff works")
	check(inventory.equipped[Inventory.Equip.MAIN_HAND] == staff, "staff in the main hand")
	check(inventory.equipped[Inventory.Equip.OFF_HAND] == null, "and the off hand is free")
	check(inventory.backpack.has(wand) and inventory.backpack.has(tome), "both went to the backpack")
	check(inventory.equip_item(tome), "putting the tome back on")
	check(inventory.equipped[Inventory.Equip.MAIN_HAND] == null, "takes the staff off")
	var full := Inventory.new(0)
	full.add(staff)
	full.add(tome)
	check(full.equipped[Inventory.Equip.OFF_HAND] == null, "no auto-equip next to a staff")
	check(not full.can_equip(tome), "no room for the staff, so the tome can't go on")


func test_compare_against_counts_everything_taken_off() -> void:
	var tome := _made(AffixDef.Slot.OFF_HAND)
	tome.stats = PackedInt32Array([PlayerStat.Id.MAX_MANA])
	tome.values = PackedFloat32Array([20.0])
	var wand := _made(AffixDef.Slot.WEAPON)
	wand.stats = PackedInt32Array([PlayerStat.Id.BOLT_DAMAGE])
	wand.values = PackedFloat32Array([0.1])
	var staff := _made(AffixDef.Slot.WEAPON, true)
	staff.stats = PackedInt32Array([PlayerStat.Id.BOLT_DAMAGE])
	staff.values = PackedFloat32Array([0.3])
	var replaced: Array[ItemData] = [wand, tome]
	var rows := ItemCompare.compare_against(staff, replaced)
	check_eq(rows.size(), 2, "bolt damage and the lost mana")
	check_eq(rows[0]["change"], ItemCompare.Change.BETTER, "more bolt damage")
	check_eq(rows[1]["change"], ItemCompare.Change.LOST, "loses the tome's mana")


func test_salvage_everything_spares_equipped() -> void:
	var inventory := Inventory.new(6)
	var worn := _made(AffixDef.Slot.WEAPON, false, 2)
	inventory.add(worn)
	for rarity in 3:
		inventory.add(_made(AffixDef.Slot.WEAPON, false, rarity))
	var table := PackedInt32Array([1, 3, 6])
	check_eq(inventory.salvage_all_preview(-1, table)[0], 3, "three in the backpack")
	check_eq(inventory.salvage_all(-1, table), 10, "1 + 3 + 6 stones")
	check(inventory.backpack.is_empty(), "backpack emptied, rares too")
	check(inventory.equipped[Inventory.Equip.MAIN_HAND] == worn, "the worn rare is kept")


func test_old_saves_fit_the_new_slots() -> void:
	var inventory := Inventory.new(8)
	var staff := _made(AffixDef.Slot.WEAPON, true)
	var shield := _made(AffixDef.Slot.OFF_HAND)
	var data := {"progress": {}, "inventory": {"equipped": [SaveCodec.item_to_dict(staff),
			SaveCodec.item_to_dict(_made(AffixDef.Slot.AMULET)), null,
			SaveCodec.item_to_dict(shield)]}}
	var progress := PlayerProgress.new(load("res://data/rpg/progression.tres") as ProgressionConfig,
			load("res://data/rpg/skills.tres") as SkillTree)
	SaveCodec.decode(data, progress, inventory, null, 50, 10)
	check(inventory.equipped[Inventory.Equip.MAIN_HAND] != null, "weapon still in the main hand")
	check(inventory.equipped[Inventory.Equip.AMULET] != null, "old charm is now the amulet")
	check(inventory.equipped[Inventory.Equip.OFF_HAND] == null, "no off hand beside a staff")
	check_eq(inventory.backpack.size(), 1, "the shield went to the backpack")
	check(inventory.equipped[Inventory.Equip.MAIN_HAND].two_handed, "two-handed survives a save")


func test_backpack_sorts_by_each_mode() -> void:
	var inventory := Inventory.new(8)
	var old_rare := _rolled(AffixDef.Slot.RING, 2)
	old_rare.item_level = 3
	var new_common := _rolled(AffixDef.Slot.WEAPON, 0)
	new_common.item_level = 9
	var mid_magic := _rolled(AffixDef.Slot.ARMOR, 1)
	mid_magic.item_level = 5
	old_rare.item_name = "rare"
	new_common.item_name = "common"
	mid_magic.item_name = "magic"
	for item in [old_rare, mid_magic, new_common]:
		inventory.backpack.append(item)
		item.acquired = inventory.next_acquired
		inventory.next_acquired += 1
	inventory.sort_mode = Inventory.SortMode.RARITY
	inventory.sort_backpack()
	check_eq(_names(inventory), ["rare", "magic", "common"], "rarity: best first")
	inventory.sort_mode = Inventory.SortMode.LEVEL
	inventory.sort_backpack()
	check_eq(_names(inventory), ["common", "magic", "rare"], "level: highest first")
	inventory.sort_mode = Inventory.SortMode.NEWEST
	inventory.sort_backpack()
	check_eq(_names(inventory), ["common", "magic", "rare"], "newest first")
	check_eq(inventory.cycle_sort(), Inventory.SortMode.SLOT, "cycling wraps around to slot")
	var picked := _rolled(AffixDef.Slot.BELT, 0)
	var fresh := Inventory.new(8)
	fresh.add(picked)
	check(picked.acquired > 0, "picking up stamps the item")


func _names(inventory: Inventory) -> Array:
	var names := []
	for item in inventory.backpack:
		names.append(item.item_name)
	return names


func test_a_rarity_cap_keeps_open_world_gear_lower() -> void:
	var generator := ItemGenerator.new(_loot(), 9)
	for n in 300:
		check(generator.roll(40, 0, -1, -1, 3).rarity <= 3, "no better than epic")
	check(generator.roll(40, 0, -1, 4, 3).rarity == 4, "a forced rarity is kept")
