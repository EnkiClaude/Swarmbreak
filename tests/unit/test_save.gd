extends TestSuite

const TEST_PATH := "user://test_save_unit.json"


func _jobs() -> JobTree:
	return load("res://data/rpg/jobs.tres") as JobTree


func _progress() -> PlayerProgress:
	return PlayerProgress.new(load("res://data/rpg/progression.tres") as ProgressionConfig,
			load("res://data/rpg/skills.tres") as SkillTree)


func _item(slot: int, rarity: int) -> ItemData:
	var item := ItemData.new()
	item.slot = slot
	item.rarity = rarity
	item.item_name = "Storm Wand"
	item.stats = PackedInt32Array([PlayerStat.Id.BOLT_DAMAGE, PlayerStat.Id.NOVA_DAMAGE])
	item.values = PackedFloat32Array([0.12, 0.08])
	item.item_level = 3
	item.upgrade_level = 4
	item.upgrade_bonus = 0.08
	item.fail_streak = 2
	return item


func test_round_trip_keeps_everything() -> void:
	var jobs := _jobs()
	var progress := _progress()
	progress.level = 27
	progress.xp = 123.5
	progress.skill_points = 3
	progress.ranks[0] = 4
	progress.ranks[5] = 2
	progress.job = 2
	progress.job_rank = 2
	var inventory := Inventory.new(16)
	inventory.add(_item(AffixDef.Slot.WEAPON, 2))
	inventory.add(_item(AffixDef.Slot.WEAPON, 1))  # goes to the backpack
	inventory.stones = 41
	# Through JSON text, exactly as the file would hold it.
	var text := JSON.stringify(SaveCodec.encode(progress, inventory, 6))
	var data: Dictionary = JSON.parse_string(text)

	var p2 := _progress()
	var inv2 := Inventory.new(16)
	var zone := SaveCodec.decode(data, p2, inv2, jobs, 50, 10)
	check_eq(zone, 6, "zone level")
	check_eq(p2.level, 27, "level")
	check_near(p2.xp, 123.5, 0.001, "xp")
	check_eq(p2.skill_points, 3, "skill points")
	check_eq(p2.ranks[0], 4, "rank 0")
	check_eq(p2.ranks[5], 2, "rank 5")
	check_eq(p2.job, 2, "job")
	check_eq(p2.job_rank, 2, "job rank")
	check_eq(inv2.stones, 41, "stones")
	var wand := inv2.equipped[AffixDef.Slot.WEAPON]
	check(wand != null, "weapon equipped")
	check(inv2.equipped[AffixDef.Slot.CHARM] == null, "empty slot stays empty")
	check_eq(inv2.backpack.size(), 1, "backpack item")
	check_eq(wand.rarity, 2, "rarity")
	check_eq(wand.upgrade_level, 4, "refine level")
	check_eq(wand.fail_streak, 2, "failure streak")
	check_near(wand.value_of(PlayerStat.Id.BOLT_DAMAGE),
			_item(0, 2).value_of(PlayerStat.Id.BOLT_DAMAGE), 0.0001, "same stat value")


func test_decode_tolerates_missing_and_bad_data() -> void:
	var progress := _progress()
	var inventory := Inventory.new(4)
	var zone := SaveCodec.decode({"version": 1}, progress, inventory, _jobs(), 50, 10)
	check_eq(zone, 1, "zone defaults to 1")
	check_eq(progress.level, 1, "level defaults to 1")
	check_eq(progress.job, -1, "no job")
	var junk := {
		"zone_level": "lots",
		"progress": {"level": 9999, "job": 77, "ranks": "nope", "skill_points": -5},
		"inventory": {"stones": -3, "equipped": [{"slot": 2, "rarity": 99,
				"upgrade_level": 99, "stats": [999, 3], "values": [1.0, 0.2]}],
				"backpack": "x"},
	}
	zone = SaveCodec.decode(junk, progress, inventory, _jobs(), 50, 10)
	check_eq(zone, 1, "non-number zone falls back")
	check_eq(progress.level, 50, "level clamped to max")
	check_eq(progress.job, -1, "unknown job dropped")
	check_eq(progress.skill_points, 0, "negative points clamped")
	check_eq(inventory.stones, 0, "negative stones clamped")
	check(inventory.equipped[0] == null, "item saved under the wrong slot is dropped")


func test_store_writes_reads_and_quarantines_corruption() -> void:
	var store := SaveStore.new(TEST_PATH)
	store.delete()
	check(store.read().is_empty() and store.last_status == SaveStore.Status.MISSING, "no save yet")
	check(store.write({"version": 1, "zone_level": 3}), "write works")
	var data := store.read()
	check_eq(store.last_status, SaveStore.Status.OK, "reads back")
	check_eq(int(data.get("zone_level")), 3, "same content")
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	check(store.read().is_empty(), "corrupt save reads as empty")
	check_eq(store.last_status, SaveStore.Status.CORRUPT, "reported as corrupt")
	check(FileAccess.file_exists(TEST_PATH + ".bad"), "corrupt file kept as a backup")
	check(not store.exists(), "corrupt file moved out of the way")
	DirAccess.remove_absolute(TEST_PATH + ".bad")
