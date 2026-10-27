class_name PlayerStats
extends RefCounted
## Current stat totals from level, skill ranks, job perks and equipped items.
## Systems read these through value() and multiplier(), and the current job
## perks through perks; call recompute() whenever the level, skills, job or
## equipment change.

signal changed

var totals: PackedFloat32Array = []
## The current job rank's perks, or null with no job.
var perks: JobPerks

var _progress: PlayerProgress
var _tree: SkillTree
var _inventory: Inventory
var _progression: ProgressionConfig
var _jobs: JobTree


func _init(progress: PlayerProgress, tree: SkillTree, inventory: Inventory,
		progression: ProgressionConfig, jobs: JobTree = null) -> void:
	_progress = progress
	_tree = tree
	_inventory = inventory
	_progression = progression
	_jobs = jobs
	totals.resize(PlayerStat.COUNT)
	recompute()


func recompute() -> void:
	totals.fill(0.0)
	for skill in _tree.skills.size():
		var def := _tree.skills[skill]
		totals[def.stat] += def.per_rank * _progress.ranks[skill]
	for stat in PlayerStat.COUNT:
		totals[stat] += _inventory.total(stat)
	perks = _progress.perks(_jobs) if _jobs != null else null
	if perks != null:
		for k in perks.stats.size():
			totals[perks.stats[k]] += perks.values[k]
	totals[PlayerStat.Id.MAX_HEALTH] += _progression.health_per_level * (_progress.level - 1)
	totals[PlayerStat.Id.MAX_MANA] += _progression.mana_per_level * (_progress.level - 1)
	for stat in PlayerStat.COUNT:
		totals[stat] = minf(totals[stat], PlayerStat.CAPS[stat])
	changed.emit()


func value(stat: int) -> float:
	return totals[stat]


## 1 + the stat, for percent stats.
func multiplier(stat: int) -> float:
	return 1.0 + totals[stat]
