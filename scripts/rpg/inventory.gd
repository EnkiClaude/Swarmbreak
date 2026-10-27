class_name Inventory
extends RefCounted
## Equipped items (one per slot), the backpack and Refining Stones.

signal changed

## Indexed by AffixDef.Slot; null when empty.
var equipped: Array[ItemData] = [null, null, null]
var backpack: Array[ItemData] = []
var backpack_size: int
## Currency for refining items.
var stones: int = 0


func _init(p_backpack_size: int) -> void:
	backpack_size = p_backpack_size


## Equips into an empty slot, otherwise stores in the backpack. False if full.
func add(item: ItemData) -> bool:
	if equipped[item.slot] == null:
		equipped[item.slot] = item
		changed.emit()
		return true
	if backpack.size() >= backpack_size:
		return false
	backpack.append(item)
	changed.emit()
	return true


## Equips a backpack item, moving whatever it replaces into the backpack.
func equip(backpack_index: int) -> void:
	var item := backpack[backpack_index]
	var previous := equipped[item.slot]
	equipped[item.slot] = item
	if previous != null:
		backpack[backpack_index] = previous
	else:
		backpack.remove_at(backpack_index)
	changed.emit()


func discard(backpack_index: int) -> void:
	backpack.remove_at(backpack_index)
	changed.emit()


## Breaks a backpack item down into stones. Returns how many it gave.
func salvage(backpack_index: int, salvage_table: PackedInt32Array) -> int:
	var item := backpack[backpack_index]
	var gained: int = salvage_table[mini(item.rarity, salvage_table.size() - 1)] \
			+ item.upgrade_level
	backpack.remove_at(backpack_index)
	stones += gained
	changed.emit()
	return gained


func add_stones(amount: int) -> void:
	stones += amount
	changed.emit()


## Call after changing an item in place (e.g. refining it).
func notify_changed() -> void:
	changed.emit()


func total(stat: int) -> float:
	var sum := 0.0
	for item in equipped:
		if item != null:
			sum += item.value_of(stat)
	return sum
