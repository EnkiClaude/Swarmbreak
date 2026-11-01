class_name ItemCompare
extends RefCounted
## Stat-by-stat comparison of a candidate item against what it would
## replace, for the inventory's details panel and tooltips.

enum Change { BETTER, WORSE, SAME, GAINED, LOST }


## One row per stat on either item: {stat, value (candidate), delta, change}.
## Stats the candidate has come first, then stats it would lose.
static func compare(candidate: ItemData, current: ItemData) -> Array[Dictionary]:
	var replaced: Array[ItemData] = []
	if current != null:
		replaced.append(current)
	return compare_against(candidate, replaced)


## Like compare(), against everything wearing the candidate would take off
## (a two-handed weapon replaces the main hand and the off hand together).
static func compare_against(candidate: ItemData, replaced: Array[ItemData]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var seen := {}
	for stat in candidate.stats:
		if seen.has(stat):
			continue
		seen[stat] = true
		var mine := candidate.value_of(stat)
		var theirs := _sum(replaced, stat)
		var change := _direction(mine - theirs) if _any_has(replaced, stat) else Change.GAINED
		rows.append({"stat": stat, "value": mine, "delta": mine - theirs, "change": change})
	for item in replaced:
		for stat in item.stats:
			if seen.has(stat):
				continue
			seen[stat] = true
			var theirs := _sum(replaced, stat)
			rows.append({"stat": stat, "value": 0.0, "delta": -theirs, "change": Change.LOST})
	return rows


static func _sum(items: Array[ItemData], stat: int) -> float:
	var total := 0.0
	for item in items:
		total += item.value_of(stat)
	return total


static func _any_has(items: Array[ItemData], stat: int) -> bool:
	for item in items:
		if item.stats.has(stat):
			return true
	return false


static func _direction(delta: float) -> Change:
	if absf(delta) < 0.0001:
		return Change.SAME
	return Change.BETTER if delta > 0.0 else Change.WORSE
