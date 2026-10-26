class_name ItemData
extends RefCounted
## One item: a slot, a rarity, a name and the stats it rolled.

## An AffixDef.Slot value.
var slot: int
var rarity: int
var item_name: String
var stats: PackedInt32Array = []
var values: PackedFloat32Array = []
## Zone level it dropped in.
var item_level: int = 1


func value_of(stat: int) -> float:
	var total := 0.0
	for k in stats.size():
		if stats[k] == stat:
			total += values[k]
	return total


func describe_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for k in stats.size():
		lines.append(PlayerStat.describe(stats[k], values[k]))
	return lines
