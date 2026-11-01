class_name Inventory
extends RefCounted
## Equipped items, the backpack and Geon (the currency, kept in `stones`). Equipment positions
## (Equip) match AffixDef.Slot for every slot but rings, which have two. A
## two-handed weapon and an off-hand item can't be worn together: equipping
## one moves the other to the backpack, so that needs room there.
## Talismans live in the backpack and are never worn. Wearing several pieces
## of a set adds its bonuses (sets) to total().

signal changed

## How sort_backpack() orders the backpack (talismans always last).
enum SortMode { SLOT, RARITY, LEVEL, NEWEST }
const SORT_NAMES: PackedStringArray = ["Slot", "Rarity", "Level", "Newest"]

## Where an item can be worn. The first five equal their AffixDef.Slot;
## from HELM on, each is its slot + 1 (rings take two positions).
enum Equip {
	MAIN_HAND, AMULET, ARMOR, OFF_HAND, BELT, RING_1, RING_2, HELM, GLOVES, PANTS, BOOTS, PET,
}

const EQUIP_COUNT := 12
const EQUIP_NAMES: PackedStringArray = [
	"Main hand", "Amulet", "Armor", "Off hand", "Belt", "Left ring", "Right ring", "Helm",
	"Gloves", "Pants", "Boots", "Pet",
]

## Indexed by Equip; null when empty.
var equipped: Array[ItemData] = []
var backpack: Array[ItemData] = []
var backpack_size: int
## Currency for refining items (Geon).
var stones: int = 0
## Rare stones that make one refine attempt certain to succeed.
var blessed_stones: int = 0
## Item sets, for set bonuses (null: no sets).
var sets: SetList
var sort_mode: SortMode = SortMode.SLOT
## Stamp for the next item that arrives (ItemData.acquired).
var next_acquired: int = 1


func _init(p_backpack_size: int) -> void:
	backpack_size = p_backpack_size
	equipped.resize(EQUIP_COUNT)


## The equipment positions an item of a slot can go in.
static func positions_for(slot: int) -> PackedInt32Array:
	if slot == AffixDef.Slot.RING:
		return PackedInt32Array([Equip.RING_1, Equip.RING_2])
	if slot > AffixDef.Slot.RING:
		return PackedInt32Array([slot + 1])
	return PackedInt32Array([slot])


## Where the item is worn, or -1.
func position_of(item: ItemData) -> int:
	return equipped.find(item) if item != null else -1


func is_equipped(item: ItemData) -> bool:
	return position_of(item) >= 0


## Where equipping goes by default: an empty position the item fits, else the first.
func target_for(item: ItemData) -> int:
	var positions := positions_for(item.slot)
	for position in positions:
		if equipped[position] == null:
			return position
	return positions[0]


## Worn items that wearing item at position would take off: what's there now,
## and the off hand for a two-handed weapon (or a two-handed weapon for an
## off-hand item).
func displaced_by(item: ItemData, position: int) -> Array[ItemData]:
	var out: Array[ItemData] = []
	var current := equipped[position]
	if current != null and current != item:
		out.append(current)
	if item.two_handed:
		var off := equipped[Equip.OFF_HAND]
		if off != null and off != item:
			out.append(off)
	elif item.slot == AffixDef.Slot.OFF_HAND:
		var main := equipped[Equip.MAIN_HAND]
		if main != null and main.two_handed:
			out.append(main)
	return out


## True if the item fits position and the backpack can take what it displaces.
func can_equip(item: ItemData, position: int = -1) -> bool:
	if item.is_talisman:
		return false
	if position < 0:
		position = target_for(item)
	if not positions_for(item.slot).has(position):
		return false
	var room := backpack_size - backpack.size() + (1 if backpack.has(item) else 0)
	return displaced_by(item, position).size() <= room


## Wears an item (from the backpack or another position) at position (-1 for
## target_for()), moving what it displaces into the backpack. False if it
## can't (wrong position, or no room for what comes off).
func equip_item(item: ItemData, position: int = -1) -> bool:
	if position < 0:
		position = target_for(item)
	if not can_equip(item, position):
		return false
	var was_at := position_of(item)
	if was_at >= 0:
		equipped[was_at] = null
	var index := backpack.find(item)
	if index >= 0:
		backpack.remove_at(index)
	for other in displaced_by(item, position):
		equipped[position_of(other)] = null
		backpack.append(other)
	equipped[position] = item
	changed.emit()
	return true


## Equips a backpack item by index (see equip_item()).
func equip(backpack_index: int, position: int = -1) -> bool:
	return equip_item(backpack[backpack_index], position)


## Takes off what's at position into the backpack. False if there's no room.
func unequip(position: int) -> bool:
	var item := equipped[position]
	if item == null or backpack.size() >= backpack_size:
		return false
	equipped[position] = null
	backpack.append(item)
	changed.emit()
	return true


## An empty position the item could go in without taking anything off, or -1.
func free_position(item: ItemData) -> int:
	if item.is_talisman:
		return -1
	for position in positions_for(item.slot):
		if equipped[position] == null and displaced_by(item, position).is_empty():
			return position
	return -1


## True if add() would succeed: the item can be worn at once or the backpack has room.
func can_accept(item: ItemData) -> bool:
	return free_position(item) >= 0 or backpack.size() < backpack_size


## Wears the item if a position is free (and nothing would come off),
## otherwise stores it in the backpack. False if full.
func add(item: ItemData) -> bool:
	if item.acquired <= 0:
		item.acquired = next_acquired
		next_acquired += 1
	var position := free_position(item)
	if position >= 0:
		equipped[position] = item
		changed.emit()
		return true
	if backpack.size() >= backpack_size:
		return false
	backpack.append(item)
	changed.emit()
	return true


func discard(backpack_index: int) -> void:
	backpack.remove_at(backpack_index)
	changed.emit()


## Stones salvaging this item would give.
static func salvage_value(item: ItemData, salvage_table: PackedInt32Array) -> int:
	return salvage_table[mini(item.rarity, salvage_table.size() - 1)] + item.upgrade_level


## Salvages a backpack item by reference. Returns the stones gained (0 if absent).
func salvage_item(item: ItemData, salvage_table: PackedInt32Array) -> int:
	var index := backpack.find(item)
	return salvage(index, salvage_table) if index >= 0 else 0


## How many backpack items of a rarity (-1: every rarity) there are and what
## salvaging them all would give: [count, stones].
func salvage_all_preview(rarity: int, salvage_table: PackedInt32Array) -> Array:
	var count := 0
	var stones_total := 0
	for item in backpack:
		if rarity < 0 or item.rarity == rarity:
			count += 1
			stones_total += salvage_value(item, salvage_table)
	return [count, stones_total]


## Salvages every backpack item of one rarity (-1: every rarity). Equipped
## items are never touched. Returns the stones gained.
func salvage_all(rarity: int, salvage_table: PackedInt32Array) -> int:
	var gained := 0
	for index in range(backpack.size() - 1, -1, -1):
		if rarity < 0 or backpack[index].rarity == rarity:
			gained += salvage_value(backpack[index], salvage_table)
			backpack.remove_at(index)
	if gained > 0:
		stones += gained
		changed.emit()
	return gained


## Orders the backpack by sort_mode, talismans always last:
##   SLOT    by slot, then best rarity and refine level first
##   RARITY  best rarity first, then highest level, then slot
##   LEVEL   highest item level first, then best rarity
##   NEWEST  most recently picked up first
func sort_backpack() -> void:
	var mode := sort_mode
	backpack.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.is_talisman != b.is_talisman:
			return b.is_talisman
		match mode:
			SortMode.RARITY:
				if a.rarity != b.rarity:
					return a.rarity > b.rarity
				if a.item_level != b.item_level:
					return a.item_level > b.item_level
				return a.slot < b.slot
			SortMode.LEVEL:
				if a.item_level != b.item_level:
					return a.item_level > b.item_level
				if a.rarity != b.rarity:
					return a.rarity > b.rarity
				return a.slot < b.slot
			SortMode.NEWEST:
				return a.acquired > b.acquired
		if a.slot != b.slot:
			return a.slot < b.slot
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		return a.upgrade_level > b.upgrade_level)


## Switches to the next sort mode and sorts. Returns the new mode.
func cycle_sort() -> SortMode:
	sort_mode = ((sort_mode + 1) % SORT_NAMES.size()) as SortMode
	sort_backpack()
	changed.emit()
	return sort_mode


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


func add_blessed_stones(amount: int) -> void:
	blessed_stones += amount
	changed.emit()


## Empties everything (New Game).
func reset() -> void:
	equipped.fill(null)
	backpack.clear()
	stones = 0
	blessed_stones = 0
	changed.emit()


## Call after changing an item in place (e.g. refining it).
func notify_changed() -> void:
	changed.emit()


func total(stat: int) -> float:
	var sum := 0.0
	for item in equipped:
		if item != null:
			sum += item.value_of(stat)
	if sets != null:
		for set_index in sets.sets.size():
			var worn := set_count(set_index)
			if worn < 2:
				continue
			var def := sets.sets[set_index]
			for k in def.bonus_stats.size():
				if def.bonus_stats[k] == stat and worn >= def.bonus_pieces[k]:
					sum += def.bonus_values[k]
	return sum


## Worn pieces of a set.
func set_count(set_index: int) -> int:
	var count := 0
	for item in equipped:
		if item != null and item.set_id == set_index:
			count += 1
	return count
