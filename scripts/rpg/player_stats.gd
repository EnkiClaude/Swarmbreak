class_name PlayerStats
extends RefCounted
## Current stat totals from level, skill ranks and equipped items. Systems
## read these through value() and multiplier(); call recompute() whenever
## the level, skills or equipment change.

signal changed

var totals: PackedFloat32Array = []

var _progress: PlayerProgress
var _tree: SkillTree
var _inventory: Inventory
var _progression: ProgressionConfig


func _init(progress: PlayerProgress, tree: SkillTree, inventory: Inventory,
		progression: ProgressionConfig) -> void:
	_progress = progress
	_tree = tree
	_inventory = inventory
	_progression = progression
	totals.resize(PlayerStat.COUNT)
	recompute()


func recompute() -> void:
	totals.fill(0.0)
	for skill in _tree.skills.size():
		var def := _tree.skills[skill]
		totals[def.stat] += def.per_rank * _progress.ranks[skill]
	for stat in PlayerStat.COUNT:
		totals[stat] += _inventory.total(stat)
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
