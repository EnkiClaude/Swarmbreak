extends TestSuite


func _pets() -> PetConfig:
	return load("res://data/rpg/pets.tres") as PetConfig


func test_eggs_hatch_at_ten_and_evolve_every_ten() -> void:
	var config := _pets()
	check_eq(PetRules.stage(config, 1), 0, "an egg at level 1")
	check_eq(PetRules.stage(config, 9), 0, "still an egg at 9")
	check_eq(PetRules.stage(config, 10), 1, "hatched at 10")
	check_eq(PetRules.stage(config, 20), 2, "evolved at 20")
	check_eq(PetRules.stage(config, 30), 3, "evolved again at 30")
	check(PetRules.xp_share(config, 20) > PetRules.xp_share(config, 5),
			"later stages take a bigger share of kill XP")
	check(PetRules.xp_to_next(config, 10) > PetRules.xp_to_next(config, 9) * 1.3,
			"each stage needs much more XP")


func test_every_egg_suits_a_build_and_grows() -> void:
	var config := _pets()
	check(config.pets.size() >= 4, "four eggs (%d)" % config.pets.size())
	var stats := {}
	for kind in config.pets.size():
		var egg := PetRules.make_egg(config, kind)
		check(egg.is_pet(), "an egg goes in the pet slot")
		check_eq(egg.item_name, config.pets[kind].stage_names[0], "named as an egg")
		check(not egg.stats.is_empty(), "%s gives stats" % egg.item_name)
		stats[egg.stats[0]] = true
		var first := egg.values[0]
		egg.pet_level = 25
		PetRules.refresh(config, egg)
		check(egg.values[0] > first, "%s's stats grow with level" % config.pets[kind].display_name)
		check_eq(egg.item_name, config.pets[kind].stage_names[2], "named for its stage")
	check_eq(stats.size(), config.pets.size(), "each egg favors a different stat")


func test_xp_levels_the_pet_and_it_hatches() -> void:
	var config := _pets()
	var egg := PetRules.make_egg(config, 0)
	var levels := 0
	for n in 2000:
		levels += PetRules.gain_xp(config, egg, 40.0)
		if egg.pet_level >= 10:
			break
	check(egg.pet_level >= 10, "enough XP hatches it (level %d)" % egg.pet_level)
	check_eq(egg.item_name, config.pets[0].stage_names[1], "hatched name")
	check(levels >= 9, "levelled up step by step")


func test_pet_slot_takes_only_pets() -> void:
	var inventory := Inventory.new(4)
	var egg := PetRules.make_egg(_pets(), 1)
	check(inventory.add(egg), "egg added")
	check(inventory.equipped[Inventory.Equip.PET] == egg, "worn in the pet slot")
	var helm := ItemData.new()
	helm.slot = AffixDef.Slot.HELM
	inventory.add(helm)
	check(inventory.equipped[Inventory.Equip.HELM] == helm, "a helm goes on the head")
	check(not inventory.can_equip(helm, Inventory.Equip.PET), "a helm is not a pet")


func test_quest_counts_camps_then_offers_its_reward_once() -> void:
	var quests := QuestLog.new(load("res://data/rpg/quests.tres") as QuestList)
	var q := quests.current()
	check_eq(q, 0, "the first quest is current")
	var target := quests.list.quests[q].target
	for n in target - 1:
		quests.on_camp_cleared()
	check(not quests.reward_waiting(q), "not done one camp short")
	quests.on_camp_cleared()
	check(quests.reward_waiting(q), "done after %d camps" % target)
	check(quests.claim(q), "claim the reward")
	check(not quests.claim(q), "only once")


func test_saves_keep_pets_quests_and_blessed_stones() -> void:
	var progress := PlayerProgress.new(load("res://data/rpg/progression.tres") as ProgressionConfig,
			load("res://data/rpg/skills.tres") as SkillTree)
	var inventory := Inventory.new(8)
	var egg := PetRules.make_egg(_pets(), 2)
	egg.pet_level = 14
	egg.pet_xp = 33.0
	inventory.add(egg)
	inventory.blessed_stones = 3
	var quests := QuestLog.new(load("res://data/rpg/quests.tres") as QuestList)
	quests.on_camp_cleared()
	quests.on_camp_cleared()
	var data := SaveCodec.encode(progress, inventory, 1)
	data["quests"] = SaveCodec.encode_quests(quests)
	var inv2 := Inventory.new(8)
	SaveCodec.decode(data, progress, inv2, null, 50, 10)
	var quests2 := QuestLog.new(quests.list)
	SaveCodec.decode_quests(data.get("quests"), quests2)
	var pet := inv2.equipped[Inventory.Equip.PET]
	check(pet != null and pet.pet_type == 2, "the pet came back")
	check_eq(pet.pet_level, 14, "at its level")
	check_near(pet.pet_xp, 33.0, 0.001, "with its XP")
	check_eq(inv2.blessed_stones, 3, "Blessed Stones kept")
	check_eq(quests2.progress[0], 2, "quest progress kept")


func test_blessed_stone_always_succeeds() -> void:
	var config := load("res://data/rpg/loot.tres") as LootConfig
	var refinery := Refinery.new(config, 4)
	var inventory := Inventory.new(4)
	var item := ItemData.new()
	item.slot = AffixDef.Slot.WEAPON
	item.upgrade_level = 9
	inventory.add(item)
	check_eq(refinery.attempt_blessed(item, inventory), Refinery.Result.NOT_ENOUGH_STONES,
			"needs a stone")
	inventory.blessed_stones = 1
	check_eq(refinery.attempt_blessed(item, inventory), Refinery.Result.SUCCESS, "certain success")
	check_eq(item.upgrade_level, 10, "+9 to +10")
	check_eq(inventory.blessed_stones, 0, "the stone was used")


func test_pickup_range_grows_a_metre_every_level() -> void:
	var config := _pets()
	check_eq(PetRules.pickup_radius(config, 9), 0.0, "an egg collects nothing")
	var hatched := PetRules.pickup_radius(config, 10)
	check(hatched > 0.0, "a hatched pet collects (%.1f m)" % hatched)
	check_near(PetRules.pickup_radius(config, 11) - hatched, 1.0, 0.001, "+1 m at the next level")
	check_near(PetRules.pickup_radius(config, 30) - hatched, 20.0, 0.001, "+20 m twenty levels on")


func test_pets_fight_from_25_and_aggro_from_50() -> void:
	var config := _pets()
	check_eq(PetRules.attack_damage(config, config.attack_level - 1), 0.0, "no damage before 25")
	var first := PetRules.attack_damage(config, config.attack_level)
	check(first > 0.0, "it starts zapping at %d (%.1f)" % [config.attack_level, first])
	check(PetRules.attack_damage(config, config.attack_level + 1) > first, "a little more per level")
	check(PetRules.attack_damage(config, config.attack_level + 1) - first < first * 0.5,
			"growing slowly")
	check_eq(PetRules.aggro_range(config, config.aggro_level - 1), 0.0, "no aggro before 50")
	var reach := PetRules.aggro_range(config, config.aggro_level)
	check(reach > 0.0, "it draws monsters at %d (%.1f m)" % [config.aggro_level, reach])
	check(PetRules.aggro_range(config, config.aggro_level + 10) > reach, "farther every level")
