extends TestSuite


func _progress() -> PlayerProgress:
	var progress := PlayerProgress.new(load("res://data/rpg/progression.tres") as ProgressionConfig,
			load("res://data/rpg/skills.tres") as SkillTree,
			load("res://data/rpg/attributes.tres") as AttributeTable)
	progress.set_actives(load("res://data/rpg/actives.tres") as ActiveSkillList)
	return progress


func test_active_skills_unlock_by_level_and_grade_up_with_points() -> void:
	var progress := _progress()
	var list := progress.actives
	check(list.skills.size() >= 4, "four active skills")
	var last_unlock := 0
	for def in list.skills:
		check(def.unlock_level > last_unlock, "%s unlocks later than the one before" %
				def.display_name)
		last_unlock = def.unlock_level
	var def := list.skills[0]
	progress.skill_points = 10
	progress.level = def.unlock_level - 1
	check(not progress.can_raise_grade(0), "too low a level to learn it")
	progress.level = def.unlock_level
	check(progress.raise_grade(0), "learned at its unlock level")
	check_eq(progress.active_grade(0), 1, "grade 1")
	check_eq(progress.skill_points, 10 - list.grade_cost, "costs a skill point")
	check(not progress.can_raise_grade(0), "grade 2 needs more levels")
	progress.level = progress.level_for_grade(0, 2)
	check(progress.raise_grade(0), "grade 2 once the level is reached")
	progress.level = 200
	progress.skill_points = 100
	while progress.raise_grade(0):
		pass
	check_eq(progress.active_grade(0), def.max_grade, "stops at the max grade")
	progress.skill_points = 0
	check(not progress.can_raise_grade(1), "no points, no learning")


func test_active_grades_save_and_reset() -> void:
	var progress := _progress()
	progress.level = 40
	progress.skill_points = 5
	progress.raise_grade(1)
	progress.raise_grade(2)
	var inventory := Inventory.new(8)
	var data: Dictionary = JSON.parse_string(JSON.stringify(SaveCodec.encode(progress, inventory, 1)))
	var loaded := _progress()
	SaveCodec.decode(data, loaded, Inventory.new(8), null, 99, 10)
	check_eq(loaded.active_grade(1), 1, "grade survives a save")
	check_eq(loaded.active_grade(2), 1, "every grade survives")
	check_eq(loaded.active_grade(0), 0, "unlearned stays unlearned")
	var old := _progress()
	data["progress"].erase("active_grades")
	SaveCodec.decode(data, old, Inventory.new(8), null, 99, 10)
	check_eq(old.active_grade(1), 0, "older saves load with nothing learned")
	loaded.reset()
	check_eq(loaded.active_grade(1), 0, "new game forgets them")
