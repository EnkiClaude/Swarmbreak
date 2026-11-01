extends TestSuite


func _loot() -> LootConfig:
	return load("res://data/rpg/loot.tres") as LootConfig


func _sets() -> SetList:
	return load("res://data/rpg/sets.tres") as SetList


func test_epic_and_legendary_roll_rarely_and_hit_harder() -> void:
	var config := _loot()
	var generator := ItemGenerator.new(config, 7)
	var counts := PackedInt32Array()
	counts.resize(config.rarity_names.size())
	var legendary: ItemData = null
	for n in 6000:
		var item := generator.roll(1)
		counts[item.rarity] += 1
		check(item.stats.size() >= 1, "every item has a stat")
		if item.rarity == 4 and legendary == null:
			legendary = item
	check(counts[3] > 0 and counts[3] < counts[2], "epics drop, rarer than rares (%d)" % counts[3])
	check(counts[4] > 0 and counts[4] < counts[3], "legendaries are rarer still (%d)" % counts[4])
	check_eq(counts[5], 0, "set rarity never rolls at random")
	check(config.rarity_affixes[4] > config.rarity_affixes[2], "legendaries roll more affixes")
	check(config.rarity_power[4] > config.rarity_power[2], "and bigger values")
	if legendary != null:
		var kind := config.item_kinds[legendary.kind]
		if kind.has_implicit:
			check(legendary.values[0] >= kind.implicit_min * config.rarity_power[4] - 0.011,
					"a legendary's implicit is boosted (%f)" % legendary.values[0])


func test_dungeon_bosses_each_have_a_set() -> void:
	var world := load("res://data/world/world.tres") as WorldConfig
	var sets := _sets()
	check_eq(world.dungeons.size(), 6, "six dungeons")
	var used := {}
	var last_level := 0
	for def in world.dungeons:
		check(def.set_index >= 0 and def.set_index < sets.sets.size(), "%s has a set" %
				def.display_name)
		check(not used.has(def.set_index), "%s's set is its own" % def.display_name)
		used[def.set_index] = true
		check(def.level > last_level, "%s is a higher tier than the one before" % def.display_name)
		last_level = def.level
	for def in sets.sets:
		check(def.pieces.size() >= 4, "%s has pieces" % def.set_name)
		check_eq(def.bonus_values.size(), def.bonus_stats.size(), "%s bonuses line up" %
				def.set_name)


func test_set_pieces_and_bonuses() -> void:
	var config := _loot()
	var sets := _sets()
	var generator := ItemGenerator.new(config, 3)
	var inventory := Inventory.new(16)
	inventory.sets = sets
	var def := sets.sets[0]
	# Collect distinct pieces of set 0.
	var pieces := {}
	for n in 200:
		var piece := generator.roll_set_piece(sets, 0, 1)
		check_eq(piece.set_id, 0, "piece knows its set")
		check_eq(piece.rarity, sets.set_rarity, "set rarity")
		pieces[piece.item_name] = piece
	check_eq(pieces.size(), def.pieces.size(), "every piece can drop")
	var first_bonus_stat: int = def.bonus_stats[0]
	var bonus: float = def.bonus_values[0]
	var worn := 0
	var without := 0.0
	for piece: ItemData in pieces.values():
		if not inventory.equip_item(piece):
			continue
		worn += 1
		if worn == 1:
			without = inventory.total(first_bonus_stat)
			check_eq(inventory.set_count(0), 1, "one piece worn")
		elif worn == 2:
			var piece_value := piece.value_of(first_bonus_stat)
			check_near(inventory.total(first_bonus_stat), without + piece_value + bonus, 0.001,
					"two pieces add the first bonus")
	check(worn >= def.bonus_pieces[def.bonus_pieces.size() - 1], "the whole set can be worn")
	# Same seed, same piece: only the level differs.
	var level_one := ItemGenerator.new(config, 21).roll_set_piece(sets, 0, 1)
	var level_ten := ItemGenerator.new(config, 21).roll_set_piece(sets, 0, 10)
	check_eq(level_ten.item_name, level_one.item_name, "same piece")
	check(level_ten.values[0] > level_one.values[0], "pieces grow with level")


func test_talismans_roll_and_cannot_be_worn() -> void:
	var config := _loot()
	var generator := ItemGenerator.new(config, 11)
	var inventory := Inventory.new(16)
	for n in 200:
		var t := generator.roll_talisman(5)
		check(t.is_talisman, "is a talisman")
		check(t.rarity <= config.talisman_max_rarity, "never set rarity")
		check_eq(t.stats.size(), config.talisman_stat_counts[t.rarity], "stats by rarity")
	var talisman := generator.roll_talisman(1)
	check(not inventory.can_equip(talisman), "can't be worn")
	check(inventory.add(talisman), "goes into the backpack")
	check(inventory.backpack.has(talisman) and inventory.position_of(talisman) < 0,
			"in the backpack, not worn")


func test_applying_talismans_never_harms_gear() -> void:
	var config := _loot()
	var generator := ItemGenerator.new(config, 5)
	var rules := TalismanRules.new(config, 99)
	var inventory := Inventory.new(64)
	var failures_seen := 0
	var gear: ItemData = null
	for _round in 10:
		inventory.equipped.fill(null)
		gear = ItemData.new()
		gear.slot = AffixDef.Slot.HELM
		gear.rarity = 4
		gear.stats = PackedInt32Array([PlayerStat.Id.MAX_HEALTH])
		gear.values = PackedFloat32Array([20.0])
		inventory.equip_item(gear)
		failures_seen += _fill_sockets(config, generator, rules, inventory, gear)
	check(failures_seen > 0, "some attempts fail (%d)" % failures_seen)
	var extra := generator.roll_talisman(1)
	inventory.backpack.append(extra)
	check_eq(rules.apply(extra, gear, inventory), TalismanRules.Result.NO_SOCKET,
			"a full item takes no more")
	check(inventory.backpack.has(extra), "and keeps the talisman")


## Applies talismans until gear's sockets are full. Returns the failures.
func _fill_sockets(config: LootConfig, generator: ItemGenerator, rules: TalismanRules,
		inventory: Inventory, gear: ItemData) -> int:
	check_eq(rules.sockets(gear), config.talisman_sockets[4], "sockets by rarity")
	var successes := 0
	var failures_seen := 0
	var attempts := 0
	while rules.free_sockets(gear) > 0 and attempts < 200:
		attempts += 1
		var talisman := generator.roll_talisman(1)
		inventory.backpack.append(talisman)
		var stats_before := gear.talisman_stats.size()
		var chance := rules.chance_for(gear)
		var result := rules.apply(talisman, gear, inventory)
		check(not inventory.backpack.has(talisman), "the talisman is used up either way")
		check(inventory.is_equipped(gear), "the gear stays worn")
		check_eq(gear.values[0], 20.0, "its own stats are untouched")
		if result == TalismanRules.Result.SUCCESS:
			successes += 1
			check_eq(gear.talisman_stats.size(), stats_before + talisman.stats.size(),
					"success adds the talisman's stats")
			check(gear.value_of(talisman.stats[0]) >= talisman.values[0] - 0.0001,
					"which count toward the gear's value")
		else:
			failures_seen += 1
			check_eq(result, TalismanRules.Result.FAILED, "or it fails")
			check_eq(gear.talisman_stats.size(), stats_before, "failure adds nothing")
		check(chance <= config.talisman_chances[0], "chance never above the first")
	check_eq(successes, config.talisman_sockets[4], "fills every socket")
	return failures_seen


func test_set_and_talisman_fields_save() -> void:
	var item := ItemData.new()
	item.slot = AffixDef.Slot.RING
	item.rarity = 5
	item.set_id = 3
	item.talisman_stats = PackedInt32Array([PlayerStat.Id.EVASION])
	item.talisman_values = PackedFloat32Array([0.03])
	item.talisman_sockets_used = 1
	var back := SaveCodec.item_from_dict(SaveCodec.item_to_dict(item), 10)
	check_eq(back.rarity, 5, "set rarity survives")
	check_eq(back.set_id, 3, "set survives")
	check_eq(back.talisman_sockets_used, 1, "sockets used survive")
	check_near(back.value_of(PlayerStat.Id.EVASION), 0.03, 0.0001, "talisman stats survive")
	var talisman := ItemData.new()
	talisman.is_talisman = true
	check(SaveCodec.item_from_dict(SaveCodec.item_to_dict(talisman), 10).is_talisman,
			"talismans stay talismans")
