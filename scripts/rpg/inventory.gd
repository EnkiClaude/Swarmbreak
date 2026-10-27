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


## True if add() would succeed: the item's slot is empty or the backpack has room.
func can_accept(item: ItemData) -> bool:
	return equipped[item.slot] == null or backpack.size() < backpack_size


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


## Equips a backpack item by reference (see equip()).
func equip_item(item: ItemData) -> void:
	var index := backpack.find(item)
	if index >= 0:
		equip(index)


## Stones salvaging this item would give.
static func salvage_value(item: ItemData, salvage_table: PackedInt32Array) -> int:
	return salvage_table[mini(item.rarity, salvage_table.size() - 1)] + item.upgrade_level


## Salvages a backpack item by reference. Returns the stones gained (0 if absent).
func salvage_item(item: ItemData, salvage_table: PackedInt32Array) -> int:
	var index := backpack.find(item)
	return salvage(index, salvage_table) if index >= 0 else 0


## How many backpack items of a rarity there are and what salvaging them all
## would give: [count, stones].
func salvage_all_preview(rarity: int, salvage_table: PackedInt32Array) -> Array:
	var count := 0
	var stones_total := 0
	for item in backpack:
		if item.rarity == rarity:
			count += 1
			stones_total += salvage_value(item, salvage_table)
	return [count, stones_total]


## Salvages every backpack item of one rarity (equipped items are never
## touched). Returns the stones gained.
func salvage_all(rarity: int, salvage_table: PackedInt32Array) -> int:
	var gained := 0
	for index in range(backpack.size() - 1, -1, -1):
		if backpack[index].rarity == rarity:
			gained += salvage_value(backpack[index], salvage_table)
			backpack.remove_at(index)
	if gained > 0:
		stones += gained
		changed.emit()
	return gained


## Orders the backpack by slot, then best rarity and refine level first.
func sort_backpack() -> void:
	backpack.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.slot != b.slot:
			return a.slot < b.slot
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		return a.upgrade_level > b.upgrade_level)


## Breaks a backpack item down into stones. Returns how many it gave.
func salvage(backpack_index: int, salvage_table: PackedInt32Array) -> int:
	var gained := salvage_value(backpack[backpack_index], salvage_table)
	backpack.remove_at(backpack_index)
	stones += gained
	changed.emit()
	return gained


func add_stones(amount: int) -> void:
	stones += amount
	changed.emit()


## Empties everything (New Game).
func reset() -> void:
	equipped = [null, null, null]
	backpack.clear()
	stones = 0
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
