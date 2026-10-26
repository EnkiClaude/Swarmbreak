class_name PlayerProgress
extends RefCounted
## Level, XP and skill points, plus how many points sit in each skill.
## Survives death and zone changes.

signal leveled_up(level: int)

var level := 1
var xp := 0.0
var skill_points := 0
## Rank per skill, indexed like SkillTree.skills.
var ranks: PackedInt32Array = []

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


## Spends a point on a skill. Returns whether it worked.
func rank_up(skill: int) -> bool:
	if not can_rank_up(skill):
		return false
	ranks[skill] += 1
	skill_points -= 1
	return true
