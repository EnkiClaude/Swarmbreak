class_name PlayerProgress
extends RefCounted
## Level, XP and skill points, how many points sit in each skill, attribute
## points and how many sit in each attribute (AttributeTable), and the chosen
## job and its rank, and the grade of each active skill (ActiveSkillList; 0
## = not learned). Skill points buy passive ranks and active grades alike.
## Survives death and travel.

signal leveled_up(level: int)
signal job_changed(job: int, rank: int)
signal skills_changed
signal attributes_changed

var level := 1
var xp := 0.0
var skill_points := 0
## Grade per active skill, indexed like ActiveSkillList.skills (0: unlearned).
var active_grades: PackedInt32Array = []
## Set by set_actives(); null when the game has no active skills.
var actives: ActiveSkillList
## Rank per skill, indexed like SkillTree.skills.
var ranks: PackedInt32Array = []
## Index into JobTree.jobs, or -1 before choosing.
var job := -1
## 0 = no job, 1 = first rank, 2 = promoted.
var job_rank := 0
var attribute_points := 0
## Points per attribute, indexed like AttributeTable.attributes.
var attributes: PackedInt32Array = []
## Null when the game has no attributes (some tests).
var attribute_table: AttributeTable

var _config: ProgressionConfig
var _tree: SkillTree


func _init(config: ProgressionConfig, tree: SkillTree, table: AttributeTable = null) -> void:
	_config = config
	_tree = tree
	attribute_table = table
	ranks.resize(tree.skills.size())
	ranks.fill(0)
	attributes.resize(table.attributes.size() if table != null else 0)
	attributes.fill(0)
	attribute_points = table.starting_points if table != null else 0


func is_max_level() -> bool:
	return level >= _config.max_level


func xp_to_next() -> float:
	return _config.xp_first_level * pow(_config.xp_growth, level - 1)


func add_xp(amount: float) -> void:
	if level >= _config.max_level:
		return
	xp += amount
	while xp >= xp_to_next() and level < _config.max_level:
		xp -= xp_to_next()
		level += 1
		skill_points += _config.skill_points_per_level
		if attribute_table != null:
			attribute_points += attribute_table.points_per_level
		leveled_up.emit(level)


func set_actives(list: ActiveSkillList) -> void:
	actives = list
	active_grades.resize(list.skills.size() if list != null else 0)


func active_grade(skill: int) -> int:
	return active_grades[skill] if skill >= 0 and skill < active_grades.size() else 0


## The level a skill's next grade needs (its unlock level for grade 1).
func level_for_grade(skill: int, grade: int) -> int:
	var def := actives.skills[skill]
	return def.unlock_level + def.grade_level_step * (grade - 1)


func can_raise_grade(skill: int) -> bool:
	if actives == null or skill < 0 or skill >= active_grades.size():
		return false
	var next := active_grades[skill] + 1
	return next <= actives.skills[skill].max_grade and skill_points >= actives.grade_cost \
			and level >= level_for_grade(skill, next)


## Learns an active skill or raises its grade, for skill points.
func raise_grade(skill: int) -> bool:
	if not can_raise_grade(skill):
		return false
	active_grades[skill] += 1
	skill_points -= actives.grade_cost
	skills_changed.emit()
	return true


func can_rank_up(skill: int) -> bool:
	return skill_points > 0 and ranks[skill] < _tree.skills[skill].max_rank


func can_choose_job(jobs: JobTree) -> bool:
	return job < 0 and level >= jobs.unlock_level


func choose_job(jobs: JobTree, index: int) -> bool:
	if not can_choose_job(jobs) or index < 0 or index >= jobs.jobs.size():
		return false
	job = index
	job_rank = 1
	if level >= jobs.rank2_level:
		job_rank = 2
	job_changed.emit(job, job_rank)
	return true


## Promotes to rank 2 once the level allows. Returns whether it happened.
func promote_if_ready(jobs: JobTree) -> bool:
	if job < 0 or job_rank >= 2 or level < jobs.rank2_level:
		return false
	job_rank = 2
	job_changed.emit(job, job_rank)
	return true


## The current rank's perks, or null with no job.
func perks(jobs: JobTree) -> JobPerks:
	if job < 0:
		return null
	var def := jobs.jobs[job]
	return def.rank2 if job_rank >= 2 else def.rank1


func job_title(jobs: JobTree) -> String:
	if job < 0:
		return ""
	var def := jobs.jobs[job]
	return def.rank2_name if job_rank >= 2 else def.display_name


## Spends a point on a skill. Returns whether it worked.
func rank_up(skill: int) -> bool:
	if not can_rank_up(skill):
		return false
	ranks[skill] += 1
	skill_points -= 1
	skills_changed.emit()
	return true


## Attribute points a character of this level has earned in total.
func earned_attribute_points() -> int:
	if attribute_table == null:
		return 0
	return attribute_table.starting_points + attribute_table.points_per_level * (level - 1)


## Puts up to amount points into an attribute. Returns how many went in.
func raise_attribute(attribute: int, amount: int = 1) -> int:
	if attribute < 0 or attribute >= attributes.size():
		return 0
	var spent := mini(amount, attribute_points)
	if spent <= 0:
		return 0
	attributes[attribute] += spent
	attribute_points -= spent
	attributes_changed.emit()
	return spent


## Back to a brand-new level 1 character (New Game).
func reset() -> void:
	level = 1
	xp = 0.0
	skill_points = 0
	ranks.fill(0)
	active_grades.fill(0)
	attributes.fill(0)
	attribute_points = attribute_table.starting_points if attribute_table != null else 0
	job = -1
	job_rank = 0
	job_changed.emit(job, job_rank)
