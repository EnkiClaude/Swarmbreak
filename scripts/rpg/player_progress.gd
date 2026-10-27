class_name PlayerProgress
extends RefCounted
## Level, XP and skill points, how many points sit in each skill, and the
## chosen job and its rank. Survives death and zone changes.

signal leveled_up(level: int)
signal job_changed(job: int, rank: int)
signal skills_changed

var level := 1
var xp := 0.0
var skill_points := 0
## Rank per skill, indexed like SkillTree.skills.
var ranks: PackedInt32Array = []
## Index into JobTree.jobs, or -1 before choosing.
var job := -1
## 0 = no job, 1 = first rank, 2 = promoted.
var job_rank := 0

var _config: ProgressionConfig
var _tree: SkillTree


func _init(config: ProgressionConfig, tree: SkillTree) -> void:
	_config = config
	_tree = tree
	ranks.resize(tree.skills.size())
	ranks.fill(0)


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
		leveled_up.emit(level)


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


## Back to a brand-new level 1 character (New Game).
func reset() -> void:
	level = 1
	xp = 0.0
	skill_points = 0
	ranks.fill(0)
	job = -1
	job_rank = 0
	job_changed.emit(job, job_rank)
