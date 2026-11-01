class_name ItemData
extends RefCounted
## One item: a kind (LootConfig.item_kinds), its slot, a rarity, a name, the
## stats it rolled (its kind's implicit first), and its refine level. Each
## refine level adds upgrade_bonus to every stat.

## An AffixDef.Slot value.
var slot: int
## Index into LootConfig.item_kinds, or -1 when unknown (very old saves).
var kind: int = -1
## Takes both hands: equipping it empties the off hand.
var two_handed: bool = false
var rarity: int
var item_name: String
var stats: PackedInt32Array = []
var values: PackedFloat32Array = []
## Level of the camp it dropped from.
var item_level: int = 1
## +0 .. LootConfig.upgrade_max.
var upgrade_level: int = 0
## Fraction each refine level adds to every stat.
var upgrade_bonus: float = 0.0
## Failed refines in a row, which raise the next chance.
var fail_streak: int = 0
## Pets only (slot PET): the PetConfig.pets kind, level and XP (see PetRules).
var pet_type: int = -1
var pet_level: int = 1
var pet_xp: float = 0.0
## Order it reached the inventory (higher is newer), for sorting by newest.
var acquired: int = 0
## Set items: index into SetList.sets, else -1.
var set_id: int = -1
## Gear only: stats from talismans applied to it (refining doesn't raise them).
var talisman_stats: PackedInt32Array = []
var talisman_values: PackedFloat32Array = []
## Talismans applied (a talisman can carry more than one stat).
var talisman_sockets_used: int = 0


func is_pet() -> bool:
	return slot == AffixDef.Slot.PET


func is_set() -> bool:
	return set_id >= 0


func upgrade_multiplier() -> float:
	return 1.0 + upgrade_bonus * upgrade_level


func display_name() -> String:
	return item_name if upgrade_level == 0 else "+%d %s" % [upgrade_level, item_name]


func value_of(stat: int) -> float:
	var total := 0.0
	for k in stats.size():
		if stats[k] == stat:
			total += values[k]
	total *= upgrade_multiplier()
	for k in talisman_stats.size():
		if talisman_stats[k] == stat:
			total += talisman_values[k]
	return total


func describe_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var mult := upgrade_multiplier()
	for k in stats.size():
		lines.append(PlayerStat.describe(stats[k], values[k] * mult))
	for k in talisman_stats.size():
		lines.append("%s  (talisman)" % PlayerStat.describe(talisman_stats[k], talisman_values[k]))
	return lines
