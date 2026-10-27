class_name ItemCompare
extends RefCounted
## Stat-by-stat comparison of a candidate item against the one it would
## replace, for the inventory's details panel.

enum Change { BETTER, WORSE, SAME, GAINED, LOST }


## One row per stat on either item: {stat, value (candidate), delta, change}.
## Stats the candidate has come first, then stats it would lose.
static func compare(candidate: ItemData, current: ItemData) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var seen := {}
	for stat in candidate.stats:
		if seen.has(stat):
			continue
		seen[stat] = true
		var mine := candidate.value_of(stat)
		var theirs := current.value_of(stat) if current != null else 0.0
		var change := Change.GAINED
		if current != null and current.stats.has(stat):
			change = _direction(mine - theirs)
		rows.append({"stat": stat, "value": mine, "delta": mine - theirs, "change": change})
	if current != null:
		for stat in current.stats:
			if seen.has(stat):
				continue
			seen[stat] = true
			var theirs := current.value_of(stat)
			rows.append({"stat": stat, "value": 0.0, "delta": -theirs, "change": Change.LOST})
	return rows


static func _direction(delta: float) -> Change:
	if absf(delta) < 0.0001:
		return Change.SAME
	return Change.BETTER if delta > 0.0 else Change.WORSE
