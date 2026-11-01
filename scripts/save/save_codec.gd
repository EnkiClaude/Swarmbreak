class_name SaveCodec
extends RefCounted
## Turns the player's progress, inventory and zone level into a plain
## Dictionary (for JSON) and back. Decoding never trusts the data: missing
## keys fall back to defaults and out-of-range values are clamped, so an old
## or hand-edited save still loads.

const VERSION := 1
const MAX_RARITY := 5


static func encode(progress: PlayerProgress, inventory: Inventory, zone_level: int) -> Dictionary:
	var equipped: Array = []
	for item in inventory.equipped:
		equipped.append(item_to_dict(item) if item != null else null)
	var backpack: Array = []
	for item in inventory.backpack:
		backpack.append(item_to_dict(item))
	return {
		"version": VERSION,
		"zone_level": zone_level,
		"progress": {
			"level": progress.level,
			"xp": progress.xp,
			"skill_points": progress.skill_points,
			"ranks": Array(progress.ranks),
			"job": progress.job,
			"job_rank": progress.job_rank,
			"attribute_points": progress.attribute_points,
			"attributes": Array(progress.attributes),
		},
		"inventory": {
			"stones": inventory.stones,
			"blessed_stones": inventory.blessed_stones,
			"equipped": equipped,
			"backpack": backpack,
		},
	}


## Fills progress and inventory from data and returns the saved zone level.
## jobs bounds the job index; max_level and upgrade_max clamp what they say.
static func decode(data: Dictionary, progress: PlayerProgress, inventory: Inventory,
		jobs: JobTree, max_level: int, upgrade_max: int) -> int:
	var p := _dict(data.get("progress"))
	progress.level = clampi(_int(p.get("level"), 1), 1, max_level)
	progress.xp = maxf(_float(p.get("xp"), 0.0), 0.0)
	progress.skill_points = maxi(_int(p.get("skill_points"), 0), 0)
	var ranks := _array(p.get("ranks"))
	for k in progress.ranks.size():
		progress.ranks[k] = maxi(_int(ranks[k], 0), 0) if k < ranks.size() else 0
	var job := _int(p.get("job"), -1)
	progress.job = job if jobs != null and job >= 0 and job < jobs.jobs.size() else -1
	progress.job_rank = clampi(_int(p.get("job_rank"), 0), 1, 2) if progress.job >= 0 else 0
	_decode_attributes(p, progress)

	var inv := _dict(data.get("inventory"))
	inventory.stones = maxi(_int(inv.get("stones"), 0), 0)
	inventory.blessed_stones = maxi(_int(inv.get("blessed_stones"), 0), 0)
	# Equipment is saved by position. Saves from before the extra slots had
	# three (weapon, charm, armor), which are still positions 0-2.
	var equipped := _array(inv.get("equipped"))
	inventory.equipped.fill(null)
	inventory.backpack.clear()
	var unfit: Array[ItemData] = []
	for position in inventory.equipped.size():
		if position >= equipped.size() or not equipped[position] is Dictionary:
			continue
		var item := item_from_dict(equipped[position], upgrade_max)
		if not item.is_talisman and Inventory.positions_for(item.slot).has(position):
			inventory.equipped[position] = item
		else:
			unfit.append(item)
	# A two-handed weapon and an off-hand item can't both be worn.
	var main := inventory.equipped[Inventory.Equip.MAIN_HAND]
	var off := inventory.equipped[Inventory.Equip.OFF_HAND]
	if main != null and main.two_handed and off != null:
		inventory.equipped[Inventory.Equip.OFF_HAND] = null
		unfit.append(off)
	for entry in _array(inv.get("backpack")):
		if entry is Dictionary:
			unfit.append(item_from_dict(entry, upgrade_max))
	for item in unfit:
		if inventory.backpack.size() >= inventory.backpack_size:
			break
		inventory.backpack.append(item)
	return maxi(_int(data.get("zone_level"), 1), 1)


## Quest progress and states into a dictionary, for the save.
static func encode_quests(quests: QuestLog) -> Dictionary:
	return {"progress": Array(quests.progress), "states": Array(quests.states)}


## Restores quest progress; missing or odd values leave a quest fresh.
static func decode_quests(data: Variant, quests: QuestLog) -> void:
	quests.reset()
	var d := _dict(data)
	var progress := _array(d.get("progress"))
	var states := _array(d.get("states"))
	for q in quests.progress.size():
		if q < progress.size():
			quests.progress[q] = maxi(_int(progress[q], 0), 0)
		if q < states.size():
			quests.states[q] = clampi(_int(states[q], 0), QuestLog.State.ACTIVE,
					QuestLog.State.CLAIMED)


## Saves from before attributes existed get the points their level earned.
static func _decode_attributes(p: Dictionary, progress: PlayerProgress) -> void:
	progress.attributes.fill(0)
	if not p.has("attributes"):
		progress.attribute_points = progress.earned_attribute_points()
		return
	var saved := _array(p.get("attributes"))
	for k in progress.attributes.size():
		progress.attributes[k] = maxi(_int(saved[k], 0), 0) if k < saved.size() else 0
	progress.attribute_points = maxi(_int(p.get("attribute_points"), 0), 0)


static func item_to_dict(item: ItemData) -> Dictionary:
	return {
		"slot": item.slot,
		"kind": item.kind,
		"two_handed": item.two_handed,
		"rarity": item.rarity,
		"name": item.item_name,
		"stats": Array(item.stats),
		"values": Array(item.values),
		"item_level": item.item_level,
		"upgrade_level": item.upgrade_level,
		"upgrade_bonus": item.upgrade_bonus,
		"fail_streak": item.fail_streak,
		"pet_type": item.pet_type,
		"pet_level": item.pet_level,
		"pet_xp": item.pet_xp,
		"set_id": item.set_id,
		"talisman": item.is_talisman,
		"talisman_stats": Array(item.talisman_stats),
		"talisman_values": Array(item.talisman_values),
		"talisman_sockets_used": item.talisman_sockets_used,
	}


static func item_from_dict(d: Dictionary, upgrade_max: int) -> ItemData:
	var item := ItemData.new()
	item.slot = clampi(_int(d.get("slot"), 0), 0, AffixDef.Slot.size() - 1)
	item.kind = maxi(_int(d.get("kind"), -1), -1)
	item.two_handed = d.get("two_handed", false) == true
	item.rarity = clampi(_int(d.get("rarity"), 0), 0, MAX_RARITY)
	item.item_name = str(d.get("name", "Item"))
	var stats := _array(d.get("stats"))
	var values := _array(d.get("values"))
	for k in mini(stats.size(), values.size()):
		var stat := _int(stats[k], -1)
		if stat >= 0 and stat < PlayerStat.COUNT:
			item.stats.append(stat)
			item.values.append(_float(values[k], 0.0))
	item.item_level = maxi(_int(d.get("item_level"), 1), 1)
	item.upgrade_level = clampi(_int(d.get("upgrade_level"), 0), 0, upgrade_max)
	item.upgrade_bonus = maxf(_float(d.get("upgrade_bonus"), 0.0), 0.0)
	item.fail_streak = maxi(_int(d.get("fail_streak"), 0), 0)
	item.pet_type = _int(d.get("pet_type"), -1)
	item.pet_level = maxi(_int(d.get("pet_level"), 1), 1)
	item.pet_xp = maxf(_float(d.get("pet_xp"), 0.0), 0.0)
	item.set_id = maxi(_int(d.get("set_id"), -1), -1)
	item.is_talisman = d.get("talisman", false) == true
	var t_stats := _array(d.get("talisman_stats"))
	var t_values := _array(d.get("talisman_values"))
	for k in mini(t_stats.size(), t_values.size()):
		var stat := _int(t_stats[k], -1)
		if stat >= 0 and stat < PlayerStat.COUNT:
			item.talisman_stats.append(stat)
			item.talisman_values.append(_float(t_values[k], 0.0))
	item.talisman_sockets_used = maxi(_int(d.get("talisman_sockets_used"), 0), 0)
	return item


# JSON turns every number into a float and anything can be missing, so read
# each value defensively.
static func _int(v: Variant, fallback: int) -> int:
	if v is int or v is float:
		return int(v)
	return fallback


static func _float(v: Variant, fallback: float) -> float:
	if v is int or v is float:
		return float(v)
	return fallback


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _array(v: Variant) -> Array:
	return v if v is Array else []
