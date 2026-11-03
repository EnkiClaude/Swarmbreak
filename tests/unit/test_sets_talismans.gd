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
	check_eq(world.dungeons.size(), 10, "ten dungeons")
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


func test_talismans_are_fixed_per_kind_and_tier_and_stack() -> void:
	var config := _loot()
	var rules := TalismanRules.new(config, 11)
	check(config.talismans.size() >= 8, "many kinds of talisman (%d)" % config.talismans.size())
	var hints := {}
	for def in config.talismans:
		hints[def.build_hint] = true
		check_eq(def.values.size(), def.stats.size(), "%s lines up" % def.talisman_name)
	check(hints.size() >= 4, "for different builds (%d)" % hints.size())
	var inventory := Inventory.new(4)
	var first := -1
	for n in 300:
		var id := rules.roll()
		check(TalismanRules.is_valid(config, id), "a real talisman")
		check(TalismanRules.tier_of(id) <= config.talisman_max_rarity, "never set rarity")
		inventory.add_talisman(id)
		if first < 0:
			first = id
	check(inventory.backpack.is_empty(), "talismans take no backpack room")
	check(inventory.talisman_ids().size() < 300, "equal talismans stack")
	# Same kind and tier: the same values, every time.
	check_eq(TalismanRules.values_of(config, first), TalismanRules.values_of(config, first),
			"fixed values")
	var low := TalismanRules.id_of(0, 0)
	var high := TalismanRules.id_of(0, 4)
	check(TalismanRules.values_of(config, high)[0] > TalismanRules.values_of(config, low)[0],
			"a higher tier gives more")
	check(TalismanRules.display_name(config, high).begins_with(config.rarity_names[4]),
			"named by tier: %s" % TalismanRules.display_name(config, high))
	check(rules.roll(3) % TalismanRules.TIERS >= 3, "a minimum tier holds")


func test_applying_talismans_never_harms_gear() -> void:
	var config := _loot()
	var rules := TalismanRules.new(config, 99)
	var inventory := Inventory.new(8)
	var id := TalismanRules.id_of(0, 2)
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
		check_eq(rules.sockets(gear), config.talisman_sockets[4], "sockets by rarity")
		var successes := 0
		var attempts := 0
		while rules.free_sockets(gear) > 0 and attempts < 200:
			attempts += 1
			inventory.add_talisman(id)
			var before := inventory.talisman_count(id)
			var result := rules.apply(id, gear, inventory)
			check_eq(inventory.talisman_count(id), before - 1, "one is used up either way")
			check(inventory.is_equipped(gear), "the gear stays worn")
			check_eq(gear.values[0], 20.0, "its own stats are untouched")
			if result == TalismanRules.Result.SUCCESS:
				successes += 1
			else:
				failures_seen += 1
				check_eq(result, TalismanRules.Result.FAILED, "or it fails")
		check_eq(successes, config.talisman_sockets[4], "fills every socket")
		# Equal talismans stack on the gear too: the stat adds up per socket.
		var stat := TalismanRules.stats_of(config, id)[0]
		check_near(gear.value_of(stat), TalismanRules.values_of(config, id)[0] * successes
				+ (20.0 if stat == PlayerStat.Id.MAX_HEALTH else 0.0) * gear.upgrade_multiplier(),
				0.001, "stacked talismans add up")
	check(failures_seen > 0, "some attempts fail (%d)" % failures_seen)
	inventory.add_talisman(id)
	check_eq(rules.apply(id, gear, inventory), TalismanRules.Result.NO_SOCKET,
			"a full item takes no more")
	check_eq(inventory.talisman_count(id), 1, "and keeps the talisman")
	check_eq(rules.apply(TalismanRules.id_of(1, 0), gear, inventory),
			TalismanRules.Result.INVALID, "can't apply one you don't have")


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
	# Talisman stacks survive a save.
	var progress := PlayerProgress.new(load("res://data/rpg/progression.tres") as ProgressionConfig,
			load("res://data/rpg/skills.tres") as SkillTree,
			load("res://data/rpg/attributes.tres") as AttributeTable)
	var inventory := Inventory.new(8)
	inventory.add_talisman(TalismanRules.id_of(3, 2), 4)
	var data: Dictionary = JSON.parse_string(JSON.stringify(SaveCodec.encode(progress, inventory, 1)))
	var loaded := Inventory.new(8)
	SaveCodec.decode(data, progress, loaded, null, 99, 10)
	check_eq(loaded.talisman_count(TalismanRules.id_of(3, 2)), 4, "talisman stacks survive")


func test_dreadforged_armor_is_its_own_red_rarity() -> void:
	var config := _loot()
	var generator := ItemGenerator.new(config, 13)
	var dread := config.dread_rarity
	check(config.rarity_colors[dread].r > 0.8 and config.rarity_colors[dread].g < 0.3,
			"Dreadforged shows red")
	check_eq(config.rarity_weights[dread], 0.0, "never rolled at random")
	for n in 2000:
		check(generator.roll(80, 4).rarity != dread, "random drops are never Dreadforged")
	for n in 40:
		var item := generator.roll_dread(60)
		check_eq(item.rarity, dread, "the Dread Lord's drops are")
		check(config.dread_slots.has(item.slot), "and armor (slot %d)" % item.slot)
		check(item.item_name.begins_with(config.dread_prefix), "named %s" % item.item_name)
		# As many affixes as its slot's pool allows, up to the rarity's count.
		var pool := 0
		for affix in config.affixes:
			if affix.slots.has(item.slot):
				pool += 1
		check(item.stats.size() >= mini(config.rarity_affixes[dread], pool),
				"%s carries a full set of stats (%d)" % [item.item_name, item.stats.size()])


func test_talismans_dissolve_into_essence_that_buys_attribute_points() -> void:
	var config := _loot()
	var rules := TalismanRules.new(config, 3)
	var inventory := Inventory.new(8)
	var progress := PlayerProgress.new(load("res://data/rpg/progression.tres") as ProgressionConfig,
			load("res://data/rpg/skills.tres") as SkillTree,
			load("res://data/rpg/attributes.tres") as AttributeTable)
	var id := TalismanRules.id_of(2, 4)
	inventory.add_talisman(id, 10)
	var each := TalismanRules.essence_of(config, id)
	check(each > TalismanRules.essence_of(config, TalismanRules.id_of(2, 0)),
			"rarer talismans give more essence")
	check_eq(rules.dissolve(id, 3, inventory), each * 3, "three dissolved")
	check_eq(inventory.talisman_count(id), 7, "three fewer")
	rules.dissolve(id, 99, inventory)
	check_eq(inventory.talisman_count(id), 0, "can't dissolve more than you have")
	inventory.essence = 1000
	var points := progress.attribute_points
	var first := rules.scroll_cost(inventory)
	check(rules.bind_scroll(inventory, progress), "a scroll binds")
	check_eq(progress.attribute_points, points + 1, "for one attribute point")
	check_eq(inventory.essence, 1000 - first, "costing essence")
	check(rules.scroll_cost(inventory) > first, "the next costs more")
	inventory.essence = 0
	check(not rules.bind_scroll(inventory, progress), "no essence, no scroll")
