class_name ItemData
extends RefCounted
## One item: a slot, a rarity, a name, the stats it rolled, and its refine
## level. Each refine level adds upgrade_bonus to every stat.

## An AffixDef.Slot value.
var slot: int
var rarity: int
var item_name: String
var stats: PackedInt32Array = []
var values: PackedFloat32Array = []
## Zone level it dropped in.
var item_level: int = 1
## +0 .. LootConfig.upgrade_max.
var upgrade_level: int = 0
## Fraction each refine level adds to every stat.
var upgrade_bonus: float = 0.0
## Failed refines in a row, which raise the next chance.
var fail_streak: int = 0


func upgrade_multiplier() -> float:
	return 1.0 + upgrade_bonus * upgrade_level


func display_name() -> String:
	return item_name if upgrade_level == 0 else "+%d %s" % [upgrade_level, item_name]


func value_of(stat: int) -> float:
	var total := 0.0
	for k in stats.size():
		if stats[k] == stat:
			total += values[k]
	return total * upgrade_multiplier()


func describe_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var mult := upgrade_multiplier()
	for k in stats.size():
		lines.append(PlayerStat.describe(stats[k], values[k] * mult))
	return lines
